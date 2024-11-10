# Types

Types exported by the [`ThreadPool`](threadpool.md) module.

## Enums

### QueueType

```luau
export type QueueType = "FIFO" | "LIFO"
```

The type of queue to use for a thread pool. (First-In-First-Out or Last-In-First-Out)

## Objects

### AggregatedThreadStates

```luau
export type AggregatedThreadStates = {
    Ready: number,
    Running: number,
    Setup: number
}
```

A table containing the number of threads in each state. If a thread is initialized but isn't running a task, it is considered to be in the `Ready` state. If a thread is running at least one task, it is considered to be in the `Running` state. If a thread hasn't been initialized yet, it is considered to be in the `Setup` state. Uninitialized threads can not run tasks.

### ThreadPool

```luau
export type ThreadPool = typeof(ThreadPool.new(ModuleScript, number, QueueType?, boolean?))
```

A thread pool that can run tasks concurrently on multiple threads.
