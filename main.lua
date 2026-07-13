-- ===============================================
--   ☾ EVENTIDE v2.2 — Anti-Cheat Bypass Edition
--   Da Hood & Boom Hood
--   Hit Part Spoofing (не меняет направление луча!)
--   Античит НЕ палит
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

local LP  = Players.LocalPlayer
local Cam = WS.CurrentCamera

local newccl        = newcclosure or function(f) return f end
local checkcaller   = checkcaller or function() return false end
local getcallingscript = getcallingscript or function() return nil end

local function Notify(t, m, d)
    pcall(function()
        SG:SetCore("SendNotification", {Title = t, Text = m, Duration = d or 3})
    end)
end

-- ==================== CONFIG ====================
local CFG = {
    SilentAim   = true,
    AimPart     = "Head",
    FOV         = 100,        -- меньше = безопаснее
    ManualPred  = 0.135,
    PredMult    = 0.95,
    Resolver    = false,      -- ВЫКЛ по умолчанию (безопаснее)
    Smoothing   = true,
    HitPartMode = true,       -- 🔥 главная фишка v2.2
    OnlyWhenShooting = true,  -- только при стрельбе
    MaxAngle    = 20,         -- макс. угол отклонения (гр)
    TeamCheck   = false,
    NoDowned    = true,
    MaxDist     = 800,

    AimbotBackup = false,
    AimbotSmooth = 0.20,

    ESP      = true,
    Boxes    = true,
    Names    = true,
    HP       = true,
    Dist     = true,
    Tracers  = false,
    HeadDot  = true,

    ShowFOV  = true,
    ShowPred = true,
    Rainbow  = false,
    FOVCol   = Color3.fromRGB(130, 90, 240),
    Debug    = true,
}

local Target        = nil
local cachedPred    = nil
local ESPObj        = {}
local RH, FPS, FPSH = 0, 60, {}
local curPred       = 0.135
local VelHist       = {}
local aiming        = false
local hookStatus    = "⏳ Ждём..."
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
    -- Da Hood оружие имеет специфичные детали
    if tool:FindFirstChild("GunStates") 
    or tool:FindFirstChild("Ammo")
    or tool:FindFirstChild("Shoot")
    or tool:FindFirstChild("ShootEvent") then
        return true
    end
    -- fallback: если есть Handle — считаем оружием
    return tool:FindFirstChild("Handle") ~= nil
end

local function IsSafeCaller()
    local caller = getcallingscript()
    if not caller then return true end
    local name = caller.Name:lower()
    local full = caller:GetFullName():lower()
    -- блокируем античит-скрипты
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
    local myRoot = GetRoot(LP)
    local theirRoot = GetRoot(p)
    if not myRoot or not theirRoot then return false end
    local dist = (myRoot.Position - theirRoot.Position).Magnitude
    if dist > CFG.MaxDist then return false end
    return true
end

-- ==================== VELOCITY HISTORY ====================
RS.Heartbeat:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = GetRoot(p)
            if r then
                if not VelHist[p] then VelHist[p] = {} end
                table.insert(VelHist[p], 1, r.AssemblyLinearVelocity)
                if #VelHist[p] > 10 then table.remove(VelHist[p]) end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) VelHist[p] = nil end)

-- ==================== PREDICTION ====================
local function SmoothVel(plr)
    local h = VelHist[plr]
    if not h or #h == 0 then
        local r = GetRoot(plr)
        return r and r.AssemblyLinearVelocity or Vector3.zero
    end
    if not CFG.Smoothing or #h < 3 then return h[1] end
    local tw, sm = 0, Vector3.zero
    local c = math.min(#h, 6)
    for i = 1, c do
        local w = ((c - i + 1) / c) ^ 1.3
        sm = sm + h[i] * w
        tw = tw + w
    end
    return tw > 0 and sm / tw or h[1]
end

local function GetPredHead(plr)
    if not plr or not plr.Character then return nil end
    local head = GetHead(plr)
    local root = GetRoot(plr)
    if not head or not root then return nil end

    local hOff = head.Position - root.Position
    local pred = CFG.ManualPred * CFG.PredMult
    curPred    = pred
    local vel  = SmoothVel(plr)

    local pRoot = root.Position + vel * pred

    if CFG.Resolver and VelHist[plr] and #VelHist[plr] >= 3 then
        local acc = VelHist[plr][1] - VelHist[plr][2]
        pRoot = pRoot + Vector3.new(acc.X * pred * 0.4, 0, acc.Z * pred * 0.4)
    end

    return pRoot + hOff
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
                        bd = d
                        best = p
                    end
                end
            end
        end
    end
    return best
end

RS.Heartbeat:Connect(function()
    Target     = GetTarget()
    cachedPred = (Target and CFG.SilentAim) and GetPredHead(Target) or nil
end)

-- ==================== 🔥 HIT PART SPOOFING (АНТИ-ДЕТЕКТ) ====================
task.spawn(function()
    task.wait(2.5)

    -- Проверка угла между направлениями
    local function AngleBetween(v1, v2)
        local d = v1.Unit:Dot(v2.Unit)
        return math.acos(math.clamp(d, -1, 1))
    end

    pcall(function()
        local originalRaycast = WS.Raycast

        local hooked = newccl(function(self, origin, direction, rayParams)
            -- Сначала выполняем оригинальный raycast (античит видит что всё честно)
            local originalResult = originalRaycast(self, origin, direction, rayParams)

            -- Проверки безопасности
            if not CFG.SilentAim then return originalResult end
            if not cachedPred then return originalResult end
            if checkcaller() then return originalResult end
            if self ~= WS then return originalResult end
            if not IsSafeCaller() then return originalResult end
            if CFG.OnlyWhenShooting and not IsHoldingGun() then return originalResult end
            if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then 
                return originalResult 
            end
            if direction.Magnitude < 10 then return originalResult end

            -- Целевая точка
            local targetPos = cachedPred
            local newDir = (targetPos - origin)
            if newDir.Magnitude < 5 then return originalResult end

            -- 🛡️ ПРОВЕРКА УГЛА — если слишком большой, античит спалит
            local angle = math.deg(AngleBetween(direction, newDir))
            if angle > CFG.MaxAngle then return originalResult end

            -- 🔥 HIT PART SPOOF MODE
            if CFG.HitPartMode then
                -- Проверяем что цель ещё валидна
                if not Target or not Target.Character then return originalResult end
                local head = GetHead(Target)
                if not head then return originalResult end

                -- Возвращаем СВОЙ RaycastResult с головой врага
                -- Античит думает что игрок реально попал в голову
                local spoofedResult = {
                    Instance   = head,
                    Position   = targetPos,
                    Normal     = -direction.Unit,
                    Material   = head.Material,
                    Distance   = (targetPos - origin).Magnitude,
                }

                -- Возвращаем как таблицу (Roblox позволяет читать поля)
                return setmetatable(spoofedResult, {
                    __index = function(_, k)
                        return spoofedResult[k]
                    end,
                    __tostring = function() return "RaycastResult" end,
                })
            else
                -- Старый метод (легкая подмена направления)
                local newDirection = newDir.Unit * direction.Magnitude
                return originalRaycast(self, origin, newDirection, rayParams)
            end
        end)

        hookfunction(originalRaycast, hooked)
        hooksInstalled = 1
        hookStatus = "🛡️ Bypass active"
        Notify("Eventide v2.2", "🛡️ Anti-Cheat Bypass активен!", 5)
        print("[Eventide v2.2] Anti-Cheat Bypass loaded")
    end)

    if hooksInstalled == 0 then
        hookStatus = "❌ Failed"
        Notify("Eventide", "Hook не удался", 5)
    end
end)

-- ==================== BACKUP AIMBOT ====================
UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = true
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = false
    end
end)

RS.RenderStepped:Connect(function()
    Cam = WS.CurrentCamera
    if CFG.AimbotBackup and aiming and Target then
        local pos = cachedPred or (GetHead(Target) and GetHead(Target).Position)
        if pos then
            local cur     = Cam.CFrame
            local desired = CFrame.new(cur.Position, pos)
            Cam.CFrame    = cur:Lerp(desired, CFG.AimbotSmooth)
        end
    end
end)

-- ==================== ESP ====================
local function MakeESP(p)
    if p == LP or ESPObj[p] then return end
    local e = {
        Box  = Drawing.new("Square"),
        BoxO = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        HP   = Drawing.new("Text"),
        Dist = Drawing.new("Text"),
        Trc  = Drawing.new("Line"),
        HPB  = Drawing.new("Square"),
        HPBG = Drawing.new("Square"),
        HD   = Drawing.new("Circle"),
    }
    for _, v in pairs(e) do v.Visible = false end
    e.Box.Thickness  = 1.5
    e.BoxO.Thickness = 3
    e.BoxO.Color     = Color3.new(0,0,0)
    e.BoxO.Transparency = 0.5
    e.Name.Size   = 13; e.Name.Center  = true
    e.Name.Outline = true; e.Name.Font = 2
    e.HP.Size     = 12; e.HP.Center    = true
    e.HP.Outline  = true; e.HP.Font    = 2
    e.Dist.Size   = 11; e.Dist.Center  = true
    e.Dist.Outline = true; e.Dist.Font = 2
    e.Dist.Color  = Color3.fromRGB(180,180,180)
    e.Trc.Thickness  = 1.5
    e.HPB.Filled  = true
    e.HPBG.Filled = true
    e.HPBG.Color  = Color3.fromRGB(20,20,20)
    e.HD.Filled   = true; e.HD.Radius = 3.5; e.HD.NumSides = 12
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
FOVd.Thickness = 1.8; FOVd.NumSides = 64
FOVd.Filled = false; FOVd.Transparency = 0.85

local PD = Drawing.new("Circle")
PD.Filled = true; PD.Radius = 6
PD.NumSides = 12; PD.Color = Color3.fromRGB(0,255,130)

local PL = Drawing.new("Line")
PL.Thickness = 1.6; PL.Color = Color3.fromRGB(0,255,200); PL.Transparency = 0.65

local DB = Drawing.new("Text")
DB.Size = 14; DB.Outline = true; DB.Font = 2
DB.Color = Color3.fromRGB(255,240,100)

RS.RenderStepped:Connect(function(dt)
    table.insert(FPSH, 1/dt)
    if #FPSH > 30 then table.remove(FPSH,1) end
    local s = 0
    for _, v in ipairs(FPSH) do s = s + v end
    FPS = math.floor(s / #FPSH)
end)

local et = 0
RS.RenderStepped:Connect(function(dt)
    Cam = WS.CurrentCamera
    RH  = (RH + 0.003) % 1
    local sc = Cam.ViewportSize / 2

    FOVd.Visible = CFG.ShowFOV
    FOVd.Radius  = CFG.FOV
    FOVd.Position = sc
    FOVd.Color   = CFG.Rainbow and Color3.fromHSV(RH,1,1) or CFG.FOVCol

    if cachedPred and CFG.ShowPred then
        local sp = Cam:WorldToViewportPoint(cachedPred)
        PD.Visible = sp.Z > 0
        PD.Position = Vector2.new(sp.X, sp.Y)
        if Target then
            local h = GetHead(Target)
            if h then
                local hs = Cam:WorldToViewportPoint(h.Position)
                if hs.Z > 0 and sp.Z > 0 then
                    PL.Visible = true
                    PL.From = Vector2.new(hs.X, hs.Y)
                    PL.To   = Vector2.new(sp.X, sp.Y)
                else PL.Visible = false end
            end
        end
    else
        PD.Visible = false; PL.Visible = false
    end

    if CFG.Debug then
        DB.Visible = true
        local tn = Target and Target.Name or "NONE"
        local gun = IsHoldingGun() and "YES" or "NO"
        DB.Text = string.format(
            "PRED:%.0fms | PING:%dms | TGT:%s | GUN:%s | %s",
            curPred*1000, math.floor(GetPing()), tn, gun, hookStatus
        )
        DB.Position = Vector2.new(12, 40)
    else DB.Visible = false end

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

            local col = (Target == p) and Color3.fromRGB(0,255,140) or Color3.fromRGB(160,100,255)
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
                e.HPBG.Visible = true; e.HPBG.Position = Vector2.new(bx-8,by); e.HPBG.Size = Vector2.new(4,bh)
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
                e.Name.Position = Vector2.new(rp.X, by-18)
                e.Name.Color = col
            else e.Name.Visible = false end

            if CFG.Dist then
                e.Dist.Visible = true
                e.Dist.Text = "["..math.floor(d).."m]"
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

-- ==================== GUI ====================
local SGui = Instance.new("ScreenGui")
SGui.Name = "Eventide_"..math.random(10000,99999)
SGui.ResetOnSpawn = false
SGui.IgnoreGuiInset = true
SGui.DisplayOrder = 999999
pcall(function() SGui.Parent = gethui() or game:GetService("CoreGui") end)
if not SGui.Parent then SGui.Parent = LP:WaitForChild("PlayerGui") end

local CC = {
    BG=Color3.fromRGB(10,12,20), BG2=Color3.fromRGB(14,16,26),
    BG3=Color3.fromRGB(20,22,34), Border=Color3.fromRGB(40,42,65),
    Acc=Color3.fromRGB(130,90,240), Grn=Color3.fromRGB(0,230,140),
    Red=Color3.fromRGB(255,80,100), Yel=Color3.fromRGB(255,200,60),
    Txt=Color3.fromRGB(240,240,255), Dim=Color3.fromRGB(140,140,180),
    Off=Color3.fromRGB(38,40,58),
}

local M = Instance.new("Frame")
M.Size = UDim2.new(0,500,0,580)
M.Position = UDim2.new(0.5,-250,0.5,-290)
M.BackgroundColor3 = CC.BG
M.Active = true; M.Draggable = true; M.Visible = true
M.Parent = SGui
Instance.new("UICorner", M).CornerRadius = UDim.new(0,12)
local ms = Instance.new("UIStroke", M); ms.Color = CC.Border; ms.Thickness = 1.2

local T = Instance.new("TextLabel", M)
T.Size = UDim2.new(1,0,0,42); T.BackgroundTransparency = 1
T.Text = "☾  EVENTIDE  v2.2  BYPASS"
T.TextColor3 = CC.Acc; T.Font = Enum.Font.GothamBold; T.TextSize = 16

local St = Instance.new("TextLabel", M)
St.Size = UDim2.new(1,0,0,18); St.Position = UDim2.new(0,0,0,40)
St.BackgroundTransparency = 1
St.Text = "🛡️  Anti-Cheat Bypass  •  Hit Part Spoof"
St.TextColor3 = CC.Grn; St.Font = Enum.Font.Gotham; St.TextSize = 11

local CB = Instance.new("TextButton", M)
CB.Size = UDim2.new(0,28,0,28); CB.Position = UDim2.new(1,-34,0,8)
CB.BackgroundColor3 = CC.Red; CB.Text = "✕"; CB.TextColor3 = Color3.new(1,1,1)
CB.Font = Enum.Font.GothamBold; CB.TextSize = 16; CB.BorderSizePixel = 0
CB.AutoButtonColor = false
Instance.new("UICorner", CB).CornerRadius = UDim.new(0,6)
CB.MouseButton1Click:Connect(function()
    M.Visible = false
    Notify("Eventide","INSERT — открыть меню",2)
end)

local SF = Instance.new("ScrollingFrame", M)
SF.Size = UDim2.new(1,-16,1,-68); SF.Position = UDim2.new(0,8,0,62)
SF.BackgroundTransparency = 1; SF.ScrollBarThickness = 3
SF.ScrollBarImageColor3 = CC.Acc
SF.AutomaticCanvasSize = Enum.AutomaticSize.Y
SF.CanvasSize = UDim2.new(0,0,0,0); SF.BorderSizePixel = 0
local SFL = Instance.new("UIListLayout", SF); SFL.Padding = UDim.new(0,8)

local function Sec(title)
    local w = Instance.new("Frame", SF)
    w.Size = UDim2.new(1,-4,0,38); w.BackgroundColor3 = CC.BG2
    w.AutomaticSize = Enum.AutomaticSize.Y; w.BorderSizePixel = 0
    Instance.new("UICorner", w).CornerRadius = UDim.new(0,8)
    local ws = Instance.new("UIStroke", w); ws.Color = CC.Border; ws.Thickness = 1
    local bar = Instance.new("Frame", w)
    bar.Size = UDim2.new(0,3,0,18); bar.Position = UDim2.new(0,10,0,10)
    bar.BackgroundColor3 = CC.Acc; bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    local tl = Instance.new("TextLabel", w)
    tl.Size = UDim2.new(1,-30,0,36); tl.Position = UDim2.new(0,20,0,0)
    tl.BackgroundTransparency = 1; tl.Text = title; tl.TextColor3 = CC.Txt
    tl.Font = Enum.Font.GothamBold; tl.TextSize = 12
    tl.TextXAlignment = Enum.TextXAlignment.Left
    local cont = Instance.new("Frame", w)
    cont.Size = UDim2.new(1,0,0,0); cont.Position = UDim2.new(0,0,0,36)
    cont.BackgroundTransparency = 1; cont.AutomaticSize = Enum.AutomaticSize.Y
    cont.BorderSizePixel = 0
    local cl = Instance.new("UIListLayout", cont); cl.Padding = UDim.new(0,4)
    local cp = Instance.new("UIPadding", cont)
    cp.PaddingLeft = UDim.new(0,12); cp.PaddingRight = UDim.new(0,12)
    cp.PaddingBottom = UDim.new(0,10)
    return cont
end

local function Tog(par, lbl, key, cb)
    local f = Instance.new("Frame", par)
    f.Size = UDim2.new(1,0,0,28); f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.72,0,1,0); l.BackgroundTransparency = 1
    l.Text = lbl; l.TextColor3 = CC.Txt; l.Font = Enum.Font.Gotham
    l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("Frame", f)
    sw.Size = UDim2.new(0,36,0,18); sw.Position = UDim2.new(1,-40,0.5,-9)
    sw.BackgroundColor3 = CFG[key] and CC.Acc or CC.Off; sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1,0)
    local kn = Instance.new("Frame", sw)
    kn.Size = UDim2.new(0,13,0,13)
    kn.Position = CFG[key] and UDim2.new(1,-15,0.5,-6.5) or UDim2.new(0,2,0.5,-6.5)
    kn.BackgroundColor3 = Color3.new(1,1,1); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1,0)
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(1,0,1,0); bt.BackgroundTransparency = 1
    bt.Text = ""; bt.AutoButtonColor = false
    bt.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TS:Create(sw, TweenInfo.new(0.18),{BackgroundColor3 = CFG[key] and CC.Acc or CC.Off}):Play()
        TS:Create(kn, TweenInfo.new(0.18),{
            Position = CFG[key] and UDim2.new(1,-15,0.5,-6.5) or UDim2.new(0,2,0.5,-6.5)
        }):Play()
        if cb then cb(CFG[key]) end
    end)
end

local function Sld(par, lbl, key, mn, mx, dc, cb)
    dc = dc or 0
    local f = Instance.new("Frame", par); f.Size = UDim2.new(1,0,0,40)
    f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.6,0,0,18); l.BackgroundTransparency = 1
    l.Text = lbl; l.TextColor3 = CC.Txt; l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    local vl = Instance.new("TextLabel", f)
    vl.Size = UDim2.new(0.4,0,0,18); vl.Position = UDim2.new(0.6,0,0,0)
    vl.BackgroundTransparency = 1; vl.TextColor3 = CC.Acc
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 11
    vl.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("Frame", f)
    track.Size = UDim2.new(1,0,0,5); track.Position = UDim2.new(0,0,0,22)
    track.BackgroundColor3 = CC.Off; track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", track); fill.BackgroundColor3 = CC.Acc
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0,13,0,13); thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.ZIndex = 5; thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    local function U()
        local pct = math.clamp((CFG[key]-mn)/(mx-mn), 0, 1)
        fill.Size = UDim2.new(pct,0,1,0); thumb.Position = UDim2.new(pct,-6,0.5,-6)
        vl.Text = dc > 0 and string.format("%."..dc.."f", CFG[key]) or tostring(math.floor(CFG[key]))
    end
    U()
    local dr = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((i.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
            local raw = mn + (mx-mn)*pct
            CFG[key] = dc > 0 and math.floor(raw*10^dc+0.5)/10^dc or math.floor(raw+0.5)
            U(); if cb then cb(CFG[key]) end
        end
    end)
end

local function Btn(par, lbl, cb, col)
    local b = Instance.new("TextButton", par)
    b.Size = UDim2.new(1,0,0,30); b.BackgroundColor3 = col or CC.Off
    b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold
    b.TextSize = 11; b.Text = lbl; b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
end

local function Lbl(par, txt, col)
    local l = Instance.new("TextLabel", par)
    l.Size = UDim2.new(1,0,0,16); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = col or CC.Dim
    l.Font = Enum.Font.Gotham; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
end

local function Gap(par)
    local g = Instance.new("Frame", par); g.Size = UDim2.new(1,0,0,4)
    g.BackgroundTransparency = 1
end

-- ==================== SECTIONS ====================
local s1 = Sec("🛡️  SILENT AIM (BYPASS)")
Lbl(s1, "Hit Part Spoof — античит НЕ палит!", CC.Grn)
Gap(s1)
Tog(s1, "Enable Silent Aim", "SilentAim")
Tog(s1, "Hit Part Mode (безопасный)", "HitPartMode")
Tog(s1, "Только при стрельбе", "OnlyWhenShooting")
Tog(s1, "Velocity Smoothing", "Smoothing")
Tog(s1, "Resolver (⚠ рискованно)", "Resolver")
Tog(s1, "Team Check", "TeamCheck")
Tog(s1, "Ignore Downed", "NoDowned")
Gap(s1)
Sld(s1, "FOV (меньше = безопаснее)", "FOV", 30, 300, 0)
Sld(s1, "Prediction", "ManualPred", 0.05, 0.30, 3)
Sld(s1, "Prediction Multiplier", "PredMult", 0.5, 2.0, 2)
Sld(s1, "Макс. угол (гр)", "MaxAngle", 5, 45, 0)
Sld(s1, "Max Distance", "MaxDist", 100, 2000, 0)

local s2 = Sec("⚡  PRESETS")
Btn(s2, "🛡️  MAX SAFE  (без кика)", function()
    CFG.FOV=70; CFG.MaxAngle=15; CFG.PredMult=0.9
    CFG.Resolver=false; CFG.HitPartMode=true
    Notify("Preset","MAX SAFE применён",2)
end, Color3.fromRGB(30,100,60))
Btn(s2, "🎯  BALANCED", function()
    CFG.FOV=120; CFG.MaxAngle=25; CFG.PredMult=1.0
    CFG.Resolver=false; CFG.HitPartMode=true
    Notify("Preset","BALANCED применён",2)
end)
Btn(s2, "🔥  AGGRESSIVE (риск кика)", function()
    CFG.FOV=200; CFG.MaxAngle=40; CFG.PredMult=1.1
    CFG.Resolver=true; CFG.HitPartMode=false
    Notify("Preset","AGGRESSIVE — риск!",3)
end, Color3.fromRGB(100,50,30))

local s3 = Sec("🎮  BACKUP AIMBOT (ПКМ)")
Lbl(s3, "Античит НЕ палит (это движение мыши)", CC.Grn)
Gap(s3)
Tog(s3, "Enable Backup Aimbot", "AimbotBackup")
Sld(s3, "Smoothness", "AimbotSmooth", 0.04, 0.5, 2)

local s4 = Sec("👁  ESP")
Tog(s4, "Enable ESP", "ESP")
Tog(s4, "Boxes", "Boxes"); Tog(s4, "Names", "Names")
Tog(s4, "Health Bar", "HP"); Tog(s4, "Distance", "Dist")
Tog(s4, "Head Dot", "HeadDot"); Tog(s4, "Tracers", "Tracers")
Gap(s4)
Tog(s4, "Show FOV Circle", "ShowFOV")
Tog(s4, "Show Prediction Dot", "ShowPred")
Tog(s4, "Rainbow FOV", "Rainbow")
Tog(s4, "Debug Info", "Debug")

local s5 = Sec("ℹ  INFO")
Lbl(s5, "☾ EVENTIDE v2.2 — Bypass Edition", CC.Acc)
Gap(s5)
Lbl(s5, "🛡️ Hit Part Spoofing:", CC.Grn)
Lbl(s5, "Не меняем направление луча", CC.Txt)
Lbl(s5, "Подменяем ТОЛЬКО результат Raycast", CC.Txt)
Lbl(s5, "Античит видит: игрок попал куда целился", CC.Txt)
Gap(s5)
Lbl(s5, "⚠ Правила безопасности:", CC.Yel)
Lbl(s5, "• Не ставь FOV больше 150", CC.Dim)
Lbl(s5, "• Не включай Resolver против серверов с AC", CC.Dim)
Lbl(s5, "• Держи оружие в руках", CC.Dim)
Gap(s5)
Lbl(s5, "INSERT — меню | F2 — silent | END — выгрузить", CC.Txt)

local s6 = Sec("🗑  ВЫГРУЗИТЬ")
Btn(s6, "UNLOAD", function()
    pcall(function() FOVd:Remove(); PD:Remove(); PL:Remove(); DB:Remove() end)
    for p in pairs(ESPObj) do KillESP(p) end
    getgenv()._EV_XS = nil
    pcall(function() SGui:Destroy() end)
    Notify("Eventide","Выгружен",3)
end, CC.Red)

-- ==================== HOTKEYS ====================
UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.Insert then
        M.Visible = not M.Visible
    end
    if i.KeyCode == Enum.KeyCode.F2 then
        CFG.SilentAim = not CFG.SilentAim
        Notify("Silent Aim", CFG.SilentAim and "✅ ON" or "❌ OFF", 2)
    end
    if i.KeyCode == Enum.KeyCode.F3 then
        CFG.ESP = not CFG.ESP
        Notify("ESP", CFG.ESP and "✅ ON" or "❌ OFF", 2)
    end
    if i.KeyCode == Enum.KeyCode.End then
        pcall(function() FOVd:Remove(); PD:Remove(); PL:Remove(); DB:Remove() end)
        for p in pairs(ESPObj) do KillESP(p) end
        getgenv()._EV_XS = nil
        pcall(function() SGui:Destroy() end)
        Notify("Eventide","Выгружен",3)
    end
end)

Notify("☾ EVENTIDE v2.2","🛡️ Anti-Cheat Bypass загружен!\nHit Part Spoof активен",8)