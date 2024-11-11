# Thread Dispatching

Resync provides 3 primary ways to dispatch tasks to the thread pool:

1. One task at a time
2. In batches of tasks from a queue
3. Dynamically as tasks are added

The method you choose depends on the nature of your tasks and how you want to manage them.
Additionally, you can disable thread state tracking to reduce overhead when you don't need to track the state of tasks or know when they complete.

## Choosing the Right Method

Note: The arguments used for dispatching threads in the code examples in this section are arbitrary and can be replaced with any values you need to pass to your task function.
They do not affect how the thread pool dispatches the tasks.

### One at a Time

The simplest way to dispatch tasks is to use the `ThreadPool:Dispatch` method. This method takes a variadic list of arguments to pass to the task function. The task function is then executed on the thread pool when a worker thread is available.
This method gives you the finest control over task execution, allowing you to dispatch individual tasks as needed.

```luau
-- Yields until the task is complete
myThreadPool:Dispatch("synchronous dispatch", 2, "arg")

-- Only yields until the task is dispatched, does not wait for it to complete
myThreadPool:DispatchAsync("asynchronous dispatch", 3, "arg")
```

### In Batches

If you have a known group of tasks that you want to execute in parallel, you can use the `ThreadPool:Add` or `ThreadPool:AddBatch` and `ThreadPool:DispatchAll` methods. These methods allow you to add tasks to a queue and then dispatch them all at once.
This can be useful if you want to execute a batch of tasks in parallel and then wait for all of them to complete before continuing.

```luau
-- Add tasks to the queue
myThreadPool:Add("task 1", 1)
myThreadPool:Add("task 2", 2)
myThreadPool:Add("task 3", 3)

-- Add a batch of tasks to the queue
myThreadPool:AddBatch({
    {"task 4", 4},
    {"task 5", 5},
    {"task 6", 6},
})

-- Dispatch all tasks in the queue and yield until they are all complete
myThreadPool:DispatchAll()

-- Asynchronous version of DispatchAll will only yield until all tasks are dispatched
myThreadPool:DispatchAllAsync()
```

### Dynamically

For use cases where tasks are added to the queue over time, you can use the `ThreadPool:Add` or `ThreadPool:AddBatch` methods and set `ThreadPool.AutoDispatch` to `true`. This will automatically dispatch tasks as they are added to the queue.
This approach is useful when you have a continuous stream of tasks that need to be executed in parallel, such as procedural generation.

```luau
-- Enable auto dispatching
myThreadPool.AutoDispatch = true

-- Add tasks to the queue
myThreadPool:Add("task 1", 1)
myThreadPool:Add("task 2", 2)
myThreadPool:Add("task 3", 3)

-- Add a batch of tasks to the queue
myThreadPool:AddBatch({
    {"task 4", 4},
    {"task 5", 5},
    {"task 6", 6},
})

-- There is no need to call DispatchAll, added tasks will be dispatched automatically
```

!!! note
    Unlike the other methods, dynamically dispatching tasks does not provide a way to wait for all tasks to complete. You can use `ThreadPool:WaitForCompletion`, but keep in mind that in the case of constant task addition, this method may cause your main thread to yield indefinitely if the task queue is never completed.

## Thread State Tracking

!!! danger "Experimental Feature"
    Thread state tracking is still experimental. If the current implementation is found to be stable, `ThreadPool.AllowDispatchingToBusyThreads` may be removed in a future version of Resync.

By default, Resync tracks the state of each task dispatched to the thread pool. This allows you to wait for tasks to complete, and allows Resync to only dispatch tasks to threads that are not currently busy.
This tracking and management of thread state can introduce some overhead as tasks are dispatched and completed. If you don't need to track the state of tasks or know when they complete, you can disable thread state tracking by setting `ThreadPool.AllowDispatchingToBusyThreads` to `true`.

```luau
-- Create a thread pool with 2 threads and thread state tracking disabled
local myThreadPool = ThreadPool.new(myWorkerScript, 2, "FIFO", true)
-- You can also disable thread state tracking after creating the thread pool
-- by setting myThreadPool.AllowDispatchingToBusyThreads = true

-- Add more tasks than the thread pool size
for i = 1, 10 do
    myThreadPool:Add("task " .. i, i)
end

-- Dispatch all tasks in the queue
myThreadPool:DispatchAll()

-- Since thread state tracking is disabled, all tasks will instantly be evenly
-- distributed to the 2 worker threads
```

!!! warning
    Disabling thread state tracking will cause `ThreadPool:WaitForFreeThread` and `ThreadPool:WaitForThread` to return immediately, even if all threads are busy. `ThreadPool:WaitForCompletion` and synchronous dispatch methods will wait for the task queue to be empty, but may not reliably wait for all threads to complete their tasks after the queue is empty.

### Benefits of Thread State Tracking

- Allows tracking of task state and completion. This makes it possible to fully use Resync's synchronous API.
- Ensures that tasks are dispatched in order and only to threads that are not busy.

### Drawbacks of Thread State Tracking

- Increased performance overhead when dispatching tasks. Becomes apparent when the number of tasks dispatched exceeds the thread pool size.
