# Parallel Terrain Generation

In this guide, we'll be parallelizing the terrain generation algorithm we implemented in the [Generating Terrain](generating-terrain.md) tutorial. We'll be using Resync to generate multiple chunks of terrain in parallel.

## Parallelizing the Chunk Generation

Resync requires a ModuleScript that returns a function to dispatch tasks to the thread pool, which is why we implemented the terrain generation like this in the previous tutorial.
To make the `ChunkGenerator` script work with Resync, we'll need to modify it slightly.

```luau linenums="1" hl_lines="18 19 56"
-- ServerScriptService.ChunkGenerator
--!native

-- Create an N-dimensional table where each dimension has a length of size.
-- Initialize all elements in the table with elemValue.
function makeNdArray(numDim, size, elemValue)
    if numDim == 0 then
        return elemValue
    end
    local result = {}
    for i = 1, size do
        result[i] = makeNdArray(numDim - 1, size, elemValue)
    end
    return result
end

-- Generate a chunk at the given chunk position (chunk position = absolute position / chunk size)
return function(_actor: Actor, _threadId: number, x: number, z: number, chunkSize: number, noiseScale: number)
    task.desynchronize()

    -- Calculate the position of the -x,-z corner of the chunk
    local absoluteX = x * chunkSize * 4
    local absoluteZ = z * chunkSize * 4
    
    -- Loop through all points in the chunk and calculate the height value
    local materials = makeNdArray(3, chunkSize, Enum.Material.Grass)
    local occupancy = makeNdArray(3, chunkSize, 0)
    
    for x = 0, chunkSize - 1 do
        for z = 0, chunkSize - 1 do
            local noiseX = (absoluteX + x * 4) / noiseScale
            local noiseZ = (absoluteZ + z * 4) / noiseScale
            
            -- Set the base height to 10 and add a random amount to it with math.noise
            local noise = math.noise(noiseX, noiseZ) * 10
            local height = noise + 10
            
            for y = 0, chunkSize - 1 do
                local xIndex = x + 1
                local yIndex = y + 1
                local zIndex = z + 1
                
                -- Set the occupancy at the current point
                occupancy[xIndex][yIndex][zIndex] = math.clamp(height - y, 0, 1)
            end
        end
    end
    
    -- Set up the region for the chunk
    local region = Region3.new(
        Vector3.new(absoluteX, 0, absoluteZ),
        Vector3.new(absoluteX + chunkSize * 4, chunkSize * 4, absoluteZ + chunkSize * 4)
    )
    
    -- Write the voxels
    task.synchronize()
    workspace.Terrain:WriteVoxels(region, 4, materials, occupancy)
end
```

The first two arguments `_actor` and `_threadId` are provided by Resync and can be used by the task function if information about the Actor object or the thread ID is needed.
Since in this case we don't need them, we've prefixed them with an underscore to indicate that they're unused.

Additionally we've added `task.desynchronize()` and `task.synchronize()` calls to the task function. These functions are built in to Luau and are used to switch execution between parallel and serial execution steps.
In this case, we're doing the Perlin noise sampling (the slowest part of terrain generation) in parallel, and synchronize the task before writing the voxels to the terrain.

Next, let's go back to the executing script and modify it to use a Resync thread pool to generate terrain in parallel.

```luau linenums="1" hl_lines="3 9-11 16 19 25-27"
local ServerScriptService = game:GetService("ServerScriptService")
local ChunkGenerator = require(ServerScriptService.ChunkGenerator)
local ThreadPool = require(game.ReplicatedStorage.Resync.ThreadPool)

-- Experiment with different values for these parameters
-- to see how they affect performance
local areaSize = 32
local chunkSize = 32
local numThreads = 64

local pool = ThreadPool.new(script.Parent.ChunkGenerator, numThreads)

local startTime = os.clock()
for x = -areaSize // 2, areaSize // 2 do
    for z = -areaSize // 2, areaSize // 2 do
        pool:Add(x, z, chunkSize, 100)
    end
end
pool:DispatchAll()
local endTime = os.clock()

local timeTaken = endTime - startTime
print("Parallel execution time:", timeTaken)

-- Since we know we won't be using the thread pool anymore, we should
-- destroy it to free up resources
pool:Destroy()
```

In this script, we've created a new thread pool with a maximum of 64 worker threads and added tasks to the pool for each chunk to be generated.
Note that the arguments we pass to `pool:Add` are the same as the arguments we pass to the `ChunkGenerator` function in serial implementation.

Now when you run the script, you should see the terrain appear after a few seconds. The script will print the time taken to generate the terrain in parallel,
and if you compare it to the serial execution time from the previous tutorial, the parallel execution time should be faster.

The speedup you see will depend on several factors, such as the number of worker threads in the pool, the number of tasks, and the amount of work each task does.
Try experimenting with different values for these parameters to see how they affect the performance of your terrain generation algorithm.
Keep in mind that some workloads may be slower when executed in parallel due to the performance overhead of creating and managing threads.
