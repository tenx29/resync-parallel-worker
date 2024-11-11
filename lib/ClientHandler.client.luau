local Actor = script:GetActor()

function init()
    local id = Actor:GetAttribute("Id")
    local done = script.Parent.Parent:WaitForChild("ThreadDone") :: BindableEvent
    
    -- Ensure the worker module is loaded
    local worker = script.Parent:FindFirstChildOfClass("ModuleScript")
    if not worker then
        done:Fire(id, false, "worker module not found")
        return
    end

    -- Ensure the worker module returns a function
    local workerFunction = require(worker)
    if typeof(workerFunction) ~= "function" then
        done:Fire(id, false, `expected worker module to return a function, got {typeof(workerFunction)}`)
        return
    end

    Actor:BindToMessage("dispatch", function(actor: Actor, threadId: number, ...: any)
        -- Handle errors thrown by the worker
        local success, trace = xpcall(function(...)
            workerFunction(actor, threadId, ...)
        end, debug.traceback, ...)

        -- Sketchy workaround to exceeding re-entrancy depth for ActorMessageEvent if the worker function doesn't desynchronize
        task.desynchronize()

        -- Synchronize the thread and return the results
        task.synchronize()
        done:Fire(threadId, success, trace)
    end)

    -- Let the thread pool know that the worker is ready
    done:Fire(id, true, nil)
end

if Actor then
    init()
end