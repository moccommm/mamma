-- // MAMMA Loader by moccommm

local ScriptName = "MAMMA"
local RawLink = "https://raw.githubusercontent.com/moccommm/mamma/main/main.lua"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("MammaLoader") then
    playerGui.MammaLoader:Destroy()
end

local Loader = Instance.new("ScreenGui")
Loader.Name = "MammaLoader"
Loader.ResetOnSpawn = false
Loader.IgnoreGuiInset = true
Loader.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Loader.Parent = playerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 380, 0, 240)
Main.Position = UDim2.new(0.5, -190, 0.5, -120)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
Main.BorderSizePixel = 0
Main.Parent = Loader

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 18)

local Stroke = Instance.new("UIStroke", Main)
Stroke.Color = Color3.fromRGB(130, 0, 255)
Stroke.Thickness = 2

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 60)
Title.BackgroundTransparency = 1
Title.Text = ScriptName
Title.TextColor3 = Color3.fromRGB(170, 0, 255)
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 30)
Status.Position = UDim2.new(0, 0, 0.35, 0)
Status.BackgroundTransparency = 1
Status.Text = "Initializing..."
Status.TextColor3 = Color3.fromRGB(180, 180, 180)
Status.TextScaled = true
Status.Font = Enum.Font.Gotham
Status.Parent = Main

local ProgressBG = Instance.new("Frame")
ProgressBG.Size = UDim2.new(0.85, 0, 0, 10)
ProgressBG.Position = UDim2.new(0.075, 0, 0.65, 0)
ProgressBG.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
ProgressBG.BorderSizePixel = 0
ProgressBG.Parent = Main
Instance.new("UICorner", ProgressBG).CornerRadius = UDim.new(1, 0)

local Progress = Instance.new("Frame")
Progress.Size = UDim2.new(0, 0, 1, 0)
Progress.BackgroundColor3 = Color3.fromRGB(140, 0, 255)
Progress.BorderSizePixel = 0
Progress.Parent = ProgressBG
Instance.new("UICorner", Progress).CornerRadius = UDim.new(1, 0)

local Credit = Instance.new("TextLabel")
Credit.Size = UDim2.new(1, 0, 0, 20)
Credit.Position = UDim2.new(0, 0, 0.82, 0)
Credit.BackgroundTransparency = 1
Credit.Text = "by moccommm"
Credit.TextColor3 = Color3.fromRGB(90, 90, 90)
Credit.TextSize = 13
Credit.Font = Enum.Font.Gotham
Credit.Parent = Main

local function SetStatus(t) Status.Text = t end
local function SetProgress(v, t)
    TweenService:Create(Progress, TweenInfo.new(t or 1, Enum.EasingStyle.Quint), {
        Size = UDim2.new(v, 0, 1, 0)
    }):Play()
end

task.spawn(function()
    SetStatus("Connecting...")
    SetProgress(0.3, 0.8); task.wait(1)

    SetStatus("Downloading script...")
    SetProgress(0.7, 1); task.wait(1.2)

    SetStatus("Executing...")
    SetProgress(1, 0.8); task.wait(1)

    SetStatus("Loaded successfully!")
    task.wait(1)

    TweenService:Create(Main, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    task.wait(0.6)
    Loader:Destroy()

    local ok, err = pcall(function()
        loadstring(game:HttpGet(RawLink))()
    end)
    if not ok then
        warn("[MAMMA] Load error: " .. tostring(err))
    end
end)
