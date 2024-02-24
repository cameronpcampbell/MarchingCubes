--!strict
--!native


--> Packages ------------------------------------------------------------------------------------------
local LOOKUP_TABLE = require(script["LookupTable"])
local Settings = require(script["Settings"])
-------------------------------------------------------------------------------------------------------


--> Types ---------------------------------------------------------------------------------------------
export type ValuesTable = { number }
type VerticesTable = { [Vector3]: number }
type AddTriToEMesh = (eMesh: EditableMesh) -> ((vert1Id: number, vert2Id: number, vert3Id: number) -> nil)
-------------------------------------------------------------------------------------------------------

--> Variables -----------------------------------------------------------------------------------------
local ISO_VALUE, VOXEL_RES, INVERTED = Settings.IsoValue, Settings.VoxelResolution, Settings.Inverted

local VOXEL_COUNT = (VOXEL_RES + 1) ^ 3

local MIDPOINT_PARENTS = {
	{1,2}, {2,3}, {3,4}, {4,1},
	{5,6}, {6,7}, {7,8}, {8,5},
	{1,5}, {2,6}, {3,7}, {4,8}
}

local FORWARDS = VOXEL_RES+((VOXEL_RES+1)*VOXEL_RES)+1
local RIGHT = 1
local UP = VOXEL_RES+1

local OFFSET_A, OFFSET_B, OFFSET_C, OFFSET_D, OFFSET_E, OFFSET_F, OFFSET_G = 
	FORWARDS,
	FORWARDS+RIGHT,
	RIGHT,
	UP,
	FORWARDS+UP,
	FORWARDS+UP+RIGHT,
	UP+RIGHT
-------------------------------------------------------------------------------------------------------


--> Private Functions ---------------------------------------------------------------------------------
-- Interpolates between 2 positions using 2 values.
local function PositionInterpolation(pos1: Vector3, val1: number, pos2: Vector3, val2: number)
	return pos1+((ISO_VALUE-val1)/(val2-val1))*(pos2-pos1)
end

local function IndexToPosition(
	startX: number, startY: number, startZ: number,
	endX: number, endY: number, endZ: number,
	step: number
)
	return function(i: number)
		local x = math.floor((i - 1) / (math.ceil((endZ - startZ + 1) / step) * math.ceil((endY - startY + 1) / step))) * step + startX
		local z = math.floor(((i - 1) / math.ceil((endZ - startZ + 1) / step)) % math.ceil((endY - startY + 1) / step)) * step + startZ
		local y = (i - 1) % math.ceil((endZ - startZ + 1) / step) * step + startY

		return Vector3.new(x, y, z)
	end
end

local function AddVertToEmesh(eMesh:EditableMesh, vertices: VerticesTable)
	return function(pos:Vector3)
		local vertexId = eMesh:AddVertex(pos)

		vertices[pos] = vertexId

		return vertexId
	end
end

local AddTriToEMesh: AddTriToEMesh = INVERTED and (
	function(eMesh: EditableMesh)
		return function(vertex1Id: number, vertex2Id: number, vertex3Id: number)
			eMesh:AddTriangle(vertex1Id, vertex2Id, vertex3Id)
		end
	end
) or (
	function(eMesh: EditableMesh)
		return function(vertex1Id: number, vertex2Id: number, vertex3Id: number)
			eMesh:AddTriangle(vertex3Id, vertex2Id, vertex1Id)
		end
	end
)

-- Performs the marching cubes algorithm on a cube of 8 positions starting from a specified position.
local function MarchingCubes(
	eMesh: EditableMesh,
	vertices: VerticesTable, values: ValuesTable,
	voxelSize: number,
	indexToPosition: (index: number) -> Vector3
)
	local addVertToEmesh, addTriToEMesh = AddVertToEmesh(eMesh, vertices), AddTriToEMesh(eMesh)
	
	return function(startIndex: number)

		-- Gets the indexes of each corner of the voxel.
		local voxelIndexA, voxelIndexB, voxelIndexC, voxelIndexD, voxelIndexE, voxelIndexF, voxelIndexG, voxelIndexH = 
			startIndex, startIndex+OFFSET_A, startIndex+OFFSET_B, startIndex+OFFSET_C,
			startIndex+OFFSET_D, startIndex+OFFSET_E, startIndex+OFFSET_F, startIndex+OFFSET_G
		local voxelIndexes = {
			voxelIndexA, voxelIndexB, voxelIndexC, voxelIndexD, voxelIndexE, voxelIndexF, voxelIndexG, voxelIndexH
		}

		--[[ Calculates the index in the LOOKUP_TABLE for the cube. If index is
    	     0 or 255 then we return since those indexes represent empty space ]]
		local index =
			(values[voxelIndexA] < ISO_VALUE and 0 or 1)
			+(values[voxelIndexB] < ISO_VALUE and 0 or 2)
			+(values[voxelIndexC] < ISO_VALUE and 0 or 4)
			+(values[voxelIndexD] < ISO_VALUE and 0 or 8)
			+(values[voxelIndexE] < ISO_VALUE and 0 or 16)
			+(values[voxelIndexF] < ISO_VALUE and 0 or 32)
			+(values[voxelIndexG] < ISO_VALUE and 0 or 64)
			+(values[voxelIndexH] < ISO_VALUE and 0 or 128)
		
		if index == 0 or index == 255 then return end
		
		local lookupData = LOOKUP_TABLE[index]

		--[[ lookupData is split up into chunks of 3 (this is because triangles have 3 vertices),
	         therefore if we divide its length by 3 we get the amount of times we should iterate ]]
		for count=1,#lookupData/3 do
			local countTimes3 = count*3
			local edge1CornerIds = MIDPOINT_PARENTS[lookupData[-2+countTimes3]]
			local edge2CornerIds = MIDPOINT_PARENTS[lookupData[-1+countTimes3]]
			local edge3CornerIds = MIDPOINT_PARENTS[lookupData[countTimes3]]
			
			-- Triangle does not exist if any of the edge ids are missing.
			if edge3CornerIds == nil or edge2CornerIds == nil or edge1CornerIds == nil then continue end

			local edge1CornerAIdx, edge1CornerBIdx = voxelIndexes[edge1CornerIds[1]], voxelIndexes[edge1CornerIds[2]]
			local edge2CornerAIdx, edge2CornerBIdx = voxelIndexes[edge2CornerIds[1]], voxelIndexes[edge2CornerIds[2]]
			local edge3CornerAIdx, edge3CornerBIdx = voxelIndexes[edge3CornerIds[1]], voxelIndexes[edge3CornerIds[2]]

			local edge1CornerAPos, edge1CornerBPos = indexToPosition(edge1CornerAIdx), indexToPosition(edge1CornerBIdx)
			local edge2CornerAPos, edge2CornerBPos = indexToPosition(edge2CornerAIdx), indexToPosition(edge2CornerBIdx)
			local edge3CornerAPos, edge3CornerBPos = indexToPosition(edge3CornerAIdx), indexToPosition(edge3CornerBIdx)

			-- Weighted interpolation between each edges corners
			local vertex1Pos = PositionInterpolation(edge1CornerAPos, values[edge1CornerAIdx], edge1CornerBPos, values[edge1CornerBIdx])
			local vertex2Pos = PositionInterpolation(edge2CornerAPos, values[edge2CornerAIdx], edge2CornerBPos, values[edge2CornerBIdx])
			local vertex3Pos = PositionInterpolation(edge3CornerAPos, values[edge3CornerAIdx], edge3CornerBPos, values[edge3CornerBIdx])
			
			-- Makes sure all vert positions are unique to prevent any future issues when constructing a mesh.
			if vertex1Pos == vertex2Pos or vertex1Pos == vertex3Pos or vertex2Pos == vertex3Pos then continue end
			
			local vertex1Id = vertices[vertex1Pos] or addVertToEmesh(vertex1Pos)
			local vertex2Id = vertices[vertex2Pos] or addVertToEmesh(vertex2Pos)
			local vertex3Id = vertices[vertex3Pos] or addVertToEmesh(vertex3Pos)
			addTriToEMesh(vertex1Id, vertex2Id, vertex3Id)
		end

	end
end


-------------------------------------------------------------------------------------------------------


return {
	new = function(position: Vector3, nodeSize: number, values: ValuesTable): EditableMesh
		local xOffset, yOffset, zOffset = position.X, position.Y, position.Z

		local startX, startY, startZ = xOffset-(nodeSize/2), yOffset-(nodeSize/2), zOffset-(nodeSize/2)
		local endX, endY, endZ = startX+nodeSize, startY+nodeSize, startZ+nodeSize
		local voxelSize = nodeSize / VOXEL_RES

		local eMesh = Instance.new("EditableMesh")
		local vertices = {}

		local indexToPosition = IndexToPosition(startX, startY, startZ, endX, endY, endZ, voxelSize)
		local march = MarchingCubes(eMesh, vertices, values, voxelSize, indexToPosition)
		local i3d = 0
		for x = startX, endX, voxelSize do
			for z = startZ, endZ, voxelSize do
				for y = startY, endY, voxelSize do
					i3d += 1

					if x > endX-voxelSize or y > endY-voxelSize or z > endZ-voxelSize then continue end
					
					march(i3d)
				end
			end
		end

		return eMesh
	end,
	
	VoxelCount = VOXEL_COUNT,
	VoxelResolution = VOXEL_RES
}
