# ThreadPool

A ThreadPool is a collection of threads that can be used to execute tasks concurrently.

## Constructor

### new

```luau
(worker: ModuleScript, threads: number, queueType: QueueType?, allowDispatchingToBusyThreads: boolean?): ThreadPool
```

Creates a new ThreadPool using the specified worker module and number of threads. All threads are initialized automatically when the ThreadPool is created. Yields the current thread until all threads are initialized.

- `worker` should be a [ModuleScript](https://create.roblox.com/docs/reference/engine/classes/ModuleScript) that returns a function. When a task is dispatched, the function is called with the current thread's [Actor](https://create.roblox.com/docs/reference/engine/classes/Actor), the thread worker's index (1-indexed), and any additional arguments passed to the dispatch method.
- `threads` is the number of threads to create in the pool. Should be a positive integer.
- `queueType` is an optional parameter that specifies the type of queue to use. If not provided, the default queue type is `"FIFO"`. Supported queue types are `"FIFO"` and `"LIFO"`.
- `allowDispatchingToBusyThreads` is an optional parameter that specifies whether tasks can be dispatched to threads that are already busy. If not provided, the default value is `false`.
  Setting this to `true` will disable Resync's [Thread State Tracking](../getting-started/thread-dispatching.md#thread-state-tracking) feature, which can improve performance in some cases.

---

## Properties

### Actors

[`{Actor}`](https://create.roblox.com/docs/reference/engine/classes/Actor)

Table of all the actors in the thread pool. Should not be modified.

### AllowDispatchingToBusyThreads

[`boolean`](https://create.roblox.com/docs/luau/booleans)

Whether tasks can be dispatched to threads that are already executing a task. If `true`, tasks will be dispatched to the next initialized thread in a round-robin fashion even if the thread is busy. If `false`, busy threads will be skipped until an idle thread is found, or the thread pool will wait until a thread becomes available.

!!! important
    Setting this property to `true` will disable Resync's [Thread State Tracking](../getting-started/thread-dispatching.md#thread-state-tracking) feature, which can improve performance, but without it Resync will not guarantee that all threads have finished their tasks once the task queue is empty. Resync should still be able to keep track of this internally, but won't strictly enforce it.

!!! danger "Experimental Feature"
    This property may be removed in a future version of Resync if Resync's thread state tracking is found to be stable without this restriction.

### AutoDispatch

[`boolean`](https://create.roblox.com/docs/luau/booleans)

Whether the thread pool should automatically dispatch tasks when they are added to the queue. Respects the `AllowDispatchingToBusyThreads` property.

### PoolId

[`string`](https://create.roblox.com/docs/luau/strings)

A unique identifier for the thread pool. Currently unused.

### QueueType

[`QueueType`](types.md#queuetype)

The type of task queue to use for the thread pool. Supported queue types are `"FIFO"` and `"LIFO"`.

### TaskQueue

[`{{any}}`](https://create.roblox.com/docs/luau/tables)

Table of arrays containing the arguments to pass to the worker function when a task is dispatched. Should not be modified.

### ThreadContainer

[`Folder`](https://create.roblox.com/docs/reference/engine/classes/Folder)

The folder containing the actors and worker scripts for the thread pool. Should not be modified.

### ThreadCount

[`number`](https://create.roblox.com/docs/luau/numbers)

The number of threads in the thread pool. Should not be modified directly. Use the [`Resize`](#resize) method to change the number of threads.

### Worker

[`ModuleScript`](https://create.roblox.com/docs/reference/engine/classes/ModuleScript)

The worker module used by the thread pool. Should not be modified.

### WorkerState

[`SharedTable<number>`](https://create.roblox.com/docs/reference/engine/datatypes/SharedTable)

A SharedTable containing the number of tasks each thread is currently running. Should not be modified. Only contains values for initialized threads.

### _batchDispatchInProgress

[`boolean`](https://create.roblox.com/docs/luau/booleans)

Internal property used to track whether a batch dispatch is in progress. Should not be modified.

### _lastDispatchedThread

[`number`](https://create.roblox.com/docs/luau/numbers)

Internal property used to track the last thread that was dispatched to in order to maintain round-robin dispatching. Should not be modified.

### _threadDoneConnection

[`RBXScriptConnection`](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptConnection)

Internal property used to be able to dispose of the connection to the `ThreadDone` event. Should not be modified.

---

## Methods

### Add

```luau
Add(...: any): void
```

Adds a task to the task queue. The task function will be called with the provided arguments. If `AutoDispatch` is `true`, the task will be dispatched immediately.

### AddBatch

```luau
AddBatch(batch: {{any}}): void
```

Adds multiple tasks to the task queue. Each element in the batch should be an array containing the arguments to pass to the worker function. If `AutoDispatch` is `true`, the tasks will be dispatched immediately.

### Clear

```luau
Clear(): void
```

Clears the task queue. Does not affect tasks that are currently running.

### Destroy

```luau
Destroy(): void
```

Destroys the thread pool and all related objects. Clears the task queue and waits for all currently running tasks to complete before destroying the pool.

!!! important
    Since the ThreadPool object references [`Instance`](https://create.roblox.com/docs/reference/engine/classes/Instance) objects, Roblox's Lua garbage collector will not collect the ThreadPool object until it is destroyed. It is important to call `Destroy` on the ThreadPool object when you are done with it to avoid memory leaks.

### Dispatch

```luau
Dispatch(...: any): number
```

Dispatches one task to the thread pool. The task function will be called with the provided arguments. Yields the current thread until the task has completed.

Returns the ID of the thread that the task was dispatched to.

### DispatchAsync

```luau
DispatchAsync(...: any): number
```

Dispatches one task to the thread pool asynchronously. The task function will be called with the provided arguments. Yields the current thread until the task can be dispatched.

Returns the ID of the thread that the task was dispatched to.

### DispatchAll

```luau
DispatchAll(): number
```

Dispatches all tasks in the task queue to the thread pool. Yields the current thread until all tasks have been completed.

Returns the number of tasks that were dispatched.

### DispatchAllAsync

```luau
DispatchAllAsync(): number
```

Dispatches all tasks in the task queue to the thread pool asynchronously. Yields the current thread until all tasks can be dispatched.

Returns the number of tasks that were dispatched.

### DispatchNext

```luau
DispatchNext(): number
```

Dispatches the next task in the task queue to the thread pool. Yields the current thread until the task has completed.

Returns the ID of the thread that the task was dispatched to.

### DispatchNextAsync

```luau
DispatchNextAsync(): number
```

Dispatches the next task in the task queue to the thread pool asynchronously. Yields the current thread until the task can be dispatched.

Returns the ID of the thread that the task was dispatched to.

### DispatchToAllFreeThreads

```luau
DispatchToAllFreeThreads(): number
```

Dispatches tasks to all free threads in the thread pool. Yields the current thread until all tasks have been completed.

Returns the number of tasks that were dispatched.

### DispatchToAllFreeThreadsAsync

```luau
DispatchToAllFreeThreadsAsync(): number
```

Dispatches tasks to all free threads in the thread pool asynchronously. Yields the current thread until all tasks can be dispatched.

Returns the number of tasks that were dispatched.

### GetNextFreeThread

```luau
GetNextFreeThread(): number?
```

Returns the ID of the next free thread in the thread pool. If no threads are free, returns `nil`.

### GetThreadStates

```luau
GetThreadStates(): (AggregatedThreadStates, {number})
```

Returns a tuple containing an [`AggregatedThreadStates`](types.md#aggregatedthreadstates) table and a table listing the number of active tasks in each thread, or -1 if a thread hasn't been initialized. The `AggregatedThreadStates` table contains the total number of threads in each state.

### Resize

```luau
Resize(newThreadCount: number): void
```

Resizes the thread pool to the specified number of threads. If the new thread count is greater than the current thread count, new threads will be created. If the new thread count is less than the current thread count, threads will be destroyed.
Waits until all currently running tasks have completed before resizing the thread pool. New threads will be initialized with the worker function from the original thread pool. Yields the current thread until all new workers are initialized.

`newThreadCount` should be a positive integer.

### WaitForCompletion

```luau
WaitForCompletion(requireEmptyQueue: boolean?): void
```

Yields the current thread until all currently running tasks have completed. If `requireEmptyQueue` is `true`, also waits for the task queue to be empty. `requireEmptyQueue` is `true` by default.

### WaitForFreeThread

```luau
WaitForFreeThread(): number
```

Yields the current thread until a free thread is available in the thread pool. If `AllowDispatchingToBusyThreads` is `true`, this method will return immediately.

Returns the ID of the free thread.

### WaitForThread

```luau
WaitForThread(threadId: number): void
```

Yields the current thread until the specified thread has completed all of its tasks. If `AllowDispatchingToBusyThreads` is `true`, this method will return immediately.
