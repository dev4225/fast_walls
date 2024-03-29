local Toolbar = plugin:CreateToolbar("Mapping Tools")
local PluginButton = Toolbar:CreateButton("Walls", "Walls made easy!", "rbxassetid://16096364344", "Fast Walls")
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

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local matchHeightButtonEnabled = true
local matchThickButtonEnabled = true
local matchColorButtonEnabled = true

local flush = true
local xHeightCall = true
local autoThick = false
local autoHeight = false
local autoColor = false
local autoRoof = false


local wallThickness = 1
local wallHeight = 1
local wallColor = Color3.fromHex("1B2A35")


local autoColorHighlight = Color3.new(0.666667, 0, 1)
local defaultButtonColor =  Color3.new(0.333333, 0.333333, 0.498039)
local matchColorHighlight = Color3.new(0.666667, 0.666667, 1)
local matchColorBorderHighlight = Color3.new(0.666667, 0, 1)
local errorColor = Color3.fromHex("FF2A00")
local bannerColor = Color3.fromHex("00d5ff")


local currentConnection = nil

local function disconnectPreviousConnection()
	if currentConnection then
		currentConnection:Disconnect()
		currentConnection = nil
	end
end

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
	Part = nil,
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
		--warn("Invalid numeric input. Please enter a number between " .. minValue .. " and " .. maxValue)
		return nil
	end
end

local function validateHexColor(input)
	-- Remove '#' if present in the input
	input = input:gsub("#", "")

	-- Validate if the input is a valid hexadecimal color string
	if (#input == 6 or #input == 3) and input:match("[0-9A-Fa-f]+") then
		return input
	else
		--warn("Invalid hexadecimal color input. Please enter a valid 6-digit or 3-digit hex color code.")
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
		updateWallSizes()
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

local function rotate(wallGroup)
	wallGroup:PivotTo(wallGroup:GetPivot() * CFrame.Angles(math.rad(partObj.Orientation.X), math.rad(partObj.Orientation.Y), math.rad(partObj.Orientation.Z)))
end

function ungroupModel(model)
	-- Get all children of the model
	local children = model:GetChildren()

	-- Reparent each child to the workspace
	for _, child in ipairs(children) do
		if child:IsA("Part") or child:IsA("Model") then -- Check if the child is a Part or a Model
			child.Parent = workspace
		end
	end

	-- Delete the model
	model:Destroy()
end 
-- Function to create and reflect walls
local function createFlushWalls()
	local vectorFloorObj = {
		Size = partObj.Size,
		Position = partObj.Position,
	}

	local newWallPosition1 = calculateNewPosition1(vectorFloorObj.Position, vectorFloorObj.Size, wallSizeZ)
	local newWallPosition2 = reflectX(newWallPosition1, vectorFloorObj)
	

	local offset = wallSizeZ.X * 2
	if(flush) then
		wallSizeX = Vector3.new(partObj.Size.X - offset, wallHeight, wallThickness)
	else
		wallSizeX = Vector3.new(partObj.Size.X, wallHeight, wallThickness)
	end
	
	
	local newWallPosition3 = calculateNewPosition2(vectorFloorObj.Position, vectorFloorObj.Size, wallSizeX, offset)
	local newWallPosition4 = reflectZ(newWallPosition3, vectorFloorObj)

	local wallGroup = Instance.new("Model")
	wallGroup.Name = "WallGroup"
	wallGroup.Parent = workspace

	local newWall_1 = createWallPart(wallSizeZ, newWallPosition1, wallGroup)
	local newWall_2 = createWallPart(wallSizeZ, newWallPosition2, wallGroup)
	local newWall_3 = createWallPart(wallSizeX, newWallPosition3, wallGroup)
	local newWall_4 = createWallPart(wallSizeX, newWallPosition4, wallGroup)
	
	rotate(wallGroup)
	ungroupModel(wallGroup)
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


function createWallPart(size, position, parentModel)
	print("part created")
	local newPart = Instance.new("Part")
	newPart.Size = size
	newPart.Position = position
	if parentModel ~= nil then
		print("hit")
		newPart.Parent = parentModel
	end
	newPart.Anchored = true
	newPart.Color = wallColor
	return newPart
end

-- Function to calculate new position
function calculateNewPosition1(floorPosition, floorSize, newWallSize)
	local newWallPosition = floorPosition - (floorSize / 2) + (newWallSize / 2)
	local newWallHeight = floorPosition.Y + (floorSize.Y / 2) + (newWallSize.Y / 2)
	if(flush) then
		newWallPosition = Vector3.new(newWallPosition.X, newWallHeight, newWallPosition.Z)
	else
		newWallPosition = Vector3.new(newWallPosition.X - wallThickness, newWallHeight, newWallPosition.Z)
	end
	

	return newWallPosition
end


-- Function to calculate new position
function calculateNewPosition2(floorPosition, floorSize, newWallSize, offset)
	local newWallPosition = floorPosition + (floorSize / 2) - (newWallSize / 2)
	local newWallHeight = floorPosition.Y + (floorSize.Y / 2) + (newWallSize.Y / 2)

	if(flush) then
		newWallPosition = Vector3.new(newWallPosition.X - (offset/2), newWallHeight, newWallPosition.Z)
	else
		newWallPosition = Vector3.new(newWallPosition.X, newWallHeight, newWallPosition.Z + wallThickness)
	end

	

	return newWallPosition
end

local function addRoof()
	local floorSize = Vector3.new(partObj.Size.X, partObj.Size.Y, partObj.Size.Z)
	local floorPosition = Vector3.new(partObj.Position.X, partObj.Position.Y + wallHeight + 1, partObj.Position.Z)
	print("adding roof")
	createWallPart(floorSize, floorPosition, workspace)
end

-- Function to get part information
local function getPartInfo()
	local selectedParts = game:GetService("Selection"):Get()

	disconnectPreviousConnection()

	-- Check if there is at least one part selected
	if #selectedParts > 0 then
		-- Take the first part in the selection
		local part = selectedParts[1]
		partObj.Part = part
		partObj.Size = roundVector(part.Size, 3)
		partObj.Position = roundVector(part.CFrame.Position, 3)
		partObj.Orientation = roundVector(part.Orientation, 3)
		partObj.Color = part.Color
		updateWallSizes()
		if autoThick == true then
			updateWallThickness(partObj.Size.Y)
			TEXTBOX_Thickness.Text = round(partObj.Size.Y,3)
		end
		if autoHeight == true and xHeightCall == true then
			updateWallHeight(partObj.Size.X)
			TEXTBOX_Height.Text = round(partObj.Size.X,3)
		end
		if autoHeight == true and xHeightCall == false then
			updateWallHeight(partObj.Size.Z)
			TEXTBOX_Height.Text = round(partObj.Size.Z,3)
		end
		if autoColor == true then
			updateWallColor(partObj.Color, true)
			TEXTBOX_Color.Text = color3ToHex(partObj.Color)
		end

		currentConnection = part.Changed:Connect(function(propertyName)
			-- Check if the changed property is one of the properties we care about
			if propertyName == "Size" or propertyName == "Position" or propertyName == "Orientation" or propertyName == "Color" then
				getPartInfo() -- Call your function to update the UI
			end
		end)

	else
		-- Handle the case when no parts are selected
		--print("No parts selected")
	end
end


function showError(errorNumber)
	if errorNumber == 1 then
		LABEL_Status.BackgroundColor3 = errorColor
		LABEL_Status.Text = "NO PART SELECTED"
	end
end


-- Connect the function to the selection changed event
game:GetService("Selection").SelectionChanged:Connect(getPartInfo)


BUTTON_MatchHeight.MouseButton1Click:Connect(function()
	if(matchHeightButtonEnabled) then
		if xHeightCall == true then
			updateWallHeight(partObj.Size.X)
			TEXTBOX_Height.Text = round(partObj.Size.X,3)
			xHeightCall = false
			BUTTON_MatchHeight.Text = "match floor [h]z"
		else
			updateWallHeight(partObj.Size.Z)
			TEXTBOX_Height.Text = round(partObj.Size.Z,3)
			xHeightCall = true
			BUTTON_MatchHeight.Text = "match floor [h]x"
		end
	end
end)

BUTTON_MatchThickness.MouseButton1Click:Connect(function()
	if(matchThickButtonEnabled) then
		updateWallThickness(partObj.Size.Y)
		TEXTBOX_Thickness.Text = round(partObj.Size.Y,3)
	end
end)

BUTTON_MatchColor.MouseButton1Click:Connect(function()
	if(matchColorButtonEnabled) then
		updateWallColor(partObj.Color, true)
		TEXTBOX_Color.Text = color3ToHex(partObj.Color)
	end
end)

BUTTON_AutoThick.MouseButton1Click:Connect(function()
	if(autoThick == false) then
		matchThickButtonEnabled = false
		BUTTON_AutoThick.BackgroundColor3 = autoColorHighlight
		BUTTON_MatchThickness.Text = "automatch[t]y"
		BUTTON_MatchThickness.BackgroundColor3 = matchColorHighlight
		autoThick = true
	else
		matchThickButtonEnabled = true
		BUTTON_MatchThickness.Text = "match floor [t]y"
		BUTTON_MatchThickness.BackgroundColor3 = defaultButtonColor
		BUTTON_AutoThick.BackgroundColor3 = defaultButtonColor
		autoThick = false
	end
end)

BUTTON_AutoHeight.MouseButton1Click:Connect(function()
	if not autoHeight then
		matchHeightButtonEnabled = false
		BUTTON_MatchHeight.Text = "automatch[h]x"
		BUTTON_MatchHeight.BackgroundColor3 = matchColorHighlight

		BUTTON_AutoHeight.BackgroundColor3 = autoColorHighlight
		autoHeight = true
		xHeightCall = true
	elseif autoHeight and BUTTON_AutoHeight.Text == "[h] x" then
		BUTTON_MatchHeight.Active = false
		BUTTON_MatchHeight.Text = "automatch[h]z"
		BUTTON_MatchHeight.BackgroundColor3 = matchColorHighlight

		BUTTON_AutoHeight.Text = "[h] z"
		BUTTON_AutoHeight.BackgroundColor3 = autoColorHighlight
		autoHeight = true
		xHeightCall = false
	elseif autoHeight and BUTTON_AutoHeight.Text == "[h] z" then
		matchHeightButtonEnabled = true
		BUTTON_MatchHeight.Text = "match floor [h]x"
		BUTTON_MatchHeight.BackgroundColor3 = defaultButtonColor

		BUTTON_AutoHeight.Text = "[h] x"
		BUTTON_AutoHeight.BackgroundColor3 = defaultButtonColor
		autoHeight = false
		xHeightCall = true
	end
end)

BUTTON_AutoColor.MouseButton1Click:Connect(function()
	if(autoColor == false) then
		matchColorButtonEnabled = false
		BUTTON_AutoColor.BackgroundColor3 = autoColorHighlight
		BUTTON_MatchColor.Text = "automatch[c]"
		BUTTON_MatchColor.BackgroundColor3 = matchColorHighlight
		autoColor = true
	else
		matchColorButtonEnabled = true
		BUTTON_MatchColor.Text = "match floor [c]"
		BUTTON_MatchColor.BackgroundColor3 = defaultButtonColor
		BUTTON_AutoColor.BackgroundColor3 = defaultButtonColor
		autoColor = false
	end
end)

BUTTON_AddRoof.MouseButton1Click:Connect(function()
	addRoof()
end)

BUTTON_AutoRoof.MouseButton1Click:Connect(function()
	if(autoRoof == false) then
		autoRoof = true
		BUTTON_AutoRoof.BackgroundColor3 = matchColorHighlight
	else
		autoRoof = false
		BUTTON_AutoRoof.BackgroundColor3 = defaultButtonColor
	end
end)

BUTTON_WallPlacement.MouseButton1Click:Connect(function()
	if(flush == true) then
		BUTTON_WallPlacement.Text = "outside"
		flush = false
	else
		BUTTON_WallPlacement.Text = "flush"
		flush = true
	end
end)


BUTTON_Place.MouseButton1Click:Connect(function()
	getPartInfo()
	updateWallSettings()
	createFlushWalls()
	if autoRoof == true  then
		addRoof()
	end
	TEXTBOX_Color.BorderColor3 = wallColor
	LABEL_Status.Text = "h[" .. wallHeight .. "]t[" .. wallThickness .. "]_fastwalls"
end)

