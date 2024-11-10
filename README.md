# Resync

[![github-pages](https://github.com/tenx29/resync-parallel-worker/actions/workflows/github-pages.yml/badge.svg)](https://github.com/tenx29/resync-parallel-worker/actions/workflows/github-pages.yml)

Parallel computing library for Roblox with a focus on ease of use.

Resync provides simple synchronous and asynchronous APIs for dispatching parallel tasks and managing thread pools from serial contexts.

## Installation

1. Insert Resync to your project and place it to the location of your choice. `ReplicatedStorage` is recommended as it allows both client and server code to access it.
2. Require the Resync ThreadPool class in your code.
   ```lua
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local ThreadPool = require(game.ReplicatedStorage.Resync.ThreadPool)
   ```
3. You're ready to start parallelizing your tasks! Refer to the API reference or follow the tutorial to get started.

## Documentation

Documentation is available at [https://tenx29.github.io/resync-parallel-worker/](https://tenx29.github.io/resync-parallel-worker/).
