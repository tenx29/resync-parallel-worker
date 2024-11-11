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
   resync = "tenx29/resync@1.0.0"
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

## Documentation

Documentation is available at [https://tenx29.github.io/resync-parallel-worker/](https://tenx29.github.io/resync-parallel-worker/).
