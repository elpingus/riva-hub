--[[
    RIVA HUB - RIVALS SCRIPT
    Full ESP, Aimbot, Visuals
    Developer: elpingus
]]

-- Anti-Detection: Wait for game load
repeat task.wait() until game:IsLoaded()

-- Anti-Detection: Clone references
local cloneref = cloneref or function(o) return o end

-- Services
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local TweenService = cloneref(game:GetService("TweenService"))
local HttpService = cloneref(game:GetService("HttpService"))
local Stats = cloneref(game:GetService("Stats"))

-- Local Variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Anti-Detection: Random name generator
local function RandomName(length)
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, length do
        local idx = math.random(1, #chars)
        result = result .. chars:sub(idx, idx)
    end
    return result
end

-- Executor Detection
local ExecutorName = "Unknown"
pcall(function()
    ExecutorName = getexecutorname and getexecutorname() or identifyexecutor and identifyexecutor() or "Unknown"
end)

local LowPerformanceMode = false
for _, exec in ipairs({"Xeno", "Solara", "JJSploit"}) do
    if string.find(ExecutorName:lower(), exec:lower()) then
        LowPerformanceMode = true
        break
    end
end

-- Load Library from GitHub
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/elpingus/riva-hub/refs/heads/main/library.lua"))()

-- Settings
local Settings = {
    -- Combat
    Aimbot = {
        Enabled = false,
        TargetPart = "Head",
        FOV = 150,
        Smoothness = 0.15,
        TeamCheck = true,
        WallCheck = true,
        ShowFOV = false,
        FOVColor = Color3.fromRGB(255, 255, 255),
    },
    SilentAim = {
        Enabled = false,
        FOV = 100,
        TargetPart = "Head",
        TeamCheck = true,
        WallCheck = false,
        HitChance = 100,
        ShowFOV = false,
        FOVColor = Color3.fromRGB(255, 0, 0),
    },
    Triggerbot = {
        Enabled = false,
        Delay = 0.05,
        TeamCheck = true,
    },
    NoRecoil = {
        Enabled = false,
    },
    RageBot = {
        Enabled = false,
        TargetPart = "Head",
        AutoFire = true,
        TeamCheck = true,
        -- WARNING: High detection risk!
    },
    
    -- Visuals
    ESP = {
        Enabled = false,
        Boxes = false,
        BoxType = "Corner", -- Corner, Full, 3D
        Names = false,
        HealthBar = false,
        Distance = false,
        Tracers = false,
        TracerOrigin = "Bottom", -- Top, Center, Bottom
        Skeleton = false,
        HeadDot = false,
        TeamCheck = true,
        TeamColor = false,
        MaxDistance = 1000,
        -- Colors
        BoxColor = Color3.fromRGB(255, 255, 255),
        NameColor = Color3.fromRGB(255, 255, 255),
        HealthColor = Color3.fromRGB(0, 255, 0),
        TracerColor = Color3.fromRGB(255, 255, 255),
        SkeletonColor = Color3.fromRGB(255, 255, 255),
    },
    Chams = {
        Enabled = false,
        FillColor = Color3.fromRGB(255, 0, 100),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0,
        TeamCheck = true,
    },
    Crosshair = {
        Enabled = false,
        Size = 10,
        Thickness = 1,
        Gap = 5,
        Color = Color3.fromRGB(0, 255, 0),
    },
    
    -- Misc
    Movement = {
        Flight = false,
        FlySpeed = 50,
        Noclip = false,
        SpeedHack = false,
        WalkSpeed = 50,
        JumpPower = 50,
        InfiniteJump = false,
    },
}

-- ESP Storage
local ESPObjects = {}
local ChamsObjects = {}
local Connections = {}

-- Drawing Objects Storage
local Drawings = {
    FOVCircle = nil,
    SilentAimFOVCircle = nil,
    Crosshair = {},
}

-- ═══════════════════════════════════════════════════════════════════
-- SILENT AIM HOOKS
-- ═══════════════════════════════════════════════════════════════════

-- Hook variables
local SilentAimTarget = nil -- Set in RenderStepped loop
local OldIndex = nil
local OldNewIndex = nil
local OldNamecall = nil

-- Check if Hit Chance passes
local function PassesHitChance()
    return math.random(1, 100) <= Settings.SilentAim.HitChance
end

-- Hook Mouse metatable (__index for Mouse.Hit and Mouse.Target)
local MouseMT = getrawmetatable(Mouse)
if MouseMT and setreadonly then
    setreadonly(MouseMT, false)
    
    OldIndex = MouseMT.__index
    MouseMT.__index = newcclosure(function(self, key)
        if self == Mouse and SilentAimTarget and Settings.SilentAim.Enabled then
            if key == "Hit" then
                if PassesHitChance() then
                    return CFrame.new(SilentAimTarget.Position)
                end
            elseif key == "Target" then
                if PassesHitChance() then
                    return SilentAimTarget
                end
            elseif key == "X" or key == "Y" then
                if PassesHitChance() then
                    local screenPos = WorldToScreen(SilentAimTarget.Position)
                    if key == "X" then
                        return screenPos.X
                    else
                        return screenPos.Y
                    end
                end
            elseif key == "UnitRay" then
                if PassesHitChance() then
                    local origin = Camera.CFrame.Position
                    local direction = (SilentAimTarget.Position - origin).Unit
                    return Ray.new(origin, direction)
                end
            end
        end
        return OldIndex(self, key)
    end)
    
    setreadonly(MouseMT, true)
end

-- Hook namecall for Raycast/FindPartOnRay
if hookfunction and getnamecallmethod then
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if SilentAimTarget and Settings.SilentAim.Enabled and PassesHitChance() then
            -- Hook Workspace:Raycast
            if method == "Raycast" and self == Workspace then
                local origin = args[1]
                if typeof(origin) == "Vector3" then
                    local newDirection = (SilentAimTarget.Position - origin)
                    args[2] = newDirection
                    return OldNamecall(self, args[1], args[2], args[3])
                end
            end
            
            -- Hook FindPartOnRay (legacy)
            if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                local ray = args[1]
                if typeof(ray) == "Ray" then
                    local origin = ray.Origin
                    local newDirection = (SilentAimTarget.Position - origin)
                    args[1] = Ray.new(origin, newDirection)
                    return OldNamecall(self, unpack(args))
                end
            end
        end
        
        return OldNamecall(self, ...)
    end))
end

-- Utility Functions
local function IsAlive(player)
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local function IsTeammate(player)
    if not Settings.ESP.TeamCheck then return false end
    if not player.Team or not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function GetDistance(position)
    return (Camera.CFrame.Position - position).Magnitude
end

local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function IsVisible(part)
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, part.Parent}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, direction, params)
    return result == nil
end

local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = Settings.Aimbot.FOV
    -- Use mouse position instead of screen center (matches FOV circle)
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if Settings.Aimbot.TeamCheck and IsTeammate(player) then continue end
            
            local character = player.Character
            local targetPart = character:FindFirstChild(Settings.Aimbot.TargetPart) or character:FindFirstChild("Head")
            if not targetPart then continue end
            
            local screenPos, onScreen = WorldToScreen(targetPart.Position)
            if not onScreen then continue end
            
            local distance = (screenPos - mousePos).Magnitude
            if distance < shortestDistance then
                if Settings.Aimbot.WallCheck and not IsVisible(targetPart) then continue end
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer
end

-- ESP Class
local ESPClass = {}
ESPClass.__index = ESPClass

function ESPClass.new(player)
    local self = setmetatable({}, ESPClass)
    self.Player = player
    self.Drawings = {}
    
    -- Create all drawing objects
    -- Box (4 corners for corner box)
    self.Drawings.BoxTopLeft = Drawing.new("Line")
    self.Drawings.BoxTopRight = Drawing.new("Line")
    self.Drawings.BoxBottomLeft = Drawing.new("Line")
    self.Drawings.BoxBottomRight = Drawing.new("Line")
    self.Drawings.BoxTopLeftV = Drawing.new("Line")
    self.Drawings.BoxTopRightV = Drawing.new("Line")
    self.Drawings.BoxBottomLeftV = Drawing.new("Line")
    self.Drawings.BoxBottomRightV = Drawing.new("Line")
    
    -- Full Box Lines
    self.Drawings.BoxTop = Drawing.new("Line")
    self.Drawings.BoxBottom = Drawing.new("Line")
    self.Drawings.BoxLeft = Drawing.new("Line")
    self.Drawings.BoxRight = Drawing.new("Line")
    
    -- Name
    self.Drawings.Name = Drawing.new("Text")
    self.Drawings.Name.Center = true
    self.Drawings.Name.Outline = true
    self.Drawings.Name.Size = 13
    
    -- Distance
    self.Drawings.Distance = Drawing.new("Text")
    self.Drawings.Distance.Center = true
    self.Drawings.Distance.Outline = true
    self.Drawings.Distance.Size = 12
    
    -- Health Bar
    self.Drawings.HealthBarBackground = Drawing.new("Line")
    self.Drawings.HealthBar = Drawing.new("Line")
    self.Drawings.HealthText = Drawing.new("Text")
    self.Drawings.HealthText.Center = true
    self.Drawings.HealthText.Outline = true
    self.Drawings.HealthText.Size = 10
    
    -- Tracer
    self.Drawings.Tracer = Drawing.new("Line")
    
    -- Head Dot
    self.Drawings.HeadDot = Drawing.new("Circle")
    self.Drawings.HeadDot.Filled = true
    
    -- Skeleton Lines
    self.Drawings.SkeletonLines = {}
    for i = 1, 12 do
        self.Drawings.SkeletonLines[i] = Drawing.new("Line")
    end
    
    return self
end

function ESPClass:Update()
    local character = self.Player.Character
    if not character or not IsAlive(self.Player) then
        self:Hide()
        return
    end
    
    if Settings.ESP.TeamCheck and IsTeammate(self.Player) then
        self:Hide()
        return
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not head or not humanoid then
        self:Hide()
        return
    end
    
    local distance = GetDistance(hrp.Position)
    if distance > Settings.ESP.MaxDistance then
        self:Hide()
        return
    end
    
    local screenPos, onScreen = WorldToScreen(hrp.Position)
    if not onScreen then
        self:Hide()
        return
    end
    
    -- Calculate box size based on distance
    local scaleFactor = 1 / (distance * 0.03)
    local boxHeight = math.clamp(scaleFactor * 150, 20, 500)
    local boxWidth = boxHeight * 0.6
    
    local headPos = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
    local footPos = WorldToScreen(hrp.Position - Vector3.new(0, 3, 0))
    
    boxHeight = math.abs(footPos.Y - headPos.Y)
    boxWidth = boxHeight * 0.5
    
    local boxX = screenPos.X - boxWidth / 2
    local boxY = headPos.Y
    
    local cornerLength = boxWidth * 0.25
    
    -- Colors
    local boxColor = Settings.ESP.TeamColor and self.Player.TeamColor.Color or Settings.ESP.BoxColor
    
    -- Update Corner Box
    if Settings.ESP.Boxes and Settings.ESP.BoxType == "Corner" then
        -- Top Left
        self.Drawings.BoxTopLeft.From = Vector2.new(boxX, boxY)
        self.Drawings.BoxTopLeft.To = Vector2.new(boxX + cornerLength, boxY)
        self.Drawings.BoxTopLeft.Color = boxColor
        self.Drawings.BoxTopLeft.Thickness = 1
        self.Drawings.BoxTopLeft.Visible = true
        
        self.Drawings.BoxTopLeftV.From = Vector2.new(boxX, boxY)
        self.Drawings.BoxTopLeftV.To = Vector2.new(boxX, boxY + cornerLength)
        self.Drawings.BoxTopLeftV.Color = boxColor
        self.Drawings.BoxTopLeftV.Thickness = 1
        self.Drawings.BoxTopLeftV.Visible = true
        
        -- Top Right
        self.Drawings.BoxTopRight.From = Vector2.new(boxX + boxWidth, boxY)
        self.Drawings.BoxTopRight.To = Vector2.new(boxX + boxWidth - cornerLength, boxY)
        self.Drawings.BoxTopRight.Color = boxColor
        self.Drawings.BoxTopRight.Thickness = 1
        self.Drawings.BoxTopRight.Visible = true
        
        self.Drawings.BoxTopRightV.From = Vector2.new(boxX + boxWidth, boxY)
        self.Drawings.BoxTopRightV.To = Vector2.new(boxX + boxWidth, boxY + cornerLength)
        self.Drawings.BoxTopRightV.Color = boxColor
        self.Drawings.BoxTopRightV.Thickness = 1
        self.Drawings.BoxTopRightV.Visible = true
        
        -- Bottom Left
        self.Drawings.BoxBottomLeft.From = Vector2.new(boxX, boxY + boxHeight)
        self.Drawings.BoxBottomLeft.To = Vector2.new(boxX + cornerLength, boxY + boxHeight)
        self.Drawings.BoxBottomLeft.Color = boxColor
        self.Drawings.BoxBottomLeft.Thickness = 1
        self.Drawings.BoxBottomLeft.Visible = true
        
        self.Drawings.BoxBottomLeftV.From = Vector2.new(boxX, boxY + boxHeight)
        self.Drawings.BoxBottomLeftV.To = Vector2.new(boxX, boxY + boxHeight - cornerLength)
        self.Drawings.BoxBottomLeftV.Color = boxColor
        self.Drawings.BoxBottomLeftV.Thickness = 1
        self.Drawings.BoxBottomLeftV.Visible = true
        
        -- Bottom Right
        self.Drawings.BoxBottomRight.From = Vector2.new(boxX + boxWidth, boxY + boxHeight)
        self.Drawings.BoxBottomRight.To = Vector2.new(boxX + boxWidth - cornerLength, boxY + boxHeight)
        self.Drawings.BoxBottomRight.Color = boxColor
        self.Drawings.BoxBottomRight.Thickness = 1
        self.Drawings.BoxBottomRight.Visible = true
        
        self.Drawings.BoxBottomRightV.From = Vector2.new(boxX + boxWidth, boxY + boxHeight)
        self.Drawings.BoxBottomRightV.To = Vector2.new(boxX + boxWidth, boxY + boxHeight - cornerLength)
        self.Drawings.BoxBottomRightV.Color = boxColor
        self.Drawings.BoxBottomRightV.Thickness = 1
        self.Drawings.BoxBottomRightV.Visible = true
        
        -- Hide full box
        self.Drawings.BoxTop.Visible = false
        self.Drawings.BoxBottom.Visible = false
        self.Drawings.BoxLeft.Visible = false
        self.Drawings.BoxRight.Visible = false
        
    elseif Settings.ESP.Boxes and Settings.ESP.BoxType == "Full" then
        -- Full Box
        self.Drawings.BoxTop.From = Vector2.new(boxX, boxY)
        self.Drawings.BoxTop.To = Vector2.new(boxX + boxWidth, boxY)
        self.Drawings.BoxTop.Color = boxColor
        self.Drawings.BoxTop.Thickness = 1
        self.Drawings.BoxTop.Visible = true
        
        self.Drawings.BoxBottom.From = Vector2.new(boxX, boxY + boxHeight)
        self.Drawings.BoxBottom.To = Vector2.new(boxX + boxWidth, boxY + boxHeight)
        self.Drawings.BoxBottom.Color = boxColor
        self.Drawings.BoxBottom.Thickness = 1
        self.Drawings.BoxBottom.Visible = true
        
        self.Drawings.BoxLeft.From = Vector2.new(boxX, boxY)
        self.Drawings.BoxLeft.To = Vector2.new(boxX, boxY + boxHeight)
        self.Drawings.BoxLeft.Color = boxColor
        self.Drawings.BoxLeft.Thickness = 1
        self.Drawings.BoxLeft.Visible = true
        
        self.Drawings.BoxRight.From = Vector2.new(boxX + boxWidth, boxY)
        self.Drawings.BoxRight.To = Vector2.new(boxX + boxWidth, boxY + boxHeight)
        self.Drawings.BoxRight.Color = boxColor
        self.Drawings.BoxRight.Thickness = 1
        self.Drawings.BoxRight.Visible = true
        
        -- Hide corners
        self.Drawings.BoxTopLeft.Visible = false
        self.Drawings.BoxTopRight.Visible = false
        self.Drawings.BoxBottomLeft.Visible = false
        self.Drawings.BoxBottomRight.Visible = false
        self.Drawings.BoxTopLeftV.Visible = false
        self.Drawings.BoxTopRightV.Visible = false
        self.Drawings.BoxBottomLeftV.Visible = false
        self.Drawings.BoxBottomRightV.Visible = false
    else
        -- Hide all box elements
        for name, drawing in pairs(self.Drawings) do
            if string.find(name, "Box") then
                drawing.Visible = false
            end
        end
    end
    
    -- Name ESP
    if Settings.ESP.Names then
        self.Drawings.Name.Text = self.Player.Name
        self.Drawings.Name.Position = Vector2.new(boxX + boxWidth / 2, boxY - 15)
        self.Drawings.Name.Color = Settings.ESP.NameColor
        self.Drawings.Name.Visible = true
    else
        self.Drawings.Name.Visible = false
    end
    
    -- Distance ESP
    if Settings.ESP.Distance then
        self.Drawings.Distance.Text = string.format("[%dm]", math.floor(distance))
        self.Drawings.Distance.Position = Vector2.new(boxX + boxWidth / 2, boxY + boxHeight + 2)
        self.Drawings.Distance.Color = Color3.fromRGB(200, 200, 200)
        self.Drawings.Distance.Visible = true
    else
        self.Drawings.Distance.Visible = false
    end
    
    -- Health Bar
    if Settings.ESP.HealthBar then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = health / maxHealth
        
        local barX = boxX - 5
        local barHeight = boxHeight * healthPercent
        local barY = boxY + boxHeight
        
        -- Background
        self.Drawings.HealthBarBackground.From = Vector2.new(barX, boxY)
        self.Drawings.HealthBarBackground.To = Vector2.new(barX, boxY + boxHeight)
        self.Drawings.HealthBarBackground.Color = Color3.fromRGB(0, 0, 0)
        self.Drawings.HealthBarBackground.Thickness = 3
        self.Drawings.HealthBarBackground.Visible = true
        
        -- Health
        local healthColor = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
        self.Drawings.HealthBar.From = Vector2.new(barX, barY)
        self.Drawings.HealthBar.To = Vector2.new(barX, barY - barHeight)
        self.Drawings.HealthBar.Color = healthColor
        self.Drawings.HealthBar.Thickness = 1
        self.Drawings.HealthBar.Visible = true
        
        -- Health Text
        if healthPercent < 1 then
            self.Drawings.HealthText.Text = tostring(math.floor(health))
            self.Drawings.HealthText.Position = Vector2.new(barX, barY - barHeight - 5)
            self.Drawings.HealthText.Color = healthColor
            self.Drawings.HealthText.Visible = true
        else
            self.Drawings.HealthText.Visible = false
        end
    else
        self.Drawings.HealthBarBackground.Visible = false
        self.Drawings.HealthBar.Visible = false
        self.Drawings.HealthText.Visible = false
    end
    
    -- Tracers
    if Settings.ESP.Tracers then
        local origin
        if Settings.ESP.TracerOrigin == "Top" then
            origin = Vector2.new(Camera.ViewportSize.X / 2, 0)
        elseif Settings.ESP.TracerOrigin == "Center" then
            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        else
            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        end
        
        self.Drawings.Tracer.From = origin
        self.Drawings.Tracer.To = Vector2.new(boxX + boxWidth / 2, boxY + boxHeight)
        self.Drawings.Tracer.Color = Settings.ESP.TracerColor
        self.Drawings.Tracer.Thickness = 1
        self.Drawings.Tracer.Visible = true
    else
        self.Drawings.Tracer.Visible = false
    end
    
    -- Head Dot
    if Settings.ESP.HeadDot then
        local headScreen = WorldToScreen(head.Position)
        self.Drawings.HeadDot.Position = headScreen
        self.Drawings.HeadDot.Radius = 3
        self.Drawings.HeadDot.Color = boxColor
        self.Drawings.HeadDot.Visible = true
    else
        self.Drawings.HeadDot.Visible = false
    end
    
    -- Skeleton ESP
    if Settings.ESP.Skeleton then
        local parts = {
            Head = character:FindFirstChild("Head"),
            UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
            LowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso"),
            LeftUpperArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm"),
            LeftLowerArm = character:FindFirstChild("LeftLowerArm"),
            LeftHand = character:FindFirstChild("LeftHand"),
            RightUpperArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm"),
            RightLowerArm = character:FindFirstChild("RightLowerArm"),
            RightHand = character:FindFirstChild("RightHand"),
            LeftUpperLeg = character:FindFirstChild("LeftUpperLeg") or character:FindFirstChild("Left Leg"),
            LeftLowerLeg = character:FindFirstChild("LeftLowerLeg"),
            LeftFoot = character:FindFirstChild("LeftFoot"),
            RightUpperLeg = character:FindFirstChild("RightUpperLeg") or character:FindFirstChild("Right Leg"),
            RightLowerLeg = character:FindFirstChild("RightLowerLeg"),
            RightFoot = character:FindFirstChild("RightFoot"),
        }
        
        local connections = {
            {parts.Head, parts.UpperTorso},
            {parts.UpperTorso, parts.LowerTorso},
            {parts.UpperTorso, parts.LeftUpperArm},
            {parts.LeftUpperArm, parts.LeftLowerArm or parts.LeftUpperArm},
            {parts.UpperTorso, parts.RightUpperArm},
            {parts.RightUpperArm, parts.RightLowerArm or parts.RightUpperArm},
            {parts.LowerTorso, parts.LeftUpperLeg},
            {parts.LeftUpperLeg, parts.LeftLowerLeg or parts.LeftUpperLeg},
            {parts.LowerTorso, parts.RightUpperLeg},
            {parts.RightUpperLeg, parts.RightLowerLeg or parts.RightUpperLeg},
        }
        
        for i, conn in ipairs(connections) do
            local line = self.Drawings.SkeletonLines[i]
            if conn[1] and conn[2] then
                local pos1 = WorldToScreen(conn[1].Position)
                local pos2 = WorldToScreen(conn[2].Position)
                line.From = pos1
                line.To = pos2
                line.Color = Settings.ESP.SkeletonColor
                line.Thickness = 1
                line.Visible = true
            else
                line.Visible = false
            end
        end
    else
        for _, line in ipairs(self.Drawings.SkeletonLines) do
            line.Visible = false
        end
    end
end

function ESPClass:Hide()
    for _, drawing in pairs(self.Drawings) do
        if type(drawing) == "table" then
            for _, d in pairs(drawing) do
                d.Visible = false
            end
        else
            drawing.Visible = false
        end
    end
end

function ESPClass:Destroy()
    for _, drawing in pairs(self.Drawings) do
        if type(drawing) == "table" then
            for _, d in pairs(drawing) do
                d:Remove()
            end
        else
            drawing:Remove()
        end
    end
end

-- Chams Functions
local function CreateChams(player)
    if ChamsObjects[player] then return end
    
    local character = player.Character
    if not character then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = RandomName(8)
    highlight.Adornee = character
    highlight.FillColor = Settings.Chams.FillColor
    highlight.OutlineColor = Settings.Chams.OutlineColor
    highlight.FillTransparency = Settings.Chams.FillTransparency
    highlight.OutlineTransparency = Settings.Chams.OutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = CoreGui
    
    ChamsObjects[player] = highlight
end

local function UpdateChams(player)
    local highlight = ChamsObjects[player]
    if not highlight then return end
    
    local character = player.Character
    if not character or not IsAlive(player) then
        highlight.Enabled = false
        return
    end
    
    if Settings.Chams.TeamCheck and IsTeammate(player) then
        highlight.Enabled = false
        return
    end
    
    highlight.Enabled = Settings.Chams.Enabled
    highlight.FillColor = Settings.Chams.FillColor
    highlight.OutlineColor = Settings.Chams.OutlineColor
    highlight.FillTransparency = Settings.Chams.FillTransparency
    highlight.OutlineTransparency = Settings.Chams.OutlineTransparency
    highlight.Adornee = character
end

local function RemoveChams(player)
    if ChamsObjects[player] then
        ChamsObjects[player]:Destroy()
        ChamsObjects[player] = nil
    end
end

-- FOV Circle
local function CreateFOVCircle()
    Drawings.FOVCircle = Drawing.new("Circle")
    Drawings.FOVCircle.Thickness = 1
    Drawings.FOVCircle.NumSides = 64
    Drawings.FOVCircle.Radius = Settings.Aimbot.FOV
    Drawings.FOVCircle.Filled = false
    Drawings.FOVCircle.Visible = false
    Drawings.FOVCircle.Color = Settings.Aimbot.FOVColor
end

local function UpdateFOVCircle()
    if Drawings.FOVCircle then
        -- Follow mouse cursor instead of screen center
        local mousePos = UserInputService:GetMouseLocation()
        Drawings.FOVCircle.Position = Vector2.new(mousePos.X, mousePos.Y)
        Drawings.FOVCircle.Radius = Settings.Aimbot.FOV
        Drawings.FOVCircle.Color = Settings.Aimbot.FOVColor
        Drawings.FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    end
end

-- Silent Aim FOV Circle
local function CreateSilentAimFOVCircle()
    Drawings.SilentAimFOVCircle = Drawing.new("Circle")
    Drawings.SilentAimFOVCircle.Thickness = 1
    Drawings.SilentAimFOVCircle.NumSides = 64
    Drawings.SilentAimFOVCircle.Radius = Settings.SilentAim.FOV
    Drawings.SilentAimFOVCircle.Filled = false
    Drawings.SilentAimFOVCircle.Visible = false
    Drawings.SilentAimFOVCircle.Color = Settings.SilentAim.FOVColor
end

local function UpdateSilentAimFOVCircle()
    if Drawings.SilentAimFOVCircle then
        local mousePos = UserInputService:GetMouseLocation()
        Drawings.SilentAimFOVCircle.Position = Vector2.new(mousePos.X, mousePos.Y)
        Drawings.SilentAimFOVCircle.Radius = Settings.SilentAim.FOV
        Drawings.SilentAimFOVCircle.Color = Settings.SilentAim.FOVColor
        Drawings.SilentAimFOVCircle.Visible = Settings.SilentAim.ShowFOV and Settings.SilentAim.Enabled
    end
end

-- Get closest player for Silent Aim (screen center based)
local function GetClosestPlayerForSilentAim()
    local closestPlayer = nil
    local closestPart = nil
    local shortestDistance = Settings.SilentAim.FOV
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            if Settings.SilentAim.TeamCheck and IsTeammate(player) then continue end
            
            local character = player.Character
            local targetPart = character:FindFirstChild(Settings.SilentAim.TargetPart) or character:FindFirstChild("Head")
            if not targetPart then continue end
            
            local screenPos, onScreen = WorldToScreen(targetPart.Position)
            if not onScreen then continue end
            
            local distance = (screenPos - screenCenter).Magnitude
            if distance < shortestDistance then
                if Settings.SilentAim.WallCheck and not IsVisible(targetPart) then continue end
                shortestDistance = distance
                closestPlayer = player
                closestPart = targetPart
            end
        end
    end
    
    return closestPlayer, closestPart
end

-- Crosshair
local function CreateCrosshair()
    Drawings.Crosshair.Top = Drawing.new("Line")
    Drawings.Crosshair.Bottom = Drawing.new("Line")
    Drawings.Crosshair.Left = Drawing.new("Line")
    Drawings.Crosshair.Right = Drawing.new("Line")
end

local function UpdateCrosshair()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local size = Settings.Crosshair.Size
    local gap = Settings.Crosshair.Gap
    
    Drawings.Crosshair.Top.From = Vector2.new(center.X, center.Y - gap)
    Drawings.Crosshair.Top.To = Vector2.new(center.X, center.Y - gap - size)
    Drawings.Crosshair.Top.Color = Settings.Crosshair.Color
    Drawings.Crosshair.Top.Thickness = Settings.Crosshair.Thickness
    Drawings.Crosshair.Top.Visible = Settings.Crosshair.Enabled
    
    Drawings.Crosshair.Bottom.From = Vector2.new(center.X, center.Y + gap)
    Drawings.Crosshair.Bottom.To = Vector2.new(center.X, center.Y + gap + size)
    Drawings.Crosshair.Bottom.Color = Settings.Crosshair.Color
    Drawings.Crosshair.Bottom.Thickness = Settings.Crosshair.Thickness
    Drawings.Crosshair.Bottom.Visible = Settings.Crosshair.Enabled
    
    Drawings.Crosshair.Left.From = Vector2.new(center.X - gap, center.Y)
    Drawings.Crosshair.Left.To = Vector2.new(center.X - gap - size, center.Y)
    Drawings.Crosshair.Left.Color = Settings.Crosshair.Color
    Drawings.Crosshair.Left.Thickness = Settings.Crosshair.Thickness
    Drawings.Crosshair.Left.Visible = Settings.Crosshair.Enabled
    
    Drawings.Crosshair.Right.From = Vector2.new(center.X + gap, center.Y)
    Drawings.Crosshair.Right.To = Vector2.new(center.X + gap + size, center.Y)
    Drawings.Crosshair.Right.Color = Settings.Crosshair.Color
    Drawings.Crosshair.Right.Thickness = Settings.Crosshair.Thickness
    Drawings.Crosshair.Right.Visible = Settings.Crosshair.Enabled
end

-- Initialize
CreateFOVCircle()
CreateSilentAimFOVCircle()
CreateCrosshair()

-- Player Added/Removed
local function OnPlayerAdded(player)
    if player == LocalPlayer then return end
    
    ESPObjects[player] = ESPClass.new(player)
    CreateChams(player)
    
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        CreateChams(player)
    end)
end

local function OnPlayerRemoving(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
    RemoveChams(player)
end

for _, player in ipairs(Players:GetPlayers()) do
    OnPlayerAdded(player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Main Loop
-- Library keybind system: Library.Flags[Flag] = {Mode, Key, Toggled}
-- Toggle must be ON + Keybind must be active (based on mode)

-- Helper function to check if keybind is active
local function IsKeybindActive(flag)
    local keybindData = Library.Flags[flag]
    if keybindData and type(keybindData) == "table" then
        -- If mode is "Always", return true immediately (no key press needed)
        if keybindData.Mode == "Always" then
            return true
        end
        -- For Toggle and Hold modes, use the Toggled state
        return keybindData.Toggled
    end
    return false
end

RunService.RenderStepped:Connect(function()
    -- Update FOV Circles
    UpdateFOVCircle()
    UpdateSilentAimFOVCircle()
    
    -- Update Crosshair
    UpdateCrosshair()
    
    -- Update ESP
    if Settings.ESP.Enabled then
        for player, esp in pairs(ESPObjects) do
            esp:Update()
        end
    else
        for player, esp in pairs(ESPObjects) do
            esp:Hide()
        end
    end
    
    -- Update Chams
    for player, _ in pairs(ChamsObjects) do
        UpdateChams(player)
    end
    
    -- ═══════════════════════════════════════════════════════════════════
    -- AIMBOT SYSTEM (Camera Lock - Only when firing)
    -- ═══════════════════════════════════════════════════════════════════
    local aimbotActive = Settings.Aimbot.Enabled and IsKeybindActive("AimbotKeybind")
    
    -- Only aim when left mouse button is held (firing)
    local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local isScoping = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    
    -- Don't interfere with scoping
    if aimbotActive and isFiring and not isScoping then
        local target = GetClosestPlayer()
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(Settings.Aimbot.TargetPart) or target.Character:FindFirstChild("Head")
            if targetPart then
                local targetPos = targetPart.Position
                
                -- Prediction (velocity-based)
                if Settings.Aimbot.PredictionEnabled then
                    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and hrp.AssemblyLinearVelocity then
                        targetPos = targetPos + (hrp.AssemblyLinearVelocity * Settings.Aimbot.PredictionAmount)
                    end
                end
                
                -- Smooth aiming with proper interpolation
                local currentLookVector = Camera.CFrame.LookVector
                local targetLookVector = (targetPos - Camera.CFrame.Position).Unit
                
                -- Calculate angle difference
                local angleDiff = math.acos(math.clamp(currentLookVector:Dot(targetLookVector), -1, 1))
                
                -- Only apply smoothing if there's significant difference
                if angleDiff > 0.001 then
                    local smoothFactor = math.clamp(Settings.Aimbot.Smoothness, 0.01, 1)
                    local newCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, smoothFactor)
                end
            end
        end
    end
    
    -- ═══════════════════════════════════════════════════════════════════
    -- SILENT AIM SYSTEM (NO Camera Movement - Just redirects bullets)
    -- ═══════════════════════════════════════════════════════════════════
    -- Silent Aim works INDEPENDENTLY from Aimbot
    -- It hooks raycasts and mouse properties to redirect shots to target
    -- WITHOUT moving your camera at all - completely invisible to player
    
    local silentAimActive = Settings.SilentAim.Enabled and IsKeybindActive("SilentAimKeybind")
    if silentAimActive then
        -- Find closest target within Silent Aim FOV
        local _, targetPart = GetClosestPlayerForSilentAim()
        SilentAimTarget = targetPart
        -- The hooks will automatically redirect shots to SilentAimTarget
        -- Your camera stays where YOU aim it, but bullets go to the target
    else
        SilentAimTarget = nil
    end
    
    -- Triggerbot: Auto-fire when target is in crosshair
    local triggerbotActive = Settings.Triggerbot.Enabled and IsKeybindActive("TriggerbotKeybind")
    if triggerbotActive then
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and IsAlive(player) then
                if Settings.Triggerbot.TeamCheck and IsTeammate(player) then continue end
                
                local character = player.Character
                local head = character:FindFirstChild("Head")
                if head then
                    local screenPos, onScreen = WorldToScreen(head.Position)
                    if onScreen then
                        local distance = (screenPos - screenCenter).Magnitude
                        if distance < 50 then -- Within crosshair area
                            task.wait(Settings.Triggerbot.Delay)
                            mouse1click()
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- No Recoil: Compensate camera kick
    local noRecoilActive = Settings.NoRecoil.Enabled and IsKeybindActive("NoRecoilKeybind")
    if noRecoilActive then
        -- Store camera orientation to restore after recoil
        local currentCFrame = Camera.CFrame
        local strength = Settings.NoRecoil.Strength / 100
        
        -- Apply anti-recoil by dampening vertical camera movement
        task.defer(function()
            local newCFrame = Camera.CFrame
            local deltaY = newCFrame.LookVector.Y - currentCFrame.LookVector.Y
            if deltaY > 0.001 then -- Upward kick detected (recoil)
                local compensation = CFrame.Angles(-deltaY * strength, 0, 0)
                Camera.CFrame = Camera.CFrame * compensation
            end
        end)
    end
end)

-- Input Handler (only for features not managed by Library)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- Infinite Jump
    if Settings.Movement.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- Movement Loop
RunService.Stepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    
    -- Noclip
    if Settings.Movement.Noclip then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    -- Flight
    if Settings.Movement.Flight then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        
        local direction = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end
        
        if direction.Magnitude > 0 then
            hrp.Velocity = direction.Unit * Settings.Movement.FlySpeed
        else
            hrp.Velocity = Vector3.new(0, 0, 0)
        end
    end
    
    -- Speed Hack
    if Settings.Movement.SpeedHack then
        humanoid.WalkSpeed = Settings.Movement.WalkSpeed
    end
end)

-- ═══════════════════════════════════════════════════════════════════
-- UI SETUP
-- ═══════════════════════════════════════════════════════════════════

local Window = Library:Window({
    Name = "Riva Hub",
    Size = UDim2.new(0, 600, 0, 450),
    Theme = "Preset",
    Draggable = true,
    Resizeable = true,
    Logo = "77218680285262",
})

-- Create Watermark and KeybindList
local Watermark = Library:Watermark("Riva Hub | RIVALS")
local KeybindList = Library:KeybindList()

-- ═══════════════════════════════════════════════════════════════════
-- COMBAT TAB
-- ═══════════════════════════════════════════════════════════════════

local CombatPage = Window:Page({
    Name = "Combat",
    SubPages = true,
    Columns = 2
})

-- Aimbot SubPage
local AimbotSubPage = CombatPage:SubPage({
    Name = "Aimbot",
    Columns = 2
})

local AimbotSection = AimbotSubPage:Section({Name = "Aimbot", Side = 1})

AimbotSection:Toggle({
    Name = "Enabled",
    Flag = "AimbotEnabled",
    Default = false,
    Callback = function(value)
        Settings.Aimbot.Enabled = value
    end
}):Keybind({
    Flag = "AimbotKeybind",
    Default = Enum.KeyCode.E,
    Mode = "Hold"
    -- No callback needed - we check Library.Flags["AimbotKeybind"].Toggled directly
})

AimbotSection:Toggle({
    Name = "Show FOV Circle",
    Flag = "ShowFOV",
    Default = false,
    Callback = function(value)
        Settings.Aimbot.ShowFOV = value
    end
})

AimbotSection:Slider({
    Name = "FOV",
    Flag = "AimbotFOV",
    Min = 10,
    Max = 500,
    Default = 150,
    Decimals = 1,
    Suffix = "px",
    Callback = function(value)
        Settings.Aimbot.FOV = value
    end
})

AimbotSection:Slider({
    Name = "Smoothness",
    Flag = "AimbotSmoothness",
    Min = 0.01,
    Max = 1,
    Default = 0.15,
    Decimals = 0.01,
    Suffix = "",
    Callback = function(value)
        Settings.Aimbot.Smoothness = value
    end
})

AimbotSection:Dropdown({
    Name = "Target Part",
    Flag = "AimbotTargetPart",
    Items = {"Head", "HumanoidRootPart", "UpperTorso"},
    Default = "Head",
    Callback = function(value)
        Settings.Aimbot.TargetPart = value
    end
})

AimbotSection:Toggle({
    Name = "Team Check",
    Flag = "AimbotTeamCheck",
    Default = true,
    Callback = function(value)
        Settings.Aimbot.TeamCheck = value
    end
})

AimbotSection:Toggle({
    Name = "Wall Check",
    Flag = "AimbotWallCheck",
    Default = true,
    Callback = function(value)
        Settings.Aimbot.WallCheck = value
    end
})

-- Prediction Section
local PredictionSection = AimbotSubPage:Section({Name = "Prediction", Side = 2})

PredictionSection:Toggle({
    Name = "Enable Prediction",
    Flag = "PredictionEnabled",
    Default = false,
    Callback = function(value)
        Settings.Aimbot.PredictionEnabled = value
    end
})

PredictionSection:Slider({
    Name = "Prediction Amount",
    Flag = "PredictionAmount",
    Min = 0.01,
    Max = 0.5,
    Default = 0.165,
    Decimals = 0.001,
    Suffix = "s",
    Callback = function(value)
        Settings.Aimbot.PredictionAmount = value
    end
})

-- Triggerbot Section
local TriggerbotSection = AimbotSubPage:Section({Name = "Triggerbot", Side = 2})

TriggerbotSection:Toggle({
    Name = "Enabled",
    Flag = "TriggerbotEnabled",
    Default = false,
    Callback = function(value)
        Settings.Triggerbot.Enabled = value
    end
}):Keybind({
    Flag = "TriggerbotKeybind",
    Default = Enum.KeyCode.R,
    Mode = "Hold"
})

TriggerbotSection:Slider({
    Name = "Delay",
    Flag = "TriggerbotDelay",
    Min = 0,
    Max = 1,
    Default = 0.1,
    Decimals = 0.01,
    Suffix = "s",
    Callback = function(value)
        Settings.Triggerbot.Delay = value
    end
})

-- No Recoil Section
local NoRecoilSection = AimbotSubPage:Section({Name = "No Recoil", Side = 2})

NoRecoilSection:Toggle({
    Name = "Enabled",
    Flag = "NoRecoilEnabled",
    Default = false,
    Callback = function(value)
        Settings.NoRecoil.Enabled = value
    end
}):Keybind({
    Flag = "NoRecoilKeybind",
    Default = Enum.KeyCode.T,
    Mode = "Toggle"
})

NoRecoilSection:Slider({
    Name = "Strength",
    Flag = "NoRecoilStrength",
    Min = 0,
    Max = 100,
    Default = 100,
    Decimals = 1,
    Suffix = "%",
    Callback = function(value)
        Settings.NoRecoil.Strength = value
    end
})

-- Silent Aim SubPage
local SilentAimSubPage = CombatPage:SubPage({
    Name = "Silent Aim",
    Columns = 2
})

local SilentAimSection = SilentAimSubPage:Section({Name = "Silent Aim", Side = 1})

SilentAimSection:Toggle({
    Name = "Enabled",
    Flag = "SilentAimEnabled",
    Default = false,
    Callback = function(value)
        Settings.SilentAim.Enabled = value
    end
}):Keybind({
    Flag = "SilentAimKeybind",
    Default = Enum.KeyCode.Q,
    Mode = "Hold"
    -- No callback needed - we check Library.Flags["SilentAimKeybind"].Toggled directly
})

SilentAimSection:Toggle({
    Name = "Show FOV Circle",
    Flag = "SilentAimShowFOV",
    Default = false,
    Callback = function(value)
        Settings.SilentAim.ShowFOV = value
    end
})

SilentAimSection:Slider({
    Name = "FOV",
    Flag = "SilentAimFOV",
    Min = 10,
    Max = 500,
    Default = 100,
    Decimals = 1,
    Suffix = "px",
    Callback = function(value)
        Settings.SilentAim.FOV = value
    end
})

SilentAimSection:Dropdown({
    Name = "Target Part",
    Flag = "SilentAimTargetPart",
    Items = {"Head", "HumanoidRootPart", "UpperTorso"},
    Default = "Head",
    Callback = function(value)
        Settings.SilentAim.TargetPart = value
    end
})

-- Silent Aim Settings Section
local SilentAimSettingsSection = SilentAimSubPage:Section({Name = "Settings", Side = 2})

SilentAimSettingsSection:Slider({
    Name = "Hit Chance",
    Flag = "SilentAimHitChance",
    Min = 1,
    Max = 100,
    Default = 100,
    Decimals = 1,
    Suffix = "%",
    Callback = function(value)
        Settings.SilentAim.HitChance = value
    end
})

SilentAimSettingsSection:Toggle({
    Name = "Team Check",
    Flag = "SilentAimTeamCheck",
    Default = true,
    Callback = function(value)
        Settings.SilentAim.TeamCheck = value
    end
})

SilentAimSettingsSection:Toggle({
    Name = "Wall Check",
    Flag = "SilentAimWallCheck",
    Default = false,
    Callback = function(value)
        Settings.SilentAim.WallCheck = value
    end
})

SilentAimSettingsSection:Dropdown({
    Name = "Method",
    Flag = "SilentAimMethod",
    Items = {"Raycast", "Mouse.Hit", "Camera"},
    Default = "Raycast",
    Callback = function(value)
        Settings.SilentAim.Method = value
    end
})

-- ═══════════════════════════════════════════════════════════════════
-- VISUALS TAB
-- ═══════════════════════════════════════════════════════════════════

local VisualsPage = Window:Page({
    Name = "Visuals",
    SubPages = true,
    Columns = 2
})

-- ESP SubPage
local ESPSubPage = VisualsPage:SubPage({
    Name = "ESP",
    Columns = 2
})

local ESPSection = ESPSubPage:Section({Name = "ESP", Side = 1})

ESPSection:Toggle({
    Name = "Enabled",
    Flag = "ESPEnabled",
    Default = false,
    Callback = function(value)
        Settings.ESP.Enabled = value
    end
})

ESPSection:Toggle({
    Name = "Box ESP",
    Flag = "BoxESP",
    Default = false,
    Callback = function(value)
        Settings.ESP.Boxes = value
    end
})

ESPSection:Dropdown({
    Name = "Box Type",
    Flag = "BoxType",
    Items = {"Corner", "Full"},
    Default = "Corner",
    Callback = function(value)
        Settings.ESP.BoxType = value
    end
})

ESPSection:Toggle({
    Name = "Name ESP",
    Flag = "NameESP",
    Default = false,
    Callback = function(value)
        Settings.ESP.Names = value
    end
})

ESPSection:Toggle({
    Name = "Health Bar",
    Flag = "HealthBarESP",
    Default = false,
    Callback = function(value)
        Settings.ESP.HealthBar = value
    end
})

ESPSection:Toggle({
    Name = "Distance ESP",
    Flag = "DistanceESP",
    Default = false,
    Callback = function(value)
        Settings.ESP.Distance = value
    end
})

ESPSection:Toggle({
    Name = "Tracers",
    Flag = "TracerESP",
    Default = false,
    Callback = function(value)
        Settings.ESP.Tracers = value
    end
})

ESPSection:Dropdown({
    Name = "Tracer Origin",
    Flag = "TracerOrigin",
    Items = {"Top", "Center", "Bottom"},
    Default = "Bottom",
    Callback = function(value)
        Settings.ESP.TracerOrigin = value
    end
})

ESPSection:Toggle({
    Name = "Skeleton ESP",
    Flag = "SkeletonESP",
    Default = false,
    Callback = function(value)
        Settings.ESP.Skeleton = value
    end
})

ESPSection:Toggle({
    Name = "Head Dot",
    Flag = "HeadDot",
    Default = false,
    Callback = function(value)
        Settings.ESP.HeadDot = value
    end
})

-- ESP Settings Section
local ESPSettingsSection = ESPSubPage:Section({Name = "Settings", Side = 2})

ESPSettingsSection:Toggle({
    Name = "Team Check",
    Flag = "ESPTeamCheck",
    Default = true,
    Callback = function(value)
        Settings.ESP.TeamCheck = value
    end
})

ESPSettingsSection:Toggle({
    Name = "Use Team Colors",
    Flag = "ESPTeamColor",
    Default = false,
    Callback = function(value)
        Settings.ESP.TeamColor = value
    end
})

ESPSettingsSection:Slider({
    Name = "Max Distance",
    Flag = "ESPMaxDistance",
    Min = 100,
    Max = 2000,
    Default = 1000,
    Decimals = 1,
    Suffix = "m",
    Callback = function(value)
        Settings.ESP.MaxDistance = value
    end
})

-- Chams SubPage
local ChamsSubPage = VisualsPage:SubPage({
    Name = "Chams",
    Columns = 2
})

local ChamsSection = ChamsSubPage:Section({Name = "Chams", Side = 1})

ChamsSection:Toggle({
    Name = "Enabled",
    Flag = "ChamsEnabled",
    Default = false,
    Callback = function(value)
        Settings.Chams.Enabled = value
    end
})

ChamsSection:Toggle({
    Name = "Team Check",
    Flag = "ChamsTeamCheck",
    Default = true,
    Callback = function(value)
        Settings.Chams.TeamCheck = value
    end
})

ChamsSection:Slider({
    Name = "Fill Transparency",
    Flag = "ChamsFillTransparency",
    Min = 0,
    Max = 1,
    Default = 0.5,
    Decimals = 0.1,
    Suffix = "",
    Callback = function(value)
        Settings.Chams.FillTransparency = value
    end
})

ChamsSection:Slider({
    Name = "Outline Transparency",
    Flag = "ChamsOutlineTransparency",
    Min = 0,
    Max = 1,
    Default = 0,
    Decimals = 0.1,
    Suffix = "",
    Callback = function(value)
        Settings.Chams.OutlineTransparency = value
    end
})

-- Crosshair SubPage
local CrosshairSubPage = VisualsPage:SubPage({
    Name = "Crosshair",
    Columns = 2
})

local CrosshairSection = CrosshairSubPage:Section({Name = "Crosshair", Side = 1})

CrosshairSection:Toggle({
    Name = "Enabled",
    Flag = "CrosshairEnabled",
    Default = false,
    Callback = function(value)
        Settings.Crosshair.Enabled = value
    end
})

CrosshairSection:Slider({
    Name = "Size",
    Flag = "CrosshairSize",
    Min = 1,
    Max = 50,
    Default = 10,
    Decimals = 1,
    Suffix = "px",
    Callback = function(value)
        Settings.Crosshair.Size = value
    end
})

CrosshairSection:Slider({
    Name = "Gap",
    Flag = "CrosshairGap",
    Min = 0,
    Max = 20,
    Default = 5,
    Decimals = 1,
    Suffix = "px",
    Callback = function(value)
        Settings.Crosshair.Gap = value
    end
})

CrosshairSection:Slider({
    Name = "Thickness",
    Flag = "CrosshairThickness",
    Min = 1,
    Max = 5,
    Default = 1,
    Decimals = 1,
    Suffix = "px",
    Callback = function(value)
        Settings.Crosshair.Thickness = value
    end
})

-- ═══════════════════════════════════════════════════════════════════
-- MISC TAB
-- ═══════════════════════════════════════════════════════════════════

local MiscPage = Window:Page({
    Name = "Misc",
    SubPages = false,
    Columns = 2
})

local MovementSection = MiscPage:Section({Name = "Movement", Side = 1})

MovementSection:Toggle({
    Name = "Flight",
    Flag = "Flight",
    Default = false,
    Callback = function(value)
        Settings.Movement.Flight = value
    end
})

MovementSection:Slider({
    Name = "Fly Speed",
    Flag = "FlySpeed",
    Min = 10,
    Max = 200,
    Default = 50,
    Decimals = 1,
    Suffix = "",
    Callback = function(value)
        Settings.Movement.FlySpeed = value
    end
})

MovementSection:Toggle({
    Name = "Noclip",
    Flag = "Noclip",
    Default = false,
    Callback = function(value)
        Settings.Movement.Noclip = value
    end
})

MovementSection:Toggle({
    Name = "Speed Hack",
    Flag = "SpeedHack",
    Default = false,
    Callback = function(value)
        Settings.Movement.SpeedHack = value
    end
})

MovementSection:Slider({
    Name = "Walk Speed",
    Flag = "WalkSpeed",
    Min = 16,
    Max = 200,
    Default = 50,
    Decimals = 1,
    Suffix = "",
    Callback = function(value)
        Settings.Movement.WalkSpeed = value
    end
})

MovementSection:Toggle({
    Name = "Infinite Jump",
    Flag = "InfiniteJump",
    Default = false,
    Callback = function(value)
        Settings.Movement.InfiniteJump = value
    end
})

-- Settings Section
local SettingsSection = MiscPage:Section({Name = "Settings", Side = 2})

SettingsSection:Button({
    Name = "Unload Script",
    Callback = function()
        -- Cleanup
        for _, esp in pairs(ESPObjects) do
            esp:Destroy()
        end
        for _, chams in pairs(ChamsObjects) do
            chams:Destroy()
        end
        if Drawings.FOVCircle then
            Drawings.FOVCircle:Remove()
        end
        for _, line in pairs(Drawings.Crosshair) do
            line:Remove()
        end
        Library:Unload()
    end
})

-- ═══════════════════════════════════════════════════════════════════
-- SETTINGS TAB (Last in order)
-- ═══════════════════════════════════════════════════════════════════

-- Create Settings Page (Theming, Configs, Settings tabs) - Created last so it appears at bottom
local SettingsPage = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- Notification
Library:Notification("Riva Hub", "Script loaded successfully!", 5)

print("[Riva Hub] Loaded successfully!")
print("[Riva Hub] Executor: " .. ExecutorName)
print("[Riva Hub] Low Performance Mode: " .. tostring(LowPerformanceMode))
