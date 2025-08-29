local QBCore = exports['qb-core']:GetCoreObject()
local currentMission = nil
local bossPed = nil
local missionVehicle = nil
local missionTarget = nil
local missionGuards = {}
local deliveryBlip = nil
local missionBlip = nil
local activeFires = {}

-- Boss NPC Config
local MafiaBoss = {
    ped = "ig_g",
    coords = vector4(-1587.25, 773.58, 189.19, 117.09),
}

-- Vehicle mission spawn points
local StealVehicleSpawns = {
    {coords = vector4(395.49, -1663.34, 32.53, 135.4)},
    {coords = vector4(-294.96, -762.38, 38.78, 298.19)},
    {coords = vector4(-151.31, -617.19, 32.42, 72.11)},
    {coords = vector4(-612.4, 345.54, 85.12, 164.94)}
}

-- Delivery location for stolen car
local DeliveryLocations = {
    vector3(1218.81, -3235.1, 5.53),
    vector3(853.75, -2120.15, 30.6),
    vector3(802.01, -2502.91, 22.23),
    vector3(1037.36, -2177.81, 31.53)
}

-- Burn Mission locations
local BurnLocations = {
    vector3(-1062.5, -1660.6, 4.5),
    vector3(1394.3, 3607.6, 34.9),
    vector3(-437.61, 6261.25, 30.07),
    vector3(976.81, -1831.57, 31.27)
}

-- Kill Mission locations
local KillLocations = {
    vector3(319.88, -200.83, 54.09),
    vector3(2432.7, 4981.6, 46.8),
    vector3(-1954.03, -516.75, 11.88),
    vector3(-289.23, 6317.8, 32.43)
}

-- Spawn Boss Ped
CreateThread(function()
    RequestModel(MafiaBoss.ped)
    while not HasModelLoaded(MafiaBoss.ped) do Wait(0) end

    bossPed = CreatePed(0, MafiaBoss.ped, MafiaBoss.coords.x, MafiaBoss.coords.y, MafiaBoss.coords.z - 1, MafiaBoss.coords.w, false, true)
    FreezeEntityPosition(bossPed, true)
    SetEntityInvincible(bossPed, true)
    SetBlockingOfNonTemporaryEvents(bossPed, true)

    exports['qb-target']:AddTargetEntity(bossPed, {
        options = {
            {
                label = "Talk to Mafia Boss",
                icon = "fa-solid fa-user-tie",
                action = function()
                    if currentMission == nil then
                        TriggerServerEvent('qb-mafiaboss:server:giveMission')
                    else
                        QBCore.Functions.Notify("Finish your current mission first!", "error")
                    end
                end
            },
            {
                label = "Collect Reward",
                icon = "fa-solid fa-sack-dollar",
                action = function()
                    if currentMission == "done" then
                        -- stop fires if any
                        for _, f in ipairs(activeFires) do
                            RemoveScriptFire(f)
                        end
                        activeFires = {}

                        TriggerServerEvent('qb-mafiaboss:server:finishMission')
                        ClearMission()
                    else
                        QBCore.Functions.Notify("No mission completed yet!", "error")
                    end
                end
            }
        },
        distance = 2.5
    })
end)

-- Reset mission cleanup
function ClearMission()
    currentMission = nil
    if missionVehicle and DoesEntityExist(missionVehicle) then
        DeleteEntity(missionVehicle)
        missionVehicle = nil
    end
    if missionTarget and DoesEntityExist(missionTarget) then
        DeleteEntity(missionTarget)
        missionTarget = nil
    end
    for _, guard in pairs(missionGuards) do
        if DoesEntityExist(guard) then
            DeleteEntity(guard)
        end
    end
    missionGuards = {}
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    if missionBlip then
        RemoveBlip(missionBlip)
        missionBlip = nil
    end
    exports['qb-target']:RemoveZone("burnBuilding")
    exports['qb-target']:RemoveZone("deliveryPoint")
end

-- 🪦 Mission Fail on Death
CreateThread(function()
    while true do
        Wait(2000)
        if currentMission ~= nil and currentMission ~= "done" then
            -- fail only for burn & steal
            if currentMission == "burn" or currentMission == "steal" then
                if IsEntityDead(PlayerPedId()) then
                    QBCore.Functions.Notify("You died... The mission has failed!", "error")
                    ClearMission()
                end
            end
        end
    end
end)

-- 🔥 Burn Mission
function StartBurnMission()
    local coords = BurnLocations[math.random(1, #BurnLocations)]
    QBCore.Functions.Notify("Mission: Go burn the marked building!", "primary")

    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, 436)
    SetBlipColour(missionBlip, 1)
    SetBlipRoute(missionBlip, true)

    exports['qb-target']:AddCircleZone("burnBuilding", coords, 2.5, {
        name = "burnBuilding",
        debugPoly = false
    }, {
        options = {
            {
                label = "Burn the Building 🔥",
                icon = "fa-solid fa-fire",
                action = function()
                    if currentMission == "burn" then
                        local ped = PlayerPedId()

                        RequestAnimDict("weapon@w_sp_jerrycan")
                        while not HasAnimDictLoaded("weapon@w_sp_jerrycan") do Wait(0) end

                        TaskPlayAnim(ped, "weapon@w_sp_jerrycan", "fire", 3.0, -1, 5000, 49, 0, 0, 0, 0)

                        QBCore.Functions.Progressbar("burn_building", "Pouring Gasoline...", 5000, false, true, {
                            disableMovement = true,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                        }, {}, {}, {}, function()
                            ClearPedTasks(ped)

                            local fire = StartScriptFire(coords.x, coords.y, coords.z, 25, false)
                            table.insert(activeFires, fire)

                            QBCore.Functions.Notify("The building is burning! Return to the Mafia Boss.", "success")
                            currentMission = "done"
                            if missionBlip then
                                RemoveBlip(missionBlip)
                                missionBlip = nil
                            end
                            exports['qb-target']:RemoveZone("burnBuilding")
                        end, function()
                            ClearPedTasks(ped)
                            QBCore.Functions.Notify("You stopped pouring gasoline.", "error")
                        end)
                    end
                end
            }
        },
        distance = 2.5
    })
end

-- 🚗 Steal Vehicle Mission
function StartStealMission()
    QBCore.Functions.Notify("Mission: Go steal the marked vehicle!", "primary")

    local spot = StealVehicleSpawns[math.random(1, #StealVehicleSpawns)]
    local coords = spot.coords

    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, 523)
    SetBlipColour(missionBlip, 5)
    SetBlipRoute(missionBlip, true)

    local model = `speedo4`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    missionVehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, true, true)
    SetVehicleDoorsLocked(missionVehicle, 1)
    SetVehicleNumberPlateText(missionVehicle, "MAFIA"..math.random(100,999))
    SetEntityAsMissionEntity(missionVehicle, true, true)

    -- guards
    local guardModel = `s_m_m_chemsec_01`
    RequestModel(guardModel)
    while not HasModelLoaded(guardModel) do Wait(0) end

    local guardPositions = {
        vector4(coords.x + 3.0, coords.y + 2.0, coords.z, coords.w),
        vector4(coords.x - 4.0, coords.y - 1.5, coords.z, coords.w),
        vector4(coords.x + 2.0, coords.y - 3.5, coords.z, coords.w)
    }

    for _, gPos in ipairs(guardPositions) do
        local ped = CreatePed(4, guardModel, gPos.x, gPos.y, gPos.z - 1.0, gPos.w, true, true)
        GiveWeaponToPed(ped, `weapon_machete`, 200, false, true)
        SetPedArmour(ped, 50)
        SetPedAccuracy(ped, 60)
        SetPedAsEnemy(ped, true)
        SetPedRelationshipGroupHash(ped, `HATES_PLAYER`)
        TaskCombatPed(ped, PlayerPedId(), 0, 16)
        table.insert(missionGuards, ped)
    end

    QBCore.Functions.Notify("Guards are protecting the car, be careful!", "error")

    CreateThread(function()
        while currentMission == "steal" do
            Wait(1000)
            if IsPedInVehicle(PlayerPedId(), missionVehicle, false) then
                if missionBlip then
                    RemoveBlip(missionBlip)
                    missionBlip = nil
                end

                local dropoff = DeliveryLocations[math.random(1, #DeliveryLocations)]
                deliveryBlip = AddBlipForCoord(dropoff.x, dropoff.y, dropoff.z)
                SetBlipSprite(deliveryBlip, 50)
                SetBlipColour(deliveryBlip, 5)
                SetBlipRoute(deliveryBlip, true)

                exports['qb-target']:AddCircleZone("deliveryPoint", dropoff, 4.0, {
                    name = "deliveryPoint",
                    debugPoly = false
                }, {
                    options = {
                        {
                            label = "Deliver Vehicle 🚗",
                            icon = "fa-solid fa-flag-checkered",
                            action = function()
                                if IsPedInVehicle(PlayerPedId(), missionVehicle, false) then
                                    DeleteEntity(missionVehicle)
                                    QBCore.Functions.Notify("Vehicle delivered! Return to the Mafia Boss.", "success")
                                    currentMission = "done"
                                    exports['qb-target']:RemoveZone("deliveryPoint")
                                    if deliveryBlip then
                                        RemoveBlip(deliveryBlip)
                                        deliveryBlip = nil
                                    end
                                else
                                    QBCore.Functions.Notify("You must be in the vehicle to deliver it.", "error")
                                end
                            end
                        }
                    },
                    distance = 3.5
                })
                break
            end
        end
    end)
end

-- 🔫 Kill Target Mission
function StartKillMission()
    local coords = KillLocations[math.random(1, #KillLocations)]
    QBCore.Functions.Notify("Mission: Eliminate the target!", "primary")

    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, 310)
    SetBlipColour(missionBlip, 1)
    SetBlipRoute(missionBlip, true)

    local pedModel = `g_m_m_chiboss_01`
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(0) end

    missionTarget = CreatePed(4, pedModel, coords.x, coords.y, coords.z - 1.0, 90.0, true, true)
    GiveWeaponToPed(missionTarget, `weapon_machete`, 100, false, true)
    SetPedArmour(missionTarget, 100)
    SetPedAsEnemy(missionTarget, true)
    SetPedRelationshipGroupHash(missionTarget, `HATES_PLAYER`)
    TaskCombatPed(missionTarget, PlayerPedId(), 0, 16)

    CreateThread(function()
        while currentMission == "kill" do
            Wait(1000)
            if IsEntityDead(missionTarget) then
                if not IsEntityDead(PlayerPedId()) then
                    QBCore.Functions.Notify("Target eliminated! Return to the Mafia Boss.", "success")
                    currentMission = "done"
                    if missionBlip then
                        RemoveBlip(missionBlip)
                        missionBlip = nil
                    end
                end
                break
            end
        end
    end)
end

-- 🚀 Mission Starter
RegisterNetEvent('qb-mafiaboss:client:startMission', function(mission)
    currentMission = mission
    if mission == "burn" then
        StartBurnMission()
    elseif mission == "steal" then
        StartStealMission()
    elseif mission == "kill" then
        StartKillMission()
    end
end)

-- Debug
RegisterCommand("finishmission", function()
    if currentMission ~= nil then
        currentMission = "done"
        QBCore.Functions.Notify("Return to the Mafia Boss to collect your reward.", "success")
    else
        QBCore.Functions.Notify("You don’t have an active mission.", "error")
    end
end)
