-- ===============================================
--   ☾ EVENTIDE v3.5 — FIXED HITBOX EDITION
--   Da Hood & Boom Hood
--   Hit Part Spoof + Hitbox (no floating bodies!)
-- ===============================================

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1.5)

local getgenv = getgenv or function() return _G end
if getgenv()._EV_XS then return end
getgenv()._EV_XS = true

pcall(function()
    if gethui then
        for _, g in ipairs(gethui():GetChildren()) do
            if g:IsA("ScreenGui") then g:Destroy() end
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

local function Notify(t, m, d)
    pcall(function()
        SG:SetCore("SendNotification", {Title = t, Text = m, Duration = d or 3})
    end)
end

-- ==================== CONFIG ====================
local CFG = {
    SilentAim        = true,
    FOV              = 120,
    Prediction       = 0.135,
    PredMult         = 1.0,
    AutoPred         = true,
    OnlyWhenShooting = false,
    HoldToAim        = true,
    AimButton        = "Right",
    TeamCheck        = false,
    NoDowned         = true,
    VisCheck         = false,
    MaxDist          = 900,

    HeadOnly         = true,
    PingComp         = true,
    AccelComp        = true,
    GravityComp      = true,
    AntiJitter       = true,
    SnapRadius       = 8,

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
    KeyPanic   = "F1",
    KeyUnload  = "End",
}

local Target         = nil
local cachedPred     = nil
local ESPObj         = {}
local VelHist        = {}
local PosHist        = {}
local RH             = 0
local curPred        = 0.135
local isShooting     = false
local isHolding      = false
local hookStatus     = "⏳ Ждём..."
local hooksInstalled = 0

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

local function IsAlive(p)
    local hum = GetHum(p)
    return hum and hum.Health > 0
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

local function IsHoldingGun()
    local char = LP.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    for _, name in ipairs({
        "GunStates","Ammo","ShootEvent","Shoot",
        "AimPart","FireRate","GunScript","GunInfo"
    }) do
        if tool:FindFirstChild(name) then return true end
    end
    return tool:FindFirstChild("Handle") ~= nil
end

local function IsSafeCaller()
    local getCalling = getcallingscript
    if not getCalling then return true end
    local ok, caller = pcall(getCalling)
    if not ok or not caller then return true end
    local name = caller.Name:lower()
    local full = caller:GetFullName():lower()
    if name:find("anti") or name:find("cheat")
    or name:find("detect") or name:find("check")
    or name:find("security") or name:find("guard")
    or full:find("anticheat") or full:find("security") then
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
    local myRoot    = GetRoot(LP)
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

-- ==================== VELOCITY + POSITION HISTORY ====================
RS.Heartbeat:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = GetRoot(p)
            local h = GetHead(p)
            if r and h then
                if not VelHist[p] then VelHist[p] = {} end
                table.insert(VelHist[p], 1, r.AssemblyLinearVelocity)
                if #VelHist[p] > 15 then table.remove(VelHist[p]) end

                if not PosHist[p] then PosHist[p] = {} end
                table.insert(PosHist[p], 1, {
                    pos = h.Position, root = r.Position,
                    vel = r.AssemblyLinearVelocity, time = tick()
                })
                if #PosHist[p] > 20 then table.remove(PosHist[p]) end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    VelHist[p] = nil
    PosHist[p] = nil
end)

-- ==================== 100% HEADSHOT PREDICTION ====================
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

    local pred
    if CFG.AutoPred then
        pred = CalcAutoPrediction()
    else
        pred = CFG.Prediction * CFG.PredMult
    end
    curPred = pred

    local vel = GetSmoothedVelocity(plr)
    local predictedRoot = root.Position + Vector3.new(vel.X*pred, 0, vel.Z*pred)

    if CFG.AccelComp then
        local acc = GetAcceleration(plr)
        predictedRoot = predictedRoot + Vector3.new(
            acc.X*pred*pred*0.5, 0, acc.Z*pred*pred*0.5
        )
    end

    if CFG.GravityComp and hum then
        local state = hum:GetState()
        local g = WS.Gravity or 196.2
        if state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall then
            local predY = root.Position.Y + vel.Y*pred - 0.5*g*pred*pred
            predictedRoot = Vector3.new(predictedRoot.X, predY, predictedRoot.Z)
        else
            predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y, predictedRoot.Z)
        end
    else
        predictedRoot = Vector3.new(predictedRoot.X, root.Position.Y, predictedRoot.Z)
    end

    if CFG.PingComp then
        local ping = GetPing()
        local extraComp = (ping / 1000) * 0.15
        predictedRoot = predictedRoot + Vector3.new(
            vel.X*extraComp, 0, vel.Z*extraComp
        )
    end

    local headOffset = head.Position - root.Position
    local finalHead = predictedRoot + headOffset

    local maxOffset = vel.Magnitude*pred*2 + CFG.SnapRadius
    local diff = finalHead - head.Position
    if diff.Magnitude > maxOffset then
        finalHead = head.Position + diff.Unit * maxOffset
    end

    if vel.Magnitude < 3 then
        finalHead = head.Position
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

-- ==================== 💀 HITBOX EXPANDER (FIXED) ====================
local OriginalHeadSizes = {}

local function ExpandHitbox(plr)
    if plr == LP then return end
    local char = plr and plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    
    -- ФИКС: не трогаем мёртвых
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if not OriginalHeadSizes[plr] then
        OriginalHeadSizes[plr] = {
            size     = head.Size,
            transp   = head.Transparency,
            canCol   = head.CanCollide,
            mat      = head.Material,
            col      = head.Color,
            massless = head.Massless,
        }
    end

    if CFG.HitboxExpander then
        local s = CFG.HitboxSize
        head.Size = Vector3.new(s, s, s)
        head.Transparency = CFG.ShowHitbox and CFG.HitboxTransp or 1
        head.CanCollide = false
        head.Massless = true  -- ФИКС: не влияет на физику
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
    for _, plr in ipairs(Players:GetPlayers()) do
        ResetHitbox(plr)
    end
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
            
            -- ФИКС: не трогаем мёртвых, сбрасываем если умер
            if not hum or hum.Health <= 0 then
                if OriginalHeadSizes[plr] then
                    ResetHitbox(plr)
                end
            elseif head then
                local s = CFG.HitboxSize
                if head.Size.X ~= s then
                    ExpandHitbox(plr)
                end
                if CFG.ShowHitbox then
                    head.Transparency = CFG.HitboxTransp
                else
                    head.Transparency = 1
                end
            end
        end
    end
end)

-- ФИКС: подписываемся на смерть и респавн
local function HookCharacter(plr)
    if plr == LP then return end
    
    plr.CharacterAdded:Connect(function(char)
        task.wait(1)
        if CFG.HitboxExpander then
            ExpandHitbox(plr)
        end
        
        -- Сброс при смерти
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                ResetHitbox(plr)
            end)
        end
    end)
    
    plr.CharacterRemoving:Connect(function()
        ResetHitbox(plr)
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
                end)
            end
        end
    end
end

Players.PlayerAdded:Connect(HookCharacter)

-- ==================== HIT PART SPOOFING ====================
task.spawn(function()
    task.wait(3)
    local installed = 0

    local function ShouldSpoof()
        if not CFG.SilentAim then return false end
        if not cachedPred then return false end
        if checkcaller() then return false end
        if not IsSafeCaller() then return false end
        if not IsHoldingGun() then return false end
        if CFG.OnlyWhenShooting and not isShooting then return false end
        if CFG.HoldToAim and not isHolding then return false end
        return true
    end

    local function GetFreshHeadPos()
        if not Target or not cachedPred then return cachedPred end
        return GetHeadPosition100(Target) or cachedPred
    end

    pcall(function()
        local orig = Cam.ViewportPointToRay
        hookfunction(orig, newccl(function(self, x, y, ...)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                local wp = self:WorldToViewportPoint(hp)
                if wp.Z > 0 then return orig(self, wp.X, wp.Y, ...) end
            end
            return orig(self, x, y, ...)
        end))
        installed += 1
    end)

    pcall(function()
        local orig = Cam.ScreenPointToRay
        hookfunction(orig, newccl(function(self, x, y, ...)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                local wp, vis = self:WorldToScreenPoint(hp)
                if vis then return orig(self, wp.X, wp.Y, ...) end
            end
            return orig(self, x, y, ...)
        end))
        installed += 1
    end)

    pcall(function()
        local orig = UIS.GetMouseLocation
        hookfunction(orig, newccl(function(self)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
                local wp = Cam:WorldToViewportPoint(hp)
                if wp.Z > 0 then return Vector2.new(wp.X, wp.Y) end
            end
            return orig(self)
        end))
        installed += 1
    end)

    pcall(function()
        if not getrawmetatable then return end
        local mt = getrawmetatable(Mouse)
        if not mt then return end
        local oldIdx = mt.__index
        if setreadonly then setreadonly(mt, false) end
        mt.__index = newccl(function(self, key)
            if ShouldSpoof() then
                local hp = GetFreshHeadPos()
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
                if key == "X" then
                    return Cam:WorldToViewportPoint(hp).X
                end
                if key == "Y" then
                    return Cam:WorldToViewportPoint(hp).Y
                end
            end
            return oldIdx(self, key)
        end)
        if setreadonly then setreadonly(mt, true) end
        installed += 1
    end)

    hooksInstalled = installed
    if installed > 0 then
        hookStatus = "🎯 " .. installed .. " hooks"
        Notify("Eventide v3.5", "💀 " .. installed .. " hooks | Держи ПКМ", 5)
    else
        hookStatus = "❌ 0 hooks"
        Notify("Eventide", "Hooks не установлены", 5)
    end
end)

RS.RenderStepped:Connect(function()
    Cam = WS.CurrentCamera
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
DB.Size = 13; DB.Outline = true; DB.Font = 2; DB.Color = Color3.fromRGB(200,180,255)

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
        local tn  = Target and Target.Name or "—"
        local gun = IsHoldingGun() and "🔫" or "—"
        local sh  = isShooting and "💀" or "—"
        local aim = isHolding and "🎯" or "—"
        local hb  = CFG.HitboxExpander and ("HB:"..CFG.HitboxSize) or ""
        DB.Text = string.format(
            "☾ PRED:%dms  PING:%dms  TGT:%s  %s %s %s  %s  %s",
            curPred*1000, math.floor(GetPing()), tn, gun, sh, aim, hookStatus, hb
        )
        DB.Position = Vector2.new(12, 36)
    else
        DB.Visible = false
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
--         ☾  PREMIUM BLACK-PURPLE GUI  ☾
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

local AccLine = Instance.new("Frame", Main)
AccLine.Size = UDim2.new(1,-40,0,2); AccLine.Position = UDim2.new(0,20,0,52)
AccLine.BackgroundColor3 = P.Accent; AccLine.BorderSizePixel = 0
Instance.new("UICorner", AccLine).CornerRadius = UDim.new(1,0)
local AccGrad = Instance.new("UIGradient", AccLine)
AccGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80,30,160)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180,80,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80,30,160)),
})

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
VerText.Text = "v3.5 🔧"; VerText.TextColor3 = Color3.new(1,1,1)
VerText.Font = Enum.Font.GothamBold; VerText.TextSize = 10

local StatusLbl = Instance.new("TextLabel", TopBar)
StatusLbl.Size = UDim2.new(0,300,0,14); StatusLbl.Position = UDim2.new(0,18,1,-18)
StatusLbl.BackgroundTransparency = 1; StatusLbl.Text = "Fixed Hitbox • RMB Silent Aim"
StatusLbl.TextColor3 = P.Dim; StatusLbl.Font = Enum.Font.Gotham; StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0,30,0,30); CloseBtn.Position = UDim2.new(1,-40,0.5,-15)
CloseBtn.BackgroundColor3 = P.Off; CloseBtn.Text = "✕"; CloseBtn.TextColor3 = P.Dim
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 14; CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,8)
CloseBtn.MouseEnter:Connect(function() TS:Create(CloseBtn, TI_Fast, {BackgroundColor3=P.Red, TextColor3=Color3.new(1,1,1)}):Play() end)
CloseBtn.MouseLeave:Connect(function() TS:Create(CloseBtn, TI_Fast, {BackgroundColor3=P.Off, TextColor3=P.Dim}):Play() end)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0,30,0,30); MinBtn.Position = UDim2.new(1,-76,0.5,-15)
MinBtn.BackgroundColor3 = P.Off; MinBtn.Text = "—"; MinBtn.TextColor3 = P.Dim
MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 14; MinBtn.BorderSizePixel = 0
MinBtn.AutoButtonColor = false
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,8)
MinBtn.MouseEnter:Connect(function() TS:Create(MinBtn, TI_Fast, {BackgroundColor3=P.AccentD, TextColor3=Color3.new(1,1,1)}):Play() end)
MinBtn.MouseLeave:Connect(function() TS:Create(MinBtn, TI_Fast, {BackgroundColor3=P.Off, TextColor3=P.Dim}):Play() end)
MinBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

-- ==================== TAB SYSTEM ====================
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

    btn.MouseEnter:Connect(function() if ActiveTab ~= name then TS:Create(btn, TI_Fast, {BackgroundColor3=P.Off}):Play() end end)
    btn.MouseLeave:Connect(function() if ActiveTab ~= name then TS:Create(btn, TI_Fast, {BackgroundColor3=P.TabOff}):Play() end end)
    btn.MouseButton1Click:Connect(Activate)
    table.insert(TabButtons, {btn=btn,icon=iconLbl,name=nameLbl,indicator=indicator,page=page,activate=Activate})
    tabY = tabY + 44
    return page, Activate
end

-- ==================== GUI BUILDERS ====================
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
    local glow = Instance.new("UIStroke", sw); glow.Color = P.Glow
    glow.Thickness = CFG[key] and 1 or 0; glow.Transparency = 0.5
    local kn = Instance.new("Frame", sw)
    kn.Size = UDim2.new(0,14,0,14)
    kn.Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    kn.BackgroundColor3 = CFG[key] and Color3.new(1,1,1) or P.OffKnob; kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1,0)
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1; bt.Text = ""; bt.AutoButtonColor = false
    bt.MouseEnter:Connect(function() TS:Create(f, TI_Fast, {BackgroundColor3=P.Card2}):Play() end)
    bt.MouseLeave:Connect(function() TS:Create(f, TI_Fast, {BackgroundColor3=P.Card}):Play() end)
    bt.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TS:Create(sw, TI_Smooth, {BackgroundColor3 = CFG[key] and P.Accent or P.Off}):Play()
        TS:Create(kn, TI_Smooth, {
            Position = CFG[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
            BackgroundColor3 = CFG[key] and Color3.new(1,1,1) or P.OffKnob
        }):Play()
        glow.Thickness = CFG[key] and 1 or 0
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
    Instance.new("UIGradient", fill).Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100,40,180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180,80,255)),
    })
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0,14,0,14); thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.ZIndex = 5; thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    local tg = Instance.new("UIStroke", thumb); tg.Color = P.Accent2; tg.Thickness = 1.5; tg.Transparency = 0.5
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
    b.MouseEnter:Connect(function() TS:Create(b, TI_Fast, {BackgroundColor3=(col or P.Card2):Lerp(P.Accent,0.3)}):Play() end)
    b.MouseLeave:Connect(function() TS:Create(b, TI_Fast, {BackgroundColor3=col or P.Card2}):Play() end)
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

-- ==================== 🎮 KEYBIND SYSTEM ====================
local BindingKey = nil
local BindButtons = {}

local function KeybindButton(par, lbl, cfgKey)
    local f = Instance.new("Frame", par)
    f.Size = UDim2.new(1,0,0,32)
    f.BackgroundColor3 = P.Card; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.55,0,1,0); l.Position = UDim2.new(0,14,0,0)
    l.BackgroundTransparency = 1; l.Text = lbl; l.TextColor3 = P.White
    l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0, 110, 0, 22)
    btn.Position = UDim2.new(1, -120, 0.5, -11)
    btn.BackgroundColor3 = P.Off
    btn.Text = "[ " .. CFG[cfgKey] .. " ]"
    btn.TextColor3 = P.Accent2
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = P.Border; stroke.Thickness = 1

    BindButtons[cfgKey] = btn

    btn.MouseEnter:Connect(function()
        if BindingKey ~= cfgKey then
            TS:Create(btn, TI_Fast, {BackgroundColor3 = P.Card2}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if BindingKey ~= cfgKey then
            TS:Create(btn, TI_Fast, {BackgroundColor3 = P.Off}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if BindingKey then
            local prev = BindButtons[BindingKey]
            if prev then
                prev.Text = "[ " .. CFG[BindingKey] .. " ]"
                TS:Create(prev, TI_Fast, {BackgroundColor3 = P.Off}):Play()
            end
        end
        BindingKey = cfgKey
        btn.Text = "[ ... нажми клавишу ]"
        TS:Create(btn, TI_Fast, {BackgroundColor3 = P.Accent}):Play()
        Notify("☾ Keybind", "Нажми клавишу для '" .. lbl .. "'\nESC — отмена", 4)
    end)
end

UIS.InputBegan:Connect(function(input, gpe)
    if not BindingKey then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Escape then
        local btn = BindButtons[BindingKey]
        if btn then
            btn.Text = "[ " .. CFG[BindingKey] .. " ]"
            TS:Create(btn, TI_Fast, {BackgroundColor3 = P.Off}):Play()
        end
        Notify("☾ Keybind", "Отменено", 1.5)
        BindingKey = nil
        return
    end
    local keyName = key.Name
    CFG[BindingKey] = keyName
    local btn = BindButtons[BindingKey]
    if btn then
        btn.Text = "[ " .. keyName .. " ]"
        TS:Create(btn, TI_Fast, {BackgroundColor3 = P.Off}):Play()
    end
    Notify("☾ Keybind", "Установлено: " .. keyName, 2)
    BindingKey = nil
end)

-- ==================== TABS ====================

-- TAB 1: AIM
local p1, act1 = CreateTab("💀", "Aim")
SectionHeader(p1, "100% HEADSHOT")
Label(p1, "Держи ПКМ — целится в голову", P.Green)
Spacer(p1)
Toggle(p1, "Enable Silent Aim", "SilentAim")
Toggle(p1, "Hold to Aim (по кнопке)", "HoldToAim")
Toggle(p1, "Only When Shooting", "OnlyWhenShooting")
Spacer(p1, 4)

-- Aim Button Selector
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

btnL.MouseButton1Click:Connect(function() CFG.AimButton = "Left";   UpdateMouseBtns(); Notify("☾","Aim: ЛКМ",1.5) end)
btnR.MouseButton1Click:Connect(function() CFG.AimButton = "Right";  UpdateMouseBtns(); Notify("☾","Aim: ПКМ",1.5) end)
btnM.MouseButton1Click:Connect(function() CFG.AimButton = "Middle"; UpdateMouseBtns(); Notify("☾","Aim: СКМ",1.5) end)

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
Slider(p1, "FOV", "FOV", 30, 350, 0)
Slider(p1, "Prediction (Manual)", "Prediction", 0.05, 0.30, 3)
Slider(p1, "Pred Multiplier", "PredMult", 0.5, 2.0, 2)
Slider(p1, "Max Distance", "MaxDist", 100, 2000, 0)
Slider(p1, "Snap Radius", "SnapRadius", 2, 20, 0)

-- TAB 2: HITBOX
local p2, act2 = CreateTab("🎯", "Hitbox")
SectionHeader(p2, "💀 HITBOX EXPANDER (FIXED)")
Label(p2, "✅ Больше не летают после смерти!", P.Green)
Label(p2, "Работает вместе с Silent Aim", P.Yellow)
Spacer(p2)
Toggle(p2, "Enable Hitbox Expander", "HitboxExpander")
Toggle(p2, "Show Hitbox Visual", "ShowHitbox")
Spacer(p2, 6)
Slider(p2, "Head Size", "HitboxSize", 1, 20, 1)
Slider(p2, "Hitbox Transparency", "HitboxTransp", 0, 1, 2)
Spacer(p2, 8)
SectionHeader(p2, "QUICK ACTIONS")
Spacer(p2)
Button(p2, "🔄  Reset All Hitboxes", function()
    ResetAllHitboxes()
    Notify("☾ Hitbox", "Все головы сброшены", 2)
end)
Spacer(p2, 3)
Button(p2, "👤  NORMAL (1)", function()
    CFG.HitboxSize = 1
    Notify("☾ Hitbox", "Стандартный размер", 2)
end)
Spacer(p2, 3)
Button(p2, "⚡  BALANCED (6)", function()
    CFG.HitboxSize = 6; CFG.HitboxExpander = true
    Notify("☾ Hitbox", "Balanced (6)", 2)
end)
Spacer(p2, 3)
Button(p2, "🔥  LARGE (10)", function()
    CFG.HitboxSize = 10; CFG.HitboxExpander = true
    Notify("☾ Hitbox", "Large (10)", 2)
end, Color3.fromRGB(50, 30, 20))
Spacer(p2, 3)
Button(p2, "💀  MAX SIZE (20)", function()
    CFG.HitboxSize = 20; CFG.HitboxExpander = true
    Notify("☾ Hitbox", "МАКСИМУМ!", 2)
end, Color3.fromRGB(60, 20, 60))

-- TAB 3: PRESETS
local p3, act3 = CreateTab("⚡", "Presets")
SectionHeader(p3, "WEAPON PRESETS")
Spacer(p3)
Button(p3, "🔫  Pistol  •  0.12 × 0.92", function()
    CFG.Prediction=0.12; CFG.PredMult=0.92; Notify("☾","Pistol",2) end)
Spacer(p3,3)
Button(p3, "⚡  AR / SMG  •  0.135 × 1.0", function()
    CFG.Prediction=0.135; CFG.PredMult=1.0; Notify("☾","AR/SMG",2) end)
Spacer(p3,3)
Button(p3, "🎯  Sniper  •  0.15 × 1.15", function()
    CFG.Prediction=0.15; CFG.PredMult=1.15; Notify("☾","Sniper",2) end)
Spacer(p3,3)
Button(p3, "💥  Shotgun  •  0.10 × 0.80", function()
    CFG.Prediction=0.10; CFG.PredMult=0.80; Notify("☾","Shotgun",2) end)
Spacer(p3,12)
SectionHeader(p3, "COMBO PRESETS")
Spacer(p3)
Button(p3, "🛡️  MAX SAFE (FOV 70)", function()
    CFG.FOV=70; CFG.PredMult=0.9; CFG.HitboxSize=3
    Notify("☾","SAFE mode",2) end, Color3.fromRGB(20,50,35))
Spacer(p3,3)
Button(p3, "💀  MAX ACCURACY", function()
    CFG.AutoPred=true; CFG.PingComp=true; CFG.AccelComp=true
    CFG.GravityComp=true; CFG.AntiJitter=true; CFG.FOV=150
    CFG.HitboxExpander=true; CFG.HitboxSize=8
    Notify("☾","MAX ACCURACY",2) end, Color3.fromRGB(50,20,50))
Spacer(p3,3)
Button(p3, "🔥  RAGE MODE (без ПКМ)", function()
    CFG.FOV=250; CFG.HitboxExpander=true; CFG.HitboxSize=15
    CFG.OnlyWhenShooting=false; CFG.HoldToAim=false
    Notify("☾","RAGE!",2) end, Color3.fromRGB(60,20,20))

-- TAB 4: ESP
local p4, act4 = CreateTab("👁", "ESP")
SectionHeader(p4, "ESP ELEMENTS")
Toggle(p4, "Enable ESP", "ESP")
Toggle(p4, "Boxes", "Boxes"); Toggle(p4, "Names", "Names")
Toggle(p4, "Health Bar", "HP"); Toggle(p4, "Distance", "Dist")
Toggle(p4, "Head Dot", "HeadDot"); Toggle(p4, "Tracers", "Tracers")
Spacer(p4, 10)
SectionHeader(p4, "VISUALS")
Toggle(p4, "FOV Circle", "ShowFOV"); Toggle(p4, "Prediction Dot", "ShowPred")
Toggle(p4, "Rainbow FOV", "Rainbow"); Toggle(p4, "Debug Info", "Debug")

-- TAB 5: KEYBINDS
local p5, act5 = CreateTab("⌨️", "Keys")
SectionHeader(p5, "🎮 CUSTOM KEYBINDS")
Label(p5, "Нажми на бинд и выбери клавишу", P.Green)
Label(p5, "ESC — отменить переназначение", P.Yellow)
Spacer(p5)
KeybindButton(p5, "Open Menu", "KeyMenu")
KeybindButton(p5, "Toggle Silent Aim", "KeyAim")
KeybindButton(p5, "Toggle ESP", "KeyESP")
KeybindButton(p5, "Toggle Hitbox", "KeyHitbox")
KeybindButton(p5, "🚨 PANIC (выкл всё)", "KeyPanic")
KeybindButton(p5, "Unload Script", "KeyUnload")
Spacer(p5, 10)
SectionHeader(p5, "🔄 RESET BINDS")
Spacer(p5)
Button(p5, "Восстановить по умолчанию", function()
    CFG.KeyMenu = "Insert"
    CFG.KeyAim = "F2"
    CFG.KeyESP = "F3"
    CFG.KeyHitbox = "F4"
    CFG.KeyPanic = "F1"
    CFG.KeyUnload = "End"
    for k, btn in pairs(BindButtons) do
        btn.Text = "[ " .. CFG[k] .. " ]"
    end
    Notify("☾ Keybinds", "Сброшено по умолчанию", 2)
end)

-- TAB 6: INFO
local p6, act6 = CreateTab("ℹ️", "Info")
SectionHeader(p6, "☾ EVENTIDE v3.5")
Spacer(p6)
Label(p6, "Fixed Hitbox Edition", P.Accent2)
Label(p6, "Da Hood & Boom Hood", P.Dim)
Spacer(p6, 8)
SectionHeader(p6, "🔧 ИСПРАВЛЕНО В v3.5")
Label(p6, "✅ Тела не летают после смерти", P.Green)
Label(p6, "✅ Хитбокс сбрасывается при смерти", P.Green)
Label(p6, "✅ Добавлен Massless = true", P.Green)
Label(p6, "✅ Подписка на Humanoid.Died", P.Green)
Spacer(p6, 8)
SectionHeader(p6, "💀 ФУНКЦИИ")
Label(p6, "• Hold RMB → Silent Aim", P.Green)
Label(p6, "• 100% Headshot", P.Green)
Label(p6, "• Hitbox Expander (FIXED)", P.Green)
Label(p6, "• Custom Keybinds", P.Green)
Label(p6, "• Auto Prediction по пингу", P.White)
Label(p6, "• Компенсация ускорения и гравитации", P.White)
Label(p6, "• Anti-Jitter от лагов", P.White)
Label(p6, "• Snap Radius (магнит)", P.White)
Spacer(p6, 8)
SectionHeader(p6, "🛡️ БЕЗОПАСНОСТЬ")
Label(p6, "• workspace.Raycast НЕ тронут", P.Green)
Label(p6, "• Хуки: Camera + Mouse", P.White)
Label(p6, "• Античит не палит", P.Green)
Spacer(p6, 8)
SectionHeader(p6, "🎮 УПРАВЛЕНИЕ")
Label(p6, "🎯 Держи ПКМ — Silent Aim активен", P.Accent2)
Label(p6, "INSERT — открыть меню", P.White)
Label(p6, "F2 — вкл/выкл Silent Aim", P.White)
Label(p6, "F3 — вкл/выкл ESP", P.White)
Label(p6, "F4 — вкл/выкл Hitbox", P.White)
Label(p6, "F1 — 🚨 PANIC (выкл всё)", P.Red)
Label(p6, "END — выгрузить скрипт", P.White)
Spacer(p6, 8)
SectionHeader(p6, "🗑️ ВЫГРУЗИТЬ")
Spacer(p6)
Button(p6, "UNLOAD EVENTIDE", function()
    ResetAllHitboxes()
    pcall(function() FOVd:Remove(); PD:Remove(); DB:Remove() end)
    for px in pairs(ESPObj) do KillESP(px) end
    getgenv()._EV_XS = nil
    pcall(function() SGui:Destroy() end)
    Notify("Eventide","Выгружен",3)
end, P.Red)

act1()

-- Ambient glow
task.spawn(function()
    local t = 0
    while Main and Main.Parent do
        t = (t + 0.008) % 1
        MainStroke.Color = Color3.fromHSV(0.75 + math.sin(t*math.pi*2)*0.05, 0.6, 0.5)
        AccGrad.Offset = Vector2.new(math.sin(t*math.pi*2)*0.3, 0)
        task.wait(0.03)
    end
end)

-- Open animation
Main.Size = UDim2.new(0,520,0,0); Main.Visible = true
TS:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0,520,0,500)
}):Play()

-- ==================== HOTKEYS ====================
UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if BindingKey then return end
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

    if keyName == CFG.KeyPanic then
        CFG.SilentAim = false
        CFG.ESP = false
        CFG.HitboxExpander = false
        CFG.ShowFOV = false
        CFG.ShowPred = false
        ResetAllHitboxes()
        Notify("☾ PANIC", "🚨 ВСЁ ВЫКЛЮЧЕНО", 3)
    end

    if keyName == CFG.KeyUnload then
        ResetAllHitboxes()
        pcall(function() FOVd:Remove(); PD:Remove(); DB:Remove() end)
        for px in pairs(ESPObj) do KillESP(px) end
        getgenv()._EV_XS = nil
        pcall(function() SGui:Destroy() end)
    end
end)

Notify("☾ EVENTIDE v3.5", "🔧 Фикс хитбокса!\nТела больше не летают", 8)