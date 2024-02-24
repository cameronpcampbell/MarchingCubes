![image](https://github.com/MightyPart/MarchingCubes/assets/66361859/f410f3de-a711-487d-93c6-579af5b6e2bf)


# Marching Cubes


## Settings
`VoxelResolution: number` | The amount of voxels in each direction (if the VoxelResolution is 10 then there would be `10 x 10 x 10` voxels in total).

`IsoValue: number` | The value which represents the surface of the mesh.

`Inverted: boolean` | Specifies the winding mode of the triangles (false is clockwise, true is counter-clockwise).


## Example

```lua
--!strict

local MarchingCubes = require(game:GetService("ReplicatedStorage").MarchingCubes)
local VOXEL_RES, VOXEL_COUNT = MarchingCubes.VoxelResolution, MarchingCubes.VoxelCount

local Values: MarchingCubes.ValuesTable = table.create(VOXEL_COUNT)

local start = tick()

local Iter = 1
for x = 0, VOXEL_RES do
	for y = 0, VOXEL_RES do
		for z = 0, VOXEL_RES do
			Values[Iter] = math.noise((x * VOXEL_RES) / 64, (y * VOXEL_RES) / 64, (z * VOXEL_RES) / 64)
			Iter += 1
		end
	end
end

local EMesh = MarchingCubes.new(Vector3.new(0,0,0), 200, Values)

local Mesh = Instance.new("MeshPart")
Mesh.Size = Vector3.one
Mesh.Anchored = true
Mesh.Parent = workspace
EMesh.Parent = Mesh

print(`Generated In {tick() - start}s!`)
```
