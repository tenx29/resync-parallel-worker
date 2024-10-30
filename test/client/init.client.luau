-- Client benchmarking script for the Resync ThreadPool module
-- Does not perform any heavy computation, only used to verify that client-side thread pools are functional
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resync = ReplicatedStorage:WaitForChild("Resync") :: ModuleScript
local ThreadPool = require(Resync.ThreadPool)

local myWorker = ReplicatedStorage:WaitForChild("NoiseWorker") :: ModuleScript

local pool16 = ThreadPool.new(myWorker, 16, nil, true)

local data = {
    coords = {math.random(), math.random(), math.random(), math.random()},
    amplitude = 10,
    octaves = 32,
    persistence = 0.5
}

local samples = 1000

for _ = 1, samples do
    pool16:Add({
        coords = data.coords,
        amplitude = data.amplitude,
        octaves = data.octaves,
        persistence = data.persistence
    })
end

print("Dispatching all client-side threads...")
pool16:DispatchAll()
print("All client-side threads finished.")
