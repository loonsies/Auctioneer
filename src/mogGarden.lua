local chat = require('chat')
local search = require('src/search')
local tabTypes = require('data/tabTypes')

local mogGarden = {}

local lastZone = 0

-- Initialize mog garden state
function mogGarden.init()
    auctioneer.mogGarden = {
        active = false,
        currentZone = 0,
        inventorySnapshot = {},
        newItems = {},
        isZoning = false,
        zoneStartTime = 0,
        lastInventoryCount = 0,
        lastStableTime = 0
    }
end

-- Check zone and activate/deactivate tracking
local function checkMogGardenZone()
    if not auctioneer.config.mogGarden[1] then
        return
    end

    local currentZone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)

    if lastZone ~= currentZone then
        if lastZone ~= 0 then
            auctioneer.mogGarden.isZoning = true
            auctioneer.mogGarden.zoneStartTime = os.clock()
            auctioneer.mogGarden.lastInventoryCount = 0
            auctioneer.mogGarden.lastStableTime = 0
        end
        lastZone = currentZone
    end

    if currentZone == 280 and not auctioneer.mogGarden.active then
        -- Entering Mog Garden
        auctioneer.mogGarden.active = true
        auctioneer.mogGarden.currentZone = currentZone
        auctioneer.mogGarden.inventorySnapshot = {}
        auctioneer.mogGarden.newItems = {}
        auctioneer.mogGarden.isZoning = true
        auctioneer.mogGarden.zoneStartTime = os.clock()
        auctioneer.mogGarden.lastInventoryCount = 0
        auctioneer.mogGarden.lastStableTime = 0

        search.update(tabTypes.mogGarden, auctioneer.tabs[tabTypes.mogGarden])
        print(chat.header(addon.name):append(chat.message('Mog Garden tracking activated')))
    elseif auctioneer.mogGarden.active and currentZone ~= 280 then
        -- Leaving Mog Garden
        auctioneer.mogGarden.active = false
        auctioneer.mogGarden.inventorySnapshot = {}
        auctioneer.mogGarden.newItems = {}
        auctioneer.mogGarden.isZoning = false
        auctioneer.mogGarden.zoneStartTime = 0
        auctioneer.mogGarden.lastInventoryCount = 0
        auctioneer.mogGarden.lastStableTime = 0

        print(chat.header(addon.name):append(chat.message('Mog Garden tracking deactivated')))
    end
end

-- Update item tracking
function mogGarden.update()
    checkMogGardenZone()

    if not auctioneer.config.mogGarden[1] or not auctioneer.mogGarden.active then
        return
    end

    local inv = AshitaCore:GetMemoryManager():GetInventory()

    -- Wait for inventory to load after zoning
    if auctioneer.mogGarden.isZoning then
        local currentTime = os.clock()
        local timeSinceZone = currentTime - auctioneer.mogGarden.zoneStartTime

        -- Count items in inventory
        local itemCount = 0
        for i = 0, 80 do
            local item = inv:GetContainerItem(0, i)
            if item and item.Id ~= 0 then
                itemCount = itemCount + 1
            end
        end

        -- Reset timer if inventory is still changing
        if itemCount ~= auctioneer.mogGarden.lastInventoryCount then
            auctioneer.mogGarden.lastInventoryCount = itemCount
            auctioneer.mogGarden.lastStableTime = currentTime
        end

        local stableTime = auctioneer.mogGarden.lastStableTime > 0 and (currentTime - auctioneer.mogGarden.lastStableTime) or 0

        local minWaitTime = 10.0
        local stableWaitTime = 3.0

        if timeSinceZone >= minWaitTime and
            itemCount > 0 and
            stableTime >= stableWaitTime then
            -- Capture snapshot
            auctioneer.mogGarden.inventorySnapshot = {}
            for i = 0, 80 do
                local item = inv:GetContainerItem(0, i)
                if item and item.Id ~= 0 and items[item.Id] then
                    local key = string.format('%d_%d', item.Id, i)
                    auctioneer.mogGarden.inventorySnapshot[key] = {
                        id = item.Id,
                        count = item.Count,
                        slot = i
                    }
                end
            end
            auctioneer.mogGarden.isZoning = false
        end
        return
    end

    local currentItems = {}
    local foundNewItems = false

    for i = 0, 80 do
        local item = inv:GetContainerItem(0, i)
        if item and item.Id ~= 0 and items[item.Id] then
            local key = string.format('%d_%d', item.Id, i)
            currentItems[key] = {
                id = item.Id,
                count = item.Count,
                slot = i
            }

            local snapshot = auctioneer.mogGarden.inventorySnapshot[key]
            local existingNew = auctioneer.mogGarden.newItems[key]

            if not snapshot then
                -- New item
                if not existingNew then
                    foundNewItems = true
                    auctioneer.mogGarden.newItems[key] = {
                        id = item.Id,
                        count = item.Count,
                        slot = i,
                        isNew = true
                    }

                    auctioneer.mogGarden.inventorySnapshot[key] = {
                        id = item.Id,
                        count = item.Count,
                        slot = i
                    }
                end
            elseif snapshot.count < item.Count then
                -- Item count increased
                foundNewItems = true
                local newCount = item.Count - snapshot.count
                if existingNew then
                    auctioneer.mogGarden.newItems[key].count = existingNew.count + newCount
                else
                    auctioneer.mogGarden.newItems[key] = {
                        id = item.Id,
                        count = newCount,
                        slot = i,
                        isNew = false
                    }
                end
                print(chat.header(addon.name):append(chat.message(string.format('Item increased: %s (+%d)', items[item.Id].shortName, newCount))))

                snapshot.count = item.Count
            end
        end
    end

    -- Remove items no longer in inventory
    local itemsToRemove = {}
    for key, newItem in pairs(auctioneer.mogGarden.newItems) do
        if not currentItems[key] then
            itemsToRemove[#itemsToRemove + 1] = key
            foundNewItems = true
        end
    end

    for _, key in ipairs(itemsToRemove) do
        auctioneer.mogGarden.newItems[key] = nil
        auctioneer.mogGarden.inventorySnapshot[key] = nil
    end

    if foundNewItems then
        search.update(tabTypes.mogGarden, auctioneer.tabs[tabTypes.mogGarden])
    end
end

-- Reset snapshot
function mogGarden.resetSnapshot()
    if not auctioneer.mogGarden.active then
        return false, 'Mog Garden tracking is not active'
    end

    auctioneer.mogGarden.inventorySnapshot = {}
    auctioneer.mogGarden.newItems = {}

    local inv = AshitaCore:GetMemoryManager():GetInventory()
    for i = 0, 80 do
        local item = inv:GetContainerItem(0, i)
        if item and item.Id ~= 0 and items[item.Id] then
            local key = string.format('%d_%d', item.Id, i)
            auctioneer.mogGarden.inventorySnapshot[key] = {
                id = item.Id,
                count = item.Count,
                slot = i
            }
        end
    end

    search.update(tabTypes.mogGarden, auctioneer.tabs[tabTypes.mogGarden])

    return true, 'Snapshot reset successfully'
end

return mogGarden
