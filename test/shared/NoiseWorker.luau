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

return function(_actor: Actor, _threadId: number, data: Data)
    task.desynchronize()
    Perlin.new(data.coords, data.amplitude, data.octaves, data.persistence)
end
