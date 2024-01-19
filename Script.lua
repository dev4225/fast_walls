local Toolbar = plugin:CreateToolbar("Mapping Tools 2")
local PluginButton = Toolbar:CreateButton("Walls", "Walls made easy!", "rbxassetid://4370186570", "Fast Walls")
local Opened = false

local WallsWidgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,  -- Widget will be initialized in floating panel
	false,   -- Widget will be initially enabled
	false,  -- Don't override the previous enabled state
	200,    -- Default width of the floating window
	350,    -- Default height of the floating window
	200,    -- Minimum width of the floating window
	360     -- Minimum height of the floating window
)
local WallsWidget = plugin:CreateDockWidgetPluginGui("Walls", WallsWidgetInfo)

WallsWidget.Title = "Fast Walls"

local WallsGui = script.Parent.WallsGui
local TopContainer = WallsGui.Content.TopContainer
local MidContainer = WallsGui.Content.MidContainer
local BotContainer = WallsGui.Content.BotContainer

WallsGui.Parent = WallsWidget

local LABEL_Status = WallsGui.Header.Status

local BUTTON_WallPlacement = TopContainer.FlushButton
local BUTTON_AutoRoof = TopContainer.RoofContainer.AutoRoofButton
local BUTTON_AddRoof = TopContainer.RoofContainer.AddRoofButton

local BUTTON_MatchHeight = MidContainer.MatchHeightButton
local BUTTON_MatchThickness = MidContainer.MatchThickButton
local TEXTBOX_Height = MidContainer.HeightTextBox
local TEXTBOX_Thickness = MidContainer.ThickTextBox

local BUTTON_MatchColor = BotContainer.Frame.MatchColorButton
local TEXTBOX_Color = BotContainer.Frame.ColorTextBox

local BUTTON_AutoHeight = BotContainer.Auto.AutoH
local BUTTON_AutoThick = BotContainer.Auto.AutoT
local BUTTON_AutoColor = BotContainer.Auto.AutoC

local BUTTON_Place = WallsGui.PlaceButton


local xHeightCall = true

local wallThickness = 1
local wallHeight = 1
local wallColor = Color3.fromHex("FFFFFF")



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
	Orientation = {X = nil, Y = nil, Z = nil},
	Color = nil
}

local function validateNumberInput(input, minValue, maxValue)
	local numericValue = tonumber(input)
	if numericValue and numericValue >= minValue and numericValue <= maxValue then
		return numericValue
	else
		warn("Invalid numeric input. Please enter a number between " .. minValue .. " and " .. maxValue)
		return nil
	end
end

local function validateHexColor(input)
	-- Remove '#' if present in the input
	input = input:gsub("#", "")

	-- Validate if the input is a valid hexadecimal color string
	if (#input == 6 or 3) and input:match("[0-9A-Fa-f]+") then
		return input
	else
		warn("Invalid hexadecimal color input. Please enter a valid 6-digit hex color code.")
		return nil
	end
end

local wallSizeZ = Vector3.new(wallThickness, wallHeight, partObj.Size.Z)
local wallSizeX = Vector3.new(partObj.Size.X, wallHeight, wallThickness)

-- Function to update wall size
local function updateWallSizes()
	wallSizeZ = Vector3.new(wallThickness, wallHeight, partObj.Size.Z)
	wallSizeX = Vector3.new(partObj.Size.X, wallHeight, wallThickness)
end

local function updateWallHeight(input)
	local numericValue = validateNumberInput(input, 0.001, 2048)
	if numericValue then
		wallHeight = input
	end
	
end

local function updateWallThickness(input)
	local numericValue = validateNumberInput(input, 0.001, 2048)
	if numericValue then
		wallThickness = input
		updateWallSizes()
	end
	
end

local function updateWallColor(input, valid)
	if valid then
		wallColor = input
	else
		local hexColor = validateHexColor(input)
		if hexColor then
			print("HEXINPUT?" .. input)
			wallColor = Color3.fromHex(input)
		end
	end
end

local function updateWallSettings()
	updateWallHeight(TEXTBOX_Height.Text)
	updateWallThickness(TEXTBOX_Thickness.Text)
	updateWallColor(TEXTBOX_Color.Text)
end

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

local function color3ToHex(color)
	local function componentToHex(component)
		local hex = string.format("%02X", math.floor(component * 255 + 0.5))
		return hex
	end

	local r, g, b = color.r, color.g, color.b
	local hexColor = componentToHex(r) .. componentToHex(g) .. componentToHex(b)

	return hexColor
end

-- Function to create and reflect walls
local function createFlushWalls()
	local vectorFloorObj = {
		Size = partObj.Size,
		Position = partObj.Position,
	}

	local newWallPosition1 = calculateNewPosition1(vectorFloorObj.Position, vectorFloorObj.Size, wallSizeZ)
	local newWall_1 = createWallPart(wallSizeZ, newWallPosition1)

	local newWallPosition2 = reflectX(newWallPosition1, vectorFloorObj)
	local newWall_2 = createWallPart(wallSizeZ, newWallPosition2)
	
	local offset = wallSizeZ.X * 2
	wallSizeX = Vector3.new(partObj.Size.X - offset, wallHeight, wallThickness)
	local newWallPosition3 = calculateNewPosition2(vectorFloorObj.Position, vectorFloorObj.Size, wallSizeX, offset)
	local newWall_3 = createWallPart(wallSizeX, newWallPosition3)
	
	local newWallPosition4 = reflectZ(newWallPosition3, vectorFloorObj)
	local newWall_4 = createWallPart(wallSizeX, newWallPosition4)
	print(newWallPosition3)
	return newWall_1, newWall_2
end

-- Function to reflect a wall
function reflectX(floorPos, floorObj)
	local reflectedX = 2 * floorObj.Position.X - floorPos.X
	local reflectedPosition = Vector3.new(reflectedX, floorPos.Y, floorPos.Z)
	return reflectedPosition
end

function reflectZ(floorPos, floorObj)
	local reflectedZ = 2 * floorObj.Position.Z - floorPos.Z
	local reflectedPosition = Vector3.new(floorPos.X, floorPos.Y, reflectedZ)
	return reflectedPosition
end



-- Function to create a wall part
function createWallPart(size, position)
	local newPart = Instance.new("Part")

	-- Set properties for the new part
	newPart.Size = size
	newPart.Position = position
	newPart.Parent = workspace -- Assuming you want to parent it to the workspace
	newPart.Anchored = true
	newPart.Color = wallColor

	return newPart
end

function calculateNewOffsetPosition(wallPosition)
	print(wallPosition)
end

-- Function to calculate new position
function calculateNewPosition1(floorPosition, floorSize, newWallSize)
	local newWallPosition = floorPosition - (floorSize / 2) + (newWallSize / 2)
	local newWallHeight = floorPosition.Y + (floorSize.Y / 2) + (newWallSize.Y / 2)
	newWallPosition = Vector3.new(newWallPosition.X, newWallHeight, newWallPosition.Z)

	return newWallPosition
end

-- Function to calculate new position
function calculateNewPosition2(floorPosition, floorSize, newWallSize, offset)
	local newWallPosition = floorPosition + (floorSize / 2) - (newWallSize / 2)
	local newWallHeight = floorPosition.Y + (floorSize.Y / 2) + (newWallSize.Y / 2)
	newWallPosition = Vector3.new(newWallPosition.X - (offset/2), newWallHeight, newWallPosition.Z)

	return newWallPosition
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
		partObj.Color = part.Color
		updateWallSizes()
		
	else
		-- Handle the case when no parts are selected
		print("No parts selected")
	end
end





-- Connect the function to the selection changed event
game:GetService("Selection").SelectionChanged:Connect(getPartInfo)


BUTTON_MatchHeight.MouseButton1Click:Connect(function()
	if xHeightCall == true then
		updateWallHeight(partObj.Size.X)
		TEXTBOX_Height.Text = partObj.Size.X
		xHeightCall = false
		BUTTON_MatchHeight.Text = "match floor [h]z"
	else
		updateWallHeight(partObj.Size.Z)
		TEXTBOX_Height.Text = partObj.Size.Z
		xHeightCall = true
		BUTTON_MatchHeight.Text = "match floor [h]x"
	end
end)

BUTTON_MatchThickness.MouseButton1Click:Connect(function()
	updateWallThickness(partObj.Size.Y)
	TEXTBOX_Thickness.Text = partObj.Size.Y
end)

BUTTON_MatchColor.MouseButton1Click:Connect(function()
	updateWallColor(partObj.Color, true)
	TEXTBOX_Color.Text = color3ToHex(partObj.Color)
end)


BUTTON_Place.MouseButton1Click:Connect(function()
	getPartInfo()
	updateWallSettings()
	createFlushWalls()
end)
