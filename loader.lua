-- // Mamma Loader
-- Made for moccommm

local ScriptName = "MAMMA"
local Version = "1.0"
local RawLink = "https://raw.smokingscripts.org/moccommm/mamma/main/main.lua"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// Создание GUI
local Loader = Instance.new("ScreenGui")
Loader.Name = "MammaLoader"
Loader.ResetOnSpawn = false
Loader.Parent = playerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 380, 0, 240)
Main.Position = UDim2.new(0.5, -190, 0.5, -140)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
Main.BorderSizePixel = 0
Main.Parent = Loader

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 18)
UICorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(130, 0, 255)
Stroke.Thickness = 2.2
Stroke.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 60)
Title.BackgroundTransparency = 1
Title.Text = ScriptName
Title.TextColor3 = Color3.fromRGB(170, 0, 255)
Title.TextScaled = true
Title.Font = Enum.Font.GothamBold
Title.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 40)
Status.Position = UDim2.new(0, 0, 0.32, 0)
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
ProgressBG.Parent = Main

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(1, 0)
ProgressCorner.Parent = ProgressBG

local Progress = Instance.new("Frame")
Progress.Size = UDim2.new(0, 0, 1, 0)
Progress.BackgroundColor3 = Color3.fromRGB(140, 0, 255)
Progress.Parent = ProgressBG

local ProgressCorner2 = Instance.new("UICorner")
ProgressCorner2.CornerRadius = UDim.new(1, 0)
ProgressCorner2.Parent = Progress

local Credit = Instance.new("TextLabel")
Credit.Size = UDim2.new(1, 0, 0, 20)
Credit.Position = UDim2.new(0, 0, 0.82, 0)
Credit.BackgroundTransparency = 1
Credit.Text = "by moccommm • smokingscripts.org"
Credit.TextColor3 = Color3.fromRGB(90, 90, 90)
Credit.TextSize = 13
Credit.Font = Enum.Font.Gotham
Credit.Parent = Main

--// Анимация появления
Main.BackgroundTransparency = 1
Main.Position = UDim2.new(0.5, -190, 0.6, -140)
TweenService:Create(Main, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    BackgroundTransparency = 0,
    Position = UDim2.new(0.5, -190, 0.5, -140)
}):Play()

local function SetStatus(text)
    Status.Text = text
end

local function SetProgress(value, time)
    TweenService:Create(Progress, TweenInfo.new(time or 1.1, Enum.EasingStyle.Quint), {
        Size = UDim2.new(value, 0, 1, 0)
    }):Play()
end

--// Последовательность загрузки
task.spawn(function()
    SetStatus("Connecting to servers...")
    SetProgress(0.25, 0.8)
    task.wait(1.1)

    SetStatus("Authenticating...")
    SetProgress(0.55, 1.2)
    task.wait(1.3)

    SetStatus("Downloading script...")
    SetProgress(0.85, 0.9)
    task.wait(1.1)

    SetStatus("Executing " .. ScriptName .. "...")
    SetProgress(1, 0.8)
    task.wait(1.2)

    SetStatus("Successfully loaded!")
    task.wait(1.4)

    -- Удаляем лоадер
    TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
    task.wait(0.6)
    Loader:Destroy()

    -- Загружаем твой основной скрипт
    loadstring(game:HttpGet(RawLink))()
end)