-- Benchmarking script for the Resync ThreadPool module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resync = ReplicatedStorage:WaitForChild("Resync") :: ModuleScript
local ThreadPool = require(Resync.ThreadPool)

local perlinModule = ReplicatedStorage:WaitForChild("Noise") :: ModuleScript
local perlin = require(perlinModule)
local myWorker = ReplicatedStorage:WaitForChild("NoiseWorker") :: ModuleScript
local Dataset = require(ReplicatedStorage:WaitForChild("Dataset")) :: ModuleScript

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
        pool:Add(data.coords, data.amplitude, difficulty, data.persistence)
    end
    pool:DispatchAll()
    local t1 = os.clock()
    return string.format("%.2f", (t1 - t0) / samples * 1000)
end

print(`Perlin benchmark, timings averaged over {samples} samples`)
print("Octaves,Serial,Parallel16,Parallel64,Parallel128")
local lowDifficultyDataset = Dataset.new({"Octaves", "Serial", "Parallel16", "Parallel64", "Parallel128"})
for i = 16, 1024, 16 do
    -- Interrupt the benchmark if a player is in the game to avoid lag during client testing
    if isPlayTest then
        error("Interrupted server benchmark: playtest in progress")
    end

    local serial = serialBenchmark(i)
    local parallel16 = parallel16Benchmark(pool16, i)
    local parallel64 = parallel16Benchmark(pool64, i)
    local parallel128 = parallel16Benchmark(pool128, i)
    local row = lowDifficultyDataset:AppendRow({i, serial, parallel16, parallel64, parallel128})
    print(lowDifficultyDataset:RowToCsv(row))
end

-- Exponential difficulty benchmark
print("\nOctaves,Serial,Parallel16,Parallel64,Parallel128")
local highDifficultyDataset = Dataset.new({"Octaves", "Serial", "Parallel16", "Parallel64", "Parallel128"})
for i = 8, 13 do
    local difficulty = 2^i
    local serial = serialBenchmark(difficulty)
    local parallel16 = parallel16Benchmark(pool16, difficulty)
    local parallel64 = parallel16Benchmark(pool64, difficulty)
    local parallel128 = parallel16Benchmark(pool128, difficulty)
    local row = highDifficultyDataset:AppendRow({difficulty, serial, parallel16, parallel64, parallel128})
    print(highDifficultyDataset:RowToCsv(row))
end

-- Print the datasets as CSV for analysis
print("Small workload dataset:\n" .. lowDifficultyDataset:ToCsv() .."\n")
print("Large workload dataset:\n" .. lowDifficultyDataset:ToCsv())

-- Cleanup
pool16:Destroy()
pool64:Destroy()
pool128:Destroy()
