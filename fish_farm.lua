--// STOP OLD LOOP
if getgenv().FishFarmLoop ~= nil then
    getgenv().FishFarmLoop = false
    task.wait()
end
getgenv().FishFarmLoop = false

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local StartPosition = CFrame.new(-1917, -2037, -1437)
local ReturnPosition = CFrame.new(-1930, 2532, -1415)
local SellNPCPosition = CFrame.new(-1930, 2532, -1415) -- ปรับตำแหน่ง NPC ที่ขายของ
local MaxBackpackItems = 20 -- จำนวนสูงสุดของในกระเป๋า

-- Priority order
local PriorityOrder = {
    ["Polar Bear"] = 1,
    ["Blue Whale"] = 2,
}

local LowPriorityFish = {
    ["Penguin"] = true,
}

-- GUI
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Toggle = Instance.new("TextButton")
Toggle.Size = UDim2.new(0,150,0,50)
Toggle.Position = UDim2.new(0,20,0,200)
Toggle.Text = "Fish Farm: OFF"
Toggle.BackgroundColor3 = Color3.fromRGB(255,60,60)
Toggle.Parent = ScreenGui

----------------------------------------------------
-- PLATFORM SYSTEM
----------------------------------------------------
local CurrentPlatform = nil

local function CreatePlatform(position)
    if CurrentPlatform then
        CurrentPlatform:Destroy()
    end

    local part = Instance.new("Part")
    part.Size = Vector3.new(8,1,8)
    part.Anchored = true
    part.Transparency = 1
    part.CanCollide = true
    part.CFrame = CFrame.new(position.X, position.Y - 3, position.Z)
    part.Parent = workspace

    CurrentPlatform = part
end

local function SafeTeleport(cf)
    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = cf
    CreatePlatform(hrp.Position)
end

----------------------------------------------------
-- VISIT COUNTER FOR BROKEN FISH
----------------------------------------------------
local VisitCounter = {}

local function CountVisit(model)
    if not VisitCounter[model] then
        VisitCounter[model] = 0
    end
    VisitCounter[model] = VisitCounter[model] + 1

    if VisitCounter[model] >= 5 then
        if model and model.Parent then
            model:Destroy() -- remove broken fish
        end
        VisitCounter[model] = nil
        return true -- indicates deleted
    end

    return false
end

----------------------------------------------------
-- BACKPACK CHECK & AUTO SELL
----------------------------------------------------
local function IsBackpackFull()
    local backpackItems = 0
    if LocalPlayer.Backpack then
        backpackItems = #LocalPlayer.Backpack:GetChildren()
    end
    return backpackItems >= MaxBackpackItems
end

local function SellItems()
    -- ครั้งที่ 1: วาปไปหา NPC และกด ProximityPrompt
    SafeTeleport(SellNPCPosition)
    task.wait(0.5)

    local char = LocalPlayer.Character
    if not char then return end

    -- หา NPC และ ProximityPrompt ของร้านขาย
    local npcs = workspace:FindFirstChild("NPCs") or workspace:FindFirstChild("Game")
    if not npcs then return end

    for _, npc in ipairs(npcs:GetChildren()) do
        local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            fireproximityprompt(prompt, prompt.HoldDuration)
            task.wait(0.5)
            break
        end
    end

    -- ครั้งที่ 2: หาและกดปุ่มขาย
    task.wait(0.3)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        local sellButton = gui:FindFirstChild("SellButton", true) 
            or gui:FindFirstChild("Sell", true)
            or gui:FindFirstChild("SellAll", true)
        
        if sellButton and sellButton:IsA("GuiButton") then
            sellButton:Activate()
            task.wait(0.3)
            break
        end
    end

    -- กลับไปยังตำแหน่งเดิม
    task.wait(0.5)
    SafeTeleport(StartPosition)
end

----------------------------------------------------
-- GET SORTED FISH LIST (AFTER EVERY CATCH)
----------------------------------------------------
local function GetSortedFish()
    local fishes = workspace:FindFirstChild("Game")
        and workspace.Game:FindFirstChild("Fishes")

    local tempList = {}

    if fishes then
        for _, model in pairs(fishes:GetChildren()) do
            local zoneObject = model:FindFirstChild("ZoneObject")

            if zoneObject and zoneObject.Value
            and zoneObject.Value.Name == "IceArea" then
                tempList[#tempList+1] = model
            end
        end
    end

    table.sort(tempList, function(a, b)
        -- Crabfish always last
        if LowPriorityFish[a.Name] and not LowPriorityFish[b.Name] then
            return false
        elseif LowPriorityFish[b.Name] and not LowPriorityFish[a.Name] then
            return true
        end

        local pa = PriorityOrder[a.Name] or 999
        local pb = PriorityOrder[b.Name] or 999
        return pa < pb
    end)

    return tempList
end

----------------------------------------------------
-- FARM LOOP
----------------------------------------------------
local function TeleportAndFire()
    while getgenv().FishFarmLoop do
        -- ตรวจสอบว่าเต็มหรือไม่
        if IsBackpackFull() then
            print("Backpack full! Selling items...")
            SellItems()
            task.wait(1)
            continue
        end

        local fishList = GetSortedFish()

        for _, model in ipairs(fishList) do
            if not getgenv().FishFarmLoop then break end
            if not model or not model.Parent then continue end

            -- Check broken fish
            if CountVisit(model) then
                continue
            end

            local part = model:FindFirstChildWhichIsA("BasePart", true)
            local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)

            if part and prompt then
                SafeTeleport(part.CFrame * CFrame.new(0,0,-2))

                task.wait(0.4)

                if not getgenv().FishFarmLoop then break end

                fireproximityprompt(prompt, prompt.HoldDuration)

                task.wait(0.2)

                -- Immediately rescan after catch
                break
            end
        end

        task.wait(0.05)
    end
end

----------------------------------------------------
-- TOGGLE
----------------------------------------------------
Toggle.MouseButton1Click:Connect(function()
    getgenv().FishFarmLoop = not getgenv().FishFarmLoop

    if getgenv().FishFarmLoop then
        Toggle.Text = "Fish Farm: ON"
        Toggle.BackgroundColor3 = Color3.fromRGB(60,255,60)

        SafeTeleport(StartPosition)
        task.wait(1)

        task.spawn(TeleportAndFire)

    else
        Toggle.Text = "Fish Farm: OFF"
        Toggle.BackgroundColor3 = Color3.fromRGB(255,60,60)

        SafeTeleport(ReturnPosition)

        if CurrentPlatform then
            CurrentPlatform:Destroy()
            CurrentPlatform = nil
        end
    end
end)