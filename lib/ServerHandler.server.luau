local Actor = script:GetActor()

function init()
    Actor:BindToMessage("dispatch", function(done: BindableEvent, actor: Actor, threadId: number, data: any)
        local worker = (script.Parent :: Instance):FindFirstChildOfClass("ModuleScript")

        -- Handle errors thrown by the worker
        local success, trace = xpcall(function()
            require(worker)(actor, threadId, data)
        end, debug.traceback)

        -- Sketchy workaround to exceeding re-entrancy depth for ActorMessageEvent if the worker function doesn't desynchronize
        task.desynchronize()

        -- Synchronize the thread and return the results
        task.synchronize()
        done:Fire(threadId, success, trace)
    end)
end

if Actor then
    init()
end