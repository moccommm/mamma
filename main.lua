-- ===============================================
--   ☾ EVENTIDE v3.7 — FIXED SILENT AIM EDITION
--   Da Hood & Boom Hood
--   Multi-hook + Fallback camera lock
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1.5)

local getgenv = getgenv or function() return _G end
if getgenv()._EV_XS then return end
getgenv()._EV_XS = true

pcall(function()
    if gethui then
        for _, g in ipairs(gethui():GetChildren()) do
            if g:IsA("ScreenGui") and g.Name:find("Eventide") then g:Destroy() end
        end
    end
end)

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local WS      = game:GetService("Workspace")
local TS      = game:GetService("TweenService")
local SG      = game:GetService("StarterGui")
local Stats   = game:GetService("Stats")

local LP    = Players.LocalPlayer
local Cam   = WS.CurrentCamera
local Mouse = LP:GetMouse()

local newccl      = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local hookfunc    = hookfunction or hookfunc or (syn and syn.hook)
local getrawmt    = getrawmetatable
local setreadonly = setreadonly or (make_writeable and function(t) make_writeable(t) end)

local function Notify(t, m, d)
    pcall(function()
        SG:SetCore("SendNotification", {Title = t, Text = m, Duration = d or 3})
    end)
end

-- ==================== CONFIG ====================
local CFG = {
    SilentAim        = true,
    FOV              = 150,
    Prediction       = 0.135,
    PredMult         = 1.0,
    AutoPred         = true,
    HoldToAim        = true,
    AimButton        = "Right",
    RequireGun       = false,        -- ❗ теперь по умолчанию НЕ требует оружие
    OnlyWhenShooting = false,
    TeamCheck        = false,
    NoDowned         = true,
    VisCheck         = false,
    MaxDist          = 1500,

    HeadOnly         = true,
    PingComp         = true,
    AccelComp        = true,
    GravityComp      = true,
    AntiJitter       = true,
    SnapRadius       = 10,

    CameraLock       = false,        -- ❗ Fallback режим (двигает камеру)
    CamLockSmooth    = 0.35,

    HitboxExpander   = false,
    HitboxSize       = 6,
    HitboxTransp     = 0.7,
    ShowHitbox       = true,

    ESP       = true,
    Boxes     = true,
    Names     = true,
    HP        = true,
    Dist      = true,
    Tracers   = false,
    HeadDot   = true,

    ShowFOV   = true,
    ShowPred  = true,
    Rainbow   = false,
    FOVCol    = Color3.fromRGB(130, 90, 240),
    Debug     = true,

    KeyMenu    = "Insert",
    KeyAim     = "F2",
    KeyESP     = "F3",
    KeyHitbox  = "F4",
    KeyCamLock = "F5",
    KeyPanic   = "F1",
    KeyUnload  = "End",
}

local Target         = nil
local cachedPred     = nil
local ESPObj         = {}
local VelHist        = {}
local PosHist        = {}
local SpawnTimes     = {}
local HeadOffsetCache = {}
local DEFAULT_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local SPAWN_GRACE    = 0.5
local OFFSET_SETTLE  = 0.3
local RH             = 0
local curPred        = 0.135
local isShooting     = false
local isHolding      = false
local hookStatus     = "⏳ Ждём..."
local hooksInstalled = 0
local exploitInfo    = ""

-- ==================== EXPLOIT DETECTION ====================
task.spawn(function()
    local features = {}
    if hookfunc then table.insert(features, "hookfunc") end
    if getrawmt then table.insert(features, "getrawmt") end
    if setreadonly then table.insert(features, "setrw") end
    if newcclosure then table.insert(features, "newccl") end
    exploitInfo = table.concat(features, "|")
    if #features < 2 then
        Notify("⚠️ Eventide", "Слабый эксплоит! Silent Aim может не работать.\nВключи Camera Lock (F5)", 6)
    end
end)

-- ==================== UTILS ====================
local function GetPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and v or 80
end

local function GetRoot(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHead(p)
    local c = p and p.Character
    return c and c:FindFirstChild("Head")
end

local function GetHum(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsDowned(p)
    local c = p and p.Character
    if not c then return true end
    local be = c:FindFirstChild("BodyEffects")
    if be then
        local ko = be:FindFirstChild("K.O")
        if ko then return ko.Value end
    end
    return false
end

-- МЯГКАЯ проверка оружия (любой Tool = ok)
local function IsHoldingGun()
    if not CFG.RequireGun then return true end
    local char = LP.Character
    if not char then return false end
    return char:FindFirstChildOfClass("Tool") ~= nil
end

local function IsSafeCaller()
    if not getcallingscript then return true end
    local ok, caller = pcall(getcallingscript)
    if not ok or not caller then return true end
    local name = caller.Name:lower()
    if name:find("anti") or name:find("cheat") or name:find("guard") then
        return false
    end
    return true
end

local function IsValid(p)
    if p == LP or not p or not p.Parent then return false end
    local c = p.Character
    if not c then return false end
    local h = GetHum(p)
    if not h or h.Health <= 0 then return false end
    if not GetHead(p) then return false end
    if CFG.TeamCheck and p.Team == LP.Team then return false end
    if CFG.NoDowned and IsDowned(p) then return false end
    local myRoot = GetRoot(LP)
    local theirRoot = GetRoot(p)
    if not myRoot or not theirRoot then return false end
    if (myRoot.Position - theirRoot.Position).Magnitude > CFG.MaxDist then return false end
    if CFG.VisCheck then
        local th = GetHead(p)
        if myRoot and th then
            local par = RaycastParams.new()
            par.FilterDescendantsInstances = {LP.Character, p.Character}
            par.FilterType = Enum.RaycastFilterType.Exclude
            if WS:Raycast(myRoot.Position, (th.Position - myRoot.Position), par) then
                return false
            end
        end
    end
    return true
end

-- ==================== VELOCITY / POS HISTORY ====================
RS.Heartbeat:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local st = SpawnTimes[p]
            if st and (tick() - st) < OFFSET_SETTLE then continue end

            local r = GetRoot(p)
            local h = GetHead(p)
            if r and h then
                local liveOffset = h.Position - r.Position
                if liveOffset.Magnitude > 0.3 and liveOffset.Magnitude < 5 then
                    HeadOffsetCache[p] = liveOffset
                elseif not HeadOffsetCache[p] then
                    HeadOffsetCache[p] = DEFAULT_HEAD_OFFSET
                end

                if not VelHist[p] then VelHist[p] = {} end
                table.insert(VelHist[p], 1, r.AssemblyLinearVelocity)
                if #VelHist[p] > 15 then table.remove(VelHist[p]) end

                if not PosHist[p] then PosHist[p] = {} end
                table.insert(PosHist[p], 1, {
                    pos  = h.Position,
                    root = r.Position,
                    vel  = r.AssemblyLinearVelocity,
                    time = tick()
                })
                if #PosHist[p] > 20 then table.remove(PosHist[p]) end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    VelHist[p] = nil
    PosHist[p] = nil
    SpawnTimes[p] = nil
    HeadOffsetCache[p] = nil
end)

-- ==================== PREDICTION ====================
local function GetSmoothedVelocity(plr)
    local h = VelHist[plr]
    if not h or #h == 0 then
        local r = GetRoot(plr)
        return r and r.AssemblyLinearVelocity or Vector3.zero
    end
    if #h < 3 then return h[1] end

    local sm, tw = Vector3.zero, 0
    local count = math.min(#h, 8)
    for i = 1, count do
        local w = (count - i + 1) / count
        w = w * w
        sm = sm + h[i] * w
        tw = tw + w
    end
    local smoothed = tw > 0 and sm / tw or h[1]

    if CFG.AntiJitter and #h >= 3 then
        local diff = (h[1] - h[2]).Magnitude
        if diff > 30 then
            local avg = Vector3.zero
            local c2 = math.min(#h, 5)
            for i = 1, c2 do avg = avg + h[i] end
            smoothed = avg / c2
        end
    end
    return smoothed
end

local function GetAcceleration(plr)
    local h = VelHist[plr]
    if not h or #h < 3 then return Vector3.zero end
    local acc = Vector3.zero
    local count = math.min(#h - 1, 4)
    for i = 1, count do acc = acc + (h[i] - h[i + 1]) end
    return acc / count
end

local function CalcAutoPrediction()
    local ping = GetPing()
    local pred = (ping / 1000) + (1 / 60) + 0.02
    pred = math.clamp(pred, 0.08, 0.25)
    return pred * CFG.PredMult
end

local function GetHeadPosition100(plr)
    if not plr or not plr.Character then return nil end
    local head = GetHead(plr)
    local root = GetRoot(plr)
    local hum  = GetHum(plr)
    if not head or not root then return nil end

    local st = SpawnTimes[plr]
    if st and (tick() - st) < SPAWN_GRACE then
        return head.Position
    end

    local velHistory = VelHist[plr]
    if not velHistory or #velHistory < 3 then
        return head.Position
    end

    local pred = CFG.AutoPred and CalcAutoPrediction() or (CFG.Prediction * CFG.PredMult)
    curPred = pred

    local vel = GetSmoothedVelocity(plr)

    if vel.Magnitude < 3 then
        return head.Position
    end

    local predictedRoot = root.Position + Vector3.new(vel.X * pred, 0, vel.Z * pred)

    if CFG.AccelComp then
        local acc = GetAcceleration(plr)
        predictedRoot = predictedRoot + Vector3.new(
            acc.X * pred * pred * 0.5, 0, acc.Z * pred * pred * 0.5
        )
    end

    if CFG.GravityComp and hum then
        local state = hum:GetState()
        local g = WS.Gravity or 196.2
        if state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall then
            local predY = root.Position.Y + vel.Y * pred - 0.5 * g * pred * pred
            predictedRoot = Vector3.new(predictedRoot.X, predY, predictedRoot.Z)
        else
            predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y, predictedRoot.Z)
        end
    else
        predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y, predictedRoot.Z)
    end

    if CFG.PingComp then
        local extraComp = (GetPing() / 1000) * 0.15
        predictedRoot = predictedRoot + Vector3.new(vel.X * extraComp, 0, vel.Z * extraComp)
    end

    local headOffset = HeadOffsetCache[plr]
    if not headOffset then
        local liveOffset = head.Position - root.Position
        if liveOffset.Magnitude > 0.3 and liveOffset.Magnitude < 5 then
            headOffset = liveOffset
            HeadOffsetCache[plr] = headOffset
        else
            headOffset = DEFAULT_HEAD_OFFSET
        end
    end

    local finalHead = predictedRoot + headOffset

    local maxOffset = vel.Magnitude * pred * 2 + CFG.SnapRadius
    local diff = finalHead - head.Position
    if diff.Magnitude > maxOffset then
        finalHead = head.Position + diff.Unit * maxOffset
    end

    return finalHead
end

local function GetTarget()
    local best, bd = nil, math.huge
    local sc = Cam.ViewportSize / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if IsValid(p) then
            local h = GetHead(p)
            if h then
                local sp = Cam:WorldToViewportPoint(h.Position)
                if sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - sc).Magnitude
                    if d < CFG.FOV and d < bd then
                        bd = d; best = p
                    end
                end
            end
        end
    end
    return best
end

RS.Heartbeat:Connect(function()
    Target     = GetTarget()
    cachedPred = (Target and CFG.SilentAim) and GetHeadPosition100(Target) or nil
end)

-- ==================== SHOOT / AIM DETECTION ====================
local function GetAimButtonEnum()
    if CFG.AimButton == "Right" then
        return Enum.UserInputType.MouseButton2
    elseif CFG.AimButton == "Middle" then
        return Enum.UserInputType.MouseButton3
    else
        return Enum.UserInputType.MouseButton1
    end
end

UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = true
    end
    if i.UserInputType == GetAimButtonEnum() then
        isHolding = true
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        isShooting = false
    end
    if i.UserInputType == GetAimButtonEnum() then
        isHolding = false
    end
end)

-- ==================== HITBOX EXPANDER ====================
local OriginalHeadSizes = {}

local function ExpandHitbox(plr)
    if plr == LP then return end
    local char = plr and plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if not OriginalHeadSizes[plr] then
        OriginalHeadSizes[plr] = {
            size = head.Size, transp = head.Transparency,
            canCol = head.CanCollide, mat = head.Material,
            col = head.Color, massless = head.Massless,
        }
    end

    if CFG.HitboxExpander then
        local s = CFG.HitboxSize
        head.Size = Vector3.new(s, s, s)
        head.Transparency = CFG.ShowHitbox and CFG.HitboxTransp or 1
        head.CanCollide = false
        head.Massless = true
        head.Material = Enum.Material.ForceField
        head.Color = Color3.fromRGB(160, 60, 255)
    end
end

local function ResetHitbox(plr)
    local char = plr and plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local orig = OriginalHeadSizes[plr]
    if orig then
        pcall(function()
            head.Size = orig.size
            head.Transparency = orig.transp
            head.CanCollide = true
            head.Massless = orig.massless or false
            head.Material = orig.mat or Enum.Material.Plastic
            head.Color = orig.col or Color3.fromRGB(163, 162, 165)
        end)
    else
        pcall(function()
            head.Size = Vector3.new(2, 1, 1)
            head.Transparency = 0
            head.CanCollide = true
            head.Massless = false
            head.Material = Enum.Material.Plastic
        end)
    end
    OriginalHeadSizes[plr] = nil
end

local function ResetAllHitboxes()
    for _, plr in ipairs(Players:GetPlayers()) do ResetHitbox(plr) end
    OriginalHeadSizes = {}
end

RS.Heartbeat:Connect(function()
    if not CFG.HitboxExpander then
        for _, plr in ipairs(Players:GetPlayers()) do
            if OriginalHeadSizes[plr] then ResetHitbox(plr) end
        end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local char = plr.Character
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then
                if OriginalHeadSizes[plr] then ResetHitbox(plr) end
            elseif head then
                local s = CFG.HitboxSize
                if head.Size.X ~= s then ExpandHitbox(plr) end
                head.Transparency = CFG.ShowHitbox and CFG.HitboxTransp or 1
            end
        end
    end
end)

local function HookCharacter(plr)
    if plr == LP then return end
    plr.CharacterAdded:Connect(function(char)
        VelHist[plr] = {}
        PosHist[plr] = {}
        HeadOffsetCache[plr] = nil
        SpawnTimes[plr] = tick()

        local root = char:WaitForChild("HumanoidRootPart", 10)
        local head = char:WaitForChild("Head", 10)
        if root and head then
            task.wait(OFFSET_SETTLE)
            local offset = head.Position - root.Position
            HeadOffsetCache[plr] = (offset.Magnitude > 0.3 and offset.Magnitude < 5) and offset or DEFAULT_HEAD_OFFSET
        end

        task.wait(0.7)
        if CFG.HitboxExpander then ExpandHitbox(plr) end

        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                ResetHitbox(plr)
                VelHist[plr] = {}
                PosHist[plr] = {}
                HeadOffsetCache[plr] = nil
            end)
        end
    end)
    plr.CharacterRemoving:Connect(function()
        ResetHitbox(plr)
        VelHist[plr] = {}
        PosHist[plr] = {}
        HeadOffsetCache[plr] = nil
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then
        HookCharacter(plr)
        if plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Died:Connect(function()
                    ResetHitbox(plr)
                    VelHist[plr] = {}
                    PosHist[plr] = {}
                    HeadOffsetCache[plr] = nil
                end)
            end
        end
    end
end

Players.PlayerAdded:Connect(HookCharacter)

-- ==================== SILENT AIM HOOKS (MULTI) ====================
local function ShouldSpoof()
    if not CFG.SilentAim then return false end
    if not cachedPred then return false end
    if checkcaller() then return false end
    if not IsSafeCaller() then return false end
    if CFG.RequireGun and not IsHoldingGun() then return false end
    if CFG.OnlyWhenShooting and not isShooting then return false end
    if CFG.HoldToAim and not isHolding then return false end
    return true
end

local function GetFreshHeadPos()
    if not Target or not cachedPred then return cachedPred end
    return GetHeadPosition100(Target) or cachedPred
end

task.spawn(function()
    task.wait(2)
    local installed = 0

    if not hookfunc then
        hookStatus = "❌ Нет hookfunction"
        Notify("Eventide", "❌ Эксплоит не поддерживает hookfunction!\nВключи Camera Lock (F5)", 6)
        return
    end

    -- Hook 1: ViewportPointToRay
    pcall(function()
        local orig; orig = hookfunc(Cam.ViewportPointToRay, newccl(function(self, x, y, ...)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then
                    local wp = self:WorldToViewportPoint(hp)
                    if wp.Z > 0 then return orig(self, wp.X, wp.Y, ...) end
                end
            end
            return orig(self, x, y, ...)
        end))
        installed += 1
    end)

    -- Hook 2: ScreenPointToRay
    pcall(function()
        local orig; orig = hookfunc(Cam.ScreenPointToRay, newccl(function(self, x, y, ...)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then
                    local wp, vis = self:WorldToScreenPoint(hp)
                    if vis then return orig(self, wp.X, wp.Y, ...) end
                end
            end
            return orig(self, x, y, ...)
        end))
        installed += 1
    end)

    -- Hook 3: GetMouseLocation
    pcall(function()
        local orig; orig = hookfunc(UIS.GetMouseLocation, newccl(function(self)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then
                    local wp = Cam:WorldToViewportPoint(hp)
                    if wp.Z > 0 then return Vector2.new(wp.X, wp.Y) end
                end
            end
            return orig(self)
        end))
        installed += 1
    end)

    -- Hook 4: Mouse metatable (Hit, Target, UnitRay, X, Y)
    pcall(function()
        if not getrawmt then return end
        local mt = getrawmt(Mouse)
        if not mt then return end
        local oldIdx = mt.__index
        if setreadonly then pcall(setreadonly, mt, false) end
        mt.__index = newccl(function(self, key)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then
                    if key == "Hit" or key == "hit" then return CFrame.new(hp) end
                    if key == "Target" or key == "target" then
                        local head = Target and GetHead(Target)
                        if head then return head end
                    end
                    if key == "UnitRay" then
                        local origin = Cam.CFrame.Position
                        local dir = (hp - origin).Unit
                        return Ray.new(origin, dir)
                    end
                    if key == "X" then return Cam:WorldToViewportPoint(hp).X end
                    if key == "Y" then return Cam:WorldToViewportPoint(hp).Y end
                end
            end
            return oldIdx(self, key)
        end)
        if setreadonly then pcall(setreadonly, mt, true) end
        installed += 1
    end)

    -- Hook 5: workspace.Raycast (ловим выстрелы)
    pcall(function()
        local orig; orig = hookfunc(WS.Raycast, newccl(function(self, origin, direction, params, ...)
            if ShouldSpoof() and typeof(direction) == "Vector3" then
                local hp = GetFreshHeadPos()
                if hp and typeof(origin) == "Vector3" then
                    local newDir = (hp - origin).Unit * direction.Magnitude
                    return orig(self, origin, newDir, params, ...)
                end
            end
            return orig(self, origin, direction, params, ...)
        end))
        installed += 1
    end)

    hooksInstalled = installed
    if installed > 0 then
        hookStatus = "🎯 " .. installed .. " hooks"
        Notify("Eventide v3.7", "💀 " .. installed .. " hooks активны!\nДержи ПКМ", 5)
    else
        hookStatus = "❌ 0 hooks"
        Notify("Eventide", "❌ Хуки не установились!\nВключи Camera Lock (F5)", 6)
    end
end)

-- ==================== CAMERA LOCK (FALLBACK) ====================
RS.RenderStepped:Connect(function()
    Cam = WS.CurrentCamera
    if CFG.CameraLock and CFG.SilentAim and Target and cachedPred and (not CFG.HoldToAim or isHolding) then
        local myRoot = GetRoot(LP)
        if myRoot then
            local currentCF = Cam.CFrame
            local targetCF = CFrame.new(currentCF.Position, cachedPred)
            Cam.CFrame = currentCF:Lerp(targetCF, CFG.CamLockSmooth)
        end
    end
end)

-- ==================== ESP ====================
local function MakeESP(p)
    if p == LP or ESPObj[p] then return end
    local e = {
        Box=Drawing.new("Square"), BoxO=Drawing.new("Square"),
        Name=Drawing.new("Text"), HP=Drawing.new("Text"),
        Dist=Drawing.new("Text"), Trc=Drawing.new("Line"),
        HPB=Drawing.new("Square"), HPBG=Drawing.new("Square"),
        HD=Drawing.new("Circle"),
    }
    for _, v in pairs(e) do v.Visible = false end
    e.Box.Thickness = 1.5
    e.BoxO.Thickness = 3; e.BoxO.Color = Color3.new(0,0,0); e.BoxO.Transparency = 0.5
    e.Name.Size = 13; e.Name.Center = true; e.Name.Outline = true; e.Name.Font = 2
    e.HP.Size = 12; e.HP.Center = true; e.HP.Outline = true; e.HP.Font = 2
    e.Dist.Size = 11; e.Dist.Center = true; e.Dist.Outline = true; e.Dist.Font = 2
    e.Dist.Color = Color3.fromRGB(180,180,180)
    e.Trc.Thickness = 1.5
    e.HPB.Filled = true
    e.HPBG.Filled = true; e.HPBG.Color = Color3.fromRGB(20,20,20)
    e.HD.Filled = true; e.HD.Radius = 3.5; e.HD.NumSides = 12
    ESPObj[p] = e
end

local function KillESP(p)
    local e = ESPObj[p]
    if not e then return end
    for _, v in pairs(e) do pcall(function() v:Remove() end) end
    ESPObj[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do MakeESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(1); MakeESP(p) end)
Players.PlayerRemoving:Connect(KillESP)

local FOVd = Drawing.new("Circle")
FOVd.Thickness = 1.8; FOVd.NumSides = 80; FOVd.Filled = false; FOVd.Transparency = 0.85

local PD = Drawing.new("Circle")
PD.Filled = true; PD.Radius = 5; PD.NumSides = 16; PD.Color = Color3.fromRGB(160,80,255)

local DB = Drawing.new("Text")
DB.Size = 14; DB.Outline = true; DB.Font = 2; DB.Color = Color3.fromRGB(200,180,255)

local DB2 = Drawing.new("Text")
DB2.Size = 12; DB2.Outline = true; DB2.Font = 2; DB2.Color = Color3.fromRGB(150,120,200)

local et = 0
RS.RenderStepped:Connect(function(dt)
    Cam = WS.CurrentCamera
    RH  = (RH + 0.002) % 1
    local sc = Cam.ViewportSize / 2

    FOVd.Visible  = CFG.ShowFOV
    FOVd.Radius   = CFG.FOV
    FOVd.Position = sc
    FOVd.Color    = CFG.Rainbow and Color3.fromHSV(RH,0.8,1)
        or (isHolding and Color3.fromRGB(0,255,140) or (isShooting and Color3.fromRGB(255,60,180) or CFG.FOVCol))

    if cachedPred and CFG.ShowPred and Target then
        local sp = Cam:WorldToViewportPoint(cachedPred)
        PD.Visible = sp.Z > 0
        PD.Position = Vector2.new(sp.X, sp.Y)
        PD.Color = isHolding and Color3.fromRGB(0,255,140) or (isShooting and Color3.fromRGB(255,0,0) or Color3.fromRGB(160,80,255))
        PD.Radius = (isHolding or isShooting) and 8 or 5
    else
        PD.Visible = false
    end

    if CFG.Debug then
        DB.Visible = true
        DB2.Visible = true
        local tn  = Target and Target.Name or "—"
        local sh  = isShooting and "💀SHOOT" or "—"
        local aim = isHolding and "🎯HOLD" or "—"
        local cl  = CFG.CameraLock and "📷LOCK" or ""
        DB.Text = string.format(
            "☾ EVENTIDE  |  TGT:%s  %s  %s  %s  %s",
            tn, sh, aim, hookStatus, cl
        )
        DB.Position = Vector2.new(12, 36)
        DB2.Text = string.format(
            "PRED:%dms  PING:%dms  FOV:%d  EXPL:[%s]",
            curPred*1000, math.floor(GetPing()), CFG.FOV, exploitInfo
        )
        DB2.Position = Vector2.new(12, 54)
    else
        DB.Visible = false
        DB2.Visible = false
    end

    et = et + dt
    if et < 0.033 then return end
    et = 0

    local mr = GetRoot(LP)
    if not mr then return end

    for p, e in pairs(ESPObj) do
        pcall(function()
            local function hide() for _, v in pairs(e) do v.Visible = false end end
            if not CFG.ESP or not p.Parent then return hide() end
            local c = p.Character
            if not c then return hide() end
            local hm = GetHum(p)
            if not hm or hm.Health <= 0 then return hide() end
            local r = GetRoot(p); local h = GetHead(p)
            if not r or not h then return hide() end
            local d = (mr.Position - r.Position).Magnitude
            if d > CFG.MaxDist then return hide() end
            local rp = Cam:WorldToViewportPoint(r.Position)
            local hp = Cam:WorldToViewportPoint(h.Position + Vector3.new(0,0.5,0))
            if rp.Z <= 0 then return hide() end
            local col = (Target == p) and Color3.fromRGB(180,80,255) or Color3.fromRGB(120,80,200)
            local hpv = math.floor(hm.Health)
            local mhp = math.max(math.floor(hm.MaxHealth), 1)
            local hpr = math.clamp(hpv / mhp, 0, 1)
            local bh = math.abs(rp.Y - hp.Y) * 2.3
            local bw = bh * 0.55
            local bx, by = rp.X - bw/2, rp.Y - bh/2

            if CFG.Boxes then
                e.BoxO.Visible = true; e.BoxO.Position = Vector2.new(bx,by); e.BoxO.Size = Vector2.new(bw,bh)
                e.Box.Visible = true; e.Box.Position = Vector2.new(bx,by); e.Box.Size = Vector2.new(bw,bh); e.Box.Color = col
            else e.Box.Visible = false; e.BoxO.Visible = false end

            if CFG.HP then
                e.HPBG.Visible = true; e.HPBG.Position = Vector2.new(bx-8, by); e.HPBG.Size = Vector2.new(4, bh)
                e.HPB.Visible = true; e.HPB.Position = Vector2.new(bx-8, by+bh*(1-hpr))
                e.HPB.Size = Vector2.new(4, bh*hpr)
                e.HPB.Color = Color3.fromRGB(math.floor(255*(1-hpr)), math.floor(255*hpr), 0)
                e.HP.Visible = true; e.HP.Text = hpv.."/"..mhp
                e.HP.Position = Vector2.new(rp.X, by+bh+4)
                e.HP.Color = hpr > 0.6 and Color3.fromRGB(100,255,100) or hpr > 0.35 and Color3.fromRGB(255,255,80) or Color3.fromRGB(255,60,60)
            else e.HPB.Visible = false; e.HPBG.Visible = false; e.HP.Visible = false end

            if CFG.Names then
                e.Name.Visible = true
                e.Name.Text = p.Name..(IsDowned(p) and " [DOWN]" or "")
                e.Name.Position = Vector2.new(rp.X, by-18); e.Name.Color = col
            else e.Name.Visible = false end

            if CFG.Dist then
                e.Dist.Visible = true; e.Dist.Text = "["..math.floor(d).."m]"
                e.Dist.Position = Vector2.new(rp.X, by+bh+18)
            else e.Dist.Visible = false end

            if CFG.Tracers then
                e.Trc.Visible = true
                e.Trc.From = Vector2.new(sc.X, Cam.ViewportSize.Y-30)
                e.Trc.To = Vector2.new(rp.X, rp.Y); e.Trc.Color = col
            else e.Trc.Visible = false end

            if CFG.HeadDot and hp.Z > 0 then
                e.HD.Visible = true; e.HD.Position = Vector2.new(hp.X, hp.Y); e.HD.Color = col
            else e.HD.Visible = false end
        end)
    end
end)

-- ===============================================
--              GUI
-- ===============================================

local SGui = Instance.new("ScreenGui")
SGui.Name = "Eventide_" .. math.random(100000, 999999)
SGui.ResetOnSpawn = false; SGui.IgnoreGuiInset = true; SGui.DisplayOrder = 999999
pcall(function() SGui.Parent = gethui() or game:GetService("CoreGui") end)
if not SGui.Parent then SGui.Parent = LP:WaitForChild("PlayerGui") end

local P = {
    BG=Color3.fromRGB(8,6,14), BG2=Color3.fromRGB(14,10,24),
    Card=Color3.fromRGB(18,14,30), Card2=Color3.fromRGB(24,18,38),
    Border=Color3.fromRGB(55,30,90), Accent=Color3.fromRGB(140,60,220),
    Accent2=Color3.fromRGB(180,80,255), AccentD=Color3.fromRGB(90,40,160),
    Glow=Color3.fromRGB(160,80,255), White=Color3.fromRGB(235,230,255),
    Dim=Color3.fromRGB(130,120,160), Green=Color3.fromRGB(80,220,160),
    Red=Color3.fromRGB(220,60,80), Yellow=Color3.fromRGB(255,200,80),
    Off=Color3.fromRGB(30,24,44), OffKnob=Color3.fromRGB(70,60,100),
    TabOff=Color3.fromRGB(16,12,26),
}

local TI_Fast   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_Smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,520,0,500); Main.Position = UDim2.new(0.5,-260,0.5,-250)
Main.BackgroundColor3 = P.BG; Main.Active = true; Main.Draggable = true
Main.Visible = true; Main.ClipsDescendants = true; Main.Parent = SGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)
local MainStroke = Instance.new("UIStroke", Main); MainStroke.Color = P.Border; MainStroke.Thickness = 1.5; MainStroke.Transparency = 0.3

local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1,0,0,52); TopBar.BackgroundColor3 = P.BG2; TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0,14)
local TopFix = Instance.new("Frame", TopBar)
TopFix.Size = UDim2.new(1,0,0,14); TopFix.Position = UDim2.new(0,0,1,-14)
TopFix.BackgroundColor3 = P.BG2; TopFix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(0,300,1,0); Title.Position = UDim2.new(0,18,0,0)
Title.BackgroundTransparency = 1; Title.Text = "☾  EVENTIDE"
Title.TextColor3 = P.Accent2; Title.Font = Enum.Font.GothamBold; Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left

local VerBadge = Instance.new("Frame", TopBar)
VerBadge.Size = UDim2.new(0,70,0,20); VerBadge.Position = UDim2.new(0,148,0.5,-10)
VerBadge.BackgroundColor3 = P.Accent; VerBadge.BorderSizePixel = 0
Instance.new("UICorner", VerBadge).CornerRadius = UDim.new(0,6)
local VerText = Instance.new("TextLabel", VerBadge)
VerText.Size = UDim2.new(1,0,1,0); VerText.BackgroundTransparency = 1
VerText.Text = "v3.7 🔥"; VerText.TextColor3 = Color3.new(1,1,1)
VerText.Font = Enum.Font.GothamBold; VerText.TextSize = 10

local StatusLbl = Instance.new("TextLabel", TopBar)
StatusLbl.Size = UDim2.new(0,300,0,14); StatusLbl.Position = UDim2.new(0,18,1,-18)
StatusLbl.BackgroundTransparency = 1; StatusLbl.Text = "Fixed Silent Aim • Multi-Hook • Camera Lock"
StatusLbl.TextColor3 = P.Dim; StatusLbl.Font = Enum.Font.Gotham; StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0,30,0,30); CloseBtn.Position = UDim2.new(1,-40,0.5,-15)
CloseBtn.BackgroundColor3 = P.Off; CloseBtn.Text = "✕"; CloseBtn.TextColor3 = P.Dim
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 14; CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,8)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0,30,0,30); MinBtn.Position = UDim2.new(1,-76,0.5,-15)
MinBtn.BackgroundColor3 = P.Off; MinBtn.Text = "—"; MinBtn.TextColor3 = P.Dim
MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 14; MinBtn.BorderSizePixel = 0
MinBtn.AutoButtonColor = false
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,8)
MinBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

local TabBar = Instance.new("Frame", Main)
TabBar.Size = UDim2.new(0,100,1,-58); TabBar.Position = UDim2.new(0,0,0,58)
TabBar.BackgroundColor3 = P.BG2; TabBar.BorderSizePixel = 0

local ContentArea = Instance.new("Frame", Main)
ContentArea.Size = UDim2.new(1,-108,1,-66); ContentArea.Position = UDim2.new(0,104,0,62)
ContentArea.BackgroundTransparency = 1; ContentArea.ClipsDescendants = true

local TabButtons = {}
local ActiveTab = nil

local function CreatePage()
    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Size = UDim2.new(1,0,1,0); page.BackgroundTransparency = 1
    page.ScrollBarThickness = 2; page.ScrollBarImageColor3 = P.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0,0,0,0); page.BorderSizePixel = 0; page.Visible = false
    Instance.new("UIListLayout", page).Padding = UDim.new(0,6)
    local pad = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0,4); pad.PaddingBottom = UDim.new(0,12)
    pad.PaddingLeft = UDim.new(0,4); pad.PaddingRight = UDim.new(0,4)
    return page
end

local tabY = 8
local function CreateTab(icon, name)
    local page = CreatePage()
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(1,-12,0,38); btn.Position = UDim2.new(0,6,0,tabY)
    btn.BackgroundColor3 = P.TabOff; btn.Text = ""; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    local iconLbl = Instance.new("TextLabel", btn)
    iconLbl.Size = UDim2.new(0,28,1,0); iconLbl.Position = UDim2.new(0,4,0,0)
    iconLbl.BackgroundTransparency = 1; iconLbl.Text = icon
    iconLbl.TextColor3 = P.Dim; iconLbl.Font = Enum.Font.Gotham; iconLbl.TextSize = 14

    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1,-32,1,0); nameLbl.Position = UDim2.new(0,30,0,0)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = name
    nameLbl.TextColor3 = P.Dim; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 10
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local indicator = Instance.new("Frame", btn)
    indicator.Size = UDim2.new(0,3,0.5,0); indicator.Position = UDim2.new(0,0,0.25,0)
    indicator.BackgroundColor3 = P.Accent2; indicator.BackgroundTransparency = 1; indicator.BorderSizePixel = 0
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1,0)

    local function Activate()
        for _, tb in ipairs(TabButtons) do
            TS:Create(tb.btn, TI_Smooth, {BackgroundColor3=P.TabOff}):Play()
            TS:Create(tb.icon, TI_Smooth, {TextColor3=P.Dim}):Play()
            TS:Create(tb.name, TI_Smooth, {TextColor3=P.Dim}):Play()
            TS:Create(tb.indicator, TI_Smooth, {BackgroundTransparency=1}):Play()
            tb.page.Visible = false
        end
        TS:Create(btn, TI_Smooth, {BackgroundColor3=P.Card2}):Play()
        TS:Create(iconLbl, TI_Smooth, {TextColor3=P.Accent2}):Play()
        TS:Create(nameLbl, TI_Smooth, {TextColor3=P.White}):Play()
        TS:Create(indicator, TI_Smooth, {BackgroundTransparency=0}):Play()
        page.Visible = true; ActiveTab = name
    end

    btn.MouseButton1Click:Connect(Activate)
    table.insert(TabButtons, {btn=btn,icon=iconLbl,name=nameLbl,indicator=indicator,page=page,activate=Activate})
    tabY = tabY + 44
    return page, Activate
end

local function SectionHeader(par, title)
    local hdr = Instance.new("Frame", par); hdr.Size = UDim2.new(1,0,0,26); hdr.BackgroundTransparency = 1
    local dot = Instance.new("Frame", hdr)
    dot.Size = UDim2.new(0,4,0,14); dot.Position = UDim2.new(0,2,0.5,-7)
    dot.BackgroundColor3 = P.Accent2; dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local lbl = Instance.new("TextLabel", hdr)
    lbl.Size = UDim2.new(1,-14,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = title; lbl.TextColor3 = P.White
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function Toggle(par, lbl, key, cb)
    local f = Instance.new("Frame", par)
    f.Size = UDim2.new(1,0,0,32); f.BackgroundColor3 = P.Card; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.7,0,1,0); l.Position = UDim2.new(0,14,0,0)
    l.BackgroundTransparency = 1; l.Text = lbl; l.TextColor3 = P.White
    l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("Frame", f)
    sw.Size = UDim2.new(0,38,0,20); sw.Position = UDim2.new(1,-50,0.5,-10)
    sw.BackgroundColor3 = CFG[key] and P.Accent or P.Off; sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1,0)
    local kn = Instance.new("Frame", sw)
    kn.Size = UDim2.new(0,14,0,14)
    kn.Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    kn.BackgroundColor3 = CFG[key] and Color3.new(1,1,1) or P.OffKnob; kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1,0)
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1; bt.Text = ""; bt.AutoButtonColor = false
    bt.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TS:Create(sw, TI_Smooth, {BackgroundColor3 = CFG[key] and P.Accent or P.Off}):Play()
        TS:Create(kn, TI_Smooth, {
            Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
            BackgroundColor3 = CFG[key] and Color3.new(1,1,1) or P.OffKnob
        }):Play()
        if cb then cb(CFG[key]) end
    end)
end

local function Slider(par, lbl, key, mn, mx, dc, cb)
    dc = dc or 0
    local f = Instance.new("Frame", par); f.Size = UDim2.new(1,0,0,48)
    f.BackgroundColor3 = P.Card; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.55,0,0,22); l.Position = UDim2.new(0,14,0,4)
    l.BackgroundTransparency = 1; l.Text = lbl; l.TextColor3 = P.White
    l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    local vl = Instance.new("TextLabel", f)
    vl.Size = UDim2.new(0.4,0,0,22); vl.Position = UDim2.new(0.58,0,0,4)
    vl.BackgroundTransparency = 1; vl.TextColor3 = P.Accent2
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 11; vl.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("Frame", f)
    track.Size = UDim2.new(1,-28,0,6); track.Position = UDim2.new(0,14,0,32)
    track.BackgroundColor3 = P.Off; track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", track); fill.BackgroundColor3 = P.Accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0,14,0,14); thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.ZIndex = 5; thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    local function U()
        local pct = math.clamp((CFG[key]-mn)/(mx-mn),0,1)
        fill.Size = UDim2.new(pct,0,1,0); thumb.Position = UDim2.new(pct,-7,0.5,-7)
        vl.Text = dc > 0 and string.format("%."..dc.."f", CFG[key]) or tostring(math.floor(CFG[key]))
    end
    U()
    local dr = false
    track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dr = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dr = false end end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((i.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local raw = mn + (mx-mn)*pct
            CFG[key] = dc > 0 and math.floor(raw*10^dc+0.5)/10^dc or math.floor(raw+0.5)
            U(); if cb then cb(CFG[key]) end
        end
    end)
end

local function Button(par, lbl, cb, col)
    local b = Instance.new("TextButton", par)
    b.Size = UDim2.new(1,0,0,32); b.BackgroundColor3 = col or P.Card2
    b.TextColor3 = P.White; b.Font = Enum.Font.GothamBold; b.TextSize = 11
    b.Text = lbl; b.BorderSizePixel = 0; b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    b.MouseButton1Click:Connect(cb)
end

local function Label(par, txt, col)
    local l = Instance.new("TextLabel", par)
    l.Size = UDim2.new(1,0,0,16); l.BackgroundTransparency = 1; l.Text = txt
    l.TextColor3 = col or P.Dim; l.Font = Enum.Font.Gotham; l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
end

local function Spacer(par, h)
    local s = Instance.new("Frame", par); s.Size = UDim2.new(1,0,0,h or 6); s.BackgroundTransparency = 1
end

-- TAB 1: AIM
local p1, act1 = CreateTab("💀", "Aim")
SectionHeader(p1, "🔥 SILENT AIM v3.7")
Label(p1, "Держи ПКМ — стреляй куда угодно", P.Green)
Label(p1, "Если не работает — включи Camera Lock", P.Yellow)
Spacer(p1)
Toggle(p1, "Enable Silent Aim", "SilentAim")
Toggle(p1, "Camera Lock (Fallback)", "CameraLock")
Toggle(p1, "Hold to Aim (по кнопке)", "HoldToAim")
Toggle(p1, "Only When Shooting", "OnlyWhenShooting")
Toggle(p1, "Require Gun (нужно оружие)", "RequireGun")
Spacer(p1, 4)

local aimBtnFrame = Instance.new("Frame", p1)
aimBtnFrame.Size = UDim2.new(1,0,0,32)
aimBtnFrame.BackgroundColor3 = P.Card
aimBtnFrame.BorderSizePixel = 0
Instance.new("UICorner", aimBtnFrame).CornerRadius = UDim.new(0,8)

local aimBtnLbl = Instance.new("TextLabel", aimBtnFrame)
aimBtnLbl.Size = UDim2.new(0.5,0,1,0); aimBtnLbl.Position = UDim2.new(0,14,0,0)
aimBtnLbl.BackgroundTransparency = 1; aimBtnLbl.Text = "Aim Button"
aimBtnLbl.TextColor3 = P.White; aimBtnLbl.Font = Enum.Font.Gotham
aimBtnLbl.TextSize = 11; aimBtnLbl.TextXAlignment = Enum.TextXAlignment.Left

local function MakeMouseBtn(x, name, cfgVal)
    local b = Instance.new("TextButton", aimBtnFrame)
    b.Size = UDim2.new(0, 50, 0, 22); b.Position = UDim2.new(1, x, 0.5, -11)
    b.BackgroundColor3 = CFG.AimButton == cfgVal and P.Accent or P.Off
    b.Text = name; b.TextColor3 = P.White
    b.Font = Enum.Font.GothamBold; b.TextSize = 10
    b.BorderSizePixel = 0; b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end

local btnL = MakeMouseBtn(-170, "LMB", "Left")
local btnR = MakeMouseBtn(-115, "RMB", "Right")
local btnM = MakeMouseBtn(-60,  "MMB", "Middle")

local function UpdateMouseBtns()
    TS:Create(btnL, TI_Fast, {BackgroundColor3 = CFG.AimButton == "Left" and P.Accent or P.Off}):Play()
    TS:Create(btnR, TI_Fast, {BackgroundColor3 = CFG.AimButton == "Right" and P.Accent or P.Off}):Play()
    TS:Create(btnM, TI_Fast, {BackgroundColor3 = CFG.AimButton == "Middle" and P.Accent or P.Off}):Play()
end

btnL.MouseButton1Click:Connect(function() CFG.AimButton = "Left"; UpdateMouseBtns() end)
btnR.MouseButton1Click:Connect(function() CFG.AimButton = "Right"; UpdateMouseBtns() end)
btnM.MouseButton1Click:Connect(function() CFG.AimButton = "Middle"; UpdateMouseBtns() end)

Spacer(p1, 6)
Toggle(p1, "Auto Prediction", "AutoPred")
Toggle(p1, "Ping Compensation", "PingComp")
Toggle(p1, "Acceleration Comp", "AccelComp")
Toggle(p1, "Gravity Comp", "GravityComp")
Toggle(p1, "Anti-Jitter", "AntiJitter")
Spacer(p1, 8)
SectionHeader(p1, "FILTERS")
Toggle(p1, "Team Check", "TeamCheck")
Toggle(p1, "Ignore Downed", "NoDowned")
Toggle(p1, "Visible Check", "VisCheck")
Spacer(p1, 8)
SectionHeader(p1, "SETTINGS")
Slider(p1, "FOV", "FOV", 30, 500, 0)
Slider(p1, "Prediction (Manual)", "Prediction", 0.05, 0.30, 3)
Slider(p1, "Pred Multiplier", "PredMult", 0.5, 2.0, 2)
Slider(p1, "Max Distance", "MaxDist", 100, 2500, 0)
Slider(p1, "Snap Radius", "SnapRadius", 2, 20, 0)
Slider(p1, "Camera Lock Smoothness", "CamLockSmooth", 0.05, 1.0, 2)

-- TAB 2: HITBOX
local p2 = CreateTab("🎯", "Hitbox")
SectionHeader(p2, "💀 HITBOX EXPANDER")
Toggle(p2, "Enable Hitbox Expander", "HitboxExpander")
Toggle(p2, "Show Hitbox Visual", "ShowHitbox")
Spacer(p2, 6)
Slider(p2, "Head Size", "HitboxSize", 1, 20, 1)
Slider(p2, "Hitbox Transparency", "HitboxTransp", 0, 1, 2)
Spacer(p2, 8)
Button(p2, "🔄  Reset All Hitboxes", function() ResetAllHitboxes() end)
Spacer(p2, 3)
Button(p2, "👤  NORMAL (1)", function() CFG.HitboxSize = 1 end)
Spacer(p2, 3)
Button(p2, "⚡  BALANCED (6)", function() CFG.HitboxSize = 6; CFG.HitboxExpander = true end)
Spacer(p2, 3)
Button(p2, "🔥  LARGE (10)", function() CFG.HitboxSize = 10; CFG.HitboxExpander = true end, Color3.fromRGB(50, 30, 20))
Spacer(p2, 3)
Button(p2, "💀  MAX SIZE (20)", function() CFG.HitboxSize = 20; CFG.HitboxExpander = true end, Color3.fromRGB(60, 20, 60))

-- TAB 3: ESP
local p3 = CreateTab("👁", "ESP")
SectionHeader(p3, "ESP ELEMENTS")
Toggle(p3, "Enable ESP", "ESP")
Toggle(p3, "Boxes", "Boxes"); Toggle(p3, "Names", "Names")
Toggle(p3, "Health Bar", "HP"); Toggle(p3, "Distance", "Dist")
Toggle(p3, "Head Dot", "HeadDot"); Toggle(p3, "Tracers", "Tracers")
Spacer(p3, 10)
SectionHeader(p3, "VISUALS")
Toggle(p3, "FOV Circle", "ShowFOV"); Toggle(p3, "Prediction Dot", "ShowPred")
Toggle(p3, "Rainbow FOV", "Rainbow"); Toggle(p3, "Debug Info", "Debug")

-- TAB 4: INFO
local p4 = CreateTab("ℹ️", "Info")
SectionHeader(p4, "☾ EVENTIDE v3.7")
Spacer(p4)
Label(p4, "FIXED SILENT AIM EDITION", P.Accent2)
Spacer(p4, 6)
SectionHeader(p4, "🔥 НОВОЕ В v3.7")
Label(p4, "✅ Убран строгий фильтр оружия", P.Green)
Label(p4, "✅ Camera Lock (Fallback) для слабых эксплоитов", P.Green)
Label(p4, "✅ +Hook на workspace.Raycast", P.Green)
Label(p4, "✅ Улучшенный debug (2 строки)", P.Green)
Label(p4, "✅ Определение возможностей эксплоита", P.Green)
Spacer(p4, 8)
SectionHeader(p4, "🎮 КАК ИСПОЛЬЗОВАТЬ")
Label(p4, "1. Возьми оружие", P.White)
Label(p4, "2. Держи ПКМ на цели", P.White)
Label(p4, "3. Стреляй ЛКМ — попадёшь в голову", P.White)
Label(p4, "", P.White)
Label(p4, "⚠️ Если не работает:", P.Yellow)
Label(p4, "→ Включи Camera Lock (F5)", P.Green)
Label(p4, "→ Отключи Require Gun", P.Green)
Label(p4, "→ Отключи Hold to Aim", P.Green)
Spacer(p4, 8)
SectionHeader(p4, "⌨️ КЛАВИШИ")
Label(p4, "INSERT — открыть меню", P.White)
Label(p4, "F2 — Silent Aim ON/OFF", P.White)
Label(p4, "F3 — ESP ON/OFF", P.White)
Label(p4, "F4 — Hitbox ON/OFF", P.White)
Label(p4, "F5 — Camera Lock ON/OFF", P.Accent2)
Label(p4, "F1 — 🚨 PANIC", P.Red)
Label(p4, "END — Unload", P.White)
Spacer(p4, 10)
Button(p4, "🗑️ UNLOAD EVENTIDE", function()
    ResetAllHitboxes()
    pcall(function() FOVd:Remove(); PD:Remove(); DB:Remove(); DB2:Remove() end)
    for px in pairs(ESPObj) do KillESP(px) end
    getgenv()._EV_XS = nil
    pcall(function() SGui:Destroy() end)
end, P.Red)

act1()

Main.Size = UDim2.new(0,520,0,0); Main.Visible = true
TS:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0,520,0,500)
}):Play()

-- HOTKEYS
UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local keyName = i.KeyCode.Name

    if keyName == CFG.KeyMenu then
        if Main.Visible then
            Main.Visible = false
        else
            Main.Size = UDim2.new(0,520,0,0); Main.Visible = true
            TS:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0,520,0,500)
            }):Play()
        end
    end
    if keyName == CFG.KeyAim then
        CFG.SilentAim = not CFG.SilentAim
        Notify("☾ Silent Aim", CFG.SilentAim and "💀 ON" or "❌ OFF", 2)
    end
    if keyName == CFG.KeyESP then
        CFG.ESP = not CFG.ESP
        Notify("☾ ESP", CFG.ESP and "✅ ON" or "❌ OFF", 2)
    end
    if keyName == CFG.KeyHitbox then
        CFG.HitboxExpander = not CFG.HitboxExpander
        Notify("☾ Hitbox", CFG.HitboxExpander and ("💀 ON ("..CFG.HitboxSize..")") or "❌ OFF", 2)
    end
    if keyName == CFG.KeyCamLock then
        CFG.CameraLock = not CFG.CameraLock
        Notify("☾ Camera Lock", CFG.CameraLock and "📷 ON" or "❌ OFF", 2)
    end
    if keyName == CFG.KeyPanic then
        CFG.SilentAim = false; CFG.ESP = false; CFG.HitboxExpander = false
        CFG.ShowFOV = false; CFG.ShowPred = false; CFG.CameraLock = false
        ResetAllHitboxes()
        Notify("☾ PANIC", "🚨 ВСЁ ВЫКЛЮЧЕНО", 3)
    end
    if keyName == CFG.KeyUnload then
        ResetAllHitboxes()
        pcall(function() FOVd:Remove(); PD:Remove(); DB:Remove(); DB2:Remove() end)
        for px in pairs(ESPObj) do KillESP(px) end
        getgenv()._EV_XS = nil
        pcall(function() SGui:Destroy() end)
    end
end)

Notify("☾ EVENTIDE v3.7", "🔥 Fixed Silent Aim!\nДержи ПКМ + стреляй", 5)