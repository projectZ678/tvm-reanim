-- ═══════════════════════════════════════════════════
-- TVM Reanimation Runner - FULLY FIXED (Arm + Syntax)
-- Arm Stretch stays attached & Height restore fixed
-- + Torso Aim (Stretch / Follow / Face Attach) binds
-- Sliders now cap at 3000
-- ═══════════════════════════════════════════════════

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════════════
local C = {
    bg              = Color3.fromRGB(5, 5, 6),
    bgCard          = Color3.fromRGB(11, 11, 13),
    surface         = Color3.fromRGB(18, 18, 21),
    surfaceHover    = Color3.fromRGB(28, 28, 32),
    surfaceActive   = Color3.fromRGB(38, 38, 44),
    input           = Color3.fromRGB(23, 23, 27),
    accent          = Color3.fromRGB(245, 247, 252),
    accentDim       = Color3.fromRGB(175, 180, 190),
    text            = Color3.fromRGB(240, 242, 248),
    textMuted       = Color3.fromRGB(150, 154, 164),
    textDim         = Color3.fromRGB(95, 98, 108),
    divider         = Color3.fromRGB(36, 36, 42),
    border          = Color3.fromRGB(52, 52, 60),
    borderSoft      = Color3.fromRGB(40, 40, 46),
    playAccent      = Color3.fromRGB(230, 235, 245),
}

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

local function applyStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke", parent)
    stroke.Color = color or C.borderSoft
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return stroke
end

if CoreGui:FindFirstChild("TVMReanimationRunner") then
    CoreGui.TVMReanimationRunner:Destroy()
end

-- ═══════════════════════════════════════════════════
-- LOAD MODULE & ANIMATIONS
-- ═══════════════════════════════════════════════════
local api
local success, result = pcall(function()
    if isfile and isfile("module.lua") then
        return loadstring(readfile("module.lua"))()
    end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/projectZ678/tvm-reanim/refs/heads/master/module.lua"))()
end)
if not (success and type(result) == "table") then
    warn("TVM Reanimation: Failed to load module.lua")
    return
end
api = result

local function isCustomAnim(a)
    return a.isCustom or a.category == "Custom"
end

local function compareAnims(a, b)
    local aC, bC = isCustomAnim(a), isCustomAnim(b)
    if aC ~= bC then return not aC end
    local aCat = a.category or "Reanims"
    local bCat = b.category or "Reanims"
    if aCat ~= bCat then return aCat:lower() < bCat:lower() end
    return a.name:lower() < b.name:lower()
end

local animations = {}
local anim_success, anim_data = pcall(function()
    if isfile and isfile("animations.json") then
        return readfile("animations.json")
    end
    return game:HttpGet("https://raw.githubusercontent.com/projectZ678/tvm-reanim/refs/heads/master/animations.json")
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
        table.sort(animations, compareAnims)
    end
end

-- Config
local CONFIG_FILE = "TVMReanimConfig.json"
local savedConfig = {
    favs = {}, binds = {}, states = {}, speed = 1.0, speedBinds = {},
    customAnims = {}, hiddenLimbs = {}, favOrder = {}, height = 1.0
}
if isfile and readfile and isfile(CONFIG_FILE) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k,v in pairs(data) do if savedConfig[k] ~= nil then savedConfig[k] = v end end
        end
    end)
end

savedConfig.favOrder = savedConfig.favOrder or {}
do
    local validOrder = {}
    local seen = {}
    for _, name in ipairs(savedConfig.favOrder) do
        if savedConfig.favs[name] and not seen[name] then
            table.insert(validOrder, name)
            seen[name] = true
        end
    end
    local missing = {}
    for name, _ in pairs(savedConfig.favs) do
        if not seen[name] then table.insert(missing, name) end
    end
    table.sort(missing, function(a, b) return a:lower() < b:lower() end)
    for _, name in ipairs(missing) do table.insert(validOrder, name) end
    savedConfig.favOrder = validOrder
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
    table.sort(animations, compareAnims)
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
-- GUI CONSTRUCTION
-- ═══════════════════════════════════════════════════
local currentSpeed = savedConfig.speed or 1.0
local currentHeight = savedConfig.height or 1.0
local currentPlayingAnim = nil
local manualAnimationPlaying = false
local currentTab = "Reanims"

local gui = Instance.new("ScreenGui")
gui.Name = "TVMReanimationRunner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local GUI_WIDTH = 400
local GUI_HEIGHT = 560

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)
mainFrame.Position = UDim2.new(0.5, -GUI_WIDTH/2, 0.5, -GUI_HEIGHT/2)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui
applyCorner(mainFrame, 12)
applyStroke(mainFrame, C.border, 1, 0.35)

local outerGlow = Instance.new("Frame")
outerGlow.Size = UDim2.new(1, 4, 1, 4)
outerGlow.Position = UDim2.new(0, -2, 0, -2)
outerGlow.BackgroundTransparency = 1
outerGlow.ZIndex = -1
outerGlow.Parent = mainFrame
applyCorner(outerGlow, 14)
applyStroke(outerGlow, C.accent, 1, 0.92)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = C.bgCard
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
applyCorner(titleBar, 12)

local titleMask = Instance.new("Frame")
titleMask.Size = UDim2.new(1, 0, 0, 12)
titleMask.Position = UDim2.new(0, 0, 1, -12)
titleMask.BackgroundColor3 = C.bgCard
titleMask.BorderSizePixel = 0
titleMask.ZIndex = 1
titleMask.Parent = titleBar

local titleDivider = Instance.new("Frame")
titleDivider.Size = UDim2.new(1, 0, 0, 1)
titleDivider.Position = UDim2.new(0, 0, 1, -1)
titleDivider.BackgroundColor3 = C.divider
titleDivider.BorderSizePixel = 0
titleDivider.ZIndex = 2
titleDivider.Parent = titleBar

local macBtns = Instance.new("Frame")
macBtns.Size = UDim2.new(0, 60, 1, 0)
macBtns.Position = UDim2.new(0, 14, 0, 0)
macBtns.BackgroundTransparency = 1
macBtns.ZIndex = 3
macBtns.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 12, 0, 12)
closeBtn.Position = UDim2.new(0, 0, 0.5, -6)
closeBtn.BackgroundColor3 = Color3.fromRGB(230, 230, 235)
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.Parent = macBtns
applyCorner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 12, 0, 12)
minBtn.Position = UDim2.new(0, 20, 0.5, -6)
minBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 158)
minBtn.Text = ""
minBtn.AutoButtonColor = false
minBtn.Parent = macBtns
applyCorner(minBtn, 6)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 180, 0, 24)
titleLabel.Position = UDim2.new(0, 56, 0.5, -12)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "TVM Reanimation"
titleLabel.TextColor3 = C.accent
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 3
titleLabel.Parent = titleBar

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 124, 0, 26)
toggleBtn.Position = UDim2.new(1, -138, 0.5, -13)
toggleBtn.BackgroundColor3 = C.input
toggleBtn.Text = "Enable Reanim"
toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 10
toggleBtn.AutoButtonColor = false
toggleBtn.ZIndex = 3
toggleBtn.Parent = titleBar
applyCorner(toggleBtn, 100)
local toggleStroke = applyStroke(toggleBtn, C.border, 1, 0.6)

local bodyContainer = Instance.new("Frame")
bodyContainer.Size = UDim2.new(1, 0, 1, -48)
bodyContainer.Position = UDim2.new(0, 0, 0, 48)
bodyContainer.BackgroundTransparency = 1
bodyContainer.Parent = mainFrame

local isMinimized = false
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    bodyContainer.Visible = not isMinimized
    titleDivider.Visible = not isMinimized
    titleMask.Visible = not isMinimized
    mainFrame.Size = UDim2.new(0, GUI_WIDTH, 0, isMinimized and 44 or GUI_HEIGHT)
end)

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

-- Sub-Tab Bar
local tabNames = { "Reanims", "Favs", "Custom", "Binds", "States", "Speed", "Limbs", "Body" }
local tabButtons = {}
local switchTab

local subTabBar = Instance.new("Frame")
subTabBar.Size = UDim2.new(1, -20, 0, 34)
subTabBar.Position = UDim2.new(0, 10, 0, 10)
subTabBar.BackgroundColor3 = C.bgCard
subTabBar.BorderSizePixel = 0
subTabBar.Parent = bodyContainer
applyCorner(subTabBar, 100)
applyStroke(subTabBar, C.borderSoft, 1, 0.6)

local tabsScroll = Instance.new("ScrollingFrame")
tabsScroll.Size = UDim2.new(1, -8, 1, -6)
tabsScroll.Position = UDim2.new(0, 4, 0, 3)
tabsScroll.BackgroundTransparency = 1
tabsScroll.BorderSizePixel = 0
tabsScroll.ScrollBarThickness = 0
tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
pcall(function() tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X end)
tabsScroll.CanvasSize = UDim2.new(0, #tabNames * 58 + 10, 0, 0)
tabsScroll.Parent = subTabBar

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabsLayout.Padding = UDim.new(0, 4)
tabsLayout.Parent = tabsScroll

for i, tName in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, 54, 1, 0)
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

-- Now Playing Bar
local npBar = Instance.new("Frame")
npBar.Size = UDim2.new(1, -20, 0, 34)
npBar.Position = UDim2.new(0, 10, 1, -44)
npBar.BackgroundColor3 = C.bgCard
npBar.BorderSizePixel = 0
npBar.Parent = bodyContainer
applyCorner(npBar, 100)
applyStroke(npBar, C.borderSoft, 1, 0.6)

local npDot = Instance.new("Frame")
npDot.Size = UDim2.new(0, 7, 0, 7)
npDot.Position = UDim2.new(0, 14, 0.5, -3.5)
npDot.BackgroundColor3 = C.textMuted
npDot.BorderSizePixel = 0
npDot.Parent = npBar
applyCorner(npDot, 4)

local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1, -72, 1, 0)
nowPlayingLabel.Position = UDim2.new(0, 30, 0, 0)
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
stopBtn.Position = UDim2.new(1, -30, 0.5, -11)
stopBtn.BackgroundColor3 = C.input
stopBtn.Text = ""
stopBtn.AutoButtonColor = false
stopBtn.Parent = npBar
applyCorner(stopBtn, 11)
applyStroke(stopBtn, C.border, 1, 0.7)

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
        stopIcon.BackgroundColor3 = C.accentDim
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
contentArea.Size = UDim2.new(1, -20, 1, -102)
contentArea.Position = UDim2.new(0, 10, 0, 52)
contentArea.BackgroundTransparency = 1
contentArea.Parent = bodyContainer

-- List Panel
local listPanel = Instance.new("Frame")
listPanel.Size = UDim2.new(1, 0, 1, 0)
listPanel.BackgroundTransparency = 1
listPanel.Visible = true
listPanel.Parent = contentArea

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -100, 0, 32)
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
applyStroke(searchBox, C.borderSoft, 1, 0.6)

local searchPad = Instance.new("UIPadding", searchBox)
searchPad.PaddingLeft = UDim.new(0, 14)
searchPad.PaddingRight = UDim.new(0, 12)

local addCustomBtn = Instance.new("TextButton")
addCustomBtn.Size = UDim2.new(0, 94, 0, 32)
addCustomBtn.Position = UDim2.new(1, -94, 0, 0)
addCustomBtn.BackgroundColor3 = C.surface
addCustomBtn.Text = "+ Add Custom"
addCustomBtn.TextColor3 = C.accent
addCustomBtn.Font = Enum.Font.GothamBold
addCustomBtn.TextSize = 9.5
addCustomBtn.AutoButtonColor = false
addCustomBtn.Parent = listPanel
applyCorner(addCustomBtn, 100)
applyStroke(addCustomBtn, C.border, 1, 0.5)

local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, 0, 1, -42)
scrollList.Position = UDim2.new(0, 0, 0, 42)
scrollList.BackgroundTransparency = 1
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = C.accent
scrollList.ScrollBarImageTransparency = 0.6
scrollList.CanvasSize = UDim2.new(0,0,0,0)
scrollList.Parent = listPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollList

local emptyFavsLabel = Instance.new("TextLabel")
emptyFavsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyFavsLabel.Position = UDim2.new(0, 0, 0.3, 0)
emptyFavsLabel.BackgroundTransparency = 1
emptyFavsLabel.Text = "No favorite animations yet.\nClick the star (★) on any animation to add one.\nDrag the ≡ handle in this tab to reorder!"
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
bindsHeader.Text = "Click key button to rebind  |  Click [Unbind] to remove"
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

-- Speed Panel
local speedPanel = Instance.new("ScrollingFrame")
speedPanel.Size = UDim2.new(1, 0, 1, 0)
speedPanel.BackgroundTransparency = 1
speedPanel.BorderSizePixel = 0
speedPanel.ScrollBarThickness = 3
speedPanel.ScrollBarImageColor3 = C.accent
speedPanel.ScrollBarImageTransparency = 0.6
speedPanel.Visible = false
speedPanel.Parent = contentArea
pcall(function() speedPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
pcall(function() speedPanel.CanvasSize = UDim2.new(0,0,0,0) end)

local speedListLayout = Instance.new("UIListLayout")
speedListLayout.Padding = UDim.new(0, 10)
speedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
speedListLayout.Parent = speedPanel

-- ── Speed card ──
local sliderCard = Instance.new("Frame")
sliderCard.Size = UDim2.new(1, 0, 0, 82)
sliderCard.BackgroundColor3 = C.surface
sliderCard.Parent = speedPanel
applyCorner(sliderCard, 10)
applyStroke(sliderCard, C.borderSoft, 1, 0.5)

local scTitle = Instance.new("TextLabel")
scTitle.Size = UDim2.new(1, -20, 0, 22)
scTitle.Position = UDim2.new(0, 12, 0, 8)
scTitle.BackgroundTransparency = 1
scTitle.Text = "PLAYBACK SPEED"
scTitle.TextColor3 = C.textMuted
scTitle.Font = Enum.Font.GothamBold
scTitle.TextSize = 10
scTitle.TextXAlignment = Enum.TextXAlignment.Left
scTitle.Parent = sliderCard

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -140, 0, 6)
sliderTrack.Position = UDim2.new(0, 12, 0, 50)
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
sliderValLabel.Size = UDim2.new(0, 52, 0, 22)
sliderValLabel.Position = UDim2.new(1, -124, 0, 42)
sliderValLabel.BackgroundColor3 = C.input
sliderValLabel.Text = string.format("%.1fx", currentSpeed)
sliderValLabel.TextColor3 = C.accent
sliderValLabel.Font = Enum.Font.GothamBold
sliderValLabel.TextSize = 10
sliderValLabel.Parent = sliderCard
applyCorner(sliderValLabel, 5)

local resetSpeedBtn = Instance.new("TextButton")
resetSpeedBtn.Size = UDim2.new(0, 58, 0, 22)
resetSpeedBtn.Position = UDim2.new(1, -64, 0, 42)
resetSpeedBtn.BackgroundColor3 = C.input
resetSpeedBtn.Text = "Reset"
resetSpeedBtn.TextColor3 = C.text
resetSpeedBtn.Font = Enum.Font.GothamSemibold
resetSpeedBtn.TextSize = 9
resetSpeedBtn.AutoButtonColor = false
resetSpeedBtn.Parent = sliderCard
applyCorner(resetSpeedBtn, 5)
applyStroke(resetSpeedBtn, C.borderSoft, 1, 0.6)

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

-- ── Presets card ──
local presetCard = Instance.new("Frame")
presetCard.Size = UDim2.new(1, 0, 0, 118)
presetCard.BackgroundColor3 = C.surface
presetCard.Parent = speedPanel
applyCorner(presetCard, 10)
applyStroke(presetCard, C.borderSoft, 1, 0.5)

local pcTitle = Instance.new("TextLabel")
pcTitle.Size = UDim2.new(1, -20, 0, 20)
pcTitle.Position = UDim2.new(0, 12, 0, 8)
pcTitle.BackgroundTransparency = 1
pcTitle.Text = "SPEED PRESETS & HOTKEYS"
pcTitle.TextColor3 = C.textMuted
pcTitle.Font = Enum.Font.GothamBold
pcTitle.TextSize = 10
pcTitle.TextXAlignment = Enum.TextXAlignment.Left
pcTitle.Parent = presetCard

local pcSubtitle = Instance.new("TextLabel")
pcSubtitle.Size = UDim2.new(1, -20, 0, 14)
pcSubtitle.Position = UDim2.new(0, 12, 0, 26)
pcSubtitle.BackgroundTransparency = 1
pcSubtitle.Text = "Click speed to apply  |  Click [+] to bind key"
pcSubtitle.TextColor3 = C.textMuted
pcSubtitle.Font = Enum.Font.Gotham
pcSubtitle.TextSize = 9
pcSubtitle.TextXAlignment = Enum.TextXAlignment.Left
pcSubtitle.Parent = presetCard

local speedPresets = {0.5, 1.0, 1.5, 2.0, 3.0}
local presetRow = Instance.new("Frame")
presetRow.Size = UDim2.new(1, -20, 0, 58)
presetRow.Position = UDim2.new(0, 10, 0, 48)
presetRow.BackgroundTransparency = 1
presetRow.Parent = presetCard

local currentlyBindingSpeed = nil
local speedBindButtons = {}
local pW = 1/#speedPresets
for i, spd in ipairs(speedPresets) do
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(pW, -4, 0, 26)
    sBtn.Position = UDim2.new((i-1)*pW, 2, 0, 0)
    sBtn.BackgroundColor3 = C.input
    sBtn.Text = string.format("%.1fx", spd)
    sBtn.TextColor3 = C.text
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 11
    sBtn.AutoButtonColor = false
    sBtn.Parent = presetRow
    applyCorner(sBtn, 5)
    applyStroke(sBtn, C.borderSoft, 1, 0.6)
    sBtn.MouseButton1Click:Connect(function() applySpeed(spd) end)

    local kBtn = Instance.new("TextButton")
    kBtn.Size = UDim2.new(pW, -4, 0, 22)
    kBtn.Position = UDim2.new((i-1)*pW, 2, 0, 32)
    kBtn.BackgroundColor3 = C.input
    local bound = savedConfig.speedBinds[tostring(spd)]
    kBtn.Text = bound and ("["..bound.."]") or "[+]"
    kBtn.TextColor3 = bound and C.accent or C.textMuted
    kBtn.Font = Enum.Font.GothamSemibold
    kBtn.TextSize = 9
    kBtn.AutoButtonColor = false
    kBtn.Parent = presetRow
    applyCorner(kBtn, 5)
    applyStroke(kBtn, C.borderSoft, 1, 0.7)
    speedBindButtons[tostring(spd)] = kBtn
    kBtn.MouseButton1Click:Connect(function()
        if currentlyBindingSpeed == tostring(spd) then
            currentlyBindingSpeed = nil
            local b = savedConfig.speedBinds[tostring(spd)]
            kBtn.Text = b and ("["..b.."]") or "[+]"
            kBtn.TextColor3 = b and C.accent or C.textMuted
            return
        end
        currentlyBindingSpeed = tostring(spd)
        kBtn.Text = "[?]"
        kBtn.TextColor3 = C.accentDim
    end)
end

-- ── Height card ──
local heightCard = Instance.new("Frame")
heightCard.Size = UDim2.new(1, 0, 0, 82)
heightCard.BackgroundColor3 = C.surface
heightCard.Parent = speedPanel
applyCorner(heightCard, 10)
applyStroke(heightCard, C.borderSoft, 1, 0.5)

local hcTitle = Instance.new("TextLabel")
hcTitle.Size = UDim2.new(1, -20, 0, 22)
hcTitle.Position = UDim2.new(0, 12, 0, 8)
hcTitle.BackgroundTransparency = 1
hcTitle.Text = "STANDING HEIGHT"
hcTitle.TextColor3 = C.textMuted
hcTitle.Font = Enum.Font.GothamBold
hcTitle.TextSize = 10
hcTitle.TextXAlignment = Enum.TextXAlignment.Left
hcTitle.Parent = heightCard

local hcSubtitle = Instance.new("TextLabel")
hcSubtitle.Size = UDim2.new(1, -20, 0, 14)
hcSubtitle.Position = UDim2.new(0, 12, 0, 24)
hcSubtitle.BackgroundTransparency = 1
hcSubtitle.Text = "Raises/lowers your character without stretching limbs"
hcSubtitle.TextColor3 = C.textMuted
hcSubtitle.Font = Enum.Font.Gotham
hcSubtitle.TextSize = 9
hcSubtitle.TextXAlignment = Enum.TextXAlignment.Left
hcSubtitle.Parent = heightCard

local heightTrack = Instance.new("Frame")
heightTrack.Size = UDim2.new(1, -140, 0, 6)
heightTrack.Position = UDim2.new(0, 12, 0, 58)
heightTrack.BackgroundColor3 = C.input
heightTrack.BorderSizePixel = 0
heightTrack.Parent = heightCard
applyCorner(heightTrack, 3)

local heightFill = Instance.new("Frame")
heightFill.Size = UDim2.new(0.2, 0, 1, 0)
heightFill.BackgroundColor3 = C.accent
heightFill.BorderSizePixel = 0
heightFill.Parent = heightTrack
applyCorner(heightFill, 3)

local heightKnob = Instance.new("Frame")
heightKnob.Size = UDim2.new(0, 14, 0, 14)
heightKnob.Position = UDim2.new(1, -7, 0.5, -7)
heightKnob.BackgroundColor3 = C.text
heightKnob.BorderSizePixel = 0
heightKnob.Parent = heightFill
applyCorner(heightKnob, 7)

local heightValLabel = Instance.new("TextLabel")
heightValLabel.Size = UDim2.new(0, 52, 0, 22)
heightValLabel.Position = UDim2.new(1, -124, 0, 50)
heightValLabel.BackgroundColor3 = C.input
heightValLabel.Text = string.format("%.2fx", currentHeight)
heightValLabel.TextColor3 = C.accent
heightValLabel.Font = Enum.Font.GothamBold
heightValLabel.TextSize = 10
heightValLabel.Parent = heightCard
applyCorner(heightValLabel, 5)

local resetHeightBtn = Instance.new("TextButton")
resetHeightBtn.Size = UDim2.new(0, 58, 0, 22)
resetHeightBtn.Position = UDim2.new(1, -64, 0, 50)
resetHeightBtn.BackgroundColor3 = C.input
resetHeightBtn.Text = "Reset"
resetHeightBtn.TextColor3 = C.text
resetHeightBtn.Font = Enum.Font.GothamSemibold
resetHeightBtn.TextSize = 9
resetHeightBtn.AutoButtonColor = false
resetHeightBtn.Parent = heightCard
applyCorner(resetHeightBtn, 5)
applyStroke(resetHeightBtn, C.borderSoft, 1, 0.6)

local HEIGHT_STUDS_PER_MULT = 2.0
local baseHipHeights = setmetatable({}, { __mode = "k" })

local function getBaseHipHeight(hum)
    if not hum then return nil end
    local base = baseHipHeights[hum]
    if base == nil then
        local ok, val = pcall(function() return hum.HipHeight end)
        if not ok then return nil end
        base = val
        baseHipHeights[hum] = base
    end
    return base
end

local function applyHeightToHumanoid(hum, val)
    if not hum then return end
    local base = getBaseHipHeight(hum)
    if base == nil then return end
    local target
    if math.abs(val - 1.0) < 0.001 then
        target = base
    else
        target = base + (val - 1.0) * HEIGHT_STUDS_PER_MULT
        if target < 0 then target = 0 end
    end
    if math.abs(hum.HipHeight - target) > 0.005 then
        pcall(function() hum.HipHeight = target end)
    end
end

local function applyHeightToVisible()
    local reanimated = api.is_reanimated and api.is_reanimated()
    local char = player.Character
    local clone = api.get_clone and api.get_clone()

    if reanimated and clone then
        local cloneHum = clone:FindFirstChildOfClass("Humanoid")
        if cloneHum then
            applyHeightToHumanoid(cloneHum, currentHeight)
        end
    elseif char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            applyHeightToHumanoid(hum, currentHeight)
        end
    end
end

local function applyHeight(val)
    currentHeight = math.clamp(math.floor(val*100 + 0.5)/100, 0.5, 3.0)
    savedConfig.height = currentHeight
    saveConfig()
    heightValLabel.Text = string.format("%.2fx", currentHeight)
    local pct = (currentHeight - 0.5) / (3.0 - 0.5)
    heightFill.Size = UDim2.new(math.clamp(pct,0,1), 0, 1, 0)
    applyHeightToVisible()
end
resetHeightBtn.MouseButton1Click:Connect(function() applyHeight(1.0) end)

local draggingHeightSlider = false
local function updateHeightSliderFromInput(input)
    local relX = math.clamp(input.Position.X - heightTrack.AbsolutePosition.X, 0, heightTrack.AbsoluteSize.X)
    local pct = relX / heightTrack.AbsoluteSize.X
    applyHeight(0.5 + 2.5 * pct)
end
heightCard.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingHeightSlider = true
        updateHeightSliderFromInput(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHeightSlider = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingHeightSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateHeightSliderFromInput(input)
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.35)
    applyHeightToVisible()
end)

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
modalOverlay.BackgroundTransparency = 0.4
modalOverlay.BorderSizePixel = 0
modalOverlay.Visible = false
modalOverlay.ZIndex = 50
modalOverlay.Parent = mainFrame

local modalCard = Instance.new("Frame")
modalCard.Size = UDim2.new(0, 340, 0, 420)
modalCard.Position = UDim2.new(0.5, -170, 0.5, -210)
modalCard.BackgroundColor3 = C.bgCard
modalCard.BorderSizePixel = 0
modalCard.ZIndex = 51
modalCard.Parent = modalOverlay
applyCorner(modalCard, 12)
applyStroke(modalCard, C.border, 1, 0.4)

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, -50, 0, 36)
modalTitle.Position = UDim2.new(0, 16, 0, 8)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "Select Animation for State"
modalTitle.TextColor3 = C.text
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 12
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.ZIndex = 52
modalTitle.Parent = modalCard

local modalCloseBtn = Instance.new("TextButton")
modalCloseBtn.Size = UDim2.new(0, 26, 0, 26)
modalCloseBtn.Position = UDim2.new(1, -36, 0, 12)
modalCloseBtn.BackgroundColor3 = C.surface
modalCloseBtn.Text = "✕"
modalCloseBtn.TextColor3 = C.textMuted
modalCloseBtn.Font = Enum.Font.GothamBold
modalCloseBtn.TextSize = 11
modalCloseBtn.AutoButtonColor = false
modalCloseBtn.ZIndex = 52
modalCloseBtn.Parent = modalCard
applyCorner(modalCloseBtn, 13)
modalCloseBtn.MouseButton1Click:Connect(function()
    modalOverlay.Visible = false
    modalSelectingState = nil
end)

local modalSearch = Instance.new("TextBox")
modalSearch.Size = UDim2.new(1, -32, 0, 32)
modalSearch.Position = UDim2.new(0, 16, 0, 48)
modalSearch.BackgroundColor3 = C.input
modalSearch.PlaceholderText = "Search animations to assign..."
modalSearch.PlaceholderColor3 = C.textMuted
modalSearch.Text = ""
modalSearch.TextColor3 = C.text
modalSearch.Font = Enum.Font.GothamMedium
modalSearch.TextSize = 11
modalSearch.TextXAlignment = Enum.TextXAlignment.Left
modalSearch.ClearTextOnFocus = false
modalSearch.ZIndex = 52
modalSearch.Parent = modalCard
applyCorner(modalSearch, 100)
applyStroke(modalSearch, C.borderSoft, 1, 0.6)
local modalSearchPad = Instance.new("UIPadding", modalSearch)
modalSearchPad.PaddingLeft = UDim.new(0, 14)
modalSearchPad.PaddingRight = UDim.new(0, 12)

local modalList = Instance.new("ScrollingFrame")
modalList.Size = UDim2.new(1, -32, 1, -96)
modalList.Position = UDim2.new(0, 16, 0, 88)
modalList.BackgroundTransparency = 1
modalList.BorderSizePixel = 0
modalList.ScrollBarThickness = 3
modalList.ScrollBarImageColor3 = C.accent
modalList.ScrollBarImageTransparency = 0.6
modalList.CanvasSize = UDim2.new(0,0,0,0)
modalList.ZIndex = 52
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
            ab.Size = UDim2.new(1, -6, 0, 30)
            ab.BackgroundColor3 = C.surface
            ab.Text = a.name
            ab.TextColor3 = C.text
            ab.Font = Enum.Font.GothamMedium
            ab.TextSize = 11
            ab.TextXAlignment = Enum.TextXAlignment.Left
            ab.TextTruncate = Enum.TextTruncate.AtEnd
            ab.AutoButtonColor = false
            ab.ZIndex = 53
            ab.Parent = modalList
            applyCorner(ab, 5)
            local pad = Instance.new("UIPadding", ab)
            pad.PaddingLeft = UDim.new(0, 10)
            ab.MouseButton1Click:Connect(function()
                if modalSelectingState then
                    savedConfig.states[modalSelectingState] = { name = a.name, path = a.path }
                    saveConfig()
                    if stateSelectButtons[modalSelectingState] then
                        stateSelectButtons[modalSelectingState].Text = a.name
                        stateSelectButtons[modalSelectingState].TextColor3 = C.accentDim
                    end
                end
                modalOverlay.Visible = false
                modalSelectingState = nil
            end)
        end
    end
    modalList.CanvasSize = UDim2.new(0,0,0, count*34)
end
modalSearch:GetPropertyChangedSignal("Text"):Connect(function() populateModalList(modalSearch.Text) end)

-- Add Custom Modal
local addCustomModal = Instance.new("Frame")
addCustomModal.Size = UDim2.new(1,0,1,0)
addCustomModal.BackgroundColor3 = C.bg
addCustomModal.BackgroundTransparency = 0.4
addCustomModal.BorderSizePixel = 0
addCustomModal.Visible = false
addCustomModal.ZIndex = 50
addCustomModal.Parent = mainFrame

local addCard = Instance.new("Frame")
addCard.Size = UDim2.new(0, 340, 0, 400)
addCard.Position = UDim2.new(0.5, -170, 0.5, -200)
addCard.BackgroundColor3 = C.bgCard
addCard.BorderSizePixel = 0
addCard.ZIndex = 51
addCard.Parent = addCustomModal
applyCorner(addCard, 12)
applyStroke(addCard, C.border, 1, 0.4)

local addTitle = Instance.new("TextLabel")
addTitle.Size = UDim2.new(1, -50, 0, 36)
addTitle.Position = UDim2.new(0, 16, 0, 8)
addTitle.BackgroundTransparency = 1
addTitle.Text = "Add Custom Animation"
addTitle.TextColor3 = C.text
addTitle.Font = Enum.Font.GothamBold
addTitle.TextSize = 12
addTitle.TextXAlignment = Enum.TextXAlignment.Left
addTitle.ZIndex = 52
addTitle.Parent = addCard

local addCloseBtn = Instance.new("TextButton")
addCloseBtn.Size = UDim2.new(0, 26, 0, 26)
addCloseBtn.Position = UDim2.new(1, -36, 0, 12)
addCloseBtn.BackgroundColor3 = C.surface
addCloseBtn.Text = "✕"
addCloseBtn.TextColor3 = C.textMuted
addCloseBtn.Font = Enum.Font.GothamBold
addCloseBtn.TextSize = 11
addCloseBtn.AutoButtonColor = false
addCloseBtn.ZIndex = 52
addCloseBtn.Parent = addCard
applyCorner(addCloseBtn, 13)
addCloseBtn.MouseButton1Click:Connect(function() addCustomModal.Visible = false end)

local addNameBox = Instance.new("TextBox")
addNameBox.Size = UDim2.new(1, -32, 0, 30)
addNameBox.Position = UDim2.new(0, 16, 0, 48)
addNameBox.BackgroundColor3 = C.input
addNameBox.PlaceholderText = "Animation Name (optional)"
addNameBox.PlaceholderColor3 = C.textMuted
addNameBox.Text = ""
addNameBox.TextColor3 = C.text
addNameBox.Font = Enum.Font.GothamMedium
addNameBox.TextSize = 11
addNameBox.TextXAlignment = Enum.TextXAlignment.Left
addNameBox.ClearTextOnFocus = false
addNameBox.ZIndex = 52
addNameBox.Parent = addCard
applyCorner(addNameBox, 6)
applyStroke(addNameBox, C.borderSoft, 1, 0.6)
local addNamePad = Instance.new("UIPadding", addNameBox)
addNamePad.PaddingLeft = UDim.new(0, 10)
addNamePad.PaddingRight = UDim.new(0, 10)

local addDataBox = Instance.new("TextBox")
addDataBox.Size = UDim2.new(1, -32, 0, 220)
addDataBox.Position = UDim2.new(0, 16, 0, 86)
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
addDataBox.ZIndex = 52
addDataBox.Parent = addCard
applyCorner(addDataBox, 6)
applyStroke(addDataBox, C.borderSoft, 1, 0.6)
local addDataPad = Instance.new("UIPadding", addDataBox)
addDataPad.PaddingLeft = UDim.new(0, 8)
addDataPad.PaddingRight = UDim.new(0, 8)
addDataPad.PaddingTop = UDim.new(0, 6)

local addStatus = Instance.new("TextLabel")
addStatus.Size = UDim2.new(1, -32, 0, 20)
addStatus.Position = UDim2.new(0, 16, 0, 314)
addStatus.BackgroundTransparency = 1
addStatus.Text = "Paste keyframe data or script table above."
addStatus.TextColor3 = C.textMuted
addStatus.Font = Enum.Font.Gotham
addStatus.TextSize = 10
addStatus.TextXAlignment = Enum.TextXAlignment.Left
addStatus.ZIndex = 52
addStatus.Parent = addCard

local addSubmitBtn = Instance.new("TextButton")
addSubmitBtn.Size = UDim2.new(1, -32, 0, 34)
addSubmitBtn.Position = UDim2.new(0, 16, 1, -48)
addSubmitBtn.BackgroundColor3 = C.surface
addSubmitBtn.Text = "+ Add Animation"
addSubmitBtn.TextColor3 = C.accent
addSubmitBtn.Font = Enum.Font.GothamBold
addSubmitBtn.TextSize = 11
addSubmitBtn.AutoButtonColor = false
addSubmitBtn.ZIndex = 52
addSubmitBtn.Parent = addCard
applyCorner(addSubmitBtn, 6)
applyStroke(addSubmitBtn, C.border, 1, 0.5)

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

local populateList
local markListDirty

addSubmitBtn.MouseButton1Click:Connect(function()
    local raw = addDataBox.Text:gsub("^%s+",""):gsub("%s+$","")
    if raw == "" then
        addStatus.Text = "Please paste keyframe script or table first!"
        addStatus.TextColor3 = C.accentDim
        return
    end
    if not raw:find("{",1,true) then
        addStatus.Text = "Invalid data: doesn't look like keyframes table or script."
        addStatus.TextColor3 = C.accentDim
        return
    end
    local finalName = (addNameBox.Text:match("^%s*(.-)%s*$") or "") ~= "" and addNameBox.Text or ("Custom_"..(#savedConfig.customAnims+1))
    table.insert(savedConfig.customAnims, { name = finalName, script = raw })
    saveConfig()
    table.insert(animations, { name = finalName, path = raw, category = "Custom", isCustom = true })
    table.sort(animations, compareAnims)
    addCustomModal.Visible = false
    addDataBox.Text = ""
    addNameBox.Text = ""
    if markListDirty then markListDirty() end
    if populateList then populateList() end
end)

addCustomBtn.MouseButton1Click:Connect(function()
    addCustomModal.Visible = true
    addNameBox:CaptureFocus()
end)

-- States rows
for _, st in ipairs(stateTypes) do
    local sRow = Instance.new("Frame")
    sRow.Size = UDim2.new(1, 0, 0, 44)
    sRow.BackgroundColor3 = C.surface
    sRow.Parent = statesPanel
    applyCorner(sRow, 8)
    applyStroke(sRow, C.borderSoft, 1, 0.6)

    local stLabel = Instance.new("TextLabel")
    stLabel.Size = UDim2.new(0, 70, 1, 0)
    stLabel.Position = UDim2.new(0, 14, 0, 0)
    stLabel.BackgroundTransparency = 1
    stLabel.Text = st
    stLabel.TextColor3 = C.text
    stLabel.Font = Enum.Font.GothamBold
    stLabel.TextSize = 11
    stLabel.TextXAlignment = Enum.TextXAlignment.Left
    stLabel.Parent = sRow

    local currentAssignment = savedConfig.states[st]
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(1, -160, 0, 28)
    sBtn.Position = UDim2.new(0, 84, 0.5, -14)
    sBtn.BackgroundColor3 = C.input
    sBtn.Text = currentAssignment and currentAssignment.name or "None"
    sBtn.TextColor3 = currentAssignment and C.accentDim or C.textMuted
    sBtn.Font = Enum.Font.GothamMedium
    sBtn.TextSize = 11
    sBtn.TextXAlignment = Enum.TextXAlignment.Left
    sBtn.TextTruncate = Enum.TextTruncate.AtEnd
    sBtn.AutoButtonColor = false
    sBtn.Parent = sRow
    applyCorner(sBtn, 5)
    local padS = Instance.new("UIPadding", sBtn)
    padS.PaddingLeft = UDim.new(0, 10)
    stateSelectButtons[st] = sBtn

    sBtn.MouseButton1Click:Connect(function()
        modalSelectingState = st
        modalTitle.Text = "Assign Animation for: " .. st
        modalSearch.Text = ""
        populateModalList("")
        modalOverlay.Visible = true
    end)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 56, 0, 28)
    clearBtn.Position = UDim2.new(1, -66, 0.5, -14)
    clearBtn.BackgroundColor3 = C.input
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = C.textMuted
    clearBtn.Font = Enum.Font.GothamSemibold
    clearBtn.TextSize = 10
    clearBtn.AutoButtonColor = false
    clearBtn.Parent = sRow
    applyCorner(clearBtn, 5)
    clearBtn.MouseButton1Click:Connect(function()
        savedConfig.states[st] = nil
        saveConfig()
        sBtn.Text = "None"
        sBtn.TextColor3 = C.textMuted
    end)
end

-- Limbs Panel
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
    applyStroke(track, C.borderSoft, 1, 0.6)
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
masterCard.Size = UDim2.new(1, 0, 0, 48)
masterCard.BackgroundColor3 = C.surface
masterCard.BorderSizePixel = 0
masterCard.LayoutOrder = 2
masterCard.Parent = limbsPanel
applyCorner(masterCard, 10)
applyStroke(masterCard, C.borderSoft, 1, 0.5)

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
masterStatusLbl.TextColor3 = C.accentDim
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
        masterStatusLbl.TextColor3 = C.accentDim
        updateToggleVisual(masterTrack, masterKnob, true)
    elseif hiddenCount == #limbDefinitions then
        masterStatusLbl.Text = "ALL HIDDEN"
        masterStatusLbl.TextColor3 = C.textDim
        updateToggleVisual(masterTrack, masterKnob, false)
    else
        masterStatusLbl.Text = "CUSTOM"
        masterStatusLbl.TextColor3 = C.accentDim
        masterTrack.BackgroundColor3 = C.surfaceActive
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
        rowData.statusLbl.TextColor3 = isVisible and C.accentDim or C.textDim
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
    lRow.Size = UDim2.new(1, 0, 0, 46)
    lRow.BackgroundColor3 = C.surface
    lRow.BorderSizePixel = 0
    lRow.LayoutOrder = 3 + idx
    lRow.Parent = limbsPanel
    applyCorner(lRow, 10)
    applyStroke(lRow, C.borderSoft, 1, 0.6)

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
    statusLbl.TextColor3 = isCurrentlyHidden and C.textDim or C.accentDim
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
            rowData.statusLbl.TextColor3 = isVisible and C.accentDim or C.textDim
            updateToggleVisual(rowData.track, rowData.knob, isVisible)
        end
    end
    updateMasterToggleVisual()
end

limbsPanel.CanvasSize = UDim2.new(0,0,0, #limbDefinitions * 58 + 80)

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
-- BODY PANEL - ARM STRETCH / FACE ATTACH / TORSO AIM
-- ═══════════════════════════════════════════════════
local BodyArm = {}
(function()
    local bodyPanel = Instance.new("ScrollingFrame")
    bodyPanel.Size = UDim2.new(1, 0, 1, 0)
    bodyPanel.BackgroundTransparency = 1
    bodyPanel.BorderSizePixel = 0
    bodyPanel.ScrollBarThickness = 3
    bodyPanel.ScrollBarImageColor3 = C.accent
    bodyPanel.ScrollBarImageTransparency = 0.6
    bodyPanel.Visible = false
    bodyPanel.Parent = contentArea
    pcall(function() bodyPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    pcall(function() bodyPanel.CanvasSize = UDim2.new(0,0,0,0) end)

    local bodyPadding = Instance.new("UIPadding")
    bodyPadding.PaddingLeft = UDim.new(0, 2)
    bodyPadding.PaddingRight = UDim.new(0, 4)
    bodyPadding.PaddingTop = UDim.new(0, 2)
    bodyPadding.PaddingBottom = UDim.new(0, 12)
    bodyPadding.Parent = bodyPanel

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 10)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = bodyPanel

    local function bodySectionTitle(text, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = C.textMuted
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        lbl.Parent = bodyPanel
        return lbl
    end

    bodySectionTitle("ARM STRETCH", 1)

    local armStretchCard = Instance.new("Frame")
    armStretchCard.Size = UDim2.new(1, 0, 0, 196)
    armStretchCard.BackgroundColor3 = C.surface
    armStretchCard.BorderSizePixel = 0
    armStretchCard.LayoutOrder = 2
    armStretchCard.Parent = bodyPanel
    applyCorner(armStretchCard, 10)
    applyStroke(armStretchCard, C.borderSoft, 1, 0.5)

    local asEnableBtn = Instance.new("TextButton")
    asEnableBtn.Size = UDim2.new(1, -24, 0, 30)
    asEnableBtn.Position = UDim2.new(0, 12, 0, 12)
    asEnableBtn.BackgroundColor3 = C.input
    asEnableBtn.Text = "Enable Arm Stretch"
    asEnableBtn.TextColor3 = C.text
    asEnableBtn.Font = Enum.Font.GothamBold
    asEnableBtn.TextSize = 11
    asEnableBtn.AutoButtonColor = false
    asEnableBtn.Parent = armStretchCard
    applyCorner(asEnableBtn, 6)
    applyStroke(asEnableBtn, C.borderSoft, 1, 0.6)

    local asSideBtn = Instance.new("TextButton")
    asSideBtn.Size = UDim2.new(0, 174, 0, 26)
    asSideBtn.Position = UDim2.new(0, 12, 0, 50)
    asSideBtn.BackgroundColor3 = C.input
    asSideBtn.Text = "Side: Right"
    asSideBtn.TextColor3 = C.text
    asSideBtn.Font = Enum.Font.GothamSemibold
    asSideBtn.TextSize = 10
    asSideBtn.AutoButtonColor = false
    asSideBtn.Parent = armStretchCard
    applyCorner(asSideBtn, 6)
    applyStroke(asSideBtn, C.borderSoft, 1, 0.6)

    local asModeBtn = Instance.new("TextButton")
    asModeBtn.Size = UDim2.new(0, 174, 0, 26)
    asModeBtn.Position = UDim2.new(1, -186, 0, 50)
    asModeBtn.BackgroundColor3 = C.input
    asModeBtn.Text = "Mode: Toggle"
    asModeBtn.TextColor3 = C.text
    asModeBtn.Font = Enum.Font.GothamSemibold
    asModeBtn.TextSize = 10
    asModeBtn.AutoButtonColor = false
    asModeBtn.Parent = armStretchCard
    applyCorner(asModeBtn, 6)
    applyStroke(asModeBtn, C.borderSoft, 1, 0.6)

    local asBindBtn = Instance.new("TextButton")
    asBindBtn.Size = UDim2.new(1, -24, 0, 26)
    asBindBtn.Position = UDim2.new(0, 12, 0, 82)
    asBindBtn.BackgroundColor3 = C.input
    asBindBtn.Text = "Bind: E"
    asBindBtn.TextColor3 = C.accent
    asBindBtn.Font = Enum.Font.GothamBold
    asBindBtn.TextSize = 10
    asBindBtn.AutoButtonColor = false
    asBindBtn.Parent = armStretchCard
    applyCorner(asBindBtn, 6)
    applyStroke(asBindBtn, C.borderSoft, 1, 0.6)

    local asLenLabel = Instance.new("TextLabel")
    asLenLabel.Size = UDim2.new(1, -24, 0, 14)
    asLenLabel.Position = UDim2.new(0, 12, 0, 116)
    asLenLabel.BackgroundTransparency = 1
    asLenLabel.Text = "REACH: 14"
    asLenLabel.TextColor3 = C.textMuted
    asLenLabel.Font = Enum.Font.GothamBold
    asLenLabel.TextSize = 9
    asLenLabel.TextXAlignment = Enum.TextXAlignment.Left
    asLenLabel.Parent = armStretchCard

    local asLenTrack = Instance.new("Frame")
    asLenTrack.Size = UDim2.new(1, -24, 0, 6)
    asLenTrack.Position = UDim2.new(0, 12, 0, 134)
    asLenTrack.BackgroundColor3 = C.input
    asLenTrack.BorderSizePixel = 0
    asLenTrack.Parent = armStretchCard
    applyCorner(asLenTrack, 3)

    local asLenFill = Instance.new("Frame")
    asLenFill.Size = UDim2.new(0.1, 0, 1, 0)
    asLenFill.BackgroundColor3 = C.accent
    asLenFill.BorderSizePixel = 0
    asLenFill.Parent = asLenTrack
    applyCorner(asLenFill, 3)

    local asLenKnob = Instance.new("Frame")
    asLenKnob.Size = UDim2.new(0, 12, 0, 12)
    asLenKnob.Position = UDim2.new(1, -6, 0.5, -6)
    asLenKnob.BackgroundColor3 = C.text
    asLenKnob.BorderSizePixel = 0
    asLenKnob.Parent = asLenFill
    applyCorner(asLenKnob, 6)

    local asHint = Instance.new("TextLabel")
    asHint.Size = UDim2.new(1, -24, 0, 30)
    asHint.Position = UDim2.new(0, 12, 0, 152)
    asHint.BackgroundTransparency = 1
    asHint.Text = "Press bind to point arm forward. Hold LMB to steer while active. Works on the reanim clone."
    asHint.TextColor3 = C.textDim
    asHint.Font = Enum.Font.Gotham
    asHint.TextSize = 9
    asHint.TextWrapped = true
    asHint.TextXAlignment = Enum.TextXAlignment.Left
    asHint.TextYAlignment = Enum.TextYAlignment.Top
    asHint.Parent = armStretchCard

    -- State
    local ArmStretch = {
        active = false,
        bind = Enum.KeyCode.E,
        mode = "Toggle",
        side = "Right",
        length = 1300,
        capturing = false,
        data = nil,
        connection = nil,
        lastDir = nil,
        currentTarget = nil,
    }

    local function getActiveCharacter()
        if api and api.is_reanimated and api.is_reanimated() then
            local clone = api.get_clone and api.get_clone()
            if clone then return clone end
        end
        return player.Character
    end

    local function findPartInModel(model, name)
        if not model then return nil end
        local d = model:FindFirstChild(name)
        if d and d:IsA("BasePart") then return d end
        for _, o in ipairs(model:GetDescendants()) do
            if o:IsA("BasePart") and o.Name == name then return o end
        end
    end

    local function findMotorInModel(model, part)
        if not model then return nil end
        for _, o in ipairs(model:GetDescendants()) do
            if o:IsA("Motor6D") and o.Part1 == part then return o end
        end
    end

    local function buildBoneCFrame(origin, alongBone, refRight)
        alongBone = alongBone.Unit
        local xAxis = refRight:Cross(alongBone)
        if xAxis.Magnitude < 0.08 then
            xAxis = Vector3.new(0,1,0):Cross(alongBone)
            if xAxis.Magnitude < 0.08 then xAxis = Vector3.new(1,0,0):Cross(alongBone) end
        end
        xAxis = xAxis.Unit
        local zAxis = xAxis:Cross(alongBone).Unit
        xAxis = alongBone:Cross(zAxis).Unit
        return CFrame.fromMatrix(origin, xAxis, alongBone, zAxis)
    end

    local function buildArmDataForChar(model, side)
        local up = findPartInModel(model, side.."UpperArm")
        local lo = findPartInModel(model, side.."LowerArm")
        local hd = findPartInModel(model, side.."Hand")
        if not up or not lo or not hd then return nil end
        local sM = findMotorInModel(model, up)
        local eM = findMotorInModel(model, lo)
        local wM = findMotorInModel(model, hd)
        if not sM or not eM or not wM then return nil end

        local root = model:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        local shoulderPosition = (up.CFrame * CFrame.new(0, up.Size.Y * 0.5, 0)).Position

        local data = {
            side = side, upper = up, lower = lo, hand = hd,
            shoulderMotor = sM, elbowMotor = eM, wristMotor = wM,
            origSizes = {upper = up.Size, lower = lo.Size, hand = hd.Size},
            origAnchored = {upper = up.Anchored, lower = lo.Anchored, hand = hd.Anchored},
            origCC = {upper = up.CanCollide, lower = lo.CanCollide, hand = hd.CanCollide},
            origTouch = {upper = up.CanTouch, lower = lo.CanTouch, hand = hd.CanTouch},
            origCQ = {upper = up.CanQuery, lower = lo.CanQuery, hand = hd.CanQuery},
            origML = {upper = up.Massless, lower = lo.Massless, hand = hd.Massless},
            origMotorOn = {shoulder = sM.Enabled, elbow = eM.Enabled, wrist = wM.Enabled},
            shoulderRootOffset = root.CFrame:PointToObjectSpace(shoulderPosition),
        }

        sM.Enabled = false
        eM.Enabled = false
        wM.Enabled = false
        for _, p in ipairs({up, lo, hd}) do
            p.Anchored = true; p.CanCollide = false; p.CanTouch = false
            p.CanQuery = false; p.Massless = true
        end
        return data
    end

    local function restoreArmData(data)
        if not data then return end
        pcall(function()
            local up, lo, hd = data.upper, data.lower, data.hand
            if up and up.Parent then
                up.Size = data.origSizes.upper
                up.Anchored = data.origAnchored.upper
                up.CanCollide = data.origCC.upper
                up.CanTouch = data.origTouch.upper
                up.CanQuery = data.origCQ.upper
                up.Massless = data.origML.upper
            end
            if lo and lo.Parent then
                lo.Size = data.origSizes.lower
                lo.Anchored = data.origAnchored.lower
                lo.CanCollide = data.origCC.lower
                lo.CanTouch = data.origTouch.lower
                lo.CanQuery = data.origCQ.lower
                lo.Massless = data.origML.lower
            end
            if hd and hd.Parent then
                hd.Size = data.origSizes.hand
                hd.Anchored = data.origAnchored.hand
                hd.CanCollide = data.origCC.hand
                hd.CanTouch = data.origTouch.hand
                hd.CanQuery = data.origCQ.hand
                hd.Massless = data.origML.hand
            end
            if data.shoulderMotor and data.shoulderMotor.Parent then
                data.shoulderMotor.Enabled = data.origMotorOn.shoulder
            end
            if data.elbowMotor and data.elbowMotor.Parent then
                data.elbowMotor.Enabled = data.origMotorOn.elbow
            end
            if data.wristMotor and data.wristMotor.Parent then
                data.wristMotor.Enabled = data.origMotorOn.wrist
            end
        end)
    end

    local function getShoulderOrigin(data, root)
        if not data or not data.upper or not data.upper.Parent then return nil end
        if not root or not root.Parent then return nil end
        if not data.shoulderRootOffset then return nil end
        return root.CFrame:PointToWorldSpace(data.shoulderRootOffset)
    end

    local function updateStretchArm(data, origin, dir, length)
        if not data then return end
        if not data.upper or not data.upper.Parent then return end
        if not data.lower or not data.lower.Parent then return end
        if not data.hand or not data.hand.Parent then return end
        if not dir or dir.Magnitude < 0.01 then return end
        if not origin then return end
        dir = dir.Unit
        length = math.clamp(length or 3000, 1, 3000)

        local uL = data.origSizes.upper.Y
        local lL = math.max(length - uL, 0.1)
        lL = math.min(lL, 3000)

        local refRight = Vector3.new(1, 0, 0)
        if math.abs(dir:Dot(refRight)) > 0.95 then refRight = Vector3.new(0, 0, 1) end

        local uC = origin + dir * (uL * 0.5)
        data.upper.Size = Vector3.new(data.origSizes.upper.X, uL, data.origSizes.upper.Z)
        data.upper.CFrame = buildBoneCFrame(uC, -dir, refRight)

        local elbowPos = origin + dir * uL
        local lC = elbowPos + dir * (lL * 0.5)
        data.lower.Size = Vector3.new(data.origSizes.lower.X, lL, data.origSizes.lower.Z)
        data.lower.CFrame = buildBoneCFrame(lC, -dir, refRight)

        local handPos = origin + dir * (uL + lL)
        data.hand.Size = data.origSizes.hand
        data.hand.CFrame = buildBoneCFrame(handPos, -dir, refRight)
    end

    local function stopArmStretch()
        if ArmStretch.connection then
            ArmStretch.connection:Disconnect()
            ArmStretch.connection = nil
        end
        if ArmStretch.data then
            for _, d in ipairs(ArmStretch.data) do
                restoreArmData(d)
                if d.shoulderMotor and d.shoulderMotor.Parent and d.origMotorOn.shoulder then
                    d.shoulderMotor.Enabled = true
                end
                if d.elbowMotor and d.elbowMotor.Parent and d.origMotorOn.elbow then
                    d.elbowMotor.Enabled = true
                end
                if d.wristMotor and d.wristMotor.Parent and d.origMotorOn.wrist then
                    d.wristMotor.Enabled = true
                end
            end
            ArmStretch.data = nil
        end
        ArmStretch.active = false
        ArmStretch.lastDir = nil
        ArmStretch.currentTarget = nil
    end

    local function startArmStretch()
        if not (api and api.is_reanimated and api.is_reanimated()) then
            return false, "Enable Reanim first"
        end
        stopArmStretch()

        local model = getActiveCharacter()
        if not model then return false, "No character / clone" end

        local sides = {}
        if ArmStretch.side == "Left" then sides = {"Left"}
        elseif ArmStretch.side == "Both" then sides = {"Right", "Left"}
        else sides = {"Right"} end

        local built = {}
        for _, s in ipairs(sides) do
            local d = buildArmDataForChar(model, s)
            if not d then
                for _, b in ipairs(built) do restoreArmData(b) end
                return false, "Failed to build " .. s .. " arm (clone may not be ready)"
            end
            table.insert(built, d)
        end

        ArmStretch.data = built
        ArmStretch.active = true
        ArmStretch.lastDir = nil
        ArmStretch.currentTarget = nil

        ArmStretch.connection = RunService.Heartbeat:Connect(function(dt)
            if not ArmStretch.active then return end
            local model = getActiveCharacter()
            if not model then stopArmStretch(); return end

            for _, d in ipairs(ArmStretch.data or {}) do
                if not (d.upper and d.upper.Parent and d.lower and d.lower.Parent and d.hand and d.hand.Parent) then
                    stopArmStretch(); return
                end
            end

            local root = model:FindFirstChild("HumanoidRootPart")
            if not root then return end

            local dir
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                local mouseLoc = UserInputService:GetMouseLocation()
                local ray = workspace.CurrentCamera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
                local target = ray.Origin + ray.Direction * 100
                local v = target - root.Position
                if v.Magnitude > 0.05 then
                    dir = v.Unit
                    ArmStretch.lastDir = dir
                end
            end
            if not dir then
                dir = ArmStretch.lastDir or root.CFrame.LookVector
            end

            local aimOrigin = nil
            for _, d in ipairs(ArmStretch.data) do
                aimOrigin = getShoulderOrigin(d, root)
                if aimOrigin then break end
            end
            if not aimOrigin then return end

            local aimLen = ArmStretch.length
            local target = aimOrigin + dir * aimLen
            if not ArmStretch.currentTarget then
                ArmStretch.currentTarget = target
            else
                local a = math.clamp(dt * 20, 0, 1)
                ArmStretch.currentTarget = ArmStretch.currentTarget:Lerp(target, a)
            end

            for _, d in ipairs(ArmStretch.data) do
                local origin = getShoulderOrigin(d, root)
                if origin then
                    local toTarget = ArmStretch.currentTarget - origin
                    local dist = toTarget.Magnitude
                    if dist > 0.05 then
                        updateStretchArm(d, origin, toTarget.Unit, math.min(dist, 3000))
                    end
                end
            end
        end)

        return true, "Arm stretch ON ("..table.concat(sides, "+")..")"
    end

    local function refreshArmStretchUI()
        if ArmStretch.active then
            asEnableBtn.Text = "Disable Arm Stretch"
            asEnableBtn.BackgroundColor3 = C.accent
            asEnableBtn.TextColor3 = C.bg
            asEnableBtn:FindFirstChildOfClass("UIStroke").Color = C.accent
        else
            asEnableBtn.Text = "Enable Arm Stretch"
            asEnableBtn.BackgroundColor3 = C.input
            asEnableBtn.TextColor3 = C.text
            asEnableBtn:FindFirstChildOfClass("UIStroke").Color = C.borderSoft
        end
        asSideBtn.Text = "Side: "..ArmStretch.side
        asModeBtn.Text = "Mode: "..ArmStretch.mode
        asBindBtn.Text = "Bind: "..ArmStretch.bind.Name
        asLenLabel.Text = "REACH: "..tostring(math.floor(ArmStretch.length))
        local pct = math.clamp((ArmStretch.length - 1) / (3000 - 1), 0, 1)
        asLenFill.Size = UDim2.new(pct, 0, 1, 0)
    end

    asEnableBtn.MouseButton1Click:Connect(function()
        if ArmStretch.active then
            stopArmStretch()
            refreshArmStretchUI()
        else
            local ok, msg = startArmStretch()
            if not ok then warn("Arm stretch: "..tostring(msg)) end
            refreshArmStretchUI()
        end
    end)

    asSideBtn.MouseButton1Click:Connect(function()
        local opts = {"Right", "Left", "Both"}
        local i = 1
        for k, v in ipairs(opts) do if v == ArmStretch.side then i = k end end
        ArmStretch.side = opts[(i % #opts) + 1]
        if ArmStretch.active then
            stopArmStretch()
            startArmStretch()
        end
        refreshArmStretchUI()
    end)

    asModeBtn.MouseButton1Click:Connect(function()
        ArmStretch.mode = (ArmStretch.mode == "Toggle") and "Hold" or "Toggle"
        refreshArmStretchUI()
    end)

    asBindBtn.MouseButton1Click:Connect(function()
        ArmStretch.capturing = true
        asBindBtn.Text = "Press key..."
        asBindBtn.TextColor3 = C.accentDim
    end)

    local draggingArmLen = false
    local function updateArmLenFromInput(input)
        local relX = math.clamp(input.Position.X - asLenTrack.AbsolutePosition.X, 0, asLenTrack.AbsoluteSize.X)
        local pct = relX / asLenTrack.AbsoluteSize.X
        ArmStretch.length = math.floor(1 + pct * (3000 - 1))
        refreshArmStretchUI()
    end
    asLenTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingArmLen = true
            updateArmLenFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingArmLen = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingArmLen and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateArmLenFromInput(input)
        end
    end)

    -- ── Face Attach ──
    bodySectionTitle("FACE ATTACH", 9)

    local faceAttachCard = Instance.new("Frame")
    faceAttachCard.Size = UDim2.new(1, 0, 0, 132)
    faceAttachCard.BackgroundColor3 = C.surface
    faceAttachCard.BorderSizePixel = 0
    faceAttachCard.LayoutOrder = 9
    faceAttachCard.Parent = bodyPanel
    applyCorner(faceAttachCard, 10)
    applyStroke(faceAttachCard, C.borderSoft, 1, 0.5)

    local faceAttachBtn = Instance.new("TextButton")
    faceAttachBtn.Size = UDim2.new(1, -24, 0, 30)
    faceAttachBtn.Position = UDim2.new(0, 12, 0, 12)
    faceAttachBtn.BackgroundColor3 = C.input
    faceAttachBtn.Text = "Attach Arm to Cursor Target"
    faceAttachBtn.TextColor3 = C.text
    faceAttachBtn.Font = Enum.Font.GothamBold
    faceAttachBtn.TextSize = 10.5
    faceAttachBtn.AutoButtonColor = false
    faceAttachBtn.Parent = faceAttachCard
    applyCorner(faceAttachBtn, 6)
    applyStroke(faceAttachBtn, C.borderSoft, 1, 0.6)

    local faceAttachBindBtn = Instance.new("TextButton")
    faceAttachBindBtn.Size = UDim2.new(1, -24, 0, 26)
    faceAttachBindBtn.Position = UDim2.new(0, 12, 0, 48)
    faceAttachBindBtn.BackgroundColor3 = C.input
    faceAttachBindBtn.Text = "Bind: G"
    faceAttachBindBtn.TextColor3 = C.accent
    faceAttachBindBtn.Font = Enum.Font.GothamBold
    faceAttachBindBtn.TextSize = 10
    faceAttachBindBtn.AutoButtonColor = false
    faceAttachBindBtn.Parent = faceAttachCard
    applyCorner(faceAttachBindBtn, 6)
    applyStroke(faceAttachBindBtn, C.borderSoft, 1, 0.6)

    local faceAttachHint = Instance.new("TextLabel")
    faceAttachHint.Size = UDim2.new(1, -24, 0, 42)
    faceAttachHint.Position = UDim2.new(0, 12, 0, 82)
    faceAttachHint.BackgroundTransparency = 1
    faceAttachHint.Text = "Put your cursor over a player and press the bind.\nThe arm uses the same face-attachment method and follows their FaceFrontAttachment."
    faceAttachHint.TextColor3 = C.textDim
    faceAttachHint.Font = Enum.Font.Gotham
    faceAttachHint.TextSize = 9
    faceAttachHint.TextWrapped = true
    faceAttachHint.TextXAlignment = Enum.TextXAlignment.Left
    faceAttachHint.TextYAlignment = Enum.TextYAlignment.Top
    faceAttachHint.Parent = faceAttachCard

    local FaceAttach = {
        active = false,
        bind = Enum.KeyCode.G,
        capturing = false,
        data = nil,
        connection = nil,
        targetPlayer = nil,
        targetHead = nil,
        targetFaceAttachment = nil,
    }

    local function getFaceAttachment(head)
        if not head then return nil end
        local direct = head:FindFirstChild("FaceFrontAttachment")
        if direct and direct:IsA("Attachment") then return direct end
        for _, o in ipairs(head:GetDescendants()) do
            if o:IsA("Attachment") and o.Name == "FaceFrontAttachment" then
                return o
            end
        end
        return nil
    end

    local function getCursorTargetPlayer()
        local camera = workspace.CurrentCamera
        if not camera then return nil end

        local mouseLoc = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 2000)

        if not result or not result.Instance then return nil end

        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if not model then return nil end

        local targetPlayer = Players:GetPlayerFromCharacter(model)
        if targetPlayer and targetPlayer ~= player then
            return targetPlayer
        end

        return nil
    end

    local function refreshFaceAttachUI()
        if FaceAttach.active then
            faceAttachBtn.Text = "Detach Arm"
            faceAttachBtn.BackgroundColor3 = C.accent
            faceAttachBtn.TextColor3 = C.bg
            local stroke = faceAttachBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = C.accent end
        else
            faceAttachBtn.Text = "Attach Arm to Cursor Target"
            faceAttachBtn.BackgroundColor3 = C.input
            faceAttachBtn.TextColor3 = C.text
            local stroke = faceAttachBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = C.borderSoft end
        end

        faceAttachBindBtn.Text = "Bind: "..FaceAttach.bind.Name
        faceAttachBindBtn.TextColor3 = FaceAttach.capturing and C.accentDim or C.accent
    end

    local function stopFaceAttach()
        if FaceAttach.connection then
            FaceAttach.connection:Disconnect()
            FaceAttach.connection = nil
        end

        if FaceAttach.data then
            for _, d in ipairs(FaceAttach.data) do
                restoreArmData(d)
            end
            FaceAttach.data = nil
        end

        FaceAttach.active = false
        FaceAttach.targetPlayer = nil
        FaceAttach.targetHead = nil
        FaceAttach.targetFaceAttachment = nil
        refreshFaceAttachUI()
    end

    local function startFaceAttach(targetPlayer)
        if not targetPlayer or targetPlayer == player then
            return false, "No player under cursor"
        end

        if not (api and api.is_reanimated and api.is_reanimated()) then
            return false, "Enable Reanim first"
        end

        local targetCharacter = targetPlayer.Character
        local targetHead = targetCharacter and targetCharacter:FindFirstChild("Head")
        local faceAttachment = getFaceAttachment(targetHead)
        if not targetHead then return false, "Target head missing" end
        if not faceAttachment then return false, "Target has no FaceFrontAttachment" end

        stopFaceAttach()
        if ArmStretch.active then
            stopArmStretch()
            refreshArmStretchUI()
        end

        local model = getActiveCharacter()
        if not model then return false, "No character / clone" end

        local sides = {}
        if ArmStretch.side == "Left" then
            sides = {"Left"}
        elseif ArmStretch.side == "Both" then
            sides = {"Right", "Left"}
        else
            sides = {"Right"}
        end

        local built = {}
        for _, side in ipairs(sides) do
            local d = buildArmDataForChar(model, side)
            if not d then
                for _, b in ipairs(built) do restoreArmData(b) end
                return false, "Failed to build "..side.." arm"
            end
            table.insert(built, d)
        end

        FaceAttach.data = built
        FaceAttach.targetPlayer = targetPlayer
        FaceAttach.targetHead = targetHead
        FaceAttach.targetFaceAttachment = faceAttachment
        FaceAttach.active = true

        FaceAttach.connection = RunService.Heartbeat:Connect(function()
            if not FaceAttach.active then return end

            local currentCharacter = targetPlayer.Character
            local currentHead = currentCharacter and currentCharacter:FindFirstChild("Head")
            local currentAttachment = getFaceAttachment(currentHead)

            if not currentHead or not currentAttachment then
                stopFaceAttach()
                return
            end

            FaceAttach.targetHead = currentHead
            FaceAttach.targetFaceAttachment = currentAttachment

            local modelNow = getActiveCharacter()
            local root = modelNow and modelNow:FindFirstChild("HumanoidRootPart")
            if not root then return end

            local hcf = currentAttachment.WorldCFrame
            local handPos = hcf.Position
            local right = hcf.RightVector

            local dataCount = #(FaceAttach.data or {})

            for i, d in ipairs(FaceAttach.data or {}) do
                if not (d.upper and d.upper.Parent and d.lower and d.lower.Parent and d.hand and d.hand.Parent) then
                    stopFaceAttach()
                    return
                end

                local origin = getShoulderOrigin(d, root)
                if origin then
                    local offset = Vector3.zero
                    if dataCount == 2 then
                        offset = (i == 1) and (right * 0.12) or (right * -0.12)
                    end

                    local target = handPos + offset
                    local toTarget = target - origin
                    if toTarget.Magnitude > 0.05 then
                        updateStretchArm(d, origin, toTarget.Unit, math.min(toTarget.Magnitude, 3000))
                    end
                end
            end
        end)

        refreshFaceAttachUI()
        return true, "Attached to "..targetPlayer.DisplayName
    end

    local function toggleFaceAttachAtCursor()
        if FaceAttach.active then
            stopFaceAttach()
            return
        end

        local targetPlayer = getCursorTargetPlayer()
        if not targetPlayer then
            warn("Face attach: put your cursor over a player")
            return
        end

        local ok, msg = startFaceAttach(targetPlayer)
        if not ok then
            warn("Face attach: "..tostring(msg))
        end
    end

    faceAttachBtn.MouseButton1Click:Connect(function()
        toggleFaceAttachAtCursor()
    end)

    faceAttachBindBtn.MouseButton1Click:Connect(function()
        FaceAttach.capturing = true
        faceAttachBindBtn.Text = "Press key..."
        faceAttachBindBtn.TextColor3 = C.accentDim
    end)

    BodyArm.FaceAttach = FaceAttach
    BodyArm.stopFaceAttach = stopFaceAttach
    BodyArm.startFaceAttach = startFaceAttach
    BodyArm.toggleFaceAttachAtCursor = toggleFaceAttachAtCursor
    BodyArm.refreshFaceAttachUI = refreshFaceAttachUI

    -- ── Torso Aim (Stretch + Follow + Face Attach) ──
    bodySectionTitle("TORSO AIM", 10)

    local torsoCard = Instance.new("Frame")
    torsoCard.Size = UDim2.new(1, 0, 0, 240)
    torsoCard.BackgroundColor3 = C.surface
    torsoCard.BorderSizePixel = 0
    torsoCard.LayoutOrder = 10
    torsoCard.Parent = bodyPanel
    applyCorner(torsoCard, 10)
    applyStroke(torsoCard, C.borderSoft, 1, 0.5)

    local torsoEnableBtn = Instance.new("TextButton")
    torsoEnableBtn.Size = UDim2.new(1, -24, 0, 30)
    torsoEnableBtn.Position = UDim2.new(0, 12, 0, 12)
    torsoEnableBtn.BackgroundColor3 = C.input
    torsoEnableBtn.Text = "Enable Torso Aim"
    torsoEnableBtn.TextColor3 = C.text
    torsoEnableBtn.Font = Enum.Font.GothamBold
    torsoEnableBtn.TextSize = 11
    torsoEnableBtn.AutoButtonColor = false
    torsoEnableBtn.Parent = torsoCard
    applyCorner(torsoEnableBtn, 6)
    applyStroke(torsoEnableBtn, C.borderSoft, 1, 0.6)

    local torsoModeBtn = Instance.new("TextButton")
    torsoModeBtn.Size = UDim2.new(0, 174, 0, 26)
    torsoModeBtn.Position = UDim2.new(0, 12, 0, 50)
    torsoModeBtn.BackgroundColor3 = C.input
    torsoModeBtn.Text = "Mode: Stretch"
    torsoModeBtn.TextColor3 = C.text
    torsoModeBtn.Font = Enum.Font.GothamSemibold
    torsoModeBtn.TextSize = 10
    torsoModeBtn.AutoButtonColor = false
    torsoModeBtn.Parent = torsoCard
    applyCorner(torsoModeBtn, 6)
    applyStroke(torsoModeBtn, C.borderSoft, 1, 0.6)

    local torsoReachInfo = Instance.new("TextLabel")
    torsoReachInfo.Size = UDim2.new(0, 174, 0, 26)
    torsoReachInfo.Position = UDim2.new(1, -186, 0, 50)
    torsoReachInfo.BackgroundColor3 = C.input
    torsoReachInfo.Text = "Reach: 14"
    torsoReachInfo.TextColor3 = C.text
    torsoReachInfo.Font = Enum.Font.GothamSemibold
    torsoReachInfo.TextSize = 10
    torsoReachInfo.Parent = torsoCard
    applyCorner(torsoReachInfo, 6)
    applyStroke(torsoReachInfo, C.borderSoft, 1, 0.6)

    local torsoStretchBindBtn = Instance.new("TextButton")
    torsoStretchBindBtn.Size = UDim2.new(0, 174, 0, 26)
    torsoStretchBindBtn.Position = UDim2.new(0, 12, 0, 82)
    torsoStretchBindBtn.BackgroundColor3 = C.input
    torsoStretchBindBtn.Text = "Stretch Bind: T"
    torsoStretchBindBtn.TextColor3 = C.accent
    torsoStretchBindBtn.Font = Enum.Font.GothamBold
    torsoStretchBindBtn.TextSize = 10
    torsoStretchBindBtn.AutoButtonColor = false
    torsoStretchBindBtn.Parent = torsoCard
    applyCorner(torsoStretchBindBtn, 6)
    applyStroke(torsoStretchBindBtn, C.borderSoft, 1, 0.6)

    local torsoFollowBindBtn = Instance.new("TextButton")
    torsoFollowBindBtn.Size = UDim2.new(0, 174, 0, 26)
    torsoFollowBindBtn.Position = UDim2.new(1, -186, 0, 82)
    torsoFollowBindBtn.BackgroundColor3 = C.input
    torsoFollowBindBtn.Text = "Follow Bind: Y"
    torsoFollowBindBtn.TextColor3 = C.accent
    torsoFollowBindBtn.Font = Enum.Font.GothamBold
    torsoFollowBindBtn.TextSize = 10
    torsoFollowBindBtn.AutoButtonColor = false
    torsoFollowBindBtn.Parent = torsoCard
    applyCorner(torsoFollowBindBtn, 6)
    applyStroke(torsoFollowBindBtn, C.borderSoft, 1, 0.6)

    local torsoFaceAttachActionBtn = Instance.new("TextButton")
    torsoFaceAttachActionBtn.Size = UDim2.new(0, 174, 0, 26)
    torsoFaceAttachActionBtn.Position = UDim2.new(0, 12, 0, 112)
    torsoFaceAttachActionBtn.BackgroundColor3 = C.input
    torsoFaceAttachActionBtn.Text = "Attach to Face"
    torsoFaceAttachActionBtn.TextColor3 = C.text
    torsoFaceAttachActionBtn.Font = Enum.Font.GothamBold
    torsoFaceAttachActionBtn.TextSize = 10
    torsoFaceAttachActionBtn.AutoButtonColor = false
    torsoFaceAttachActionBtn.Parent = torsoCard
    applyCorner(torsoFaceAttachActionBtn, 6)
    applyStroke(torsoFaceAttachActionBtn, C.borderSoft, 1, 0.6)

    local torsoFaceAttachBindBtn = Instance.new("TextButton")
    torsoFaceAttachBindBtn.Size = UDim2.new(0, 174, 0, 26)
    torsoFaceAttachBindBtn.Position = UDim2.new(1, -186, 0, 112)
    torsoFaceAttachBindBtn.BackgroundColor3 = C.input
    torsoFaceAttachBindBtn.Text = "Bind: H"
    torsoFaceAttachBindBtn.TextColor3 = C.accent
    torsoFaceAttachBindBtn.Font = Enum.Font.GothamBold
    torsoFaceAttachBindBtn.TextSize = 10
    torsoFaceAttachBindBtn.AutoButtonColor = false
    torsoFaceAttachBindBtn.Parent = torsoCard
    applyCorner(torsoFaceAttachBindBtn, 6)
    applyStroke(torsoFaceAttachBindBtn, C.borderSoft, 1, 0.6)

    local torsoReachLabel = Instance.new("TextLabel")
    torsoReachLabel.Size = UDim2.new(1, -24, 0, 14)
    torsoReachLabel.Position = UDim2.new(0, 12, 0, 148)
    torsoReachLabel.BackgroundTransparency = 1
    torsoReachLabel.Text = "REACH: 14"
    torsoReachLabel.TextColor3 = C.textMuted
    torsoReachLabel.Font = Enum.Font.GothamBold
    torsoReachLabel.TextSize = 9
    torsoReachLabel.TextXAlignment = Enum.TextXAlignment.Left
    torsoReachLabel.Parent = torsoCard

    local torsoReachTrack = Instance.new("Frame")
    torsoReachTrack.Size = UDim2.new(1, -24, 0, 6)
    torsoReachTrack.Position = UDim2.new(0, 12, 0, 166)
    torsoReachTrack.BackgroundColor3 = C.input
    torsoReachTrack.BorderSizePixel = 0
    torsoReachTrack.Parent = torsoCard
    applyCorner(torsoReachTrack, 3)

    local torsoReachFill = Instance.new("Frame")
    torsoReachFill.Size = UDim2.new(0.14, 0, 1, 0)
    torsoReachFill.BackgroundColor3 = C.accent
    torsoReachFill.BorderSizePixel = 0
    torsoReachFill.Parent = torsoReachTrack
    applyCorner(torsoReachFill, 3)

    local torsoReachKnob = Instance.new("Frame")
    torsoReachKnob.Size = UDim2.new(0, 12, 0, 12)
    torsoReachKnob.Position = UDim2.new(1, -6, 0.5, -6)
    torsoReachKnob.BackgroundColor3 = C.text
    torsoReachKnob.BorderSizePixel = 0
    torsoReachKnob.Parent = torsoReachFill
    applyCorner(torsoReachKnob, 6)

    local torsoHint = Instance.new("TextLabel")
    torsoHint.Size = UDim2.new(1, -24, 0, 50)
    torsoHint.Position = UDim2.new(0, 12, 0, 182)
    torsoHint.BackgroundTransparency = 1
    torsoHint.Text = "Stretch = torso reaches to cursor.\nFollow = torso leans/rotates toward cursor.\nFace Attach = torso locks onto a player's face (aim cursor at player, press bind)."
    torsoHint.TextColor3 = C.textDim
    torsoHint.Font = Enum.Font.Gotham
    torsoHint.TextSize = 9
    torsoHint.TextWrapped = true
    torsoHint.TextXAlignment = Enum.TextXAlignment.Left
    torsoHint.TextYAlignment = Enum.TextYAlignment.Top
    torsoHint.Parent = torsoCard

    local TorsoAim = {
        active = false,
        mode = "Stretch",  -- "Stretch" | "Follow" | "Attach"
        stretchBind = Enum.KeyCode.T,
        followBind  = Enum.KeyCode.Y,
        faceAttachBind = Enum.KeyCode.H,
        stretchReach = 14,
        followStrength = 100,
        capturing = nil,  -- "stretch" | "follow" | "faceattach"
        data = nil,
        connection = nil,
        smoothPos = nil,
        lastDir = nil,
        targetPlayer = nil,
        targetFaceAttachment = nil,
    }

    local function setPartCFrame(part, pos, lookDir)
        if not part or not part.Parent then return end
        local look = lookDir
        if not look or look.Magnitude < 0.01 then look = Vector3.new(0,0,-1) end
        look = look.Unit
        local right = Vector3.new(0,1,0):Cross(look)
        if right.Magnitude < 0.05 then right = Vector3.new(1,0,0):Cross(look) end
        right = right.Unit
        local up = look:Cross(right).Unit
        part.CFrame = CFrame.fromMatrix(pos, right, up, -look)
    end

    local function findWaistMotor(model)
        if not model then return nil, nil end
        local up = model:FindFirstChild("UpperTorso")
        if not up then return nil, nil end
        local waistMotor
        for _, m in ipairs(model:GetDescendants()) do
            if m:IsA("Motor6D") and m.Part1 == up then waistMotor = m; break end
        end
        if not waistMotor then
            for _, m in ipairs(model:GetDescendants()) do
                if m:IsA("Motor6D") and m.Name:lower():find("waist") then waistMotor = m; break end
            end
        end
        return up, waistMotor
    end

    local function getFaceAttachmentT(head)
        if not head then return nil end
        local direct = head:FindFirstChild("FaceFrontAttachment")
        if direct and direct:IsA("Attachment") then return direct end
        for _, o in ipairs(head:GetDescendants()) do
            if o:IsA("Attachment") and o.Name == "FaceFrontAttachment" then
                return o
            end
        end
        return nil
    end

    local function getCursorTargetPlayerT()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local mouseLoc = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 2000)
        if not result or not result.Instance then return nil end
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if not model then return nil end
        local targetPlayer = Players:GetPlayerFromCharacter(model)
        if targetPlayer and targetPlayer ~= player then
            return targetPlayer
        end
        return nil
    end

    local function prepareStretchData(model)
        if not model then return nil end
        local up, waistMotor = findWaistMotor(model)
        if not up or not waistMotor then return nil end

        local data = {
            mode = "Stretch",
            upper = up,
            waistMotor = waistMotor,
            origUpper = {
                anchored = up.Anchored,
                canCollide = up.CanCollide,
                canTouch = up.CanTouch,
                canQuery = up.CanQuery,
                massless = up.Massless,
            },
            origWaist = {
                enabled = waistMotor.Enabled,
                c0 = waistMotor.C0,
                c1 = waistMotor.C1,
            },
            rootPart = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart"),
        }
        waistMotor.Enabled = false
        up.Anchored = true
        up.CanCollide = false
        up.CanTouch = false
        up.CanQuery = false
        up.Massless = true
        return data
    end

    local function prepareFollowData(model)
        if not model then return nil end
        local up, waistMotor = findWaistMotor(model)
        if not up or not waistMotor then return nil end
        if not waistMotor.Part0 then return nil end

        return {
            mode = "Follow",
            upper = up,
            waistMotor = waistMotor,
            origC0 = waistMotor.C0,
            origC1 = waistMotor.C1,
            rootPart = waistMotor.Part0,
        }
    end

    local function restoreTorsoData(data)
        if not data then return end
        pcall(function()
            if data.mode == "Stretch" or data.mode == "Attach" then
                if data.upper and data.upper.Parent then
                    data.upper.Anchored = data.origUpper.anchored
                    data.upper.CanCollide = data.origUpper.canCollide
                    data.upper.CanTouch = data.origUpper.canTouch
                    data.upper.CanQuery = data.origUpper.canQuery
                    data.upper.Massless = data.origUpper.massless
                end
                if data.waistMotor and data.waistMotor.Parent then
                    data.waistMotor.Enabled = data.origWaist.enabled
                    data.waistMotor.C0 = data.origWaist.c0
                    data.waistMotor.C1 = data.origWaist.c1
                end
            elseif data.mode == "Follow" then
                if data.waistMotor and data.waistMotor.Parent then
                    data.waistMotor.C0 = data.origC0
                    data.waistMotor.C1 = data.origC1
                end
            end
        end)
    end

    local function stopTorsoAim()
        if TorsoAim.connection then
            TorsoAim.connection:Disconnect()
            TorsoAim.connection = nil
        end
        if TorsoAim.data then
            restoreTorsoData(TorsoAim.data)
            TorsoAim.data = nil
        end
        TorsoAim.active = false
        TorsoAim.smoothPos = nil
        TorsoAim.lastDir = nil
        TorsoAim.targetPlayer = nil
        TorsoAim.targetFaceAttachment = nil
    end

    local function getCursorDirection(origin)
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            local mouseLoc = UserInputService:GetMouseLocation()
            local ray = workspace.CurrentCamera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
            local target = ray.Origin + ray.Direction * 200
            local v = target - origin
            if v.Magnitude > 0.1 then
                return v.Unit
            end
        end
        return nil
    end

    local function startTorsoStretch()
        if not (api and api.is_reanimated and api.is_reanimated()) then
            return false, "Enable Reanim first"
        end
        stopTorsoAim()

        local model = getActiveCharacter()
        if not model then return false, "No character / clone" end

        local data = prepareStretchData(model)
        if not data then return false, "Could not prepare torso" end

        TorsoAim.data = data
        TorsoAim.active = true
        TorsoAim.mode = "Stretch"
        TorsoAim.smoothPos = nil
        TorsoAim.lastDir = nil

        TorsoAim.connection = RunService.Heartbeat:Connect(function(dt)
            if not TorsoAim.active then return end
            local model = getActiveCharacter()
            if not model then stopTorsoAim(); return end
            local data = TorsoAim.data
            if not data or not data.upper or not data.upper.Parent then stopTorsoAim(); return end

            local root = model:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local lt = data.rootPart
            local origin
            if lt and lt.Parent then
                origin = lt.Position + Vector3.new(0, 1.2, 0)
            else
                origin = root.Position + Vector3.new(0, 1.2, 0)
            end

            local dir = getCursorDirection(origin)
            if dir then
                TorsoAim.lastDir = dir
            else
                dir = TorsoAim.lastDir or root.CFrame.LookVector
            end

            local reach = TorsoAim.stretchReach
            local dp = origin + dir * reach
            if not TorsoAim.smoothPos then
                TorsoAim.smoothPos = dp
            else
                local a = math.clamp(dt * 18, 0, 1)
                TorsoAim.smoothPos = TorsoAim.smoothPos:Lerp(dp, a)
            end

            setPartCFrame(data.upper, TorsoAim.smoothPos, dir)
        end)

        return true, "Torso stretch ON"
    end

    local function startTorsoFollow()
        if not (api and api.is_reanimated and api.is_reanimated()) then
            return false, "Enable Reanim first"
        end
        stopTorsoAim()

        local model = getActiveCharacter()
        if not model then return false, "No character / clone" end

        local data = prepareFollowData(model)
        if not data then return false, "Could not prepare torso (clone not ready?)" end

        TorsoAim.data = data
        TorsoAim.active = true
        TorsoAim.mode = "Follow"
        TorsoAim.lastDir = nil

        TorsoAim.connection = RunService.Heartbeat:Connect(function(dt)
            if not TorsoAim.active then return end
            local model = getActiveCharacter()
            if not model then stopTorsoAim(); return end
            local data = TorsoAim.data
            if not data or not data.waistMotor or not data.waistMotor.Parent then
                stopTorsoAim(); return
            end
            local part0 = data.waistMotor.Part0
            if not part0 then return end

            local origin = part0.Position
            local dir = getCursorDirection(origin)
            if dir then
                TorsoAim.lastDir = dir
            else
                dir = TorsoAim.lastDir or part0.CFrame.LookVector
            end

            local rel = part0.CFrame:VectorToObjectSpace(dir)

            local yaw = math.atan2(-rel.X, -rel.Z)
            local pitch = math.asin(math.clamp(rel.Y, -1, 1))

            local strength = math.clamp((TorsoAim.followStrength - 1) / 99, 0, 1)

            local maxYaw = math.rad(170) * strength
            local maxPitch = math.rad(90) * strength

            yaw = math.clamp(yaw, -maxYaw, maxYaw)
            pitch = math.clamp(pitch, -maxPitch, maxPitch)

            local rot = CFrame.Angles(pitch, yaw, 0)
            data.waistMotor.C0 = CFrame.new(data.origC0.Position) * rot
        end)

        return true, "Torso follow ON"
    end

    local function startTorsoFaceAttach(targetPlayer)
        if not targetPlayer or targetPlayer == player then
            return false, "No player under cursor"
        end
        if not (api and api.is_reanimated and api.is_reanimated()) then
            return false, "Enable Reanim first"
        end

        local targetCharacter = targetPlayer.Character
        local targetHead = targetCharacter and targetCharacter:FindFirstChild("Head")
        local faceAttachment = getFaceAttachmentT(targetHead)
        if not targetHead then return false, "Target head missing" end
        if not faceAttachment then return false, "Target has no FaceFrontAttachment" end

        stopTorsoAim()

        local model = getActiveCharacter()
        if not model then return false, "No character / clone" end

        local data = prepareStretchData(model)
        if not data then return false, "Could not prepare torso" end
        data.mode = "Attach"

        TorsoAim.data = data
        TorsoAim.active = true
        TorsoAim.mode = "Attach"
        TorsoAim.targetPlayer = targetPlayer
        TorsoAim.targetFaceAttachment = faceAttachment
        TorsoAim.smoothPos = nil

        TorsoAim.connection = RunService.Heartbeat:Connect(function(dt)
            if not TorsoAim.active then return end
            local model = getActiveCharacter()
            if not model then stopTorsoAim(); return end
            local data = TorsoAim.data
            if not data or not data.upper or not data.upper.Parent then stopTorsoAim(); return end

            local currentChar = targetPlayer.Character
            local currentHead = currentChar and currentChar:FindFirstChild("Head")
            local currentAtt = getFaceAttachmentT(currentHead)
            if not currentHead or not currentAtt then
                stopTorsoAim(); return
            end
            TorsoAim.targetFaceAttachment = currentAtt

            local hcf = currentAtt.WorldCFrame
            local facePos = hcf.Position

            -- Small offset in front of the face so the torso sits right at it
            local targetPos = facePos + hcf.LookVector * 0.4

            if not TorsoAim.smoothPos then
                TorsoAim.smoothPos = targetPos
            else
                local a = math.clamp(dt * 22, 0, 1)
                TorsoAim.smoothPos = TorsoAim.smoothPos:Lerp(targetPos, a)
            end

            -- Orient the torso the same direction as the target's head
            local lookDir = currentHead.CFrame.LookVector
            if lookDir.Magnitude < 0.01 then lookDir = hcf.LookVector end
            setPartCFrame(data.upper, TorsoAim.smoothPos, lookDir)
        end)

        return true, "Torso attached to "..targetPlayer.DisplayName
    end

    local function startTorsoAim(mode)
        if mode == "Follow" then
            return startTorsoFollow()
        elseif mode == "Attach" then
            local t = getCursorTargetPlayerT()
            if not t then return false, "Put cursor over a player" end
            return startTorsoFaceAttach(t)
        else
            return startTorsoStretch()
        end
    end

    local function refreshTorsoAimUI()
        if TorsoAim.active then
            torsoEnableBtn.Text = "Disable Torso Aim"
            torsoEnableBtn.BackgroundColor3 = C.accent
            torsoEnableBtn.TextColor3 = C.bg
            local stroke = torsoEnableBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = C.accent end
        else
            torsoEnableBtn.Text = "Enable Torso Aim"
            torsoEnableBtn.BackgroundColor3 = C.input
            torsoEnableBtn.TextColor3 = C.text
            local stroke = torsoEnableBtn:FindFirstChildOfClass("UIStroke")
            if stroke then stroke.Color = C.borderSoft end
        end

        if TorsoAim.mode == "Attach" and TorsoAim.active then
            torsoModeBtn.Text = "Mode: Attach"
        else
            torsoModeBtn.Text = "Mode: "..TorsoAim.mode
        end

        torsoStretchBindBtn.Text = "Stretch Bind: "..TorsoAim.stretchBind.Name
        torsoStretchBindBtn.TextColor3 = (TorsoAim.capturing == "stretch") and C.accentDim or C.accent
        torsoFollowBindBtn.Text = "Follow Bind: "..TorsoAim.followBind.Name
        torsoFollowBindBtn.TextColor3 = (TorsoAim.capturing == "follow") and C.accentDim or C.accent
        torsoFaceAttachBindBtn.Text = "Bind: "..TorsoAim.faceAttachBind.Name
        torsoFaceAttachBindBtn.TextColor3 = (TorsoAim.capturing == "faceattach") and C.accentDim or C.accent

        -- Face attach action button visual
        if TorsoAim.active and TorsoAim.mode == "Attach" then
            torsoFaceAttachActionBtn.Text = "Detach Face"
            torsoFaceAttachActionBtn.BackgroundColor3 = C.accent
            torsoFaceAttachActionBtn.TextColor3 = C.bg
            local s = torsoFaceAttachActionBtn:FindFirstChildOfClass("UIStroke")
            if s then s.Color = C.accent end
        else
            torsoFaceAttachActionBtn.Text = "Attach to Face"
            torsoFaceAttachActionBtn.BackgroundColor3 = C.input
            torsoFaceAttachActionBtn.TextColor3 = C.text
            local s = torsoFaceAttachActionBtn:FindFirstChildOfClass("UIStroke")
            if s then s.Color = C.borderSoft end
        end

        if TorsoAim.mode == "Attach" and TorsoAim.active then
            torsoReachInfo.Text = "Attached"
            torsoReachLabel.Text = "ATTACHED TO FACE"
            torsoReachFill.Size = UDim2.new(1, 0, 1, 0)
        elseif TorsoAim.mode == "Follow" then
            torsoReachInfo.Text = "Lean: "..tostring(math.floor(TorsoAim.followStrength)).."%"
            torsoReachLabel.Text = "LEAN STRENGTH: "..tostring(math.floor(TorsoAim.followStrength)).."%"
            local pct = math.clamp((TorsoAim.followStrength - 1) / 99, 0, 1)
            torsoReachFill.Size = UDim2.new(pct, 0, 1, 0)
        else
            torsoReachInfo.Text = "Reach: "..tostring(math.floor(TorsoAim.stretchReach))
            torsoReachLabel.Text = "REACH: "..tostring(math.floor(TorsoAim.stretchReach))
            local pct = math.clamp((TorsoAim.stretchReach - 1) / (3000 - 1), 0, 1)
            torsoReachFill.Size = UDim2.new(pct, 0, 1, 0)
        end
    end

    torsoEnableBtn.MouseButton1Click:Connect(function()
        if TorsoAim.active then
            stopTorsoAim()
            refreshTorsoAimUI()
        else
            local ok, msg = startTorsoAim(TorsoAim.mode)
            if not ok then warn("Torso aim: "..tostring(msg)) end
            refreshTorsoAimUI()
        end
    end)

    torsoModeBtn.MouseButton1Click:Connect(function()
        if TorsoAim.mode == "Attach" then
            TorsoAim.mode = "Stretch"
        else
            TorsoAim.mode = (TorsoAim.mode == "Stretch") and "Follow" or "Stretch"
        end
        if TorsoAim.active then
            stopTorsoAim()
            startTorsoAim(TorsoAim.mode)
        end
        refreshTorsoAimUI()
    end)

    torsoStretchBindBtn.MouseButton1Click:Connect(function()
        TorsoAim.capturing = "stretch"
        refreshTorsoAimUI()
    end)

    torsoFollowBindBtn.MouseButton1Click:Connect(function()
        TorsoAim.capturing = "follow"
        refreshTorsoAimUI()
    end)

    torsoFaceAttachBindBtn.MouseButton1Click:Connect(function()
        TorsoAim.capturing = "faceattach"
        refreshTorsoAimUI()
    end)

    torsoFaceAttachActionBtn.MouseButton1Click:Connect(function()
        if TorsoAim.active and TorsoAim.mode == "Attach" then
            stopTorsoAim()
            refreshTorsoAimUI()
            return
        end
        local t = getCursorTargetPlayerT()
        if not t then
            warn("Torso face attach: put your cursor over a player")
            return
        end
        local ok, msg = startTorsoFaceAttach(t)
        if not ok then
            warn("Torso face attach: "..tostring(msg))
        end
        refreshTorsoAimUI()
    end)

    local draggingTorsoReach = false
    local function updateTorsoReachFromInput(input)
        local relX = math.clamp(input.Position.X - torsoReachTrack.AbsolutePosition.X, 0, torsoReachTrack.AbsoluteSize.X)
        local pct = relX / torsoReachTrack.AbsoluteSize.X
        if TorsoAim.mode == "Follow" then
            TorsoAim.followStrength = math.floor(1 + pct * 99)
        else
            TorsoAim.stretchReach = math.floor(1 + pct * (3000 - 1))
        end
        refreshTorsoAimUI()
    end
    torsoReachTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingTorsoReach = true
            updateTorsoReachFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingTorsoReach = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingTorsoReach and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateTorsoReachFromInput(input)
        end
    end)

    BodyArm.TorsoAim = TorsoAim
    BodyArm.stopTorsoAim = stopTorsoAim
    BodyArm.startTorsoAim = startTorsoAim
    BodyArm.startTorsoFaceAttach = startTorsoFaceAttach
    BodyArm.getCursorTargetPlayerT = getCursorTargetPlayerT
    BodyArm.refreshTorsoAimUI = refreshTorsoAimUI
    refreshTorsoAimUI()

    -- ── UTILITIES ──
    bodySectionTitle("UTILITIES", 11)

    local stopAllCard = Instance.new("Frame")
    stopAllCard.Size = UDim2.new(1, 0, 0, 44)
    stopAllCard.BackgroundColor3 = C.surface
    stopAllCard.BorderSizePixel = 0
    stopAllCard.LayoutOrder = 12
    stopAllCard.Parent = bodyPanel
    applyCorner(stopAllCard, 10)
    applyStroke(stopAllCard, C.borderSoft, 1, 0.5)

    local stopAllBtn = Instance.new("TextButton")
    stopAllBtn.Size = UDim2.new(1, -20, 0, 28)
    stopAllBtn.Position = UDim2.new(0, 10, 0.5, -14)
    stopAllBtn.BackgroundColor3 = C.input
    stopAllBtn.Text = "Stop All Body Features"
    stopAllBtn.TextColor3 = C.text
    stopAllBtn.Font = Enum.Font.GothamBold
    stopAllBtn.TextSize = 10
    stopAllBtn.AutoButtonColor = false
    stopAllBtn.Parent = stopAllCard
    applyCorner(stopAllBtn, 6)
    applyStroke(stopAllBtn, C.borderSoft, 1, 0.6)

    stopAllBtn.MouseButton1Click:Connect(function()
        stopArmStretch()
        refreshArmStretchUI()
        stopFaceAttach()
        stopTorsoAim()
        refreshTorsoAimUI()
    end)

    refreshArmStretchUI()
    bodyPanel.CanvasSize = UDim2.new(0, 0, 0, 780)

    BodyArm.panel = bodyPanel
    BodyArm.ArmStretch = ArmStretch
    BodyArm.stopArmStretch = stopArmStretch
    BodyArm.startArmStretch = startArmStretch
    BodyArm.refreshArmStretchUI = refreshArmStretchUI
end)()

-- ═══════════════════════════════════════════════════
-- LIST ENGINE
-- ═══════════════════════════════════════════════════
local ROW_HEIGHT = 40
local currentlyBinding = nil
local activeOutlineAnim = nil

local dragState = nil

local rowPool = {}
local activeRows = {}

local displayCache = nil
local displayCacheKey = nil
local listDirty = true

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
        markListDirty()
        return
    end
    manualAnimationPlaying = true
    activeOutlineAnim = anim.name
    api.play_animation(anim.path, currentSpeed)
    updateNowPlayingUI(anim.name)
    markListDirty()
end

local function removeFromFavOrder(name)
    for i, n in ipairs(savedConfig.favOrder) do
        if n == name then table.remove(savedConfig.favOrder, i); return end
    end
end

local function addToFavOrder(name)
    removeFromFavOrder(name)
    table.insert(savedConfig.favOrder, name)
end

local function buildRow()
    local row = {}

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
    frame.BackgroundColor3 = C.surface
    frame.BorderSizePixel = 0
    frame.Parent = scrollList
    applyCorner(frame, 8)
    local stroke = applyStroke(frame, C.borderSoft, 1, 0.55)
    row.Frame = frame
    row.Stroke = stroke

    local grip = Instance.new("TextButton")
    grip.Size = UDim2.new(0, 20, 1, 0)
    grip.Position = UDim2.new(0, 0, 0, 0)
    grip.BackgroundTransparency = 1
    grip.Text = ""
    grip.AutoButtonColor = false
    grip.Visible = false
    grip.Parent = frame
    row.Grip = grip

    for di = 1, 3 do
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 3, 0, 3)
        dot.Position = UDim2.new(0.5, -1.5, 0.5, (di - 2) * 7 - 1.5)
        dot.BackgroundColor3 = C.textDim
        dot.BorderSizePixel = 0
        dot.Parent = grip
        applyCorner(dot, 2)
    end

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 0.6, 0)
    accentBar.Position = UDim2.new(0, 0, 0.2, 0)
    accentBar.BackgroundColor3 = C.accent
    accentBar.BorderSizePixel = 0
    accentBar.Visible = false
    accentBar.Parent = frame
    applyCorner(accentBar, 2)
    row.AccentBar = accentBar

    local star = Instance.new("TextButton")
    star.Size = UDim2.new(0, 26, 1, 0)
    star.Position = UDim2.new(0, 5, 0, 0)
    star.BackgroundTransparency = 1
    star.Text = "☆"
    star.TextColor3 = C.textMuted
    star.Font = Enum.Font.GothamBold
    star.TextSize = 15
    star.AutoButtonColor = false
    star.Parent = frame
    row.Star = star

    local play = Instance.new("TextButton")
    play.Size = UDim2.new(1, -108, 1, 0)
    play.Position = UDim2.new(0, 36, 0, 0)
    play.BackgroundTransparency = 1
    play.Text = ""
    play.TextColor3 = C.text
    play.Font = Enum.Font.GothamMedium
    play.TextSize = 11
    play.TextXAlignment = Enum.TextXAlignment.Left
    play.TextTruncate = Enum.TextTruncate.AtEnd
    play.AutoButtonColor = false
    play.RichText = true
    play.Parent = frame
    row.Play = play

    local key = Instance.new("TextButton")
    key.Size = UDim2.new(0, 40, 0, 22)
    key.Position = UDim2.new(1, -46, 0.5, -11)
    key.BackgroundColor3 = C.input
    key.Text = "[+]"
    key.TextColor3 = C.textMuted
    key.Font = Enum.Font.GothamBold
    key.TextSize = 10
    key.AutoButtonColor = false
    key.Parent = frame
    applyCorner(key, 5)
    applyStroke(key, C.borderSoft, 1, 0.6)
    row.Key = key

    local del = Instance.new("TextButton")
    del.Size = UDim2.new(0, 24, 0, 22)
    del.Position = UDim2.new(1, -28, 0.5, -11)
    del.BackgroundColor3 = C.input
    del.Text = "✕"
    del.TextColor3 = C.textMuted
    del.Font = Enum.Font.GothamBold
    del.TextSize = 10
    del.AutoButtonColor = false
    del.Parent = frame
    applyCorner(del, 5)
    applyStroke(del, C.borderSoft, 1, 0.6)
    row.Del = del

    frame.MouseEnter:Connect(function()
        if row.anim and activeOutlineAnim ~= row.anim.name
            and not (dragState and dragState.animName == row.anim.name) then
            frame.BackgroundColor3 = C.surfaceHover
        end
    end)
    frame.MouseLeave:Connect(function()
        if row.anim and activeOutlineAnim ~= row.anim.name
            and not (dragState and dragState.animName == row.anim.name) then
            frame.BackgroundColor3 = C.surface
        end
    end)

    star.MouseButton1Click:Connect(function()
        local anim = row.anim
        if not anim then return end
        if savedConfig.favs[anim.name] then
            savedConfig.favs[anim.name] = nil
            removeFromFavOrder(anim.name)
        else
            savedConfig.favs[anim.name] = true
            addToFavOrder(anim.name)
        end
        saveConfig()
        local isFav = savedConfig.favs[anim.name]
        star.Text = isFav and "★" or "☆"
        star.TextColor3 = isFav and C.accent or C.textMuted
        if currentTab == "Favs" then
            markListDirty()
            populateList()
        end
    end)

    play.MouseButton1Click:Connect(function()
        local anim = row.anim
        if not anim then return end
        playSelectedAnimation(anim)
        populateList()
    end)

    key.MouseButton1Click:Connect(function()
        local anim = row.anim
        if not anim then return end
        if currentlyBinding and currentlyBinding.name == anim.name then
            currentlyBinding = nil
            local b = savedConfig.binds[anim.name]
            key.Text = b and ("["..b.."]") or "[+]"
            key.TextColor3 = b and C.accent or C.textMuted
            return
        end
        currentlyBinding = { name = anim.name, btn = key }
        key.Text = "[?]"
        key.TextColor3 = C.accentDim
    end)

    del.MouseButton1Click:Connect(function()
        local anim = row.anim
        if not anim then return end
        for i, a in ipairs(animations) do
            if a.name == anim.name then table.remove(animations, i); break end
        end
        for i, ca in ipairs(savedConfig.customAnims) do
            if ca.name == anim.name then table.remove(savedConfig.customAnims, i); break end
        end
        savedConfig.favs[anim.name] = nil
        savedConfig.binds[anim.name] = nil
        removeFromFavOrder(anim.name)
        saveConfig()
        markListDirty()
        populateList()
    end)

    grip.MouseButton1Down:Connect(function()
        if currentTab ~= "Favs" then return end
        local anim = row.anim
        if not anim then return end
        local idx = table.find(savedConfig.favOrder, anim.name)
        if not idx then return end
        dragState = { animName = anim.name, index = idx }
        frame.BackgroundColor3 = C.surfaceActive
        stroke.Color = C.accent
        stroke.Transparency = 0.15
    end)

    return row
end

local function acquireRow()
    local r = table.remove(rowPool)
    if r then
        r.Frame.Visible = true
        return r
    end
    return buildRow()
end

local function releaseRow(r)
    r.Frame.Visible = false
    r.anim = nil
    table.insert(rowPool, r)
end

markListDirty = function() listDirty = true end

local function computeDisplayList()
    local key = currentTab .. "|" .. searchBox.Text .. "|" .. tostring(#animations) .. "|" .. tostring(#savedConfig.favOrder)
    if not listDirty and displayCacheKey == key and displayCache then
        return displayCache
    end
    local term = searchBox.Text:lower()
    local out = {}
    for _, a in ipairs(animations) do
        local custom = isCustomAnim(a)
        if currentTab == "Favs" then
            if savedConfig.favs[a.name] and (term == "" or a.name:lower():find(term,1,true)) then
                table.insert(out, a)
            end
        elseif currentTab == "Custom" then
            if custom and (term == "" or a.name:lower():find(term,1,true)) then
                table.insert(out, a)
            end
        else
            if term == "" or a.name:lower():find(term,1,true) then
                table.insert(out, a)
            end
        end
    end

    if currentTab == "Favs" then
        local posMap = {}
        for idx, name in ipairs(savedConfig.favOrder) do
            posMap[name] = idx
        end
        table.sort(out, function(a, b)
            local pa = posMap[a.name] or math.huge
            local pb = posMap[b.name] or math.huge
            if pa ~= pb then return pa < pb end
            return a.name:lower() < b.name:lower()
        end)
    else
        table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    end

    displayCache = out
    displayCacheKey = key
    listDirty = false
    return out
end

function populateList()
    local displayList = computeDisplayList()
    local total = #displayList
    local isFavsTab = (currentTab == "Favs")

    for i = #activeRows, 1, -1 do
        releaseRow(activeRows[i])
        activeRows[i] = nil
    end

    if currentTab == "Favs" then
        emptyFavsLabel.Visible = (total == 0)
        emptyCustomLabel.Visible = false
    elseif currentTab == "Custom" then
        emptyFavsLabel.Visible = false
        emptyCustomLabel.Visible = (total == 0)
    else
        emptyFavsLabel.Visible = false
        emptyCustomLabel.Visible = false
    end

    for i, anim in ipairs(displayList) do
        local row = acquireRow()
        row.anim = anim
        row.Frame.LayoutOrder = i

        if isFavsTab then
            row.Grip.Visible = true
            row.Star.Position = UDim2.new(0, 22, 0, 0)
            row.Play.Position = UDim2.new(0, 50, 0, 0)
        else
            row.Grip.Visible = false
            row.Star.Position = UDim2.new(0, 5, 0, 0)
            row.Play.Position = UDim2.new(0, 36, 0, 0)
        end

        local isPlaying = (activeOutlineAnim == anim.name)
        local isDragged = dragState and dragState.animName == anim.name

        if isDragged then
            row.Frame.BackgroundColor3 = C.surfaceActive
            row.Stroke.Color = C.accent
            row.Stroke.Transparency = 0.15
        elseif isPlaying then
            row.Frame.BackgroundColor3 = C.surfaceActive
            row.Stroke.Color = C.accent
            row.Stroke.Transparency = 0.2
        else
            row.Frame.BackgroundColor3 = C.surface
            row.Stroke.Color = C.borderSoft
            row.Stroke.Transparency = 0.55
        end
        row.AccentBar.Visible = isPlaying

        local isFav = savedConfig.favs[anim.name]
        row.Star.Text = isFav and "★" or "☆"
        row.Star.TextColor3 = isFav and C.accent or C.textMuted

        local custom = isCustomAnim(anim)
        if custom then
            row.Play.Text = anim.name .. " <font color=\"rgb(150,154,164)\">[CUSTOM]</font>"
            row.Play.Size = UDim2.new(1, -108, 1, 0)
            row.Key.Position = UDim2.new(1, -72, 0.5, -11)
            row.Key.Visible = true
            row.Del.Visible = true
        else
            row.Play.Text = anim.name
            row.Play.Size = UDim2.new(1, -78, 1, 0)
            row.Key.Position = UDim2.new(1, -46, 0.5, -11)
            row.Key.Visible = true
            row.Del.Visible = false
        end
        row.Play.TextColor3 = isPlaying and C.accent or C.text
        row.Play.Font = isPlaying and Enum.Font.GothamBold or Enum.Font.GothamMedium

        local boundKey = savedConfig.binds[anim.name]
        row.Key.Text = boundKey and ("["..boundKey.."]") or "[+]"
        row.Key.TextColor3 = boundKey and C.accent or C.textMuted

        activeRows[i] = row
    end

    scrollList.CanvasSize = UDim2.new(0,0,0, total * (ROW_HEIGHT + 5) + 8)
end

UserInputService.InputChanged:Connect(function(input)
    if not dragState then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local pointerY = input.Position.Y
    local relY = pointerY - scrollList.AbsolutePosition.Y + scrollList.CanvasPosition.Y
    local total = #savedConfig.favOrder
    if total == 0 then return end

    local newIndex = math.clamp(math.floor(relY / (ROW_HEIGHT + 5)) + 1, 1, total)

    if newIndex ~= dragState.index then
        table.remove(savedConfig.favOrder, dragState.index)
        table.insert(savedConfig.favOrder, newIndex, dragState.animName)
        dragState.index = newIndex
        markListDirty()
        populateList()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not dragState then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragState = nil
    saveConfig()
    markListDirty()
    populateList()
end)

local searchToken = 0
local function queueSearch()
    searchToken = searchToken + 1
    local myToken = searchToken
    task.delay(0.08, function()
        if myToken == searchToken then
            markListDirty()
            populateList()
        end
    end)
end
searchBox:GetPropertyChangedSignal("Text"):Connect(queueSearch)

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
        row.Size = UDim2.new(1, -6, 0, 38)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i+1
        row.Parent = bindsPanel
        applyCorner(row, 8)
        applyStroke(row, C.borderSoft, 1, 0.6)

        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, -124, 1, 0)
        playBtn.Position = UDim2.new(0, 14, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.Text = item.name
        playBtn.TextColor3 = C.text
        playBtn.Font = Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.AutoButtonColor = false
        playBtn.Parent = row
        playBtn.MouseButton1Click:Connect(function()
            for _, a in ipairs(animations) do if a.name == item.name then playSelectedAnimation(a); break end end
        end)

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 48, 0, 24)
        keyBtn.Position = UDim2.new(1, -104, 0.5, -12)
        keyBtn.BackgroundColor3 = C.input
        keyBtn.Text = "["..item.key.."]"
        keyBtn.TextColor3 = C.accent
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 10
        keyBtn.AutoButtonColor = false
        keyBtn.Parent = row
        applyCorner(keyBtn, 5)
        applyStroke(keyBtn, C.borderSoft, 1, 0.6)
        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == item.name then
                currentlyBinding = nil
                keyBtn.Text = "["..item.key.."]"
                keyBtn.TextColor3 = C.accent
                return
            end
            currentlyBinding = { name = item.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = C.accentDim
        end)

        local unbindBtn = Instance.new("TextButton")
        unbindBtn.Size = UDim2.new(0, 46, 0, 24)
        unbindBtn.Position = UDim2.new(1, -52, 0.5, -12)
        unbindBtn.BackgroundColor3 = C.input
        unbindBtn.Text = "Unbind"
        unbindBtn.TextColor3 = C.textMuted
        unbindBtn.Font = Enum.Font.GothamSemibold
        unbindBtn.TextSize = 9
        unbindBtn.AutoButtonColor = false
        unbindBtn.Parent = row
        applyCorner(unbindBtn, 5)
        unbindBtn.MouseButton1Click:Connect(function()
            savedConfig.binds[item.name] = nil
            saveConfig()
            markListDirty()
            populateBindsList()
        end)
    end
    bindsPanel.CanvasSize = UDim2.new(0,0,0, 26 + #boundItems * 44)
end

-- ═══════════════════════════════════════════════════
-- TAB SWITCHING
-- ═══════════════════════════════════════════════════
switchTab = function(tab)
    if dragState then
        dragState = nil
        saveConfig()
    end
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
    BodyArm.panel.Visible = (tab == "Body")

    if isAnimList then
        if tab == "Favs" then
            searchBox.PlaceholderText = "Search favorites..."
            addCustomBtn.Visible = false
            searchBox.Size = UDim2.new(1, 0, 0, 32)
        elseif tab == "Custom" then
            searchBox.PlaceholderText = "Search custom animations..."
            addCustomBtn.Visible = true
            searchBox.Size = UDim2.new(1, -100, 0, 32)
        else
            searchBox.PlaceholderText = "Search animations..."
            addCustomBtn.Visible = true
            searchBox.Size = UDim2.new(1, -100, 0, 32)
        end
        markListDirty()
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

    if BodyArm.FaceAttach and BodyArm.FaceAttach.capturing then
        BodyArm.FaceAttach.bind = input.KeyCode
        BodyArm.FaceAttach.capturing = false
        BodyArm.refreshFaceAttachUI()
        return
    end

    if BodyArm.ArmStretch.capturing then
        BodyArm.ArmStretch.bind = input.KeyCode
        BodyArm.ArmStretch.capturing = false
        BodyArm.refreshArmStretchUI()
        return
    end

    if BodyArm.TorsoAim and BodyArm.TorsoAim.capturing then
        if BodyArm.TorsoAim.capturing == "stretch" then
            BodyArm.TorsoAim.stretchBind = input.KeyCode
        elseif BodyArm.TorsoAim.capturing == "follow" then
            BodyArm.TorsoAim.followBind = input.KeyCode
        elseif BodyArm.TorsoAim.capturing == "faceattach" then
            BodyArm.TorsoAim.faceAttachBind = input.KeyCode
        end
        BodyArm.TorsoAim.capturing = nil
        BodyArm.refreshTorsoAimUI()
        return
    end

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

    if BodyArm.FaceAttach and input.KeyCode == BodyArm.FaceAttach.bind then
        BodyArm.toggleFaceAttachAtCursor()
        return
    end

    if BodyArm.TorsoAim then
        if input.KeyCode == BodyArm.TorsoAim.stretchBind then
            if BodyArm.TorsoAim.active and BodyArm.TorsoAim.mode == "Stretch" then
                BodyArm.stopTorsoAim()
            else
                local ok = BodyArm.startTorsoAim("Stretch")
                if not ok then warn("Torso aim: enable Reanim first") end
            end
            BodyArm.refreshTorsoAimUI()
            return
        elseif input.KeyCode == BodyArm.TorsoAim.followBind then
            if BodyArm.TorsoAim.active and BodyArm.TorsoAim.mode == "Follow" then
                BodyArm.stopTorsoAim()
            else
                local ok = BodyArm.startTorsoAim("Follow")
                if not ok then warn("Torso aim: enable Reanim first") end
            end
            BodyArm.refreshTorsoAimUI()
            return
        elseif input.KeyCode == BodyArm.TorsoAim.faceAttachBind then
            -- Torso Face Attach toggle
            if BodyArm.TorsoAim.active and BodyArm.TorsoAim.mode == "Attach" then
                BodyArm.stopTorsoAim()
            else
                local t = BodyArm.getCursorTargetPlayerT and BodyArm.getCursorTargetPlayerT()
                if not t then
                    warn("Torso face attach: put cursor over a player")
                else
                    local ok, msg = BodyArm.startTorsoFaceAttach(t)
                    if not ok then warn("Torso face attach: "..tostring(msg)) end
                end
            end
            BodyArm.refreshTorsoAimUI()
            return
        end
    end

    if input.KeyCode == BodyArm.ArmStretch.bind then
        if BodyArm.ArmStretch.mode == "Toggle" then
            if BodyArm.ArmStretch.active then
                BodyArm.stopArmStretch()
                BodyArm.refreshArmStretchUI()
            else
                local ok = BodyArm.startArmStretch()
                BodyArm.refreshArmStretchUI()
                if not ok then warn("Arm stretch: enable Reanim first") end
            end
        else
            if not BodyArm.ArmStretch.active then
                local ok = BodyArm.startArmStretch()
                BodyArm.refreshArmStretchUI()
                if not ok then warn("Arm stretch: enable Reanim first") end
            end
        end
        return
    end

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
                    populateList()
                    return
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if BodyArm.ArmStretch.mode == "Hold" and input.KeyCode == BodyArm.ArmStretch.bind then
        if BodyArm.ArmStretch.active then
            BodyArm.stopArmStretch()
            BodyArm.refreshArmStretchUI()
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
    toggleStroke.Color = isReanimated and C.accent or C.border
    toggleStroke.Transparency = isReanimated and 0.4 or 0.6
end

toggleBtn.MouseButton1Click:Connect(function()
    local newState = not api.is_reanimated()
    toggleBtn.Text = newState and "Reanimating..." or "Disabling..."
    toggleBtn.TextColor3 = C.textMuted
    BodyArm.stopArmStretch()
    BodyArm.refreshArmStretchUI()
    if BodyArm.stopFaceAttach then BodyArm.stopFaceAttach() end
    if BodyArm.stopTorsoAim then BodyArm.stopTorsoAim(); BodyArm.refreshTorsoAimUI() end
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
        task.wait(0.15)
        applyHeightToVisible()
    end)
end)

-- Initialize
updateReanimButtonState()
applySpeed(currentSpeed)

if player.Character then
    task.wait(0.1)
end
applyHeightToVisible()

markListDirty()
populateList()
