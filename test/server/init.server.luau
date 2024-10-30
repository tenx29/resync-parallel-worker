-- Benchmarking script for the Resync ThreadPool module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resync = ReplicatedStorage:WaitForChild("Resync") :: ModuleScript
local ThreadPool = require(Resync.ThreadPool)

local perlinModule = ReplicatedStorage:WaitForChild("Noise") :: ModuleScript
local perlin = require(perlinModule)
local myWorker = ReplicatedStorage:WaitForChild("NoiseWorker") :: ModuleScript

-- Create thread pools for benchmarking
local pool16 = ThreadPool.new(myWorker, 16)
local pool64 = ThreadPool.new(myWorker, 64)
local pool128 = ThreadPool.new(myWorker, 128)

local isPlayTest = #Players:GetPlayers() > 0

Players.PlayerAdded:Connect(function()
    isPlayTest = true
end)

-- Perlin noise data
local data = {
    coords = {math.random(), math.random(), math.random(), math.random()},
    amplitude = 10,
    octaves = 32,
    persistence = 0.5
}

local samples = 1000

function serialBenchmark(difficulty: number)
    local t0 = os.clock()
    for _ = 1, samples do
        perlin.new(data.coords, data.amplitude, difficulty, data.persistence)
    end
    local t1 = os.clock()
    return string.format("%.2f", (t1 - t0) / samples * 1000)
end

function parallel16Benchmark(pool: any, difficulty: number)
    local t0 = os.clock()
    for _ = 1, samples do
        pool:Add({
            coords = data.coords,
            amplitude = data.amplitude,
            octaves = difficulty,
            persistence = data.persistence
        })
    end
    pool:DispatchAll()
    local t1 = os.clock()
    return string.format("%.2f", (t1 - t0) / samples * 1000)
end

local datasets = {}

datasets.small = {
    Octaves = {},
    Serial = {},
    Parallel16 = {},
    Parallel64 = {},
    Parallel128 = {}
}

datasets.large = {
    Octaves = {},
    Serial = {},
    Parallel16 = {},
    Parallel64 = {},
    Parallel128 = {}
}

print(`Perlin benchmark, timings averaged over ${samples} samples`)
print("Octaves,Serial,Parallel16,Parallel64")
for i = 16, 1024, 16 do
    -- Interrupt the benchmark if a player is in the game to avoid lag during client testing
    if isPlayTest then
        error("Interrupted server benchmark: playtest in progress")
    end

    table.insert(datasets.small.Octaves, i)
    datasets.small.Serial[i] = serialBenchmark(i)
    datasets.small.Parallel16[i] = parallel16Benchmark(pool16, i)
    datasets.small.Parallel64[i] = parallel16Benchmark(pool64, i)
    datasets.small.Parallel128[i] = parallel16Benchmark(pool128, i)
    print(i .. "," .. datasets.small.Serial[i] .. "," .. datasets.small.Parallel16[i] .. "," .. datasets.small.Parallel64[i] .. "," .. datasets.small.Parallel128[i])
end

-- Exponential difficulty benchmark
for i = 8, 13 do
    local difficulty = 2^i
    table.insert(datasets.large.Octaves, difficulty)
    datasets.large.Serial[difficulty] = serialBenchmark(difficulty)
    datasets.large.Parallel16[difficulty] = parallel16Benchmark(pool16, difficulty)
    datasets.large.Parallel64[difficulty] = parallel16Benchmark(pool64, difficulty)
    datasets.large.Parallel128[difficulty] = parallel16Benchmark(pool128, difficulty)
    print(difficulty .. "," .. datasets.large.Serial[difficulty] .. "," .. datasets.large.Parallel16[difficulty] .. "," .. datasets.large.Parallel64[difficulty] .. "," .. datasets.large.Parallel128[difficulty])
end

-- Print the datasets as CSV for analysis
local small = "Octaves,Serial,Parallel16,Parallel64,Parallel128\n"
for _, v in pairs(datasets.small.Octaves) do
    small = small .. v .. "," .. datasets.small.Serial[v] .. "," .. datasets.small.Parallel16[v] .. "," .. datasets.small.Parallel64[v] .. "," .. datasets.small.Parallel128[v] .. "\n"
end
print("Small workload dataset:\n" .. small.."\n")

local large = "Octaves,Serial,Parallel16,Parallel64,Parallel128\n"
for _, v in pairs(datasets.large.Octaves) do
    large = large .. v .. "," .. datasets.large.Serial[v] .. "," .. datasets.large.Parallel16[v] .. "," .. datasets.large.Parallel64[v] .. "," .. datasets.large.Parallel128[v] .. "\n"
end
print("Large workload dataset:\n" .. large)

-- Cleanup
pool16:Destroy()
pool64:Destroy()
pool128:Destroy()
