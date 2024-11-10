# Best Practices and Optimization Tips

This section contains some useful information to keep in mind when working with Resync.

## Parallelization overhead

Like any parallel processing system (both software and hardware), Resync introduces some overhead when dispatching tasks to a thread pool. This is due to the computational cost of creating and managing threads, as well as the small amount of code used to execute the task itself. The amount of overhead is generally proportional to the number of tasks being executed, or *O(n)*, where *n* is the number of tasks. Resync's optional Thread State Tracking feature also incurs some overhead caused by waiting for threads to finish before dispatching new tasks.

### Balance the workload

To minimize the effect of parallelization overhead, it is recommended to use Resync for tasks that are computationally expensive compared to the overhead and not feasible to run sequentially.

For example, if you have a task that takes 1 second to run and you are running 1000 tasks, the overhead of Resync will be negligible compared to the total time taken to run all tasks, and the benefits of parallelization will be significant. However, if your task takes only a few microseconds to run, the overhead of Resync may outweigh any performance gains from parallelizing the task. If you have such a task, consider running it sequentially or grouping multiple tasks into a single task to reduce the impact of overhead. (e.g. generating a small area of voxel terrain instead of a single cell)

In addition to using Resync for computationally expensive tasks, it is also important to keep the amount of work done by each task limited. If a task takes too long to run, it will slow down Roblox's parallel execution step, delaying the serial execution step and causing performance issues.

### Choose the right number of threads

The number of threads in the thread pool directly affects the amount of time spent executing a batch of tasks. If the number of threads is too low, some tasks will need to wait for a thread to become available, increasing the total time taken to execute all tasks. If the number of threads is too high for the current hardware, the threads will compete for resources, which may result in diminishing returns or even a decrease in performance.

The optimal number of threads depends on the targeted hardware and frequency of task execution. A good starting point for a 4-core CPU is to use 64 threads. This number can be adjusted based on the number of cores available and the nature of the tasks being executed, but ultimately the best results will come from testing different thread counts and measuring the performance of the system.

### Use Thread State Tracking wisely

As mentioned in the [Thread Dispatching](thread-dispatching.md#thread-state-tracking) section, Thread State Tracking can be used to ensure that all threads have finished executing before dispatching new tasks. This feature can be useful in some cases, but it also introduces additional overhead. If you don't need to know exactly when all threads have finished executing, it is recommended to disable Thread State Tracking to reduce the overhead caused by waiting for threads to finish. This can also reduce the number of threads needed to achieve optimal performance.

## Dispatching methods

Resync's API provides several different methods for dispatching tasks that are best suited for different use cases.

### Use the right method for the job

Different task dispatching methods have different overheads and aren't universally optimal for all use cases. For example, if you have a constant stream of tasks that need to be executed and you don't need to know when they finish, using automatic dispatching is a good choice. For a more detailed comparison of the different dispatching methods, see the [Thread Dispatching](thread-dispatching.md) section.

### Pick the right queue type

Resync provides two different types of task queues: FIFO and LIFO. FIFO (First In, First Out) queues are best suited for tasks that need to be executed in the order they were added, while LIFO (Last In, First Out) queues are best suited for use cases when the newest tasks are more important than the older ones and should be dispatched first. Choosing the right queue type can help improve the performance of your system by ensuring that tasks are dispatched in the most efficient way.
