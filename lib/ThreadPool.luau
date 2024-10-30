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

export type ActorState = "Ready" | "Running"

-- Dispatch policy types
-- RoundRobin: Dispatches threads in a round-robin fashion. If the next worker is not ready, it will skip to the next one.
-- FirstAvailable: Uses the first available worker to dispatch the next thread.
export type DispatchPolicy = "RoundRobin" | "FirstAvailable"

-- Task queue types
-- FIFO: First-In-First-Out. Threads are dispatched in the order they were added to the queue.
-- LIFO: Last-In-First-Out. The last thread added to the queue is dispatched first.
export type QueueType = "FIFO" | "LIFO"

local function AddThread(self: any, worker: ModuleScript)
    local actor = Instance.new("Actor")
    actor.Name = tostring(#self.Actors + 1)
    actor.Parent = self.ThreadContainer
    local handler = if IsClient then ClientHandler:Clone() else ServerHandler:Clone()
    handler.Parent = actor
    worker:Clone().Parent = actor
    table.insert(self.Actors, actor)
    self.WorkerState[#self.Actors] = "Ready"
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

function ThreadPool.new(worker: ModuleScript, threads: number, policy: DispatchPolicy?, queueType: QueueType?): ThreadPool
    assert(typeof(worker) == "Instance" and worker:IsA("ModuleScript"), "A ModuleScript that returns a function must be provided as a thread worker.")
    assert(typeof(threads) == "number" and threads % 1 == 0, "Thread count must be a positive integer.")
    
    local self = setmetatable({}, ThreadPool)
    
    self.DispatchPolicy = (policy or "FirstAvailable") :: DispatchPolicy
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

    self._lastDispatchedThread = 0
    self._batchDispatchInProgress = false   -- Prevents multiple dispatches from happening at the same time to avoid assigning multiple tasks to the same thread
    self._threadFreedEvent = Instance.new("BindableEvent")

    -- BindableEvent used to notify this module when a thread is done
    self.ThreadDoneEvent = Instance.new("BindableEvent")
    self.ThreadDoneEvent.Name = "ThreadDone"
    self.ThreadDoneEvent.Parent = self.ThreadContainer

    -- Create the thread actors
    for _ = 1, threads do
        AddThread(self, worker)
    end

    -- Connect thread done event
    self._threadDoneConnection = self.ThreadDoneEvent.Event:Connect(function(threadId: number, success: boolean, err: string?)
        self.WorkerState[threadId] = "Ready"
        self._threadFreedEvent:Fire(threadId)
        if not success then
            warn(`Thread {threadId} failed with error: {err}`)
        end
    end)

    return self
end

local function TakeFromQueue(queue: {any}, queueType: QueueType): any
    if queueType == "FIFO" then
        return table.remove(queue, 1)
    else
        return table.remove(queue)
    end
end

-- Dispose of the thread pool.
-- Waits for any running threads to finish before destroying the pool.
-- Yields the current thread until the pool is destroyed.
function ThreadPool:Destroy()
    self.AutoDispatch = false
    self.TaskQueue = {}
    self:WaitForCompletion(false)
    self.TaskQueue = nil :: any
    self._threadDoneConnection:Disconnect()
    self._threadDoneConnection = nil :: any
    self.ThreadDoneEvent:Destroy()
    self.ThreadDoneEvent = nil :: any
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

-- Inserts a new item into the task queue. A thread will be dispatched with the given arguments.
-- If AutoDispatch is enabled, the thread will be dispatched immediately along with any other queued threads.
function ThreadPool:Add(...)
    table.insert(self.TaskQueue, {...})
    if self.AutoDispatch and not self._batchDispatchInProgress then
        task.spawn(function()
            self:DispatchAllAsync()
        end)
    end
end

-- Inserts a batch of items into the task queue. Threads will be dispatched with the given arguments.
-- If AutoDispatch is enabled, the threads will be dispatched immediately along with any other queued threads.
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

-- Returns the next free worker info and thread ID based on the dispatch policy.
-- Returns nil if all threads are busy.
function ThreadPool:GetNextFreeThread(): number?
    if self.DispatchPolicy == "RoundRobin" then
        for i = 1, self.ThreadCount do
            local thread = i + self._lastDispatchedThread :: number
            local finalThreadId = (thread - 1) % self.ThreadCount + 1
            local workerState = self.WorkerState[finalThreadId]
            if workerState == "Ready" then
                return finalThreadId
            end
        end
    elseif self.DispatchPolicy == "FirstAvailable" then
        for i, workerState in self.WorkerState do
            if workerState == "Ready" then
                return i
            end
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

-- Count the number of threads in each state
function ThreadPool:GetThreadStates(): {[ThreadState]: number}
    local states = {
        Ready = {},
        Running = {},
        Done = {},
    }
    local totals = {
        Ready = 0,
        Running = 0,
        Done = 0,
    }
    for i, workerState in self.WorkerState do
        table.insert(states[workerState], i)
        totals[workerState] += 1
    end
    return states, totals
end

-- Yields the current thread until the specified thread is done.
-- Note that other tasks may be dispatched soon after the thread finishes,
-- so it is not guaranteed that the thread will be free after this function returns.
function ThreadPool:WaitForThread(threadId: number)
    local id = nil
    while id ~= threadId and self.WorkerState[threadId] == "Running" do
        id = self._threadFreedEvent.Event:Wait()
    end
    return
end

-- Wait for all threads to finish. If requireEmptyQueue is true, the function will also wait for the task queue to be empty.
-- requireEmptyQueue is true by default.
function ThreadPool:WaitForCompletion(requireEmptyQueue: boolean?)
    local _, threadCounts = self:GetThreadStates()
    local requireQueue = if requireEmptyQueue == nil then true else requireEmptyQueue
    while (requireQueue and #self.TaskQueue > 0) or threadCounts.Running > 0 do
        self._threadFreedEvent.Event:Wait()
        _, threadCounts = self:GetThreadStates()
    end
end

-- Dispatches a single thread with the given arguments.
-- Returns the thread worker ID. Yields the current thread until the thread is dispatched.
function ThreadPool:DispatchAsync(...: any): number
    -- Find and reserve a free thread
    local threadId = self:WaitForFreeThread()
    self.WorkerState[threadId] = "Running"
    local actor = self.Actors[threadId]
    self._lastDispatchedThread = threadId
    actor:SendMessage("dispatch", self.ThreadDoneEvent, actor, threadId, ...)
    return threadId
end

-- Dispatches a single thread with the given arguments.
-- Returns the thread worker ID.
function ThreadPool:Dispatch(...: any)
    local threadId = self:DispatchAsync(...)
    self:WaitForThread(threadId)
    return threadId
end

-- Dispatches the next item in the task queue.
-- Yields the current thread until the thread is dispatched.
-- Returns the ID of the dispatched thread.
function ThreadPool:DispatchNextAsync()
    if #self.TaskQueue == 0 then
        return
    end
    local threadId = self:WaitForFreeThread()
    self.WorkerState[threadId] = "Running"
    local args = TakeFromQueue(self.TaskQueue, self.QueueType)
    local actor = self.Actors[threadId]
    self._lastDispatchedThread = threadId
    actor:SendMessage("dispatch", self.ThreadDoneEvent, actor, threadId, unpack(args))
    return threadId
end

-- Dispatches the next item in the task queue.
-- Yields the current thread until the thread is completed.
-- Returns the ID of the dispatched thread.
function ThreadPool:DispatchNext()
    local threadId = self:DispatchNextAsync()
    self:WaitForThread(threadId)
    return threadId
end

-- Dispatches as many items from the task queue as immediately possible.
-- Yields the current thread until all threads are dispatched.
-- Returns the number of dispatched threads.
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

        assert(self.WorkerState[threadId] == "Ready", `Returned thread ({threadId}) is not ready. This should not happen.`)
        self.WorkerState[threadId] = "Running"
        local args = TakeFromQueue(self.TaskQueue, self.QueueType)
        local actor = self.Actors[threadId]
        self._lastDispatchedThread = threadId
        actor:SendMessage("dispatch", self.ThreadDoneEvent, actor, threadId, unpack(args))
        dispatchedThreads += 1
    end
    return dispatchedThreads
end

-- Dispatches as many items from the task queue as immediately possible.
-- Yields the current thread until all threads are completed.
-- Returns the number of dispatched threads.
function ThreadPool:DispatchToAllFreeThreads()
    local dispatchedThreads = self:DispatchToAllFreeThreadsAsync()
    self:WaitForCompletion(false)
    return dispatchedThreads
end

-- Dispatches all items in the task queue until the queue is empty.
-- Yields the current thread until all threads are dispatched.
-- Returns the number of dispatched threads.
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

-- Dispatches all items in the task queue until the queue is empty.
-- Yields the current thread until all threads are completed.
-- Returns the number of dispatched threads.
function ThreadPool:DispatchAll()
    local dispatchedThreads = self:DispatchAllAsync()
    self:WaitForCompletion()
    return dispatchedThreads
end

export type ThreadPool = typeof(ThreadPool.new(Instance.new("ModuleScript"), 0))

return ThreadPool