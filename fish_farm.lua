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

local function ClickGuiButton(button)
    if not button then return false end

    if button:IsA("TextButton") then
        local ok = pcall(function()
            button:Activate()
        end)
        return ok
    end

    if button:IsA("ImageButton") then
        local ok = pcall(function()
            button.MouseButton1Click:Fire()
        end)
        if ok then
            return true
        end

        local vim = game:GetService("VirtualInputManager")
        if vim and button.AbsolutePosition and button.AbsoluteSize then
            local x = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
            local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2
            pcall(function()
                vim:SendMouseButtonEvent(x, y, true, 1, nil, 0)
                vim:SendMouseButtonEvent(x, y, false, 1, nil, 0)
            end)
            return true
        end
    end

    return false
end

local function SellItems()
    -- ครั้งที่ 1: วาปไปหา NPC และกด ProximityPrompt
    print("[SELL] Teleporting to NPC position...")
    SafeTeleport(SellNPCPosition)
    task.wait(1)

    local char = LocalPlayer.Character
    if not char then 
        print("[SELL] Character not found!")
        return 
    end

    -- หา NPC ทั้งหมดในพื้นที่ และค้นหา ProximityPrompt
    print("[SELL] Searching for NPC with ProximityPrompt...")
    local foundPrompt = false
    
    -- ค้นหา ProximityPrompt ทั้งใน Workspace
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            print("[SELL] Found ProximityPrompt:", prompt:GetFullName())
            fireproximityprompt(prompt, prompt.HoldDuration)
            foundPrompt = true
            task.wait(1)
            break
        end
    end
    
    if not foundPrompt then
        print("[SELL] No ProximityPrompt found in workspace!")
    end
    print("[SELL] Waiting for UI and looking for Sell button...")
    task.wait(1)
    
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local foundSellButton = false
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        local sellButton = gui:FindFirstChild("SellButton", true) 
            or gui:FindFirstChild("Sell", true)
            or gui:FindFirstChild("SellAll", true)
        
        if sellButton then
            print("[SELL] Found sell button:", sellButton:GetFullName(), sellButton.ClassName)
            if ClickGuiButton(sellButton) then
                foundSellButton = true
                task.wait(1)
                break
            else
                print("[SELL] Failed to click sell button:", sellButton:GetFullName())
            end
        end
    end

    if not foundSellButton then
        print("[SELL] Sell button not found in PlayerGui!")
        -- ลองค้นหา Frame หรือส่วนอื่น ๆ
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj.Name:lower():find("sell") then
                print("[SELL] Found object with 'sell':", obj:GetFullName(), obj.ClassName)
            end
        end
    end
    end

    -- กลับไปยังตำแหน่งเดิม
    print("[SELL] Returning to start position...")
    task.wait(0.5)
    SafeTeleport(StartPosition)
    print("[SELL] Done!")
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