# Installation

1. Insert Resync to your project and place it to the location of your choice. `ReplicatedStorage` is recommended as it allows both client and server code to access it.
2. Require the Resync ThreadPool class in your code.
   ```lua
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local ThreadPool = require(game.ReplicatedStorage.Resync.ThreadPool)
   ```
3. You're ready to start parallelizing your tasks! Refer to the API reference or follow the tutorial to get started.
