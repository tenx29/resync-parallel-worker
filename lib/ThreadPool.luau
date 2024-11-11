--!native
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ThreadPool = {}
ThreadPool.__index = ThreadPool

local IsClient = RunService:IsClient()

-- Scripts used to run parallel threads
local ServerHandler: Script = (script.Parent :: Instance):WaitForChild("ServerHandler") :: Script
local ClientHandler: Script = (script.Parent :: Instance):WaitForChild("ClientHandler") :: Script

export type AggregatedThreadStates = {Ready: number, Running: number, Setup: number}

-- Task queue types
-- FIFO: First-In-First-Out. Threads are dispatched in the order they were added to the queue.
-- LIFO: Last-In-First-Out. The last thread added to the queue is dispatched first.
export type QueueType = "FIFO" | "LIFO"

-- Add a new thread to a thread pool and wait for it to initialize
local function AddThread(self: any, worker: ModuleScript)
    local id = #self.Actors + 1
    local actor = Instance.new("Actor")
    actor.Name = "Worker" .. tostring(id)
    actor.Parent = self.ThreadContainer
    actor:SetAttribute("Id", id)
    table.insert(self.Actors, actor)

    -- Get the thread done event and connect to it once to avoid race conditions during initialization
    local done: BindableEvent = self.ThreadContainer:FindFirstChildOfClass("BindableEvent")
    local lastDoneId, success, err
    done.Event:Once(function(threadId, s, e)
        lastDoneId = threadId
        success = s
        err = e
    end)
    
    -- Add the handler script to the actor. Once initialized, the handler will fire the "ThreadDone" event.
    worker:Clone().Parent = actor
    local handler = if IsClient then ClientHandler:Clone() else ServerHandler:Clone()
    handler.Parent = actor
    
    -- Wait for the handler to initialize
    while lastDoneId ~= id do
        lastDoneId, success, err = done.Event:Wait()
    end

    -- Throw an error if the worker failed to initialize
    if not success then
        error(`Thread worker {id} failed to initialize: {err}`)
    end

    -- Initialize the worker state and let the thread pool know that the worker is ready
    self.WorkerState[id] = 0
    self._threadFreedEvent:Fire(id)
end

-- Get the thread pool container object and create it if it doesn't exist
local function GetThreadPoolContainer(): Folder
    local ContainerParent = if IsClient then Players.LocalPlayer:WaitForChild("PlayerScripts") else ServerScriptService
    local ServerContainerName = "ManagedThreadPools"
    local ThreadPoolsContainer: Folder = ContainerParent:FindFirstChild(ServerContainerName) or Instance.new("Folder")
    ThreadPoolsContainer.Name = ServerContainerName
    ThreadPoolsContainer.Parent = ContainerParent
    return ThreadPoolsContainer
end

--[[
    Create a new thread pool with the given worker script and thread count.
    
    If allowDispatchingToBusyThreads is true, the thread pool can dispatch new tasks to threads that are already running a task.
    This can reduce overhead in cases where knowing when a task finishes is not important, but disables the ability to wait for threads to finish.
]]
function ThreadPool.new(worker: ModuleScript, threads: number, queueType: QueueType?, allowDispatchingToBusyThreads: boolean?): ThreadPool
    assert(typeof(worker) == "Instance" and worker:IsA("ModuleScript"), "A ModuleScript that returns a function must be provided as a thread worker.")
    assert(typeof(threads) == "number" and threads % 1 == 0, "Thread count must be a positive integer.")
    
    local self = setmetatable({}, ThreadPool)
    
    self.QueueType = (queueType or "FIFO") :: QueueType
    self.Worker = worker
    self.ThreadCount = threads
    self.Actors = {}
    self.WorkerState = SharedTable.new()
    self.ThreadContainer = Instance.new("Folder")
    self.ThreadContainer.Name = worker.Name .. "Pool"
    self.ThreadContainer.Parent = GetThreadPoolContainer()
    self.TaskQueue = {} :: {{any}}
    self.PoolId = HttpService:GenerateGUID(false)
    self.AutoDispatch = false
    self.AllowDispatchingToBusyThreads = allowDispatchingToBusyThreads or false

    self._lastDispatchedThread = 0
    self._batchDispatchInProgress = false   -- Prevents multiple dispatches from happening at the same time to avoid assigning multiple tasks to the same thread
    self._threadFreedEvent = Instance.new("BindableEvent")

    -- BindableEvent used to notify this module when a thread is done
    local ThreadDoneEvent = Instance.new("BindableEvent")
    ThreadDoneEvent.Name = "ThreadDone"
    ThreadDoneEvent.Parent = self.ThreadContainer

    -- Connect thread done event
    self._threadDoneConnection = ThreadDoneEvent.Event:Connect(function(threadId: number, success: boolean, err: string?)
        -- Ignore uninitialized threads
        if not self.WorkerState[threadId] then
            return
        end

        -- Update the number of tasks the thread is running
        local oldState = SharedTable.increment(self.WorkerState, threadId, -1)
        if oldState == 1 then
            self._threadFreedEvent:Fire(threadId)
        end
        if not success then
            warn(`Thread {threadId} failed with error: {err}`)
        end
    end)

    -- Create the thread actors
    for _ = 1, threads do
        AddThread(self, worker)
    end

    return self
end

-- Remove an item from the queue based on the queue type
local function TakeFromQueue(queue: {any}, queueType: QueueType): any
    if queueType == "FIFO" then
        return table.remove(queue, 1)
    else
        return table.remove(queue)
    end
end

--[[
    Dispose of the thread pool.
    Waits for any running threads to finish before destroying the pool.
    Yields the current thread until the pool is destroyed.
]]
function ThreadPool:Destroy()
    self.AutoDispatch = false
    self.TaskQueue = {}
    self:WaitForCompletion(false)
    self.TaskQueue = nil :: any
    self._threadDoneConnection:Disconnect()
    self._threadDoneConnection = nil :: any
    self.ThreadContainer:Destroy()
    self.ThreadContainer = nil :: any
    self.WorkerState = nil
    self.Actors = nil
    self.Worker = nil
    self._threadFreedEvent:Destroy()
    self._threadFreedEvent = nil :: any
    
    -- Remove any remaining members
    for key, _ in pairs(self) do
        self[key] = nil
    end

    setmetatable(self, nil)
end

--[[
    Inserts a new item into the task queue. A thread will be dispatched with the given arguments.
    
    If AutoDispatch is enabled, the thread will be dispatched immediately along with any other queued threads.
]]
function ThreadPool:Add(...)
    table.insert(self.TaskQueue, {...})
    if self.AutoDispatch and not self._batchDispatchInProgress then
        task.spawn(function()
            self:DispatchAllAsync()
        end)
    end
end

--[[
    Inserts a batch of items into the task queue. Threads will be dispatched with the given arguments.
    If AutoDispatch is enabled, the threads will be dispatched immediately along with any other queued threads.
]]
function ThreadPool:AddBatch(batch: {{any}})
    for _, args in batch do
        self:Add(unpack(args))
    end
end

-- Clears the task queue. Does not stop running threads.
function ThreadPool:Clear()
    self.TaskQueue = {}
end

-- Changes the number of threads in the pool. If the new count is less than the current count, the extra threads will be removed.
function ThreadPool:Resize(newThreadCount: number)
    assert(newThreadCount > 0 and newThreadCount % 1 == 0, "Thread count must be a positive integer.")
    self:WaitForCompletion(true)
    if newThreadCount < self.ThreadCount then
        for i = newThreadCount + 1, self.ThreadCount do
            self.Actors[i]:Destroy()
            self.Actors[i] = nil
            self.WorkerState[i] = nil
        end
    elseif newThreadCount > self.ThreadCount then
        for _ = self.ThreadCount + 1, newThreadCount do
            AddThread(self, self.Worker)
        end
    end
    self.ThreadCount = newThreadCount
end

--[[
    Returns the next free thread ID. If no threads are free, returns nil.
    Uses a round-robin dispatch policy.
    If dispatching to busy threads is allowed, the function will return the next initialized thread even if it's running.
]]
function ThreadPool:GetNextFreeThread(): number?
    for i = 1, self.ThreadCount do
        local thread = i + self._lastDispatchedThread :: number
        local finalThreadId = (thread - 1) % self.ThreadCount + 1
        local workerState = self.WorkerState[finalThreadId]
        if workerState == 0 or (workerState ~= nil and self.AllowDispatchingToBusyThreads) then
            return finalThreadId
        end
    end

    return nil
end

-- Wait until any thread is free and return the associated WorkerInfo and ID
function ThreadPool:WaitForFreeThread()
    local id = self:GetNextFreeThread()
    if not id then
        id = self._threadFreedEvent.Event:Wait()
    end
    return id
end

-- Returns a tuple containing the aggregated thread states and the number of tasks each thread is running.
function ThreadPool:GetThreadStates(): (AggregatedThreadStates, {number})
    -- Aggregate thread states
    local totals = {
        Ready = 0,
        Running = 0,
        Setup = 0,
    }
    local states = {} :: {number}   -- How many tasks each thread is running, or -1 if the thread is not initialized
    for i, workerState in self.WorkerState do
        states[i] = workerState or -1
        if workerState == nil then
            totals.Setup += 1
        elseif workerState == 0 then
            totals.Ready += 1
        else
            totals.Running += 1
        end
    end
    return totals, states
end

--[[
    Yields the current thread until the specified thread is done.
    Note that other tasks may be dispatched soon after the thread finishes, so it is not guaranteed that the thread will be free after this function returns.
    If AllowDispatchingToBusyThreads is true, the function will return immediately.
]]
function ThreadPool:WaitForThread(threadId: number)
    if self.AllowDispatchingToBusyThreads then
        return
    end
    local id = nil
    while id ~= threadId and self.WorkerState[threadId] and self.WorkerState[threadId] > 0 do
        id = self._threadFreedEvent.Event:Wait()
    end
    return
end

--[[
    Waits for all threads to finish. If requireEmptyQueue is true, the function will also wait for the task queue to be empty.
    requireEmptyQueue is true by default.
    If AllowDispatchingToBusyThreads is true, the function may return before all threads are done if the task queue is empty.
]]
function ThreadPool:WaitForCompletion(requireEmptyQueue: boolean?)
    local threadCounts = self:GetThreadStates()
    local requireQueue = if requireEmptyQueue == nil then true else requireEmptyQueue
    while (requireQueue and self._batchDispatchInProgress and #self.TaskQueue > 0) or threadCounts.Running > 0 do
        self._threadFreedEvent.Event:Wait()
        threadCounts = self:GetThreadStates()
    end
end

--[[
    Dispatches a single thread with the given arguments.
    Returns the thread worker ID. Yields the current thread until the thread is dispatched.
]]
function ThreadPool:DispatchAsync(...: any): number
    -- Find and reserve a free thread
    local threadId: number = self:WaitForFreeThread()
    SharedTable.increment(self.WorkerState, threadId, 1)
    local actor = self.Actors[threadId]
    self._lastDispatchedThread = threadId
    actor:SendMessage("dispatch", actor, threadId, ...)
    return threadId
end

--[[
    Dispatches a single thread with the given arguments.
    Returns the thread worker ID.
]]
function ThreadPool:Dispatch(...: any)
    local threadId = self:DispatchAsync(...)
    self:WaitForThread(threadId)
    return threadId
end

--[[
    Dispatches the next item in the task queue.
    Yields the current thread until the thread is dispatched.
    Returns the ID of the dispatched thread.
]]
function ThreadPool:DispatchNextAsync()
    if #self.TaskQueue == 0 then
        return
    end
    local threadId = self:WaitForFreeThread()
    SharedTable.increment(self.WorkerState, threadId, 1)
    local args = TakeFromQueue(self.TaskQueue, self.QueueType)
    local actor = self.Actors[threadId]
    self._lastDispatchedThread = threadId
    actor:SendMessage("dispatch", actor, threadId, unpack(args))
    return threadId
end

--[[
    Dispatches the next item in the task queue.
    Yields the current thread until the thread is completed.
    Returns the ID of the dispatched thread.
]]
    function ThreadPool:DispatchNext()
    local threadId = self:DispatchNextAsync()
    self:WaitForThread(threadId)
    return threadId
end

--[[
    Dispatches as many items from the task queue as immediately possible.
    Yields the current thread until all threads are dispatched.
    Returns the number of dispatched threads.
]]
function ThreadPool:DispatchToAllFreeThreadsAsync()
    local dispatchedThreads = 0
    for _ = 1, self.ThreadCount do
        if #self.TaskQueue == 0 then
            break
        end

        local threadId = self:GetNextFreeThread()
        if not threadId then
            break
        end

        SharedTable.increment(self.WorkerState, threadId, 1)
        local args = TakeFromQueue(self.TaskQueue, self.QueueType)
        local actor = self.Actors[threadId]
        self._lastDispatchedThread = threadId
        actor:SendMessage("dispatch", actor, threadId, unpack(args))
        dispatchedThreads += 1
    end
    return dispatchedThreads
end

--[[
    Dispatches as many items from the task queue as immediately possible.
    Yields the current thread until all threads are completed.
    Returns the number of dispatched threads.
]]
function ThreadPool:DispatchToAllFreeThreads()
    local dispatchedThreads = self:DispatchToAllFreeThreadsAsync()
    self:WaitForCompletion(false)
    return dispatchedThreads
end

--[[
    Dispatches all items in the task queue until the queue is empty.
    Yields the current thread until all threads are dispatched.
    Returns the number of dispatched threads.
]]
function ThreadPool:DispatchAllAsync()
    if self._batchDispatchInProgress then
        return 0
    end
    self._batchDispatchInProgress = true
    local dispatchedThreads = 0
    while #self.TaskQueue > 0 do
        dispatchedThreads += self:DispatchToAllFreeThreadsAsync()
        if #self.TaskQueue == 0 then
            break
        end
        self:WaitForFreeThread()
    end
    self._batchDispatchInProgress = false
    return dispatchedThreads
end

--[[
    Dispatches all items in the task queue until the queue is empty.
    Yields the current thread until all threads are completed.
    Returns the number of dispatched threads.
]]
function ThreadPool:DispatchAll()
    local dispatchedThreads = self:DispatchAllAsync()
    self:WaitForCompletion()
    return dispatchedThreads
end

export type ThreadPool = typeof(ThreadPool.new(Instance.new("ModuleScript"), 0))

return ThreadPool