local Actor = script:GetActor()

function init()
    local done = script.Parent.Parent:WaitForChild("ThreadDone") :: BindableEvent
    Actor:BindToMessage("dispatch", function(actor: Actor, threadId: number, ...: any)
        local worker = (script.Parent :: Instance):FindFirstChildOfClass("ModuleScript")

        -- Handle errors thrown by the worker
        local success, trace = xpcall(function(...)
            require(worker)(actor, threadId, ...)
        end, debug.traceback, ...)

        -- Sketchy workaround to exceeding re-entrancy depth for ActorMessageEvent if the worker function doesn't desynchronize
        task.desynchronize()

        -- Synchronize the thread and return the results
        task.synchronize()
        done:Fire(threadId, success, trace)
    end)

    -- Let the thread pool know that the worker is ready
    done:Fire(Actor:GetAttribute("Id"), true, nil)
end

if Actor then
    init()
end