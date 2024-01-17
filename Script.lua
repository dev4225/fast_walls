local Toolbar = plugin:CreateToolbar("Mapping Tools")
local PluginButton = Toolbar:CreateButton("Walls", "Walls made easy!", "rbxassetid://4370186570", "Fast Walls")
local Opened = false

local WallsWidgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,  -- Widget will be initialized in floating panel
	false,   -- Widget will be initially enabled
	false,  -- Don't override the previous enabled state
	200,    -- Default width of the floating window
	300,    -- Default height of the floating window
	150,    -- Minimum width of the floating window
	150     -- Minimum height of the floating window
)
local WallsWidget = plugin:CreateDockWidgetPluginGui("Walls", WallsWidgetInfo)

WallsWidget.Title = "Fast Walls"

local WallsGui = script.Parent.WallsGui
WallsGui.Parent = WallsWidget

local LABEL_Status = WallsGui.Header.Status

local PartContainer = WallsGui.Content.PartContainer
local LABEL_PartsSelected = PartContainer.PartsSelected

local RoofContainer = WallsGui.Content.RoofContainer
local BUTTON_ToggleRoof = RoofContainer.ToggleRoof

local TypeContainer = WallsGui.Content.TypeContainer
local BUTTON_Flush = TypeContainer.Flush
local BUTTON_Outside = TypeContainer.Outside


local wallThickness = 1
local wallHeight = 1
local newWallSize = Vector3.new(1, 1, 1)


PluginButton.Click:Connect(function()
	if Opened then
		WallsWidget.Enabled = false
		Opened = false
	else
		WallsWidget.Enabled = true
		Opened = true
	end
end)

local partObj = {
	Size = {X = nil, Y = nil, Z = nil},
	Position = {X = nil, Y = nil, Z = nil},
	Orientation = {X = nil, Y = nil, Z = nil}
}


-- Helper function to round a number
local function round(number, decimalPlaces)
	local multiplier = 10 ^ decimalPlaces
	return math.floor(number * multiplier + 0.5) / multiplier
end


-- Helper function to round vector components
local function roundVector(vector, decimalPlaces)
	return Vector3.new(
		round(vector.X, decimalPlaces),
		round(vector.Y, decimalPlaces),
		round(vector.Z, decimalPlaces)
	)
end

-- Function to create and reflect walls
local function createFlushWalls()
	local vectorFloorObj = {
		Size = partObj.Size,
		Position = partObj.Position,
		Orientation = partObj.Orientation
	}

	local newWallPosition1 = CalculateNewPosition(vectorFloorObj.Position, vectorFloorObj.Size, newWallSize)
	local newWall_1 = createWallPart(newWallSize, newWallPosition1, vectorFloorObj.Orientation)

	--local newWallPosition2 = reflectWall(newWallPosition1, vectorFloorObj)
	--local newWall_2 = createWallPart(newWallSize, newWallPosition2)

	return newWall_1--, newWall_2
end

-- Function to reflect a wall
function reflectWall(floorPos, floorObj)
	local reflectedX = 2 * floorObj.Position.X - floorPos.X
	local reflectedPosition = Vector3.new(reflectedX, floorPos.Y, floorPos.Z)
	return reflectedPosition
end

-- Function to create a wall part
function createWallPart(size, position)
	local newPart = Instance.new("Part")

	-- Set properties for the new part
	newPart.Size = size
	newPart.Position = position
	newPart.Parent = workspace -- Assuming you want to parent it to the workspace

	return newPart
end

-- Function to calculate new position
function CalculateNewPosition(floorPosition, floorSize, newWallSize)
	local newWallPosition = floorPosition - (floorSize / 2) + (newWallSize / 2)
	local newWallHeight = floorPosition.Y + (floorSize.Y / 2) + (newWallSize.Y / 2)
	newWallPosition = Vector3.new(newWallPosition.X, newWallHeight, newWallPosition.Z)

	return newWallPosition
end

-- Function to update wall size
local function updateWallSize(x, y, z)
	newWallSize = Vector3.new(x, y, z)
end

-- Function to get part information
local function getPartInfo()
	local selectedParts = game:GetService("Selection"):Get()

	-- Check if there is at least one part selected
	if #selectedParts > 0 then
		-- Take the first part in the selection
		local part = selectedParts[1]

		partObj.Size = roundVector(part.Size, 3)
		partObj.Position = roundVector(part.CFrame.Position, 3)
		partObj.Orientation = roundVector(part.Orientation, 3)

		--updateWallSize(2, 5, partObj.Size.Z)
	else
		-- Handle the case when no parts are selected
		print("No parts selected")
	end
end





-- Connect the function to the selection changed event
game:GetService("Selection").SelectionChanged:Connect(getPartInfo)





BUTTON_ToggleRoof.MouseButton1Click:Connect(function()
	getPartInfo()
	createFlushWalls()
end)
