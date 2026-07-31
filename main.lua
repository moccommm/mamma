-- ===============================================
--   ☾ EVENTIDE v5.3 — VERTEX-STYLE FIXED
--   Silent Aim + Head Magnet + Camera Lock + Auto Hitbox
--   FIX: Тела больше не зависают после смерти
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
    AimMode          = "Both",
    Enable           = true,
    FOV              = 200,
    HoldToAim        = true,
    AimButton        = "Right",
    OnlyWhenShooting = false,
    RequireGun       = false,
    TeamCheck        = false,
    NoDowned         = true,
    VisCheck         = false,
    MaxDist          = 2000,

    Prediction       = 0.135,
    PredMult         = 1.0,
    AutoPred         = true,
    PingComp         = true,
    AccelComp        = true,
    GravityComp      = true,
    AntiJitter       = true,
    SnapRadius       = 10,

    MagnetMode       = "Mouse",
    UseHRP           = true,

    CameraLock       = false,
    CamLockSmooth    = 0.35,

    AutoHitbox       = false,
    HitboxSize       = 15,
    HitboxTransp     = 0.7,
    ShowHitbox       = true,
    HitboxPart       = "Head",

    ESP       = true,
    Boxes     = true,
    Names     = true,
    HP        = true,
    Dist      = true,
    Tracers   = false,
    HeadDot   = true,

    ShowFOV    = true,
    ShowTarget = true,
    Rainbow    = false,
    FOVCol     = Color3.fromRGB(88, 101, 242),
    Debug      = true,

    KeyMenu    = "Insert",
    KeyAim     = "F2",
    KeyESP     = "F3",
    KeyHitbox  = "F4",
    KeyCamLock = "F5",
    KeyPanic   = "F1",
    KeyUnload  = "End",
}

local Target          = nil
local cachedPred      = nil
local ESPObj          = {}
local VelHist         = {}
local PosHist         = {}
local SpawnTimes      = {}
local HeadOffsetCache = {}
local OrigData        = {}
local DEFAULT_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local SPAWN_GRACE     = 0.5
local OFFSET_SETTLE   = 0.3
local RH              = 0
local curPred         = 0.135
local isShooting      = false
local isHolding       = false
local magnetActive    = false
local hookStatus      = "Loading..."
local hooksInstalled  = 0
local exploitInfo     = ""

-- ==================== EXPLOIT DETECTION ====================
task.spawn(function()
    local features = {}
    if hookfunc then table.insert(features, "hookfunc") end
    if getrawmt then table.insert(features, "getrawmt") end
    if setreadonly then table.insert(features, "setrw") end
    if newcclosure then table.insert(features, "newccl") end
    exploitInfo = table.concat(features, "|")
end)

-- ==================== UTILS ====================
local function GetPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and v or 80
end

local function GetRoot(p) local c = p and p.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHead(p) local c = p and p.Character; return c and c:FindFirstChild("Head") end
local function GetHum(p)  local c = p and p.Character; return c and c:FindFirstChildOfClass("Humanoid") end

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

local function IsAlive(p)
    if not p or not p.Parent then return false end
    local c = p.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not c:FindFirstChild("Head") then return false end
    if not c:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

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
    if name:find("anti") or name:find("cheat") or name:find("guard") then return false end
    return true
end

local function IsValid(p)
    if p == LP then return false end
    if not IsAlive(p) then return false end
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
            if WS:Raycast(myRoot.Position, (th.Position - myRoot.Position), par) then return false end
        end
    end
    return true
end

-- ==================== VELOCITY HISTORY ====================
RS.Heartbeat:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local st = SpawnTimes[p]
            if st and (tick() - st) < OFFSET_SETTLE then continue end
            local r = GetRoot(p); local h = GetHead(p)
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
                table.insert(PosHist[p], 1, {pos=h.Position,root=r.Position,vel=r.AssemblyLinearVelocity,time=tick()})
                if #PosHist[p] > 20 then table.remove(PosHist[p]) end
            end
        end
    end
end)

-- ==================== PREDICTION ====================
local function GetSmoothedVelocity(plr)
    local h = VelHist[plr]
    if not h or #h == 0 then
        local r = GetRoot(plr); return r and r.AssemblyLinearVelocity or Vector3.zero
    end
    if #h < 3 then return h[1] end
    local sm, tw = Vector3.zero, 0
    local count = math.min(#h, 8)
    for i = 1, count do
        local w = (count - i + 1) / count; w = w * w
        sm = sm + h[i] * w; tw = tw + w
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
    local head = GetHead(plr); local root = GetRoot(plr); local hum = GetHum(plr)
    if not head or not root then return nil end
    local st = SpawnTimes[plr]
    if st and (tick() - st) < SPAWN_GRACE then return head.Position end
    local velHistory = VelHist[plr]
    if not velHistory or #velHistory < 3 then return head.Position end
    local pred = CFG.AutoPred and CalcAutoPrediction() or (CFG.Prediction * CFG.PredMult)
    curPred = pred
    local vel = GetSmoothedVelocity(plr)
    if vel.Magnitude < 3 then return head.Position end
    local predictedRoot = root.Position + Vector3.new(vel.X * pred, 0, vel.Z * pred)
    if CFG.AccelComp then
        local acc = GetAcceleration(plr)
        predictedRoot = predictedRoot + Vector3.new(acc.X * pred * pred * 0.5, 0, acc.Z * pred * pred * 0.5)
    end
    if CFG.GravityComp and hum then
        local state = hum:GetState()
        local g = WS.Gravity or 196.2
        if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
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
            headOffset = liveOffset; HeadOffsetCache[plr] = headOffset
        else headOffset = DEFAULT_HEAD_OFFSET end
    end
    local finalHead = predictedRoot + headOffset
    local maxOffset = vel.Magnitude * pred * 2 + CFG.SnapRadius
    local diff = finalHead - head.Position
    if diff.Magnitude > maxOffset then finalHead = head.Position + diff.Unit * maxOffset end
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
                    if d < CFG.FOV and d < bd then bd = d; best = p end
                end
            end
        end
    end
    return best
end

RS.Heartbeat:Connect(function()
    if Target and not IsAlive(Target) then
        Target = nil; cachedPred = nil; magnetActive = false
    end
    if not isHolding or not Target then Target = GetTarget() end
    if Target and CFG.Enable and CFG.AimMode ~= "Off" then
        cachedPred = GetHeadPosition100(Target)
    else cachedPred = nil end
end)

-- ==================== INPUT ====================
local function GetAimButtonEnum()
    if CFG.AimButton == "Right" then return Enum.UserInputType.MouseButton2
    elseif CFG.AimButton == "Middle" then return Enum.UserInputType.MouseButton3
    else return Enum.UserInputType.MouseButton1 end
end

UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then isShooting = true end
    if i.UserInputType == GetAimButtonEnum() then
        isHolding = true; Target = GetTarget()
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then isShooting = false end
    if i.UserInputType == GetAimButtonEnum() then
        isHolding = false; Target = nil; cachedPred = nil; magnetActive = false
    end
end)

-- ==================================================================
--   AUTO HITBOX (FIX: тела больше не зависают)
-- ==================================================================
local function SaveOriginal(plr, partName, part)
    if not OrigData[plr] then OrigData[plr] = {} end
    if OrigData[plr][partName] then return end
    OrigData[plr][partName] = {
        size = part.Size, transp = part.Transparency, canCol = part.CanCollide,
        mat = part.Material, col = part.Color, massless = part.Massless,
    }
end

local function ExpandPart(plr)
    if plr == LP then return end
    local char = plr and plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local part = char:FindFirstChild(CFG.HitboxPart); if not part then return end
    SaveOriginal(plr, CFG.HitboxPart, part)
    local s = CFG.HitboxSize
    pcall(function()
        part.Size = Vector3.new(s, s, s)
        part.Transparency = CFG.ShowHitbox and CFG.HitboxTransp or 1
        part.CanCollide = false; part.Massless = true
        part.Material = Enum.Material.ForceField
        part.Color = Color3.fromRGB(88, 101, 242)
    end)
end

-- ФИКС: возвращаем нормальную физику (CanCollide=true, Massless=false)
local function ResetPart(plr)
    local char = plr and plr.Character
    if not char then OrigData[plr] = nil; return end
    if OrigData[plr] then
        for partName, orig in pairs(OrigData[plr]) do
            local part = char:FindFirstChild(partName)
            if part then
                pcall(function()
                    part.Size = orig.size
                    part.Transparency = orig.transp
                    part.CanCollide = true         -- ФИКС: возвращаем физику
                    part.Massless = false           -- ФИКС: возвращаем массу
                    part.Material = orig.mat or Enum.Material.Plastic
                    part.Color = orig.col or Color3.fromRGB(163, 162, 165)
                end)
            end
        end
    end
    OrigData[plr] = nil
end

-- Аварийный сброс парта (даже без сохранённых данных)
local function ForceRestorePart(char, partName)
    if not char then return end
    local part = char:FindFirstChild(partName)
    if not part then return end
    pcall(function()
        part.CanCollide = true
        part.Massless = false
        part.Material = Enum.Material.Plastic
        part.Color = Color3.fromRGB(163, 162, 165)
        if partName == "Head" then
            part.Size = Vector3.new(2, 1, 1)
            part.Transparency = 0
        elseif partName == "HumanoidRootPart" then
            part.Size = Vector3.new(2, 2, 1)
            part.Transparency = 1
        end
    end)
end

local function ResetAllParts()
    for _, plr in ipairs(Players:GetPlayers()) do 
        if plr ~= LP then
            ResetPart(plr)
            local char = plr.Character
            if char then
                ForceRestorePart(char, "Head")
                ForceRestorePart(char, "HumanoidRootPart")
            end
        end
    end
    OrigData = {}
end

-- Auto Hitbox Heartbeat
RS.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then 
            if OrigData[plr] then OrigData[plr] = nil end
            continue 
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local part = char:FindFirstChild(CFG.HitboxPart)
        
        -- КРИТИЧЕСКИЙ ФИКС: враг мёртв → срочно восстанавливаем физику
        if not hum or hum.Health <= 0 then
            if OrigData[plr] then 
                ResetPart(plr)
            end
            -- Аварийная защита от зависания (даже если данных не было)
            if part and (part.Massless or not part.CanCollide) then
                pcall(function()
                    part.CanCollide = true
                    part.Massless = false
                end)
            end
            continue
        end
        
        if not CFG.AutoHitbox then
            if OrigData[plr] and part then ResetPart(plr) end
            continue
        end
        
        if part then
            local s = CFG.HitboxSize
            if math.abs(part.Size.X - s) > 0.5 then
                OrigData[plr] = nil
                ExpandPart(plr)
            else
                pcall(function()
                    part.Transparency = CFG.ShowHitbox and CFG.HitboxTransp or 1
                    part.CanCollide = false
                    part.Massless = true
                end)
            end
        end
    end
end)

-- ==================== HEAD MAGNET ====================
RS.RenderStepped:Connect(function()
    Cam = WS.CurrentCamera
    if not CFG.Enable then magnetActive = false; return end
    if CFG.AimMode ~= "HeadMagnet" and CFG.AimMode ~= "Both" then magnetActive = false; return end
    local shouldMagnet = (not CFG.HoldToAim or isHolding) and (not CFG.OnlyWhenShooting or isShooting)
    if not shouldMagnet or not Target or not Target.Parent then magnetActive = false; return end
    local char = Target.Character
    if not char or not char.Parent then magnetActive = false; return end
    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not head or not root or not hum or hum.Health <= 0 then magnetActive = false; return end
    magnetActive = true
    local camPos = Cam.CFrame.Position
    local aimDir
    if CFG.MagnetMode == "Mouse" then aimDir = (Mouse.Hit.Position - camPos).Unit
    else aimDir = Cam.CFrame.LookVector end
    local dist = (head.Position - camPos).Magnitude
    dist = math.clamp(dist, 5, CFG.MaxDist)
    local targetPos = camPos + aimDir * dist
    pcall(function()
        if CFG.UseHRP then
            local headOffset = head.Position - root.Position
            root.CFrame = CFrame.new(targetPos - headOffset)
        else head.CFrame = CFrame.new(targetPos) end
    end)
end)

-- ==================== RESPAWN HOOKS (FIX) ====================
local function OnPlayerDied(plr)
    if Target == plr then Target = nil; cachedPred = nil; magnetActive = false end
    -- КРИТИЧЕСКИ ВАЖНО: сначала сбрасываем парт (чтобы тело падало)
    ResetPart(plr)
    -- Аварийное восстановление физики
    local char = plr.Character
    if char then
        ForceRestorePart(char, "Head")
        ForceRestorePart(char, "HumanoidRootPart")
    end
    VelHist[plr] = {}; PosHist[plr] = {}; HeadOffsetCache[plr] = nil
end

local function HookCharacter(plr, char)
    if plr == LP then return end
    if Target == plr then Target = nil; cachedPred = nil; magnetActive = false end
    OrigData[plr] = nil; VelHist[plr] = {}; PosHist[plr] = {}; HeadOffsetCache[plr] = nil
    SpawnTimes[plr] = tick()
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 15)
        local root = char:WaitForChild("HumanoidRootPart", 15)
        local head = char:WaitForChild("Head", 15)
        if not hum or not root or not head then return end
        task.wait(OFFSET_SETTLE)
        local offset = head.Position - root.Position
        HeadOffsetCache[plr] = (offset.Magnitude > 0.3 and offset.Magnitude < 5) and offset or DEFAULT_HEAD_OFFSET
        task.wait(0.4)
        if CFG.AutoHitbox and hum.Health > 0 then ExpandPart(plr) end
        hum.Died:Connect(function() OnPlayerDied(plr) end)
    end)
end

local function BindPlayer(plr)
    if plr == LP then return end
    plr.CharacterAdded:Connect(function(char) HookCharacter(plr, char) end)
    plr.CharacterRemoving:Connect(function()
        if Target == plr then Target = nil; cachedPred = nil; magnetActive = false end
        OrigData[plr] = nil
    end)
    if plr.Character then HookCharacter(plr, plr.Character) end
end

for _, plr in ipairs(Players:GetPlayers()) do BindPlayer(plr) end
Players.PlayerAdded:Connect(BindPlayer)
Players.PlayerRemoving:Connect(function(plr)
    if Target == plr then Target = nil; cachedPred = nil; magnetActive = false end
    OrigData[plr] = nil; VelHist[plr] = nil; PosHist[plr] = nil
    SpawnTimes[plr] = nil; HeadOffsetCache[plr] = nil
end)

-- ==================== SILENT AIM HOOKS ====================
local function ShouldSpoof()
    if not CFG.Enable then return false end
    if CFG.AimMode ~= "SilentAim" and CFG.AimMode ~= "Both" then return false end
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
    if not hookfunc then hookStatus = "No hookfunc"; return end
    pcall(function()
        local orig; orig = hookfunc(Cam.ViewportPointToRay, newccl(function(self, x, y, ...)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then local wp = self:WorldToViewportPoint(hp)
                    if wp.Z > 0 then return orig(self, wp.X, wp.Y, ...) end end
            end
            return orig(self, x, y, ...)
        end)); installed += 1
    end)
    pcall(function()
        local orig; orig = hookfunc(Cam.ScreenPointToRay, newccl(function(self, x, y, ...)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then local wp, vis = self:WorldToScreenPoint(hp)
                    if vis then return orig(self, wp.X, wp.Y, ...) end end
            end
            return orig(self, x, y, ...)
        end)); installed += 1
    end)
    pcall(function()
        local orig; orig = hookfunc(UIS.GetMouseLocation, newccl(function(self)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                if hp then local wp = Cam:WorldToViewportPoint(hp)
                    if wp.Z > 0 then return Vector2.new(wp.X, wp.Y) end end
            end
            return orig(self)
        end)); installed += 1
    end)
    pcall(function()
        if not getrawmt then return end
        local mt = getrawmt(Mouse); if not mt then return end
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
                        return Ray.new(origin, (hp - origin).Unit)
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
    pcall(function()
        local orig; orig = hookfunc(WS.Raycast, newccl(function(self, origin, direction, params, ...)
            if ShouldSpoof() and typeof(direction) == "Vector3" then
                local hp = GetFreshHeadPos()
                if hp and typeof(origin) == "Vector3" then
                    return orig(self, origin, (hp - origin).Unit * direction.Magnitude, params, ...)
                end
            end
            return orig(self, origin, direction, params, ...)
        end)); installed += 1
    end)
    hooksInstalled = installed
    hookStatus = installed > 0 and (installed .. " hooks") or "0 hooks"
end)

-- ==================== CAMERA LOCK ====================
RS.RenderStepped:Connect(function()
    Cam = WS.CurrentCamera
    if not CFG.Enable then return end
    if CFG.CameraLock and Target and cachedPred and (not CFG.HoldToAim or isHolding) then
        local myRoot = GetRoot(LP)
        if myRoot then
            local currentCF = Cam.CFrame
            local targetCF = CFrame.new(currentCF.Position, cachedPred)
            Cam.CFrame = currentCF:Lerp(targetCF, CFG.CamLockSmooth)
        end
    end
end)

-- ==================== ESP DRAWINGS ====================
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

local TargetDot = Drawing.new("Circle")
TargetDot.Filled = true; TargetDot.Radius = 6; TargetDot.NumSides = 16

local DB = Drawing.new("Text")
DB.Size = 14; DB.Outline = true; DB.Font = 2; DB.Color = Color3.fromRGB(200,200,255)

local DB2 = Drawing.new("Text")
DB2.Size = 12; DB2.Outline = true; DB2.Font = 2; DB2.Color = Color3.fromRGB(150,150,200)

local function CountHitboxes()
    local c = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and OrigData[plr] then c = c + 1 end
    end
    return c
end

local et = 0
RS.RenderStepped:Connect(function(dt)
    Cam = WS.CurrentCamera
    RH  = (RH + 0.002) % 1
    local sc = Cam.ViewportSize / 2

    FOVd.Visible  = CFG.ShowFOV
    FOVd.Radius   = CFG.FOV
    FOVd.Position = sc
    FOVd.Color    = CFG.Rainbow and Color3.fromHSV(RH,0.8,1)
        or (magnetActive and Color3.fromRGB(0,255,140)
        or (isHolding and Color3.fromRGB(0,255,140) or (isShooting and Color3.fromRGB(255,60,180) or CFG.FOVCol)))

    if cachedPred and CFG.ShowTarget and Target then
        local sp = Cam:WorldToViewportPoint(cachedPred)
        TargetDot.Visible = sp.Z > 0
        TargetDot.Position = Vector2.new(sp.X, sp.Y)
        TargetDot.Color = magnetActive and Color3.fromRGB(0,255,100)
            or (isHolding and Color3.fromRGB(0,255,140) or Color3.fromRGB(88,101,242))
        TargetDot.Radius = (isHolding or magnetActive) and 8 or 5
    else TargetDot.Visible = false end

    if CFG.Debug then
        DB.Visible = true; DB2.Visible = true
        local tn = Target and Target.Name or "—"
        local sh = isShooting and "SHOOT" or "—"
        local aim = isHolding and "HOLD" or "—"
        local mg = magnetActive and "MAGNET" or "—"
        local en = CFG.Enable and "ON" or "OFF"
        local hbc = CountHitboxes()
        DB.Text = string.format("EVENTIDE v5.3 [%s]  MODE:%s  TGT:%s  %s %s %s",
            en, CFG.AimMode, tn, sh, aim, mg)
        DB.Position = Vector2.new(12, 36)
        DB2.Text = string.format("%s  PRED:%dms  PING:%dms  FOV:%d  HB:%d/%d",
            hookStatus, curPred*1000, math.floor(GetPing()), CFG.FOV, hbc, #Players:GetPlayers()-1)
        DB2.Position = Vector2.new(12, 54)
    else DB.Visible = false; DB2.Visible = false end

    et = et + dt
    if et < 0.033 then return end
    et = 0

    local mr = GetRoot(LP)
    if not mr then return end

    for p, e in pairs(ESPObj) do
        pcall(function()
            local function hide() for _, v in pairs(e) do v.Visible = false end end
            if not CFG.ESP or not p.Parent then return hide() end
            if not IsAlive(p) then return hide() end
            local r = GetRoot(p); local h = GetHead(p)
            if not r or not h then return hide() end
            local d = (mr.Position - r.Position).Magnitude
            if d > CFG.MaxDist then return hide() end
            local rp = Cam:WorldToViewportPoint(r.Position)
            local hp = Cam:WorldToViewportPoint(h.Position + Vector3.new(0,0.5,0))
            if rp.Z <= 0 then return hide() end
            local col = (Target == p) and Color3.fromRGB(88,101,242) or Color3.fromRGB(120,130,200)
            local hm = GetHum(p)
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
                e.Name.Visible = true; e.Name.Text = p.Name..(IsDowned(p) and " [DOWN]" or "")
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
--                  GUI
-- ===============================================
local SGui = Instance.new("ScreenGui")
SGui.Name = "Eventide_" .. math.random(100000, 999999)
SGui.ResetOnSpawn = false; SGui.IgnoreGuiInset = true; SGui.DisplayOrder = 999999
pcall(function() SGui.Parent = gethui() or game:GetService("CoreGui") end)
if not SGui.Parent then SGui.Parent = LP:WaitForChild("PlayerGui") end

local V = {
    BG=Color3.fromRGB(28,28,32), Sidebar=Color3.fromRGB(38,38,44),
    Content=Color3.fromRGB(24,24,28), Card=Color3.fromRGB(40,40,46),
    CardHover=Color3.fromRGB(48,48,54), TopBar=Color3.fromRGB(32,32,36),
    Border=Color3.fromRGB(55,55,62), ItemBg=Color3.fromRGB(50,50,58),
    Accent=Color3.fromRGB(88,101,242), White=Color3.fromRGB(240,240,245),
    Text=Color3.fromRGB(220,220,225), Dim=Color3.fromRGB(140,140,150),
    Sub=Color3.fromRGB(110,110,120), Off=Color3.fromRGB(60,60,68),
    OffKnob=Color3.fromRGB(160,160,170), Green=Color3.fromRGB(87,242,135),
    Red=Color3.fromRGB(237,66,69), Yellow=Color3.fromRGB(254,231,92),
    DotRed=Color3.fromRGB(255,95,87), DotYellow=Color3.fromRGB(255,189,46),
    DotGreen=Color3.fromRGB(39,201,63),
}

local TI_Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_Smooth = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,720,0,500); Main.Position = UDim2.new(0.5,-360,0.5,-250)
Main.BackgroundColor3 = V.BG; Main.BorderSizePixel = 0
Main.Active = true; Main.Draggable = true; Main.ClipsDescendants = true; Main.Parent = SGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,12)
local mStroke = Instance.new("UIStroke", Main)
mStroke.Color = V.Border; mStroke.Thickness = 1; mStroke.Transparency = 0.3

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0,220,1,0); Sidebar.BackgroundColor3 = V.Sidebar
Sidebar.BorderSizePixel = 0

local TopBar = Instance.new("Frame", Sidebar)
TopBar.Size = UDim2.new(1,0,0,40); TopBar.BackgroundTransparency = 1

local function MakeDot(x, color)
    local dot = Instance.new("Frame", TopBar)
    dot.Size = UDim2.new(0,12,0,12); dot.Position = UDim2.new(0,x,0.5,-6)
    dot.BackgroundColor3 = color; dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    return dot
end
local dotRed = MakeDot(16, V.DotRed)
local dotYel = MakeDot(34, V.DotYellow)
MakeDot(52, V.DotGreen)

local closeArea = Instance.new("TextButton", dotRed)
closeArea.Size = UDim2.new(1,0,1,0); closeArea.BackgroundTransparency = 1; closeArea.Text = ""
closeArea.MouseButton1Click:Connect(function() Main.Visible = false end)
local minArea = Instance.new("TextButton", dotYel)
minArea.Size = UDim2.new(1,0,1,0); minArea.BackgroundTransparency = 1; minArea.Text = ""
minArea.MouseButton1Click:Connect(function() Main.Visible = false end)

local Brand = Instance.new("Frame", Sidebar)
Brand.Size = UDim2.new(1,-30,0,60); Brand.Position = UDim2.new(0,15,0,50)
Brand.BackgroundTransparency = 1

local BrandName = Instance.new("TextLabel", Brand)
BrandName.Size = UDim2.new(1,-30,0,28); BrandName.BackgroundTransparency = 1
BrandName.Text = "eventide"; BrandName.TextColor3 = V.White
BrandName.Font = Enum.Font.GothamBold; BrandName.TextSize = 22
BrandName.TextXAlignment = Enum.TextXAlignment.Left

local BrandSub = Instance.new("TextLabel", Brand)
BrandSub.Size = UDim2.new(1,-30,0,18); BrandSub.Position = UDim2.new(0,0,0,30)
BrandSub.BackgroundTransparency = 1; BrandSub.Text = "hybrid.aim/v5.3"
BrandSub.TextColor3 = V.Dim; BrandSub.Font = Enum.Font.Gotham; BrandSub.TextSize = 13
BrandSub.TextXAlignment = Enum.TextXAlignment.Left

local Globe = Instance.new("TextLabel", Brand)
Globe.Size = UDim2.new(0,24,0,24); Globe.Position = UDim2.new(1,-24,0,12)
Globe.BackgroundTransparency = 1; Globe.Text = "🌐"
Globe.TextColor3 = V.Dim; Globe.Font = Enum.Font.Gotham; Globe.TextSize = 18

local Menu = Instance.new("Frame", Sidebar)
Menu.Size = UDim2.new(1,-20,1,-190); Menu.Position = UDim2.new(0,10,0,125)
Menu.BackgroundTransparency = 1
local MenuLayout = Instance.new("UIListLayout", Menu)
MenuLayout.Padding = UDim.new(0,4); MenuLayout.SortOrder = Enum.SortOrder.LayoutOrder

local UserCard = Instance.new("Frame", Sidebar)
UserCard.Size = UDim2.new(1,-20,0,54); UserCard.Position = UDim2.new(0,10,1,-64)
UserCard.BackgroundTransparency = 1

local Avatar = Instance.new("ImageLabel", UserCard)
Avatar.Size = UDim2.new(0,38,0,38); Avatar.Position = UDim2.new(0,0,0.5,-19)
Avatar.BackgroundColor3 = Color3.fromRGB(70,70,80); Avatar.BorderSizePixel = 0
Instance.new("UICorner", Avatar).CornerRadius = UDim.new(1,0)
pcall(function()
    Avatar.Image = Players:GetUserThumbnailAsync(LP.UserId,
        Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)

local UserName = Instance.new("TextLabel", UserCard)
UserName.Size = UDim2.new(1,-46,0,18); UserName.Position = UDim2.new(0,46,0,8)
UserName.BackgroundTransparency = 1
local dispName = LP.DisplayName or LP.Name
if #dispName > 18 then dispName = dispName:sub(1,16).."..." end
UserName.Text = dispName; UserName.TextColor3 = V.White
UserName.Font = Enum.Font.GothamBold; UserName.TextSize = 13
UserName.TextXAlignment = Enum.TextXAlignment.Left

local UserTag = Instance.new("TextLabel", UserCard)
UserTag.Size = UDim2.new(1,-46,0,16); UserTag.Position = UDim2.new(0,46,0,28)
UserTag.BackgroundTransparency = 1
local tagName = "@"..LP.Name
if #tagName > 20 then tagName = tagName:sub(1,18).."..." end
UserTag.Text = tagName; UserTag.TextColor3 = V.Dim
UserTag.Font = Enum.Font.Gotham; UserTag.TextSize = 11
UserTag.TextXAlignment = Enum.TextXAlignment.Left

local Content = Instance.new("Frame", Main)
Content.Size = UDim2.new(1,-220,1,0); Content.Position = UDim2.new(0,220,0,0)
Content.BackgroundColor3 = V.Content; Content.BorderSizePixel = 0

local ContentHeader = Instance.new("Frame", Content)
ContentHeader.Size = UDim2.new(1,0,0,60); ContentHeader.BackgroundTransparency = 1

local PageTitle = Instance.new("TextLabel", ContentHeader)
PageTitle.Size = UDim2.new(0,300,1,0); PageTitle.Position = UDim2.new(0,30,0,0)
PageTitle.BackgroundTransparency = 1; PageTitle.Text = "Main"
PageTitle.TextColor3 = V.White; PageTitle.Font = Enum.Font.GothamBold
PageTitle.TextSize = 22; PageTitle.TextXAlignment = Enum.TextXAlignment.Left

local MoveIcon = Instance.new("TextLabel", ContentHeader)
MoveIcon.Size = UDim2.new(0,24,0,24); MoveIcon.Position = UDim2.new(1,-50,0.5,-12)
MoveIcon.BackgroundTransparency = 1; MoveIcon.Text = "⤡"
MoveIcon.TextColor3 = V.Dim; MoveIcon.Font = Enum.Font.GothamBold; MoveIcon.TextSize = 18

local PagesHolder = Instance.new("Frame", Content)
PagesHolder.Size = UDim2.new(1,-40,1,-80); PagesHolder.Position = UDim2.new(0,20,0,70)
PagesHolder.BackgroundColor3 = V.Card; PagesHolder.BorderSizePixel = 0
Instance.new("UICorner", PagesHolder).CornerRadius = UDim.new(0,10)
local phStroke = Instance.new("UIStroke", PagesHolder)
phStroke.Color = V.Border; phStroke.Transparency = 0.5; phStroke.Thickness = 1

local PagesInner = Instance.new("Frame", PagesHolder)
PagesInner.Size = UDim2.new(1,0,1,0); PagesInner.BackgroundTransparency = 1
PagesInner.ClipsDescendants = true

local TabButtons = {}; local Pages = {}; local ActiveTab = nil

local function CreatePage()
    local page = Instance.new("ScrollingFrame", PagesInner)
    page.Size = UDim2.new(1,0,1,0); page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = V.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0,0,0,0); page.BorderSizePixel = 0; page.Visible = false
    local layout = Instance.new("UIListLayout", page); layout.Padding = UDim.new(0,8)
    local pad = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0,20); pad.PaddingBottom = UDim.new(0,20)
    pad.PaddingLeft = UDim.new(0,24); pad.PaddingRight = UDim.new(0,24)
    return page
end

local function CreateTab(icon, name)
    local page = CreatePage(); Pages[name] = page
    local btn = Instance.new("TextButton", Menu)
    btn.Size = UDim2.new(1,0,0,38); btn.BackgroundColor3 = V.ItemBg
    btn.BackgroundTransparency = 1; btn.Text = ""; btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    local iconLbl = Instance.new("TextLabel", btn)
    iconLbl.Size = UDim2.new(0,24,1,0); iconLbl.Position = UDim2.new(0,12,0,0)
    iconLbl.BackgroundTransparency = 1; iconLbl.Text = icon
    iconLbl.TextColor3 = V.Dim; iconLbl.Font = Enum.Font.Gotham; iconLbl.TextSize = 15
    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1,-46,1,0); nameLbl.Position = UDim2.new(0,42,0,0)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = name
    nameLbl.TextColor3 = V.Text; nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 13; nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    local function Activate()
        for tbName, tb in pairs(TabButtons) do
            TS:Create(tb.btn, TI_Smooth, {BackgroundTransparency = 1}):Play()
            TS:Create(tb.icon, TI_Smooth, {TextColor3 = V.Dim}):Play()
            TS:Create(tb.name, TI_Smooth, {TextColor3 = V.Text}):Play()
            Pages[tbName].Visible = false
        end
        TS:Create(btn, TI_Smooth, {BackgroundTransparency = 0, BackgroundColor3 = V.ItemBg}):Play()
        TS:Create(iconLbl, TI_Smooth, {TextColor3 = V.White}):Play()
        TS:Create(nameLbl, TI_Smooth, {TextColor3 = V.White}):Play()
        page.Visible = true; ActiveTab = name; PageTitle.Text = name
    end
    btn.MouseEnter:Connect(function()
        if ActiveTab ~= name then TS:Create(btn, TI_Fast, {BackgroundTransparency = 0.7, BackgroundColor3 = V.ItemBg}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= name then TS:Create(btn, TI_Fast, {BackgroundTransparency = 1}):Play() end
    end)
    btn.MouseButton1Click:Connect(Activate)
    TabButtons[name] = {btn=btn, icon=iconLbl, name=nameLbl, activate=Activate}
    return page, Activate
end

local function Divider(par)
    local d = Instance.new("Frame", par)
    d.Size = UDim2.new(1,0,0,1); d.BackgroundColor3 = V.Border
    d.BackgroundTransparency = 0.5; d.BorderSizePixel = 0
end

local function Toggle(par, lbl, key, cb)
    local f = Instance.new("Frame", par)
    f.Size = UDim2.new(1,0,0,32); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.7,0,1,0); l.BackgroundTransparency = 1
    l.Text = lbl; l.TextColor3 = V.Text; l.Font = Enum.Font.Gotham
    l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("Frame", f)
    sw.Size = UDim2.new(0,36,0,20); sw.Position = UDim2.new(1,-36,0.5,-10)
    sw.BackgroundColor3 = CFG[key] and V.Accent or V.Off; sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1,0)
    local kn = Instance.new("Frame", sw)
    kn.Size = UDim2.new(0,14,0,14)
    kn.Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    kn.BackgroundColor3 = V.White; kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1,0)
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1; bt.Text = ""; bt.AutoButtonColor = false
    bt.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TS:Create(sw, TI_Fast, {BackgroundColor3 = CFG[key] and V.Accent or V.Off}):Play()
        TS:Create(kn, TI_Fast, {Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
        if cb then cb(CFG[key]) end
    end)
end

local function Slider(par, lbl, key, mn, mx, dc, cb)
    dc = dc or 0
    local f = Instance.new("Frame", par); f.Size = UDim2.new(1,0,0,50); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.6,0,0,20); l.BackgroundTransparency = 1
    l.Text = lbl; l.TextColor3 = V.Text; l.Font = Enum.Font.Gotham
    l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    local vl = Instance.new("TextLabel", f)
    vl.Size = UDim2.new(0.4,0,0,20); vl.Position = UDim2.new(0.6,0,0,0)
    vl.BackgroundTransparency = 1; vl.TextColor3 = V.Accent
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 12; vl.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("Frame", f)
    track.Size = UDim2.new(1,0,0,4); track.Position = UDim2.new(0,0,0,32)
    track.BackgroundColor3 = V.Off; track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = V.Accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0,12,0,12); thumb.BackgroundColor3 = V.White
    thumb.ZIndex = 5; thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    local function U()
        local pct = math.clamp((CFG[key]-mn)/(mx-mn),0,1)
        fill.Size = UDim2.new(pct,0,1,0); thumb.Position = UDim2.new(pct,-6,0.5,-6)
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

local function LinkButton(par, lbl, cb)
    local f = Instance.new("Frame", par); f.Size = UDim2.new(1,0,0,36); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,-30,1,0); l.BackgroundTransparency = 1
    l.Text = lbl; l.TextColor3 = V.Text; l.Font = Enum.Font.Gotham
    l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    local arrow = Instance.new("TextLabel", f)
    arrow.Size = UDim2.new(0,24,1,0); arrow.Position = UDim2.new(1,-24,0,0)
    arrow.BackgroundTransparency = 1; arrow.Text = ">"
    arrow.TextColor3 = V.Dim; arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 14
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1; bt.Text = ""; bt.AutoButtonColor = false
    bt.MouseEnter:Connect(function()
        TS:Create(l, TI_Fast, {TextColor3 = V.White}):Play()
        TS:Create(arrow, TI_Fast, {TextColor3 = V.White}):Play()
    end)
    bt.MouseLeave:Connect(function()
        TS:Create(l, TI_Fast, {TextColor3 = V.Text}):Play()
        TS:Create(arrow, TI_Fast, {TextColor3 = V.Dim}):Play()
    end)
    bt.MouseButton1Click:Connect(cb)
end

local function DropButton(par, lbl, opts, cfgKey, onSelect)
    local f = Instance.new("Frame", par)
    f.Size = UDim2.new(1,0,0,40); f.BackgroundColor3 = V.CardHover; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,-50,1,0); l.Position = UDim2.new(0,14,0,0)
    l.BackgroundTransparency = 1; l.Text = lbl.." • "..tostring(CFG[cfgKey])
    l.TextColor3 = V.Text; l.Font = Enum.Font.Gotham; l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    local icon = Instance.new("TextLabel", f)
    icon.Size = UDim2.new(0,24,1,0); icon.Position = UDim2.new(1,-34,0,0)
    icon.BackgroundTransparency = 1; icon.Text = "▦"
    icon.TextColor3 = V.Dim; icon.Font = Enum.Font.GothamBold; icon.TextSize = 14
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1; bt.Text = ""; bt.AutoButtonColor = false
    bt.MouseEnter:Connect(function() TS:Create(f, TI_Fast, {BackgroundColor3 = V.ItemBg}):Play() end)
    bt.MouseLeave:Connect(function() TS:Create(f, TI_Fast, {BackgroundColor3 = V.CardHover}):Play() end)
    bt.MouseButton1Click:Connect(function()
        local currentIdx = 1
        for i, o in ipairs(opts) do if o == CFG[cfgKey] then currentIdx = i; break end end
        currentIdx = currentIdx + 1
        if currentIdx > #opts then currentIdx = 1 end
        CFG[cfgKey] = opts[currentIdx]
        l.Text = lbl.." • "..tostring(CFG[cfgKey])
        Notify("☾ "..lbl, tostring(CFG[cfgKey]), 1.5)
        if onSelect then onSelect(CFG[cfgKey]) end
    end)
    return f
end

local function Label(par, txt, col)
    local l = Instance.new("TextLabel", par)
    l.Size = UDim2.new(1,0,0,18); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = col or V.Dim; l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
end

local function Spacer(par, h)
    local s = Instance.new("Frame", par); s.Size = UDim2.new(1,0,0,h or 4); s.BackgroundTransparency = 1
end

-- TABS
local pMain, actMain = CreateTab("🚀", "Main")
Label(pMain, "Master control panel", V.Dim); Spacer(pMain, 4)
DropButton(pMain, "Aim Mode", {"Off","SilentAim","HeadMagnet","Both"}, "AimMode")
Toggle(pMain, "Master Enable", "Enable")
Toggle(pMain, "Camera Lock", "CameraLock")
Toggle(pMain, "Auto Hitbox", "AutoHitbox")
Toggle(pMain, "Hold to Aim", "HoldToAim")
Divider(pMain)
LinkButton(pMain, "Configure Silent Aim →", function()
    if TabButtons["Silent"] then TabButtons["Silent"].activate() end
end)
LinkButton(pMain, "Configure Head Magnet →", function()
    if TabButtons["Magnet"] then TabButtons["Magnet"].activate() end
end)

local pTarget = CreateTab("🎯", "Target")
DropButton(pTarget, "Aim Button", {"Left","Right","Middle"}, "AimButton")
Toggle(pTarget, "Team Check", "TeamCheck")
Toggle(pTarget, "Ignore Downed", "NoDowned")
Toggle(pTarget, "Visible Check", "VisCheck")
Toggle(pTarget, "Only When Shooting", "OnlyWhenShooting")
Toggle(pTarget, "Require Gun", "RequireGun")
Divider(pTarget)
Slider(pTarget, "FOV Radius", "FOV", 30, 500, 0)
Slider(pTarget, "Max Distance", "MaxDist", 100, 3000, 0)

local pSilent = CreateTab("💀", "Silent")
Label(pSilent, "Silent Aim — hookfunction based", V.Dim); Spacer(pSilent, 4)
Toggle(pSilent, "Auto Prediction", "AutoPred")
Toggle(pSilent, "Ping Compensation", "PingComp")
Toggle(pSilent, "Acceleration Comp", "AccelComp")
Toggle(pSilent, "Gravity Comp", "GravityComp")
Toggle(pSilent, "Anti-Jitter", "AntiJitter")
Divider(pSilent)
Slider(pSilent, "Prediction (Manual)", "Prediction", 0.05, 0.30, 3)
Slider(pSilent, "Pred Multiplier", "PredMult", 0.5, 2.0, 2)
Slider(pSilent, "Snap Radius", "SnapRadius", 2, 20, 0)
Slider(pSilent, "Camera Lock Smooth", "CamLockSmooth", 0.05, 1.0, 2)

local pMagnet = CreateTab("🧲", "Magnet")
Label(pMagnet, "Head Magnet — работает без hookfunction", V.Green); Spacer(pMagnet, 4)
DropButton(pMagnet, "Magnet Mode", {"Mouse","Camera"}, "MagnetMode")
Toggle(pMagnet, "Use HRP (whole body)", "UseHRP")

local pHitbox = CreateTab("🎯", "Hitbox")
Label(pHitbox, "✅ FIX v5.3: Тела не зависают после смерти", V.Green)
Spacer(pHitbox, 4)
Toggle(pHitbox, "Auto Hitbox", "AutoHitbox")
Toggle(pHitbox, "Show Hitbox Visual", "ShowHitbox")
Divider(pHitbox)
Slider(pHitbox, "Hitbox Size", "HitboxSize", 1, 30, 1)
Slider(pHitbox, "Transparency", "HitboxTransp", 0, 1, 2)
DropButton(pHitbox, "Hitbox Part", {"Head","HumanoidRootPart"}, "HitboxPart",
    function() ResetAllParts() end)
Divider(pHitbox)
LinkButton(pHitbox, "Reset All Hitboxes", function()
    ResetAllParts(); Notify("☾", "Hitboxes reset", 2)
end)
LinkButton(pHitbox, "Preset: Medium (10)", function() CFG.HitboxSize = 10; CFG.AutoHitbox = true end)
LinkButton(pHitbox, "Preset: Large (15)", function() CFG.HitboxSize = 15; CFG.AutoHitbox = true end)
LinkButton(pHitbox, "Preset: Max (25)", function() CFG.HitboxSize = 25; CFG.AutoHitbox = true end)

local pESP = CreateTab("👁", "ESP")
Toggle(pESP, "Enable ESP", "ESP")
Toggle(pESP, "Boxes", "Boxes")
Toggle(pESP, "Names", "Names")
Toggle(pESP, "Health Bar", "HP")
Toggle(pESP, "Distance", "Dist")
Toggle(pESP, "Head Dot", "HeadDot")
Toggle(pESP, "Tracers", "Tracers")
Divider(pESP)
Toggle(pESP, "FOV Circle", "ShowFOV")
Toggle(pESP, "Target Dot", "ShowTarget")
Toggle(pESP, "Rainbow FOV", "Rainbow")
Toggle(pESP, "Debug Info", "Debug")

local pSet = CreateTab("⚙", "Settings")
Label(pSet, "Keybinds", V.White); Spacer(pSet, 4)
Label(pSet, "INSERT — Toggle Menu", V.Dim)
Label(pSet, "F1 — Panic Button", V.Dim)
Label(pSet, "F2 — Master Enable", V.Dim)
Label(pSet, "F3 — ESP", V.Dim)
Label(pSet, "F4 — Auto Hitbox", V.Dim)
Label(pSet, "F5 — Camera Lock", V.Dim)
Label(pSet, "END — Unload", V.Dim)
Divider(pSet)
LinkButton(pSet, "Rejoin Server", function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
end)
LinkButton(pSet, "Unload Eventide", function()
    ResetAllParts()
    pcall(function() FOVd:Remove(); TargetDot:Remove(); DB:Remove(); DB2:Remove() end)
    for px in pairs(ESPObj) do KillESP(px) end
    getgenv()._EV_XS = nil
    pcall(function() SGui:Destroy() end)
end)

actMain()

Main.Size = UDim2.new(0,720,0,0); Main.Visible = true
TS:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0,720,0,500)
}):Play()

CFG.Enable = true
CFG.AimMode = "Both"
CFG.HoldToAim = true

UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local k = i.KeyCode.Name
    if k == CFG.KeyMenu then
        if Main.Visible then Main.Visible = false
        else
            Main.Size = UDim2.new(0,720,0,0); Main.Visible = true
            TS:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.new(0,720,0,500)}):Play()
        end
    end
    if k == CFG.KeyAim then CFG.Enable = not CFG.Enable; Notify("☾ Master", CFG.Enable and "ON" or "OFF", 2) end
    if k == CFG.KeyESP then CFG.ESP = not CFG.ESP; Notify("☾ ESP", CFG.ESP and "ON" or "OFF", 2) end
    if k == CFG.KeyHitbox then CFG.AutoHitbox = not CFG.AutoHitbox; Notify("☾ Hitbox", CFG.AutoHitbox and "ON" or "OFF", 2) end
    if k == CFG.KeyCamLock then CFG.CameraLock = not CFG.CameraLock; Notify("☾ Cam Lock", CFG.CameraLock and "ON" or "OFF", 2) end
    if k == CFG.KeyPanic then
        CFG.Enable = false; CFG.ESP = false; CFG.AutoHitbox = false
        CFG.ShowFOV = false; CFG.ShowTarget = false; CFG.CameraLock = false
        ResetAllParts(); Notify("☾ PANIC", "ALL OFF", 3)
    end
    if k == CFG.KeyUnload then
        ResetAllParts()
        pcall(function() FOVd:Remove(); TargetDot:Remove(); DB:Remove(); DB2:Remove() end)
        for px in pairs(ESPObj) do KillESP(px) end
        getgenv()._EV_XS = nil
        pcall(function() SGui:Destroy() end)
    end
end)

task.spawn(function()
    task.wait(5)
    if hooksInstalled == 0 then
        Notify("⚠️ EVENTIDE", "Silent Aim: 0 hooks!\nHead Magnet работает всё равно", 8)
    else
        Notify("✅ EVENTIDE v5.3", hooksInstalled.." hooks | Mode: "..CFG.AimMode, 5)
    end
end)

Notify("☾ EVENTIDE v5.3", "Fixed: no floating bodies\nMode: "..CFG.AimMode, 3)