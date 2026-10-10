local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local url = "https://raw.githubusercontent.com/ivanchernikin2013-dev/sgergeheshsjre/main/av.jpeg"
local fileName = "av_custom.jpeg"
if not isfile(fileName) then
    writefile(fileName, game:HttpGet(url))
end
local AvatarToUse = getcustomasset(fileName)

local settings = { AbilityEnabled = false }
local firstCastDone = false
local inFirstCast = false

local function isAbilityTool(item)
    if not item or not item:IsA("Tool") then return false end
    if item:FindFirstChild("localEvent") then return true end
    if item:FindFirstChild("abilityType") then return true end
    if item:FindFirstChild("cooldown") and item:FindFirstChild("cooldownLength") then return true end
    return false
end

local function getAbilityCooldown(tool)
    if not tool then return nil end
    local cd = tool:FindFirstChild("cooldown")
    if cd and cd:IsA("NumberValue") then return cd.Value end
    local cd2 = tool:FindFirstChild("cooldownTime")
    if cd2 and cd2:IsA("NumberValue") then return cd2.Value end
    local cd3 = tool:FindFirstChild("Cooldown")
    if cd3 and cd3:IsA("NumberValue") then return cd3.Value end
    return nil
end

local function getAllAbilities()
    local list, seen = {}, {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if isAbilityTool(item) and not seen[item] then
                seen[item] = true
                table.insert(list, item)
            end
        end
    end
    local char = LocalPlayer.Character
    if char then
        local eq = char:FindFirstChildOfClass("Tool")
        if eq and isAbilityTool(eq) and not seen[eq] then
            seen[eq] = true
            table.insert(list, eq)
        end
    end
    return list
end

local function equipTool(tool)
    local char = LocalPlayer.Character
    if not char or not tool then return end
    if tool.Parent == char then return end
    tool.Parent = char
end

local function isBusy()
    local char = LocalPlayer.Character
    if not char then return true end
    local bc = char:FindFirstChild("busyCasting")
    if bc and bc:IsA("BoolValue") then return bc.Value == true end
    return false
end

local function fireAbility(ability)
    equipTool(ability)
    local ev = ability:FindFirstChild("abilityEvent")
    if ev and ev:IsA("RemoteEvent") then pcall(function() ev:FireServer() end) end
    for _, rn in ipairs({ "spellEvent", "fireballShootEvent" }) do
        local r = ability:FindFirstChild(rn)
        if r and r:IsA("RemoteEvent") then pcall(function() r:FireServer() end) end
    end
    local localEvent = ability:FindFirstChild("localEvent")
    if localEvent and localEvent:IsA("BindableEvent") then
        pcall(function() localEvent:Fire() end)
    end
end

local lastAbilityFire = 0
local abilityLastUse = {}
local ABILITY_MIN_INTERVAL = 0.7
local ABILITY_FALLBACK_CD = 2.0

local function doAbility()
    if inFirstCast then return false end
    if not settings.AbilityEnabled then return false end
    local now = tick()
    if now - lastAbilityFire < ABILITY_MIN_INTERVAL then return false end
    if isBusy() then return false end
    local abilities = getAllAbilities()
    if #abilities == 0 then return false end
    for _, ability in ipairs(abilities) do
        local owner = ability.Parent == LocalPlayer.Character or ability.Parent == LocalPlayer.Backpack
        if owner then
            local cd = getAbilityCooldown(ability)
            local lastUse = abilityLastUse[ability] or 0
            local sinceUse = now - lastUse
            local ready = false
            if cd ~= nil then
                ready = (cd <= 0) and (sinceUse >= 0.5)
            else
                ready = (sinceUse >= ABILITY_FALLBACK_CD)
            end
            if ready then
                abilityLastUse[ability] = now
                lastAbilityFire = now
                fireAbility(ability)
                return true
            end
        end
    end
    return false
end

local function runFirstCast()
    if firstCastDone or inFirstCast then return end
    if not settings.AbilityEnabled then return end
    inFirstCast = true
    task.spawn(function()
        while settings.AbilityEnabled and not firstCastDone do
            local abilities = getAllAbilities()
            if #abilities >= 1 then
                while isBusy() do task.wait(0.1) end
                fireAbility(abilities[1])
                abilityLastUse[abilities[1]] = tick()
                lastAbilityFire = tick()
                task.wait(2.5)
                if not settings.AbilityEnabled then
                    inFirstCast = false
                    return
                end
                if #abilities >= 2 then
                    while isBusy() do task.wait(0.1) end
                    fireAbility(abilities[2])
                    abilityLastUse[abilities[2]] = tick()
                    lastAbilityFire = tick()
                end
                firstCastDone = true
                break
            end
            task.wait(0.2)
        end
        inFirstCast = false
    end)
end

RunService.Heartbeat:Connect(function(dt)
    if not settings.AbilityEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if inFirstCast then return end
    doAbility()
end)

local Window = WindUI:CreateWindow({
    Title = "Auto Abilities",
    SubTitle = "Auto ability caster",
    Icon = "sword",
    Author = "@Roblocor",
    Folder = "AutoAbilities",
    Size = UDim2.fromOffset(650, 450),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Anonymous = false,
    },
})

-- ============================================================
-- Оптимизированная замена аватарки + чистка тумблеров
-- ============================================================
local function getContainers()
    local list = { game:GetService("CoreGui") }
    local ok, hui = pcall(gethui)
    if ok and hui then table.insert(list, hui) end
    return list
end

local function applyAvatar(d)
    if not d:IsA("ImageLabel") then return end
    local img = d.Image or ""
    local low = string.lower(img)
    local isAvatarLike = low:find("rbxthumb", 1, true)
        or low:find("headshot", 1, true)
        or low:find("avatar", 1, true)
        or low:find("av_custom", 1, true)
    if isAvatarLike and d.Image ~= AvatarToUse then
        pcall(function()
            d.Image = AvatarToUse
            d.ImageRectOffset = Vector2.zero
            d.ImageRectSize = Vector2.zero
            d.ScaleType = Enum.ScaleType.Crop
            d.ResampleMode = Enum.ResamplerMode.Default
            d.ImageTransparency = 0
            d.ImageColor3 = Color3.fromRGB(255, 255, 255)
            for _, c in ipairs(d:GetChildren()) do
                if c:IsA("UIGradient") then c:Destroy() end
                if c:IsA("ImageLabel") and c ~= d then
                    c.ImageTransparency = 1
                end
            end
        end)
    end
end

local function cleanToggleKnob(d)
    if not d:IsA("ImageLabel") then return end
    local parent = d.Parent
    if not parent or not parent:IsA("Frame") then return end
    local gp = parent.Parent
    if not gp or not gp:IsA("TextButton") then return end
    local size = parent.AbsoluteSize
    if size.X > 0 and size.Y > 0 and math.abs(size.X - size.Y) < 6 and size.X < 30 then
        pcall(function()
            d.ImageTransparency = 1
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("Frame") then
                    child.BackgroundTransparency = 1
                end
                if child:IsA("ImageLabel") and child ~= d then
                    child.ImageTransparency = 1
                end
            end
        end)
    end
end

-- Первичный проход: несколько раз за первые 4 секунды
task.spawn(function()
    for _ = 1, 8 do
        task.wait(0.5)
        for _, c in ipairs(getContainers()) do
            for _, d in ipairs(c:GetDescendants()) do
                applyAvatar(d)
                cleanToggleKnob(d)
            end
        end
    end
end)

-- Подписка на новые элементы (вместо бесконечного цикла)
local function hookContainer(c)
    c.DescendantAdded:Connect(function(d)
        task.defer(function()
            applyAvatar(d)
            cleanToggleKnob(d)
        end)
    end)
end

for _, c in ipairs(getContainers()) do
    pcall(hookContainer, c)
end

-- ============================================================

local MainTab = Window:Tab({
    Title = "Abilities",
    Icon = "zap",
})

local AbilitySection = MainTab:Section({
    Title = "Ability Settings",
    Opened = true,
})

AbilitySection:Toggle({
    Title = "Auto Use Abilities",
    Desc = "Automatically use abilities when available",
    Icon = "",
    Default = false,
    Callback = function(state)
        settings.AbilityEnabled = state
        if state then
            abilityLastUse = {}
            firstCastDone = false
            inFirstCast = false
            runFirstCast()
        else
            firstCastDone = false
            inFirstCast = false
        end
    end,
})

Window:OnClose(function()
    settings.AbilityEnabled = false
    firstCastDone = false
    inFirstCast = false
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    abilityLastUse = {}
    firstCastDone = false
    inFirstCast = false
    if settings.AbilityEnabled then
        runFirstCast()
    end
end)
