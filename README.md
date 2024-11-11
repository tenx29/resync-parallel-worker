# Resync

[![github-pages](https://github.com/tenx29/resync-parallel-worker/actions/workflows/github-pages.yml/badge.svg)](https://github.com/tenx29/resync-parallel-worker/actions/workflows/github-pages.yml) [![release](https://github.com/tenx29/resync-parallel-worker/actions/workflows/release.yml/badge.svg)](https://github.com/tenx29/resync-parallel-worker/actions/workflows/release.yml)

Parallel computing library for Roblox with a focus on ease of use.

Resync provides simple synchronous and asynchronous APIs for dispatching parallel tasks and managing thread pools from serial contexts.

## Installation

Resync can be installed in two ways:

### Rojo with Wally

1. Install [Rojo](https://rojo.space/) and [Wally](https://wally.run/).
2. Add Resync as a dependency in your `wally.toml` file.
   ```toml
   [dependencies]
   resync = "tenx29/resync@1.0.1"
   ```
3. Run `wally install`.

### Manually in Roblox Studio

1. Get the latest version of Resync from the [Releases](https://github.com/tenx29/resync-parallel-worker/releases) page or the [Roblox Creator Store](https://create.roblox.com/store/asset/89261287724556).
2. Insert the model to your project and place it to the location of your choice. `ReplicatedStorage` is recommended as it allows both client and server code to access it.
3. Require the Resync ThreadPool class in your code.
   ```lua
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local ThreadPool = require(game.ReplicatedStorage.Resync.ThreadPool)
   ```
4. You're ready to start parallelizing your tasks! Refer to the API reference or follow the tutorial to get started.

## Code Example

```lua
local ThreadPool = require(game.ReplicatedStorage.Resync.ThreadPool)
local myWorkerModule = script.MyWorkerModule -- ModuleScript that returns a function

-- Create a new thread pool with 4 worker threads
local myThreadPool = ThreadPool.new(myWorkerModule, 4)

-- Add tasks to the queue. Accepts any number of arguments that will be passed to the worker function.
myThreadPool:Add("task 1", 1)
myThreadPool:Add("task 2", 2)
myThreadPool:Add("task 3", 3)

-- Dispatch all tasks in the queue and wait for them to complete
myThreadPool:DispatchAll()
```

## Documentation

- [Tutorial](https://tenx29.github.io/resync-parallel-worker/getting-started/tutorial-setup/)
- [API reference](https://tenx29.github.io/resync-parallel-worker/api-reference/threadpool/)
