local runService = game:GetService("RunService")
local selection = game:GetService("Selection")
local coreGui = game:GetService("CoreGui")

local toolbarManager = require(script.Parent.toolbarManager)






local gColor = Enum.StudioStyleGuideColor
local gModifier = Enum.StudioStyleGuideModifier
local v3 = Vector3.new
local abs = math.abs

local connections = {}

local retrievedActive = plugin:GetSetting("active") or false
local retrievedShowDirectionalVectors = false
local retrievedDynamicHighlight = plugin:GetSetting("dynamicHighlight") or true
local retrievedHightlightThickness = plugin:GetSetting("highlightThickness") or 0.15

local state = {
	selectedFace = nil,
	currentlySelected = nil,
	binded = false,
	selectedObjectEvent = nil,
	setting = {
		active = retrievedActive,
		showDirectionalVectors = retrievedShowDirectionalVectors,
		dynamicHighlight = retrievedDynamicHighlight,
		highlightThickness = retrievedHightlightThickness,
	}
}


local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 200, 400, 0, 100)
local WIDGET = plugin:CreateDockWidgetPluginGui("TestWidget", widgetInfo)
WIDGET.Title = "Select Face"
local gui = script.MainBackground
gui.Parent = WIDGET
local graphics = coreGui:GetChildren()
for _, graphic in graphics do
	if graphic.Name == "FaceSelectorVisuals" then
		graphic:Destroy()
	end
end
local visuals = script.FaceSelectorVisuals
visuals.Parent = coreGui
local faces = visuals.Face
local direction = visuals.Direction



local function getUIColor(guideColor, guideModifier)
	return settings().Studio.Theme:GetColor(gColor[guideColor], gModifier[guideModifier or "Default"])
end

local function updatePluginTheme()
	gui.BackgroundColor3 = getUIColor("MainBackground")
	gui.BorderColor3 = getUIColor("Border")
	gui.ScrollContainer.BorderColor3 = getUIColor("Border")
	gui.ScrollContainer.ScrollBarImageColor3 = getUIColor("ScrollBar")
	gui.ScrollBarBackground.BackgroundColor3 = getUIColor("ScrollBarBackground")
	gui.ScrollBarBackground.BorderColor3 = getUIColor("Border")
	local cont = gui.ScrollContainer
	cont.ActiveGui.Text.TextColor3 = getUIColor("MainText")
	cont.ActiveGui.CheckBox.BackgroundColor3 = getUIColor("Dark")
	cont.ActiveGui.CheckBox.Display.BackgroundColor3 = getUIColor("Button", "Selected")
	cont.FaceSelectorBackground.BackgroundColor3 = getUIColor("Shadow")
	for _, ui in pairs(cont.FaceSelectorBackground.FaceSelector:GetChildren()) do
		if ui.ClassName ~= "UIListLayout" then
			local typ = ui.Name == state.selectedFace and "Selected" or "Default"
			ui.BackgroundColor3 = getUIColor("RibbonButton", typ)
			ui.TextColor3 = getUIColor("MainText")
			ui.BorderColor3 = getUIColor("Border", "Default")
		end
	end
	for _, ui in pairs(cont.CheckBoxes:GetChildren()) do
		if ui.ClassName ~= "UIListLayout" then
			if ui:FindFirstChild("CheckBox") then
				ui.Text.TextColor3 = getUIColor("MainText")
				ui.CheckBox.BackgroundColor3 = getUIColor("Dark")
				ui.CheckBox.Display.BackgroundColor3 = getUIColor("Button", "Selected")
			elseif ui:FindFirstChild("TextBox") then
				ui.Text.TextColor3 = getUIColor("MainText")
				ui.TextBox.TextColor3 = getUIColor("MainText")
				ui.TextBox.BackgroundColor3 = getUIColor("DialogButton")
				ui.TextBox.BorderColor3 = getUIColor("Border")
			else
				for _, folder in pairs(ui:GetChildren()) do
					for _, text in pairs(folder:GetChildren()) do
						text.TextColor3 = getUIColor("MainText")
					end
				end
			end
		end
	end
end
updatePluginTheme()

local function getObjSize()
	local objCFrame, objSize
	if state.currentlySelected:IsA("Model") then
		return state.currentlySelected:GetBoundingBox()
	elseif state.currentlySelected:IsA("BasePart") then
		return state.currentlySelected.CFrame, state.currentlySelected.Size
	end
end

local function updateLookVectorText(update)
	if update then
		for _,t in pairs(gui.ScrollContainer.CheckBoxes.Vectors:GetChildren()) do
			local vector = getObjSize()[t.Name]
			for _,d in pairs(t:GetChildren()) do
				if d.Name ~= "Text" then
					d.Text = string.sub(tostring(vector[d.Name]), 0, 6)
				end
			end
		end
	else
		for _,t in pairs(gui.ScrollContainer.CheckBoxes.Vectors:GetChildren()) do
			for _,d in pairs(t:GetChildren()) do
				if d.Name ~= "Text" then
					d.Text = ""
				end
			end
		end
	end
end

local faceOffsets = {
	Back = v3(0,0,1),
	Bottom = v3(0,-1,0),
	Front = v3(0,0,-1),
	Left = v3(-1,0,0),
	Right = v3(1,0,0),
	Top = v3(0,1,0),
}
local targfaces = {"Top", "Bottom", "Left", "Right"}

function updateFaceAdornees(objSize)
	if state.selectedFace then
		local index = 1
		for i,v in pairs(faceOffsets) do
			if v:Cross(faceOffsets[state.selectedFace]) ~= v3() then
				local targetAdornee = faces[targfaces[index]]
				targetAdornee.Adornee = state.currentlySelected
				local targOffset = faceOffsets[state.selectedFace] + v
				targetAdornee.SizeRelativeOffset = targOffset
				local ts = v:Cross(faceOffsets[state.selectedFace])
				local min_size = math.min(objSize.X, objSize.Y, objSize.Z)
				local thick
				if state.setting.dynamicHighlight then
					thick = math.max(0.05 * min_size,0.05)
				else
					thick = state.setting.highlightThickness
				end
				targetAdornee.Size = v3(abs(ts.X) * objSize.X + thick, abs(ts.Y) * objSize.Y + thick, abs(ts.Z) * objSize.Z + thick)
				index = index + 1
			end
		end
	else
		for i,v in pairs(targfaces) do
			local targetAdornee = faces[v]
			targetAdornee.Adornee = nil
		end
	end
end

local function validateObject(v)
	return (v:IsA("BasePart") or v:IsA("Model")) and v ~= workspace and workspace:IsAncestorOf(v)
end

local function updateObject()
	local exists = state.currentlySelected
	local isValid = false;
	if exists then
		isValid = validateObject(exists)
	end
	
	if isValid then
		local objCFrame, objSize = getObjSize()
		updateFaceAdornees(objSize)
		updateLookVectorText(true)
		local targetSize = math.max(objSize.X, objSize.Y, objSize.Z) * 1.5
		for i,v in pairs(direction:GetChildren()) do
			v.Adornee = state.currentlySelected
		end
		local targetWidth = math.max(targetSize * 0.015, 0.01)
		direction.lookVector.Size = v3(targetWidth, targetWidth, targetSize)
		direction.lookVector.SizeRelativeOffset = v3(0, 0, -targetSize/objSize.Z)
		direction.rightVector.Size = v3(targetSize, targetWidth, targetWidth)
		direction.rightVector.SizeRelativeOffset = v3(targetSize/objSize.X, 0, 0)
		direction.upVector.Size = v3(targetWidth, targetSize, targetWidth)
		direction.upVector.SizeRelativeOffset = v3(0, targetSize/objSize.Y, 0)
	else
		for i,v in pairs(targfaces) do
			faces[v].Adornee = nil
		end
		for i,v in pairs(direction:GetChildren()) do
			v.Adornee = nil
		end
		updateLookVectorText(false)
	end
end


local function connectSelectionChanged()
	for i,v in pairs(selection:Get()) do
		if validateObject(v) then
			state.currentlySelected = v
			updateObject()
			state.selectedObjectEvent = state.currentlySelected.Changed:Connect(updateObject)
			break
		end
	end
	updateLookVectorText(state.currentlySelected ~= nil)
	table.insert(connections, selection.SelectionChanged:Connect(function()
		state.currentlySelected = nil
		for i,v in pairs(selection:Get()) do
			if validateObject(v) then
				state.currentlySelected = v
				updateObject()
				state.selectedObjectEvent = state.currentlySelected.Changed:Connect(updateObject)
				--state.xxx = state.currentlySelected.AncestryChanged:Connect(updateObject)
				break
			end
		end
		if not state.currentlySelected then
			if state.selectedObjectEvent then
				state.selectedObjectEvent:Disconnect()
				state.selectedObjectEvent = nil
			end
			updateObject()
		end
	end))
end

local function updateActive()
	local transparency = state.setting.active and 0.5 or 1
	gui.ScrollContainer.ActiveGui.CheckBox.Display.Visible = state.setting.active
	for _,ad in pairs(visuals.Face:GetChildren()) do
		ad.Transparency = transparency
	end
	for _,ad in pairs(visuals.Direction:GetChildren()) do
		ad.Transparency = (state.setting.active and state.setting.showDirectionalVectors) and 0.5 or 1
	end
end

local function updateVectors()
	gui.ScrollContainer.CheckBoxes.ShowVectors.CheckBox.Display.Visible = state.setting.showDirectionalVectors
	local transparency = (state.setting.showDirectionalVectors and state.setting.active) and 0.5 or 1
	for _,ad in pairs(visuals.Direction:GetChildren()) do
		ad.Transparency = transparency
	end
end

local function updateDynamicHighlight()
	gui.ScrollContainer.CheckBoxes.DynamicHighlight.CheckBox.Display.Visible = state.setting.dynamicHighlight
	if state.currentlySelected then
		local objCFrame, objSize = getObjSize()
		updateFaceAdornees(objSize)
	end
end

local function updateHighlightThickness(high_thick)
	local success, err = pcall(function()
		local target_thickness = tonumber(high_thick.Text)
		if target_thickness ~= nil then
			if target_thickness >= 0 then
				state.setting.highlightThickness = target_thickness
				plugin:SetSetting("highlightThickness", target_thickness)
				if state.currentlySelected then
					local objCFrame, objSize = getObjSize()
					updateFaceAdornees(objSize)
				end
			else
				high_thick.Text = state.setting.highlightThickness
			end
		else
			high_thick.Text = state.setting.highlightThickness
		end
	end)
end

local function faceSelectorClickConnection()
	local faceSelector = gui.ScrollContainer.FaceSelectorBackground.FaceSelector
	for _, ui in pairs(faceSelector:GetChildren()) do
		if ui.ClassName ~= "UIListLayout" then
			table.insert(connections, ui.MouseButton1Click:Connect(function()
				if faceSelector:FindFirstChild(state.selectedFace or "") then
					faceSelector[state.selectedFace].BackgroundColor3 = getUIColor("RibbonButton", "Default")
					faceSelector[state.selectedFace].TextColor3 = getUIColor("MainText", "Default")
				end
				if ui.Name ~= state.selectedFace then
					state.selectedFace = ui.Name
					ui.BackgroundColor3 = getUIColor("RibbonButton", "Selected")
					ui.TextColor3 = getUIColor("MainText")
				else
					state.selectedFace = nil
				end
				updateObject()
			end))
		end
	end
end

settings().Studio.ThemeChanged:Connect(updatePluginTheme)
local high_thick = gui.ScrollContainer.CheckBoxes.HighlightThickness.TextBox

connectSelectionChanged()
faceSelectorClickConnection()
updateActive()
updateVectors()
updateDynamicHighlight()
high_thick.Text = state.setting.highlightThickness
table.insert(connections, gui.ScrollContainer.ActiveGui.CheckBox.MouseButton1Click:Connect(function()
	state.setting.active = not state.setting.active
	plugin:SetSetting("active", state.setting.active)
	updateActive()
end))
table.insert(connections, gui.ScrollContainer.CheckBoxes.ShowVectors.CheckBox.MouseButton1Click:Connect(function()
	state.setting.showDirectionalVectors = not state.setting.showDirectionalVectors
	updateVectors()
end))
table.insert(connections, gui.ScrollContainer.CheckBoxes.DynamicHighlight.CheckBox.MouseButton1Click:Connect(function()
	state.setting.dynamicHighlight = not state.setting.dynamicHighlight
	plugin:SetSetting("dynamicHighlight", state.setting.dynamicHighlight)
	updateDynamicHighlight()
end))

table.insert(connections, high_thick.FocusLost:Connect(function()
	updateHighlightThickness(high_thick)
end))


local function buildButton(toolbar)
	local button = toolbarManager.addButton(
		toolbar,
		"Part Face Selector", 
		"Shows selected face of models and baseparts. Can also display directional vectors.", 
		"rbxassetid://5602410390"
	)
	
	button:SetActive(WIDGET.Enabled)
	button.Click:connect(function()
		WIDGET.Enabled = not WIDGET.Enabled
		button:SetActive(WIDGET.Enabled)
	end)
end

toolbarManager.getToolbar(plugin, "Tukars' Plugins", buildButton)
