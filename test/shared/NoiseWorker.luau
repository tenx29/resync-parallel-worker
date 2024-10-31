--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Noise = ReplicatedStorage:WaitForChild("Noise") :: ModuleScript
local Perlin = require(Noise)

type Data = {
    coords: {number},
    amplitude: number,
    octaves: number,
    persistence: number,
}

return function(_actor: Actor, _threadId: number, coords, amplitude, octaves, persistence)
    task.desynchronize()
    Perlin.new(coords, amplitude, octaves, persistence)
end
