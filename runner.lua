local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- THEME: PURE BLACK & WHITE (no glass, no gradients)
-- ═══════════════════════════════════════════════════
local C = {
    bg              = Color3.fromRGB(0, 0, 0),
    bgCard          = Color3.fromRGB(8, 8, 8),
    surface         = Color3.fromRGB(16, 16, 16),
    surfaceHover    = Color3.fromRGB(32, 32, 32),
    input           = Color3.fromRGB(24, 24, 24),
    accent          = Color3.fromRGB(255, 255, 255),  -- white
    accentDim       = Color3.fromRGB(180, 180, 180),
    text            = Color3.fromRGB(240, 240, 240),
    textMuted       = Color3.fromRGB(160, 160, 160),
    textDim         = Color3.fromRGB(100, 100, 100),
    divider         = Color3.fromRGB(40, 40, 40),
    border          = Color3.fromRGB(60, 60, 60),
}

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

-- Clean up old GUI
if CoreGui:FindFirstChild("TVMReanimationRunner") then
    CoreGui.TVMReanimationRunner:Destroy()
end

-- ═══════════════════════════════════════════════════
-- LOAD MODULE & ANIMATIONS (unchanged)
-- ═══════════════════════════════════════════════════
local api
local success, result = pcall(function()
    if isfile and isfile("module.lua") then
        return loadstring(readfile("module.lua"))()
    end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/module.lua"))()
end)
if not (success and type(result) == "table") then
    warn("TVM Reanimation: Failed to load module.lua")
    return
end
api = result

local animations = {}
local anim_success, anim_data = pcall(function()
    if isfile and isfile("animations.json") then
        return readfile("animations.json")
    end
    return game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/animations.json")
end)
if anim_success and type(anim_data) == "string" then
    if anim_data:sub(1,3) == "\239\187\191" then anim_data = anim_data:sub(4) end
    local decode_success, decoded = pcall(function() return HttpService:JSONDecode(anim_data) end)
    if decode_success and type(decoded) == "table" then
        for _, item in ipairs(decoded) do
            if item.name and item.path then
                table.insert(animations, { name = item.name, path = item.path, category = item.category or "Reanims" })
            end
        end
        table.sort(animations, function(a,b) return a.name:lower() < b.name:lower() end)
    end
end

-- Config
local CONFIG_FILE = "TVMReanimConfig.json"
local savedConfig = {
    favs = {}, binds = {}, states = {}, speed = 1.0, speedBinds = {},
    customAnims = {}, hiddenLimbs = {}
}
if isfile and readfile and isfile(CONFIG_FILE) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k,v in pairs(data) do if savedConfig[k] ~= nil then savedConfig[k] = v end end
        end
    end)
end

_G.hiddenBodyParts = _G.hiddenBodyParts or {}
if savedConfig.hiddenLimbs then
    for limbName, isHidden in pairs(savedConfig.hiddenLimbs) do
        if isHidden then _G.hiddenBodyParts[limbName] = true end
    end
end

if savedConfig.customAnims and #savedConfig.customAnims > 0 then
    for _, ca in ipairs(savedConfig.customAnims) do
        table.insert(animations, { name = ca.name, path = ca.script, category = "Custom", isCustom = true })
    end
    table.sort(animations, function(a,b) return a.name:lower() < b.name:lower() end)
end

local function saveConfig()
    if writefile then
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(savedConfig)) end)
    end
end

task.spawn(function()
    task.wait(2)
    if api and api.preload_animation then
        for animName, _ in pairs(savedConfig.favs) do
            for _, a in ipairs(animations) do
                if a.name == animName then
                    api.preload_animation(a.path)
                    task.wait(0.3)
                    break
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- GUI CONSTRUCTION (solid, no glass)
-- ═══════════════════════════════════════════════════
local currentSpeed = savedConfig.speed or 1.0
local currentPlayingAnim = nil
local manualAnimationPlaying = false
local currentTab = "Reanims"

local gui = Instance.new("ScreenGui")
gui.Name = "TVMReanimationRunner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local GUI_WIDTH = 380
local GUI_HEIGHT = 525

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)
mainFrame.Position = UDim2.new(0.5, -GUI_WIDTH/2, 0.5, -GUI_HEIGHT/2)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BackgroundTransparency = 0  -- solid
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui
applyCorner(mainFrame, 10)

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = C.surface
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
applyCorner(titleBar, 10)

local titleDivider = Instance.new("Frame")
titleDivider.Size = UDim2.new(1, 0, 0, 1)
titleDivider.Position = UDim2.new(0, 0, 1, -1)
titleDivider.BackgroundColor3 = C.divider
titleDivider.BorderSizePixel = 0
titleDivider.Parent = titleBar

-- Window controls
local macBtns = Instance.new("Frame")
macBtns.Size = UDim2.new(0, 44, 1, 0)
macBtns.Position = UDim2.new(0, 10, 0, 0)
macBtns.BackgroundTransparency = 1
macBtns.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 12, 0, 12)
closeBtn.Position = UDim2.new(0, 0, 0.5, -6)
closeBtn.BackgroundColor3 = Color3.fromRGB(220,220,220)
closeBtn.Text = ""
closeBtn.Parent = macBtns
applyCorner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 12, 0, 12)
minBtn.Position = UDim2.new(0, 18, 0.5, -6)
minBtn.BackgroundColor3 = Color3.fromRGB(180,180,180)
minBtn.Text = ""
minBtn.Parent = macBtns
applyCorner(minBtn, 6)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 160, 0, 24)
titleLabel.Position = UDim2.new(0, 48, 0.5, -12)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "TVM Reanimation"
titleLabel.TextColor3 = C.accent
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 118, 0, 26)
toggleBtn.Position = UDim2.new(1, -128, 0.5, -13)
toggleBtn.BackgroundColor3 = C.input
toggleBtn.Text = "Enable Reanim"
toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 10
toggleBtn.Parent = titleBar
applyCorner(toggleBtn, 100)

local bodyContainer = Instance.new("Frame")
bodyContainer.Size = UDim2.new(1, 0, 1, -44)
bodyContainer.Position = UDim2.new(0, 0, 0, 44)
bodyContainer.BackgroundTransparency = 1
bodyContainer.Parent = mainFrame

local isMinimized = false
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    bodyContainer.Visible = not isMinimized
    titleDivider.Visible = not isMinimized
    mainFrame.Size = UDim2.new(0, GUI_WIDTH, 0, isMinimized and 44 or GUI_HEIGHT)
end)

-- Dragging
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Sub‑Tab Bar
local tabNames = { "Reanims", "Favs", "Custom", "Binds", "States", "Speed", "Limbs" }
local tabButtons = {}
local switchTab

local subTabBar = Instance.new("Frame")
subTabBar.Size = UDim2.new(1, -20, 0, 34)
subTabBar.Position = UDim2.new(0, 10, 0, 8)
subTabBar.BackgroundColor3 = C.surface
subTabBar.BorderSizePixel = 0
subTabBar.Parent = bodyContainer
applyCorner(subTabBar, 100)

local tabsScroll = Instance.new("ScrollingFrame")
tabsScroll.Size = UDim2.new(1, -8, 1, -6)
tabsScroll.Position = UDim2.new(0, 4, 0, 3)
tabsScroll.BackgroundTransparency = 1
tabsScroll.BorderSizePixel = 0
tabsScroll.ScrollBarThickness = 0
tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
pcall(function() tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X end)
tabsScroll.CanvasSize = UDim2.new(0, #tabNames * 56 + 10, 0, 0)
tabsScroll.Parent = subTabBar

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabsLayout.Padding = UDim.new(0, 4)
tabsLayout.Parent = tabsScroll

for i, tName in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, 52, 1, 0)
    tb.BackgroundColor3 = (i == 1) and C.accent or C.surface
    tb.BackgroundTransparency = 0
    tb.Text = tName
    tb.TextColor3 = (i == 1) and C.bg or C.textMuted
    tb.Font = (i == 1) and Enum.Font.GothamBold or Enum.Font.GothamMedium
    tb.TextSize = 10
    tb.AutoButtonColor = false
    tb.Parent = tabsScroll
    applyCorner(tb, 100)
    tabButtons[tName] = { btn = tb }
    tb.MouseButton1Click:Connect(function()
        if switchTab then switchTab(tName) end
    end)
end

-- Now Playing Bar (solid)
local npBar = Instance.new("Frame")
npBar.Size = UDim2.new(1, -20, 0, 32)
npBar.Position = UDim2.new(0, 10, 1, -40)
npBar.BackgroundColor3 = C.surface
npBar.BorderSizePixel = 0
npBar.Parent = bodyContainer
applyCorner(npBar, 100)

local npDot = Instance.new("Frame")
npDot.Size = UDim2.new(0, 7, 0, 7)
npDot.Position = UDim2.new(0, 12, 0.5, -3.5)
npDot.BackgroundColor3 = C.textMuted
npDot.BorderSizePixel = 0
npDot.Parent = npBar
applyCorner(npDot, 4)

local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1, -68, 1, 0)
nowPlayingLabel.Position = UDim2.new(0, 28, 0, 0)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "No animation playing"
nowPlayingLabel.TextColor3 = C.textMuted
nowPlayingLabel.Font = Enum.Font.GothamMedium
nowPlayingLabel.TextSize = 10.5
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.TextTruncate = Enum.TextTruncate.AtEnd
nowPlayingLabel.Parent = npBar

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 22, 0, 22)
stopBtn.Position = UDim2.new(1, -28, 0.5, -11)
stopBtn.BackgroundColor3 = C.input
stopBtn.Text = ""
stopBtn.Parent = npBar
applyCorner(stopBtn, 11)

local stopIcon = Instance.new("Frame")
stopIcon.Size = UDim2.new(0, 8, 0, 8)
stopIcon.Position = UDim2.new(0.5, -4, 0.5, -4)
stopIcon.BackgroundColor3 = C.textMuted
stopIcon.BorderSizePixel = 0
stopIcon.Parent = stopBtn
applyCorner(stopIcon, 2)

local function updateNowPlayingUI(animName)
    currentPlayingAnim = animName
    if animName and animName ~= "" then
        nowPlayingLabel.Text = "▶  " .. animName:gsub("%.lua$","")
        nowPlayingLabel.TextColor3 = C.text
        npDot.BackgroundColor3 = C.accent
        stopIcon.BackgroundColor3 = Color3.fromRGB(180,180,180)
    else
        nowPlayingLabel.Text = "No animation playing"
        nowPlayingLabel.TextColor3 = C.textMuted
        npDot.BackgroundColor3 = C.textMuted
        stopIcon.BackgroundColor3 = C.textMuted
    end
end

stopBtn.MouseButton1Click:Connect(function()
    manualAnimationPlaying = false
    if api and api.stop_animation then api.stop_animation() end
    updateNowPlayingUI(nil)
end)

api.on_animation_play(function(url)
    local name
    for _, a in ipairs(animations) do if a.path == url then name = a.name break end end
    updateNowPlayingUI(name or "Playing Animation")
end)
api.on_animation_stop(function() updateNowPlayingUI(nil) end)

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -20, 1, -94)
contentArea.Position = UDim2.new(0, 10, 0, 48)
contentArea.BackgroundTransparency = 1
contentArea.Parent = bodyContainer

-- List Panel
local listPanel = Instance.new("Frame")
listPanel.Size = UDim2.new(1, 0, 1, 0)
listPanel.BackgroundTransparency = 1
listPanel.Visible = true
listPanel.Parent = contentArea

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -96, 0, 30)
searchBox.Position = UDim2.new(0, 0, 0, 0)
searchBox.BackgroundColor3 = C.input
searchBox.PlaceholderText = "Search animations..."
searchBox.PlaceholderColor3 = C.textMuted
searchBox.Text = ""
searchBox.TextColor3 = C.text
searchBox.Font = Enum.Font.GothamMedium
searchBox.TextSize = 10.5
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = listPanel
applyCorner(searchBox, 100)

local addCustomBtn = Instance.new("TextButton")
addCustomBtn.Size = UDim2.new(0, 90, 0, 30)
addCustomBtn.Position = UDim2.new(1, -90, 0, 0)
addCustomBtn.BackgroundColor3 = C.surface
addCustomBtn.Text = "+ Add Custom"
addCustomBtn.TextColor3 = C.accent
addCustomBtn.Font = Enum.Font.GothamBold
addCustomBtn.TextSize = 9.5
addCustomBtn.Parent = listPanel
applyCorner(addCustomBtn, 100)

local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, 0, 1, -38)
scrollList.Position = UDim2.new(0, 0, 0, 38)
scrollList.BackgroundTransparency = 1
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = C.accent
scrollList.ScrollBarImageTransparency = 0.6
scrollList.CanvasSize = UDim2.new(0,0,0,0)
scrollList.Parent = listPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollList

local emptyFavsLabel = Instance.new("TextLabel")
emptyFavsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyFavsLabel.Position = UDim2.new(0, 0, 0.3, 0)
emptyFavsLabel.BackgroundTransparency = 1
emptyFavsLabel.Text = "No favorite animations yet.\nClick the star icon (★) on any animation in the Reanims tab!"
emptyFavsLabel.TextColor3 = C.textMuted
emptyFavsLabel.Font = Enum.Font.GothamMedium
emptyFavsLabel.TextSize = 11
emptyFavsLabel.Visible = false
emptyFavsLabel.Parent = listPanel

local emptyCustomLabel = Instance.new("TextLabel")
emptyCustomLabel.Size = UDim2.new(1, 0, 0, 60)
emptyCustomLabel.Position = UDim2.new(0, 0, 0.3, 0)
emptyCustomLabel.BackgroundTransparency = 1
emptyCustomLabel.Text = "No custom animations added yet.\nClick [+ Add Custom] above to paste and import animations!"
emptyCustomLabel.TextColor3 = C.textMuted
emptyCustomLabel.Font = Enum.Font.GothamMedium
emptyCustomLabel.TextSize = 11
emptyCustomLabel.Visible = false
emptyCustomLabel.Parent = listPanel

-- Binds Panel
local bindsPanel = Instance.new("ScrollingFrame")
bindsPanel.Size = UDim2.new(1, 0, 1, 0)
bindsPanel.BackgroundTransparency = 1
bindsPanel.BorderSizePixel = 0
bindsPanel.ScrollBarThickness = 3
bindsPanel.ScrollBarImageColor3 = C.accent
bindsPanel.ScrollBarImageTransparency = 0.6
bindsPanel.Visible = false
bindsPanel.Parent = contentArea

local bindsLayout = Instance.new("UIListLayout")
bindsLayout.Padding = UDim.new(0, 6)
bindsLayout.SortOrder = Enum.SortOrder.LayoutOrder
bindsLayout.Parent = bindsPanel

local bindsHeader = Instance.new("TextLabel")
bindsHeader.Size = UDim2.new(1, 0, 0, 20)
bindsHeader.BackgroundTransparency = 1
bindsHeader.Text = "Click key button to rebind  |  Click [X] to unbind"
bindsHeader.TextColor3 = C.textMuted
bindsHeader.Font = Enum.Font.GothamMedium
bindsHeader.TextSize = 10
bindsHeader.TextXAlignment = Enum.TextXAlignment.Left
bindsHeader.Parent = bindsPanel

local emptyBindsLabel = Instance.new("TextLabel")
emptyBindsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyBindsLabel.BackgroundTransparency = 1
emptyBindsLabel.Text = "No keybinds assigned yet.\nIn the Reanims tab, click [+] next to any animation to bind a key!"
emptyBindsLabel.TextColor3 = C.textMuted
emptyBindsLabel.Font = Enum.Font.GothamMedium
emptyBindsLabel.TextSize = 11
emptyBindsLabel.Visible = false
emptyBindsLabel.Parent = bindsPanel

-- Speed Panel (simplified)
local speedPanel = Instance.new("ScrollingFrame")
speedPanel.Size = UDim2.new(1, 0, 1, 0)
speedPanel.BackgroundTransparency = 1
speedPanel.BorderSizePixel = 0
speedPanel.ScrollBarThickness = 3
speedPanel.ScrollBarImageColor3 = C.accent
speedPanel.ScrollBarImageTransparency = 0.6
speedPanel.Visible = false
speedPanel.Parent = contentArea

local speedListLayout = Instance.new("UIListLayout")
speedListLayout.Padding = UDim.new(0, 10)
speedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
speedListLayout.Parent = speedPanel

local sliderCard = Instance.new("Frame")
sliderCard.Size = UDim2.new(1, 0, 0, 78)
sliderCard.BackgroundColor3 = C.surface
sliderCard.Parent = speedPanel
applyCorner(sliderCard, 8)

local scTitle = Instance.new("TextLabel")
scTitle.Size = UDim2.new(1, -20, 0, 22)
scTitle.Position = UDim2.new(0, 10, 0, 8)
scTitle.BackgroundTransparency = 1
scTitle.Text = "PLAYBACK SPEED"
scTitle.TextColor3 = C.textMuted
scTitle.Font = Enum.Font.GothamBold
scTitle.TextSize = 10
scTitle.TextXAlignment = Enum.TextXAlignment.Left
scTitle.Parent = sliderCard

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -130, 0, 6)
sliderTrack.Position = UDim2.new(0, 10, 0, 46)
sliderTrack.BackgroundColor3 = C.input
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = sliderCard
applyCorner(sliderTrack, 3)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.3, 0, 1, 0)
sliderFill.BackgroundColor3 = C.accent
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
applyCorner(sliderFill, 3)

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, 14, 0, 14)
sliderKnob.Position = UDim2.new(1, -7, 0.5, -7)
sliderKnob.BackgroundColor3 = C.text
sliderKnob.BorderSizePixel = 0
sliderKnob.Parent = sliderFill
applyCorner(sliderKnob, 7)

local sliderValLabel = Instance.new("TextLabel")
sliderValLabel.Size = UDim2.new(0, 48, 0, 22)
sliderValLabel.Position = UDim2.new(1, -114, 0, 38)
sliderValLabel.BackgroundColor3 = C.input
sliderValLabel.Text = string.format("%.1fx", currentSpeed)
sliderValLabel.TextColor3 = C.accent
sliderValLabel.Font = Enum.Font.GothamBold
sliderValLabel.TextSize = 10
sliderValLabel.Parent = sliderCard
applyCorner(sliderValLabel, 4)

local resetSpeedBtn = Instance.new("TextButton")
resetSpeedBtn.Size = UDim2.new(0, 54, 0, 22)
resetSpeedBtn.Position = UDim2.new(1, -60, 0, 38)
resetSpeedBtn.BackgroundColor3 = C.input
resetSpeedBtn.Text = "Reset 1.0x"
resetSpeedBtn.TextColor3 = C.text
resetSpeedBtn.Font = Enum.Font.GothamSemibold
resetSpeedBtn.TextSize = 9
resetSpeedBtn.Parent = sliderCard
applyCorner(resetSpeedBtn, 4)

local function applySpeed(val)
    currentSpeed = math.clamp(math.floor(val*10)/10, 0.1, 5.0)
    savedConfig.speed = currentSpeed
    saveConfig()
    sliderValLabel.Text = string.format("%.1fx", currentSpeed)
    local pct = (currentSpeed - 0.1) / (3.0 - 0.1)
    sliderFill.Size = UDim2.new(math.clamp(pct,0,1), 0, 1, 0)
    if api and api.set_animation_speed then api.set_animation_speed(currentSpeed) end
end
resetSpeedBtn.MouseButton1Click:Connect(function() applySpeed(1.0) end)

local draggingSlider = false
local function updateSliderFromInput(input)
    local relX = math.clamp(input.Position.X - sliderTrack.AbsolutePosition.X, 0, sliderTrack.AbsoluteSize.X)
    local pct = relX / sliderTrack.AbsoluteSize.X
    applySpeed(0.1 + 2.9 * pct)
end
sliderCard.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = true
        updateSliderFromInput(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateSliderFromInput(input)
    end
end)

-- Presets (solid)
local presetCard = Instance.new("Frame")
presetCard.Size = UDim2.new(1, 0, 0, 110)
presetCard.BackgroundColor3 = C.surface
presetCard.Parent = speedPanel
applyCorner(presetCard, 8)

local pcTitle = Instance.new("TextLabel")
pcTitle.Size = UDim2.new(1, -20, 0, 20)
pcTitle.Position = UDim2.new(0, 10, 0, 8)
pcTitle.BackgroundTransparency = 1
pcTitle.Text = "SPEED PRESETS & HOTKEYS"
pcTitle.TextColor3 = C.textMuted
pcTitle.Font = Enum.Font.GothamBold
pcTitle.TextSize = 10
pcTitle.TextXAlignment = Enum.TextXAlignment.Left
pcTitle.Parent = presetCard

local pcSubtitle = Instance.new("TextLabel")
pcSubtitle.Size = UDim2.new(1, -20, 0, 14)
pcSubtitle.Position = UDim2.new(0, 10, 0, 26)
pcSubtitle.BackgroundTransparency = 1
pcSubtitle.Text = "Click speed button to apply  |  Click [+] to bind key"
pcSubtitle.TextColor3 = C.textMuted
pcSubtitle.Font = Enum.Font.Gotham
pcSubtitle.TextSize = 9
pcSubtitle.TextXAlignment = Enum.TextXAlignment.Left
pcSubtitle.Parent = presetCard

local speedPresets = {0.5, 1.0, 1.5, 2.0, 3.0}
local presetRow = Instance.new("Frame")
presetRow.Size = UDim2.new(1, -20, 0, 52)
presetRow.Position = UDim2.new(0, 10, 0, 48)
presetRow.BackgroundTransparency = 1
presetRow.Parent = presetCard

local currentlyBindingSpeed = nil
local speedBindButtons = {}
local pW = 1/#speedPresets
for i, spd in ipairs(speedPresets) do
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(pW, -4, 0, 24)
    sBtn.Position = UDim2.new((i-1)*pW, 2, 0, 0)
    sBtn.BackgroundColor3 = C.input
    sBtn.Text = string.format("%.1fx", spd)
    sBtn.TextColor3 = C.text
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 11
    sBtn.Parent = presetRow
    applyCorner(sBtn, 4)
    sBtn.MouseButton1Click:Connect(function() applySpeed(spd) end)

    local kBtn = Instance.new("TextButton")
    kBtn.Size = UDim2.new(pW, -4, 0, 20)
    kBtn.Position = UDim2.new((i-1)*pW, 2, 0, 28)
    kBtn.BackgroundColor3 = C.input
    local bound = savedConfig.speedBinds[tostring(spd)]
    kBtn.Text = bound and ("["..bound.."]") or "[+]"
    kBtn.TextColor3 = bound and C.accent or C.textMuted
    kBtn.Font = Enum.Font.GothamSemibold
    kBtn.TextSize = 9
    kBtn.Parent = presetRow
    applyCorner(kBtn, 4)
    speedBindButtons[tostring(spd)] = kBtn
    kBtn.MouseButton1Click:Connect(function()
        if currentlyBindingSpeed == tostring(spd) then
            currentlyBindingSpeed = nil
            local b = savedConfig.speedBinds[tostring(spd)]
            kBtn.Text = b and ("["..b.."]") or "[+]"
            return
        end
        currentlyBindingSpeed = tostring(spd)
        kBtn.Text = "[?]"
        kBtn.TextColor3 = Color3.fromRGB(200,200,200)
    end)
end

-- States Panel
local statesPanel = Instance.new("ScrollingFrame")
statesPanel.Size = UDim2.new(1, 0, 1, 0)
statesPanel.BackgroundTransparency = 1
statesPanel.BorderSizePixel = 0
statesPanel.ScrollBarThickness = 3
statesPanel.ScrollBarImageColor3 = C.accent
statesPanel.ScrollBarImageTransparency = 0.6
statesPanel.Visible = false
statesPanel.Parent = contentArea

local statesListLayout = Instance.new("UIListLayout")
statesListLayout.Padding = UDim.new(0, 8)
statesListLayout.SortOrder = Enum.SortOrder.LayoutOrder
statesListLayout.Parent = statesPanel

local statesHeader = Instance.new("TextLabel")
statesHeader.Size = UDim2.new(1, 0, 0, 18)
statesHeader.BackgroundTransparency = 1
statesHeader.Text = "CHARACTER STATE ANIMATIONS"
statesHeader.TextColor3 = C.textMuted
statesHeader.Font = Enum.Font.GothamBold
statesHeader.TextSize = 10
statesHeader.TextXAlignment = Enum.TextXAlignment.Left
statesHeader.Parent = statesPanel

local statesSubtitle = Instance.new("TextLabel")
statesSubtitle.Size = UDim2.new(1, 0, 0, 14)
statesSubtitle.BackgroundTransparency = 1
statesSubtitle.Text = "Automatically triggers animations on character movement"
statesSubtitle.TextColor3 = C.textMuted
statesSubtitle.Font = Enum.Font.Gotham
statesSubtitle.TextSize = 9
statesSubtitle.TextXAlignment = Enum.TextXAlignment.Left
statesSubtitle.Parent = statesPanel

local stateTypes = {"Idle","Walk","Run","Jump","Fall"}
local stateSelectButtons = {}
local modalSelectingState = nil

-- Animation Selector Modal
local modalOverlay = Instance.new("Frame")
modalOverlay.Size = UDim2.new(1,0,1,0)
modalOverlay.BackgroundColor3 = C.bg
modalOverlay.BackgroundTransparency = 0.6
modalOverlay.BorderSizePixel = 0
modalOverlay.Visible = false
modalOverlay.Parent = mainFrame

local modalCard = Instance.new("Frame")
modalCard.Size = UDim2.new(0, 330, 0, 400)
modalCard.Position = UDim2.new(0.5, -165, 0.5, -200)
modalCard.BackgroundColor3 = C.bgCard
modalCard.BorderSizePixel = 0
modalCard.Parent = modalOverlay
applyCorner(modalCard, 10)

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, -50, 0, 36)
modalTitle.Position = UDim2.new(0, 14, 0, 6)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "Select Animation for State"
modalTitle.TextColor3 = C.text
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 12
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.Parent = modalCard

local modalCloseBtn = Instance.new("TextButton")
modalCloseBtn.Size = UDim2.new(0, 24, 0, 24)
modalCloseBtn.Position = UDim2.new(1, -34, 0, 10)
modalCloseBtn.BackgroundColor3 = C.surface
modalCloseBtn.Text = "✕"
modalCloseBtn.TextColor3 = C.textMuted
modalCloseBtn.Font = Enum.Font.GothamBold
modalCloseBtn.TextSize = 11
modalCloseBtn.Parent = modalCard
applyCorner(modalCloseBtn, 12)
modalCloseBtn.MouseButton1Click:Connect(function()
    modalOverlay.Visible = false
    modalSelectingState = nil
end)

local modalSearch = Instance.new("TextBox")
modalSearch.Size = UDim2.new(1, -28, 0, 30)
modalSearch.Position = UDim2.new(0, 14, 0, 44)
modalSearch.BackgroundColor3 = C.input
modalSearch.PlaceholderText = "Search animations to assign..."
modalSearch.PlaceholderColor3 = C.textMuted
modalSearch.Text = ""
modalSearch.TextColor3 = C.text
modalSearch.Font = Enum.Font.GothamMedium
modalSearch.TextSize = 11
modalSearch.TextXAlignment = Enum.TextXAlignment.Left
modalSearch.ClearTextOnFocus = false
modalSearch.Parent = modalCard
applyCorner(modalSearch, 6)

local modalList = Instance.new("ScrollingFrame")
modalList.Size = UDim2.new(1, -28, 1, -90)
modalList.Position = UDim2.new(0, 14, 0, 80)
modalList.BackgroundTransparency = 1
modalList.BorderSizePixel = 0
modalList.ScrollBarThickness = 3
modalList.ScrollBarImageColor3 = C.accent
modalList.ScrollBarImageTransparency = 0.6
modalList.CanvasSize = UDim2.new(0,0,0,0)
modalList.Parent = modalCard

local modalListLayout = Instance.new("UIListLayout")
modalListLayout.Padding = UDim.new(0, 4)
modalListLayout.SortOrder = Enum.SortOrder.LayoutOrder
modalListLayout.Parent = modalList

local function populateModalList(filter)
    for _, c in ipairs(modalList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local term = (filter or ""):lower()
    local count = 0
    for _, a in ipairs(animations) do
        if term == "" or a.name:lower():find(term,1,true) then
            count = count + 1
            local ab = Instance.new("TextButton")
            ab.Size = UDim2.new(1, -6, 0, 28)
            ab.BackgroundColor3 = C.surface
            ab.Text = a.name
            ab.TextColor3 = C.text
            ab.Font = Enum.Font.GothamMedium
            ab.TextSize = 11
            ab.TextXAlignment = Enum.TextXAlignment.Left
            ab.TextTruncate = Enum.TextTruncate.AtEnd
            ab.Parent = modalList
            applyCorner(ab, 4)
            ab.MouseButton1Click:Connect(function()
                if modalSelectingState then
                    savedConfig.states[modalSelectingState] = { name = a.name, path = a.path }
                    saveConfig()
                    if stateSelectButtons[modalSelectingState] then
                        stateSelectButtons[modalSelectingState].Text = a.name
                        stateSelectButtons[modalSelectingState].TextColor3 = Color3.fromRGB(200,200,200)
                    end
                end
                modalOverlay.Visible = false
                modalSelectingState = nil
            end)
        end
    end
    modalList.CanvasSize = UDim2.new(0,0,0, count*32)
end
modalSearch:GetPropertyChangedSignal("Text"):Connect(function() populateModalList(modalSearch.Text) end)

-- Add Custom Modal (solid)
local addCustomModal = Instance.new("Frame")
addCustomModal.Size = UDim2.new(1,0,1,0)
addCustomModal.BackgroundColor3 = C.bg
addCustomModal.BackgroundTransparency = 0.6
addCustomModal.BorderSizePixel = 0
addCustomModal.Visible = false
addCustomModal.Parent = mainFrame

local addCard = Instance.new("Frame")
addCard.Size = UDim2.new(0, 330, 0, 380)
addCard.Position = UDim2.new(0.5, -165, 0.5, -190)
addCard.BackgroundColor3 = C.bgCard
addCard.BorderSizePixel = 0
addCard.Parent = addCustomModal
applyCorner(addCard, 10)

local addTitle = Instance.new("TextLabel")
addTitle.Size = UDim2.new(1, -50, 0, 36)
addTitle.Position = UDim2.new(0, 14, 0, 6)
addTitle.BackgroundTransparency = 1
addTitle.Text = "Add Custom Animation"
addTitle.TextColor3 = C.text
addTitle.Font = Enum.Font.GothamBold
addTitle.TextSize = 12
addTitle.TextXAlignment = Enum.TextXAlignment.Left
addTitle.Parent = addCard

local addCloseBtn = Instance.new("TextButton")
addCloseBtn.Size = UDim2.new(0, 24, 0, 24)
addCloseBtn.Position = UDim2.new(1, -34, 0, 10)
addCloseBtn.BackgroundColor3 = C.surface
addCloseBtn.Text = "✕"
addCloseBtn.TextColor3 = C.textMuted
addCloseBtn.Font = Enum.Font.GothamBold
addCloseBtn.TextSize = 11
addCloseBtn.Parent = addCard
applyCorner(addCloseBtn, 12)
addCloseBtn.MouseButton1Click:Connect(function() addCustomModal.Visible = false end)

local addNameBox = Instance.new("TextBox")
addNameBox.Size = UDim2.new(1, -28, 0, 28)
addNameBox.Position = UDim2.new(0, 14, 0, 44)
addNameBox.BackgroundColor3 = C.input
addNameBox.PlaceholderText = "Animation Name (optional)"
addNameBox.PlaceholderColor3 = C.textMuted
addNameBox.Text = ""
addNameBox.TextColor3 = C.text
addNameBox.Font = Enum.Font.GothamMedium
addNameBox.TextSize = 11
addNameBox.TextXAlignment = Enum.TextXAlignment.Left
addNameBox.ClearTextOnFocus = false
addNameBox.Parent = addCard
applyCorner(addNameBox, 6)

local addDataBox = Instance.new("TextBox")
addDataBox.Size = UDim2.new(1, -28, 0, 210)
addDataBox.Position = UDim2.new(0, 14, 0, 80)
addDataBox.BackgroundColor3 = C.input
addDataBox.PlaceholderText = "Paste keyframe script or table here...\n(Or press Ctrl+V to paste from clipboard)"
addDataBox.PlaceholderColor3 = C.textMuted
addDataBox.Text = ""
addDataBox.TextColor3 = C.text
addDataBox.Font = Enum.Font.Code
addDataBox.TextSize = 10
addDataBox.MultiLine = true
addDataBox.ClearTextOnFocus = false
addDataBox.TextWrapped = true
addDataBox.TextXAlignment = Enum.TextXAlignment.Left
addDataBox.TextYAlignment = Enum.TextYAlignment.Top
addDataBox.ClipsDescendants = true
addDataBox.Parent = addCard
applyCorner(addDataBox, 6)

local addStatus = Instance.new("TextLabel")
addStatus.Size = UDim2.new(1, -28, 0, 20)
addStatus.Position = UDim2.new(0, 14, 0, 298)
addStatus.BackgroundTransparency = 1
addStatus.Text = "Paste keyframe data or script table above."
addStatus.TextColor3 = C.textMuted
addStatus.Font = Enum.Font.Gotham
addStatus.TextSize = 10
addStatus.TextXAlignment = Enum.TextXAlignment.Left
addStatus.Parent = addCard

local addSubmitBtn = Instance.new("TextButton")
addSubmitBtn.Size = UDim2.new(1, -28, 0, 32)
addSubmitBtn.Position = UDim2.new(0, 14, 1, -44)
addSubmitBtn.BackgroundColor3 = C.surface
addSubmitBtn.Text = "+ Add Animation"
addSubmitBtn.TextColor3 = C.accent
addSubmitBtn.Font = Enum.Font.GothamBold
addSubmitBtn.TextSize = 11
addSubmitBtn.Parent = addCard
applyCorner(addSubmitBtn, 6)

local isDataBoxFocused = false
addDataBox.Focused:Connect(function() isDataBoxFocused = true end)
addDataBox.FocusLost:Connect(function() isDataBoxFocused = false end)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not isDataBoxFocused then return end
    if input.KeyCode == Enum.KeyCode.V and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        task.spawn(function()
            local ok, clip = pcall(getclipboard)
            if ok and type(clip)=="string" and #clip>0 then
                addDataBox.Text = clip
                addStatus.Text = "Loaded " .. tostring(#clip) .. " characters."
                addStatus.TextColor3 = C.text
            end
        end)
    end
end)

addSubmitBtn.MouseButton1Click:Connect(function()
    local raw = addDataBox.Text:gsub("^%s+",""):gsub("%s+$","")
    if raw == "" then
        addStatus.Text = "Please paste keyframe script or table first!"
        addStatus.TextColor3 = Color3.fromRGB(180,180,180)
        return
    end
    if not raw:find("{",1,true) then
        addStatus.Text = "Invalid data: doesn't look like keyframes table or script."
        addStatus.TextColor3 = Color3.fromRGB(180,180,180)
        return
    end
    local finalName = (addNameBox.Text:match("^%s*(.-)%s*$") or "") ~= "" and addNameBox.Text or ("Custom_"..(#savedConfig.customAnims+1))
    table.insert(savedConfig.customAnims, { name = finalName, script = raw })
    saveConfig()
    table.insert(animations, { name = finalName, path = raw, category = "Custom", isCustom = true })
    table.sort(animations, function(a,b) return a.name:lower() < b.name:lower() end)
    addCustomModal.Visible = false
    populateList()
end)

addCustomBtn.MouseButton1Click:Connect(function()
    addCustomModal.Visible = true
    addNameBox:CaptureFocus()
end)

-- States rows
for _, st in ipairs(stateTypes) do
    local sRow = Instance.new("Frame")
    sRow.Size = UDim2.new(1, 0, 0, 42)
    sRow.BackgroundColor3 = C.surface
    sRow.Parent = statesPanel
    applyCorner(sRow, 6)

    local stLabel = Instance.new("TextLabel")
    stLabel.Size = UDim2.new(0, 70, 1, 0)
    stLabel.Position = UDim2.new(0, 12, 0, 0)
    stLabel.BackgroundTransparency = 1
    stLabel.Text = st
    stLabel.TextColor3 = C.text
    stLabel.Font = Enum.Font.GothamBold
    stLabel.TextSize = 11
    stLabel.TextXAlignment = Enum.TextXAlignment.Left
    stLabel.Parent = sRow

    local currentAssignment = savedConfig.states[st]
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(1, -150, 0, 26)
    sBtn.Position = UDim2.new(0, 84, 0.5, -13)
    sBtn.BackgroundColor3 = C.input
    sBtn.Text = currentAssignment and currentAssignment.name or "None"
    sBtn.TextColor3 = currentAssignment and Color3.fromRGB(200,200,200) or C.textMuted
    sBtn.Font = Enum.Font.GothamMedium
    sBtn.TextSize = 11
    sBtn.TextXAlignment = Enum.TextXAlignment.Left
    sBtn.TextTruncate = Enum.TextTruncate.AtEnd
    sBtn.Parent = sRow
    applyCorner(sBtn, 4)
    stateSelectButtons[st] = sBtn

    sBtn.MouseButton1Click:Connect(function()
        modalSelectingState = st
        modalTitle.Text = "Assign Animation for: " .. st
        modalSearch.Text = ""
        populateModalList("")
        modalOverlay.Visible = true
    end)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 52, 0, 26)
    clearBtn.Position = UDim2.new(1, -60, 0.5, -13)
    clearBtn.BackgroundColor3 = C.input
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = C.textMuted
    clearBtn.Font = Enum.Font.GothamSemibold
    clearBtn.TextSize = 10
    clearBtn.Parent = sRow
    applyCorner(clearBtn, 4)
    clearBtn.MouseButton1Click:Connect(function()
        savedConfig.states[st] = nil
        saveConfig()
        sBtn.Text = "None"
        sBtn.TextColor3 = C.textMuted
    end)
end

-- Limbs Panel (solid, optimized)
local limbsPanel = Instance.new("ScrollingFrame")
limbsPanel.Size = UDim2.new(1, 0, 1, 0)
limbsPanel.BackgroundTransparency = 1
limbsPanel.BorderSizePixel = 0
limbsPanel.ScrollBarThickness = 3
limbsPanel.ScrollBarImageColor3 = C.accent
limbsPanel.ScrollBarImageTransparency = 0.6
limbsPanel.Visible = false
limbsPanel.Parent = contentArea

local limbsPadding = Instance.new("UIPadding")
limbsPadding.PaddingLeft = UDim.new(0, 2)
limbsPadding.PaddingRight = UDim.new(0, 4)
limbsPadding.PaddingTop = UDim.new(0, 2)
limbsPadding.PaddingBottom = UDim.new(0, 12)
limbsPadding.Parent = limbsPanel

local limbsLayout = Instance.new("UIListLayout")
limbsLayout.Padding = UDim.new(0, 8)
limbsLayout.SortOrder = Enum.SortOrder.LayoutOrder
limbsLayout.Parent = limbsPanel

local limbsHeader = Instance.new("TextLabel")
limbsHeader.Size = UDim2.new(1, 0, 0, 16)
limbsHeader.BackgroundTransparency = 1
limbsHeader.Text = "LIMB & BODY VISIBILITY"
limbsHeader.TextColor3 = C.textMuted
limbsHeader.Font = Enum.Font.GothamBold
limbsHeader.TextSize = 10
limbsHeader.TextXAlignment = Enum.TextXAlignment.Left
limbsHeader.LayoutOrder = 1
limbsHeader.Parent = limbsPanel

local function createToggleSwitch(parent, posX, posY)
    local track = Instance.new("Frame", parent)
    track.Size = UDim2.new(0, 44, 0, 22)
    track.Position = UDim2.new(1, posX or -54, 0.5, posY or -11)
    track.BackgroundColor3 = C.input
    track.BorderSizePixel = 0
    applyCorner(track, 100)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(100,100,100)
    knob.BorderSizePixel = 0
    applyCorner(knob, 100)
    return track, knob
end

local function updateToggleVisual(track, knob, isOn)
    track.BackgroundColor3 = isOn and C.accent or C.input
    knob.BackgroundColor3 = isOn and C.bg or Color3.fromRGB(100,100,100)
    knob.Position = isOn and UDim2.new(0, 25, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
end

local masterCard = Instance.new("Frame")
masterCard.Size = UDim2.new(1, 0, 0, 46)
masterCard.BackgroundColor3 = C.surface
masterCard.BorderSizePixel = 0
masterCard.LayoutOrder = 2
masterCard.Parent = limbsPanel
applyCorner(masterCard, 10)

local masterInfoFrame = Instance.new("Frame")
masterInfoFrame.Size = UDim2.new(1, -125, 1, 0)
masterInfoFrame.Position = UDim2.new(0, 14, 0, 0)
masterInfoFrame.BackgroundTransparency = 1
masterInfoFrame.Parent = masterCard

local masterTitleLbl = Instance.new("TextLabel")
masterTitleLbl.Size = UDim2.new(1, 0, 0, 20)
masterTitleLbl.Position = UDim2.new(0, 0, 0, 5)
masterTitleLbl.BackgroundTransparency = 1
masterTitleLbl.Text = "Master Limbs Switch"
masterTitleLbl.TextColor3 = C.text
masterTitleLbl.Font = Enum.Font.GothamBold
masterTitleLbl.TextSize = 11
masterTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
masterTitleLbl.Parent = masterInfoFrame

local masterDescLbl = Instance.new("TextLabel")
masterDescLbl.Size = UDim2.new(1, 0, 0, 16)
masterDescLbl.Position = UDim2.new(0, 0, 0, 23)
masterDescLbl.BackgroundTransparency = 1
masterDescLbl.Text = "Toggle all body parts on or off at once"
masterDescLbl.TextColor3 = C.textMuted
masterDescLbl.Font = Enum.Font.Gotham
masterDescLbl.TextSize = 9
masterDescLbl.TextXAlignment = Enum.TextXAlignment.Left
masterDescLbl.Parent = masterInfoFrame

local masterStatusLbl = Instance.new("TextLabel")
masterStatusLbl.Size = UDim2.new(0, 54, 1, 0)
masterStatusLbl.Position = UDim2.new(1, -114, 0, 0)
masterStatusLbl.BackgroundTransparency = 1
masterStatusLbl.Font = Enum.Font.GothamBold
masterStatusLbl.TextSize = 9
masterStatusLbl.TextXAlignment = Enum.TextXAlignment.Right
masterStatusLbl.Text = "ALL SHOWN"
masterStatusLbl.TextColor3 = Color3.fromRGB(200,200,200)
masterStatusLbl.Parent = masterCard

local masterTrack, masterKnob = createToggleSwitch(masterCard, -54, -11)

local masterBtn = Instance.new("TextButton")
masterBtn.Size = UDim2.new(1,0,1,0)
masterBtn.BackgroundTransparency = 1
masterBtn.Text = ""
masterBtn.Parent = masterCard

local limbDefinitions = {
    { id = "Head", name = "Head", desc = "Hides head, hats, face, nametag", parts = {"Head"} },
    { id = "Torso", name = "Torso", desc = "Hides main body (Torso, UpperTorso, LowerTorso)", parts = {"Torso","UpperTorso","LowerTorso"} },
    { id = "Left Arm", name = "Left Arm", desc = "Hides Left Arm / UpperArm / LowerArm / Hand", parts = {"Left Arm","LeftUpperArm","LeftLowerArm","LeftHand"} },
    { id = "Right Arm", name = "Right Arm", desc = "Hides Right Arm / UpperArm / LowerArm / Hand", parts = {"Right Arm","RightUpperArm","RightLowerArm","RightHand"} },
    { id = "Left Leg", name = "Left Leg", desc = "Hides Left Leg / UpperLeg / LowerLeg / Foot", parts = {"Left Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot"} },
    { id = "Right Leg", name = "Right Leg", desc = "Hides Right Leg / UpperLeg / LowerLeg / Foot", parts = {"Right Leg","RightUpperLeg","RightLowerLeg","RightFoot"} }
}
local limbButtons = {}

local function updateMasterToggleVisual()
    local hiddenCount = 0
    for _, ldef in ipairs(limbDefinitions) do
        local isHidden = false
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                isHidden = true; break
            end
        end
        if isHidden then hiddenCount = hiddenCount + 1 end
    end
    if hiddenCount == 0 then
        masterStatusLbl.Text = "ALL SHOWN"
        masterStatusLbl.TextColor3 = Color3.fromRGB(200,200,200)
        updateToggleVisual(masterTrack, masterKnob, true)
    elseif hiddenCount == #limbDefinitions then
        masterStatusLbl.Text = "ALL HIDDEN"
        masterStatusLbl.TextColor3 = Color3.fromRGB(120,120,120)
        updateToggleVisual(masterTrack, masterKnob, false)
    else
        masterStatusLbl.Text = "CUSTOM"
        masterStatusLbl.TextColor3 = Color3.fromRGB(180,180,180)
        masterTrack.BackgroundColor3 = Color3.fromRGB(30,30,30)
        masterKnob.BackgroundColor3 = Color3.fromRGB(140,140,140)
        masterKnob.Position = UDim2.new(0, 3, 0.5, -8)
    end
end

local function setLimbHidden(limbDef, hidden)
    for _, p in ipairs(limbDef.parts) do
        if hidden then
            _G.hiddenBodyParts[p] = true
            savedConfig.hiddenLimbs[p] = true
        else
            _G.hiddenBodyParts[p] = nil
            savedConfig.hiddenLimbs[p] = nil
        end
    end
    saveConfig()
    local rowData = limbButtons[limbDef.id]
    if rowData then
        local isVisible = not hidden
        rowData.statusLbl.Text = isVisible and "VISIBLE" or "HIDDEN"
        rowData.statusLbl.TextColor3 = isVisible and Color3.fromRGB(200,200,200) or Color3.fromRGB(100,100,100)
        updateToggleVisual(rowData.track, rowData.knob, isVisible)
    end
    updateMasterToggleVisual()
end

masterBtn.MouseButton1Click:Connect(function()
    local hiddenCount = 0
    for _, ldef in ipairs(limbDefinitions) do
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                hiddenCount = hiddenCount + 1
                break
            end
        end
    end
    local targetHidden = (hiddenCount == 0)
    for _, ldef in ipairs(limbDefinitions) do
        setLimbHidden(ldef, targetHidden)
    end
end)

for idx, ldef in ipairs(limbDefinitions) do
    local lRow = Instance.new("Frame")
    lRow.Size = UDim2.new(1, 0, 0, 44)
    lRow.BackgroundColor3 = C.surface
    lRow.BorderSizePixel = 0
    lRow.LayoutOrder = 3 + idx
    lRow.Parent = limbsPanel
    applyCorner(lRow, 10)

    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -125, 1, 0)
    infoFrame.Position = UDim2.new(0, 14, 0, 0)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = lRow

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Position = UDim2.new(0, 0, 0, 5)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = ldef.name
    titleLbl.TextColor3 = C.text
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = infoFrame

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, 0, 0, 16)
    descLbl.Position = UDim2.new(0, 0, 0, 23)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = ldef.desc
    descLbl.TextColor3 = C.textMuted
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 9
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextTruncate = Enum.TextTruncate.AtEnd
    descLbl.Parent = infoFrame

    local isCurrentlyHidden = false
    for _, p in ipairs(ldef.parts) do
        if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
            isCurrentlyHidden = true; break
        end
    end

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 52, 1, 0)
    statusLbl.Position = UDim2.new(1, -112, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 9
    statusLbl.TextXAlignment = Enum.TextXAlignment.Right
    statusLbl.Text = isCurrentlyHidden and "HIDDEN" or "VISIBLE"
    statusLbl.TextColor3 = isCurrentlyHidden and Color3.fromRGB(100,100,100) or Color3.fromRGB(200,200,200)
    statusLbl.Parent = lRow

    local track, knob = createToggleSwitch(lRow, -54, -11)
    updateToggleVisual(track, knob, not isCurrentlyHidden)

    local rowBtn = Instance.new("TextButton")
    rowBtn.Size = UDim2.new(1,0,1,0)
    rowBtn.BackgroundTransparency = 1
    rowBtn.Text = ""
    rowBtn.Parent = lRow

    limbButtons[ldef.id] = { statusLbl = statusLbl, track = track, knob = knob }

    rowBtn.MouseButton1Click:Connect(function()
        local isHidden = false
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                isHidden = true; break
            end
        end
        setLimbHidden(ldef, not isHidden)
    end)
end

local function updateLimbsUI()
    for _, ldef in ipairs(limbDefinitions) do
        local isHidden = false
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                isHidden = true; break
            end
        end
        local rowData = limbButtons[ldef.id]
        if rowData then
            local isVisible = not isHidden
            rowData.statusLbl.Text = isVisible and "VISIBLE" or "HIDDEN"
            rowData.statusLbl.TextColor3 = isVisible and Color3.fromRGB(200,200,200) or Color3.fromRGB(100,100,100)
            updateToggleVisual(rowData.track, rowData.knob, isVisible)
        end
    end
    updateMasterToggleVisual()
end

limbsPanel.CanvasSize = UDim2.new(0,0,0, #limbDefinitions * 56 + 80)

-- RenderStepped for hiding limbs
RunService.RenderStepped:Connect(function()
    local clone = api and api.get_clone and api.get_clone()
    if not clone then return end
    if not _G.hiddenBodyParts or not next(_G.hiddenBodyParts) then return end
    for partName, _ in pairs(_G.hiddenBodyParts) do
        local p = clone:FindFirstChild(partName)
        if p and p:IsA("BasePart") then
            p.LocalTransparencyModifier = 1
            p.Transparency = 1
        end
        if partName == "Head" then
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("Decal") then d.Transparency = 1
                elseif d:IsA("Accessory") then
                    local handle = d:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        handle.LocalTransparencyModifier = 1
                        handle.Transparency = 1
                    end
                end
            end
            local hum = clone:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.DisplayName = ""
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- LIST ENGINE (optimized with batching)
-- ═══════════════════════════════════════════════════
local ROW_HEIGHT = 38
local currentlyBinding = nil
local activeOutlineAnim = nil
local animButtons = {}

local function playSelectedAnimation(anim)
    if not (api and api.is_reanimated and api.is_reanimated()) then
        warn("TVM Reanimation: Enable Reanimation first!")
        return
    end
    if currentPlayingAnim == anim.name then
        manualAnimationPlaying = false
        api.stop_animation()
        activeOutlineAnim = nil
        updateNowPlayingUI(nil)
        return
    end
    manualAnimationPlaying = true
    activeOutlineAnim = anim.name
    api.play_animation(anim.path, currentSpeed)
    updateNowPlayingUI(anim.name)
end

local ROWS_PER_YIELD = 15
function populateList()
    for _, child in ipairs(scrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    table.clear(animButtons)

    local term = searchBox.Text:lower()
    local displayList = {}
    for _, a in ipairs(animations) do
        local isCustom = a.isCustom or (a.category == "Custom")
        if currentTab == "Favs" then
            if savedConfig.favs[a.name] and (term == "" or a.name:lower():find(term,1,true)) then
                table.insert(displayList, a)
            end
        elseif currentTab == "Custom" then
            if isCustom and (term == "" or a.name:lower():find(term,1,true)) then
                table.insert(displayList, a)
            end
        else
            if term == "" or a.name:lower():find(term,1,true) then
                table.insert(displayList, a)
            end
        end
    end

    if currentTab == "Favs" then
        emptyFavsLabel.Visible = (#displayList == 0)
        emptyCustomLabel.Visible = false
    elseif currentTab == "Custom" then
        emptyFavsLabel.Visible = false
        emptyCustomLabel.Visible = (#displayList == 0)
    else
        emptyFavsLabel.Visible = false
        emptyCustomLabel.Visible = false
    end

    local count = 0
    for i, anim in ipairs(displayList) do
        count = count + 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
        row.BackgroundColor3 = (activeOutlineAnim == anim.name) and C.surfaceHover or C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = scrollList
        applyCorner(row, 6)

        -- Star
        local isFav = savedConfig.favs[anim.name]
        local starBtn = Instance.new("TextButton")
        starBtn.Size = UDim2.new(0, 24, 1, 0)
        starBtn.Position = UDim2.new(0, 4, 0, 0)
        starBtn.BackgroundTransparency = 1
        starBtn.Text = isFav and "★" or "☆"
        starBtn.TextColor3 = isFav and C.accent or C.textMuted
        starBtn.Font = Enum.Font.GothamBold
        starBtn.TextSize = 14
        starBtn.Parent = row
        starBtn.MouseButton1Click:Connect(function()
            if savedConfig.favs[anim.name] then
                savedConfig.favs[anim.name] = nil
                starBtn.Text = "☆"
                starBtn.TextColor3 = C.textMuted
            else
                savedConfig.favs[anim.name] = true
                starBtn.Text = "★"
                starBtn.TextColor3 = C.accent
            end
            saveConfig()
            if currentTab == "Favs" then populateList() end
        end)

        -- Play button
        local isCustom = anim.isCustom or (anim.category == "Custom")
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, isCustom and -108 or -78, 1, 0)
        playBtn.Position = UDim2.new(0, 30, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.RichText = true
        playBtn.Text = isCustom and (anim.name .. " <font color=\"rgb(180,180,180)\">[CUSTOM]</font>") or anim.name
        playBtn.TextColor3 = (activeOutlineAnim == anim.name) and C.accent or C.text
        playBtn.Font = (activeOutlineAnim == anim.name) and Enum.Font.GothamBold or Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.Parent = row

        animButtons[anim.name] = { btn = playBtn, star = starBtn }

        playBtn.MouseButton1Click:Connect(function()
            playSelectedAnimation(anim)
            for aName, widgets in pairs(animButtons) do
                local isActive = (activeOutlineAnim == aName)
                local rowBg = isActive and C.surfaceHover or C.surface
                -- update row background if we can find it
                local parentRow = widgets.btn.Parent
                if parentRow and parentRow:IsA("Frame") then
                    parentRow.BackgroundColor3 = rowBg
                end
                widgets.btn.TextColor3 = isActive and C.accent or C.text
                widgets.btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
            end
        end)

        -- Keybind button
        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 38, 0, 22)
        keyBtn.Position = UDim2.new(1, isCustom and -72 or -44, 0.5, -11)
        keyBtn.BackgroundColor3 = C.input
        local boundKey = savedConfig.binds[anim.name]
        keyBtn.Text = boundKey and ("["..boundKey.."]") or "[+]"
        keyBtn.TextColor3 = boundKey and C.accent or C.textMuted
        keyBtn.Font = Enum.Font.GothamSemibold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        applyCorner(keyBtn, 4)
        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == anim.name then
                currentlyBinding = nil
                local b = savedConfig.binds[anim.name]
                keyBtn.Text = b and ("["..b.."]") or "[+]"
                keyBtn.TextColor3 = b and C.accent or C.textMuted
                return
            end
            currentlyBinding = { name = anim.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = Color3.fromRGB(200,200,200)
        end)

        if isCustom then
            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.new(0, 24, 0, 22)
            delBtn.Position = UDim2.new(1, -28, 0.5, -11)
            delBtn.BackgroundColor3 = C.input
            delBtn.Text = "✕"
            delBtn.TextColor3 = C.textMuted
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 10
            delBtn.Parent = row
            applyCorner(delBtn, 4)
            delBtn.MouseButton1Click:Connect(function()
                for i, a in ipairs(animations) do
                    if a.name == anim.name then table.remove(animations, i); break end
                end
                for i, ca in ipairs(savedConfig.customAnims) do
                    if ca.name == anim.name then table.remove(savedConfig.customAnims, i); break end
                end
                savedConfig.favs[anim.name] = nil
                savedConfig.binds[anim.name] = nil
                saveConfig()
                populateList()
            end)
        end

        if count % ROWS_PER_YIELD == 0 then
            task.wait()  -- yield to keep UI responsive
        end
    end

    scrollList.CanvasSize = UDim2.new(0,0,0, #displayList * (ROW_HEIGHT + 4))
end

searchBox:GetPropertyChangedSignal("Text"):Connect(populateList)

-- Binds list
function populateBindsList()
    for _, child in ipairs(bindsPanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local boundItems = {}
    for animName, keyName in pairs(savedConfig.binds) do
        local path
        for _, a in ipairs(animations) do
            if a.name == animName then path = a.path; break end
        end
        if path then table.insert(boundItems, { name = animName, path = path, key = keyName }) end
    end
    table.sort(boundItems, function(a,b) return a.name:lower() < b.name:lower() end)
    emptyBindsLabel.Visible = (#boundItems == 0)
    for i, item in ipairs(boundItems) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 36)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i+1
        row.Parent = bindsPanel
        applyCorner(row, 6)

        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, -120, 1, 0)
        playBtn.Position = UDim2.new(0, 12, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.Text = item.name
        playBtn.TextColor3 = C.text
        playBtn.Font = Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.Parent = row
        playBtn.MouseButton1Click:Connect(function()
            for _, a in ipairs(animations) do if a.name == item.name then playSelectedAnimation(a); break end end
        end)

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 48, 0, 24)
        keyBtn.Position = UDim2.new(1, -100, 0.5, -12)
        keyBtn.BackgroundColor3 = C.input
        keyBtn.Text = "["..item.key.."]"
        keyBtn.TextColor3 = C.accent
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        applyCorner(keyBtn, 4)
        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == item.name then
                currentlyBinding = nil
                keyBtn.Text = "["..item.key.."]"
                keyBtn.TextColor3 = C.accent
                return
            end
            currentlyBinding = { name = item.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = Color3.fromRGB(200,200,200)
        end)

        local unbindBtn = Instance.new("TextButton")
        unbindBtn.Size = UDim2.new(0, 42, 0, 24)
        unbindBtn.Position = UDim2.new(1, -48, 0.5, -12)
        unbindBtn.BackgroundColor3 = C.input
        unbindBtn.Text = "Unbind"
        unbindBtn.TextColor3 = C.textMuted
        unbindBtn.Font = Enum.Font.GothamSemibold
        unbindBtn.TextSize = 9
        unbindBtn.Parent = row
        applyCorner(unbindBtn, 4)
        unbindBtn.MouseButton1Click:Connect(function()
            savedConfig.binds[item.name] = nil
            saveConfig()
            populateBindsList()
        end)
    end
    bindsPanel.CanvasSize = UDim2.new(0,0,0, 26 + #boundItems * 42)
end

-- ═══════════════════════════════════════════════════
-- TAB SWITCHING (instant, no tweens)
-- ═══════════════════════════════════════════════════
switchTab = function(tab)
    currentTab = tab
    for tName, data in pairs(tabButtons) do
        local isActive = (tName == tab)
        data.btn.BackgroundColor3 = isActive and C.accent or C.surface
        data.btn.TextColor3 = isActive and C.bg or C.textMuted
        data.btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end

    local isAnimList = (tab == "Reanims" or tab == "Favs" or tab == "Custom")
    listPanel.Visible = isAnimList
    bindsPanel.Visible = (tab == "Binds")
    speedPanel.Visible = (tab == "Speed")
    statesPanel.Visible = (tab == "States")
    limbsPanel.Visible = (tab == "Limbs")

    if isAnimList then
        if tab == "Favs" then
            searchBox.PlaceholderText = "Search favorites..."
            addCustomBtn.Visible = false
            searchBox.Size = UDim2.new(1, 0, 0, 30)
        elseif tab == "Custom" then
            searchBox.PlaceholderText = "Search custom animations..."
            addCustomBtn.Visible = true
            searchBox.Size = UDim2.new(1, -96, 0, 30)
        else
            searchBox.PlaceholderText = "Search animations..."
            addCustomBtn.Visible = true
            searchBox.Size = UDim2.new(1, -96, 0, 30)
        end
        populateList()
    elseif tab == "Binds" then
        populateBindsList()
    elseif tab == "Limbs" then
        updateLimbsUI()
    end
end

-- ═══════════════════════════════════════════════════
-- CHARACTER STATE MACHINE
-- ═══════════════════════════════════════════════════
local lastLogicalState = nil
local stateThrottle = 0
RunService.Heartbeat:Connect(function()
    if not (api and api.is_reanimated and api.is_reanimated()) then return end
    if manualAnimationPlaying then return end
    if not (savedConfig.states and next(savedConfig.states)) then return end
    stateThrottle = stateThrottle + 1
    if stateThrottle % 2 ~= 0 then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    local hs = hum:GetState()
    local logical = "Idle"
    if hs == Enum.HumanoidStateType.Jumping then
        logical = "Jump"
    elseif hs == Enum.HumanoidStateType.Freefall then
        if hrp.AssemblyLinearVelocity.Y > 0.1 then logical = "Jump" else logical = "Fall" end
    else
        local horizSpeed = Vector2.new(hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Z).Magnitude
        if horizSpeed > 14 then logical = "Run"
        elseif horizSpeed > 1.5 then logical = "Walk"
        else logical = "Idle" end
    end
    if logical ~= lastLogicalState then
        lastLogicalState = logical
        local assigned = savedConfig.states[logical]
        if assigned and assigned.path then
            api.play_animation(assigned.path, currentSpeed)
            updateNowPlayingUI("["..logical.."] "..assigned.name)
        else
            api.stop_animation()
            updateNowPlayingUI(nil)
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- GLOBAL KEYBIND HANDLER
-- ═══════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if currentlyBinding then
        local kName = input.KeyCode.Name
        savedConfig.binds[currentlyBinding.name] = kName
        saveConfig()
        if currentlyBinding.btn then
            currentlyBinding.btn.Text = "["..kName.."]"
            currentlyBinding.btn.TextColor3 = C.accent
        end
        currentlyBinding = nil
        return
    end
    if currentlyBindingSpeed then
        local kName = input.KeyCode.Name
        savedConfig.speedBinds[currentlyBindingSpeed] = kName
        saveConfig()
        local btn = speedBindButtons[currentlyBindingSpeed]
        if btn then
            btn.Text = "["..kName.."]"
            btn.TextColor3 = C.accent
        end
        currentlyBindingSpeed = nil
        return
    end
    if gpe then return end
    for spdStr, kName in pairs(savedConfig.speedBinds) do
        if input.KeyCode.Name == kName then
            applySpeed(tonumber(spdStr) or 1.0)
            return
        end
    end
    for animName, kName in pairs(savedConfig.binds) do
        if input.KeyCode.Name == kName then
            for _, a in ipairs(animations) do
                if a.name == animName then
                    playSelectedAnimation(a)
                    return
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- TOGGLE REANIMATION
-- ═══════════════════════════════════════════════════
local function updateReanimButtonState()
    local isReanimated = api.is_reanimated()
    toggleBtn.Text = isReanimated and "Disable Reanim" or "Enable Reanim"
    toggleBtn.TextColor3 = isReanimated and C.accent or C.text
    toggleBtn.BackgroundColor3 = isReanimated and C.surface or C.input
end

toggleBtn.MouseButton1Click:Connect(function()
    local newState = not api.is_reanimated()
    toggleBtn.Text = newState and "Reanimating..." or "Disabling..."
    toggleBtn.TextColor3 = C.textMuted
    task.spawn(function()
        local err = api.reanimate(newState)
        if err and typeof(err)=="string" and err ~= "Already reanimated." then
            warn("TVM Reanimation: "..err)
        end
        updateReanimButtonState()
        if not newState then
            manualAnimationPlaying = false
            updateNowPlayingUI(nil)
        end
    end)
end)

-- Initialize
updateReanimButtonState()
applySpeed(currentSpeed)
populateList()
