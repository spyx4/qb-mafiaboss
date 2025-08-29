local QBCore = exports['qb-core']:GetCoreObject()

-- CONFIG
local MafiaBoss = {
    rewardMin = 250,
    rewardMax = 350,
    rareItem = "weapon_switchblade", -- bonus item
    rareChance = 25,      -- % chance
}

-- Give mission
RegisterNetEvent('qb-mafiaboss:server:giveMission', function()
    local src = source
    local missions = { "burn", "steal", "kill" }
    local mission = missions[math.random(1, #missions)]

    TriggerClientEvent('qb-mafiaboss:client:startMission', src, mission)
end)

-- Finish mission & reward
RegisterNetEvent('qb-mafiaboss:server:finishMission', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local reward = math.random(MafiaBoss.rewardMin, MafiaBoss.rewardMax)
    Player.Functions.AddMoney("cash", reward, "mafia-mission")

    if math.random(1, 100) <= MafiaBoss.rareChance then
        Player.Functions.AddItem(MafiaBoss.rareItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[MafiaBoss.rareItem], 'add')
        TriggerClientEvent('QBCore:Notify', src, "The boss gave you a bonus prize!", "success")
    end

    TriggerClientEvent('QBCore:Notify', src, "The boss paid you $"..reward, "success")
end)
