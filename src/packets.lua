local chat = require('chat')
local auctionHouse = require('src/auctionHouse')
local task = require('src/task')
local taskTypes = require('data/taskTypes')
local inventory = require('src/inventory')
local debounce = require('src/debounce')
local search = require('src/search')

local packets = {}

function packets.dropItemBySlot(slot, quantity)
    if slot == nil or quantity == nil then
        return false
    end

    local qty = tonumber(quantity)
    if qty == nil or qty <= 0 then
        return false
    end

    local dropPacket = struct.pack('IIBB', 0, qty, 0, slot):totable()
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x028, dropPacket)
    return true
end

function packets.handleIncomingPacket(e)
    if e.id == 0x04C then
        local pType = e.data:byte(5)
        if pType == 0x04 then -- Sell confirm packet
            -- lastIndex = struct.unpack("H", e.data:sub(15, 16))
            -- lastItemId = struct.unpack("H", e.data:sub(13, 14))
            -- lastSingle = e.data:byte(17)
            -- lastFee = struct.unpack("i", e.data, 9)

            local slot = auctionHouse.findEmptySlot()
            local fee = struct.unpack('i', e.data, 9)
            if last4E ~= nil and e.data:byte(7) == 0x01 and slot ~= nil and last4E ~= nil and last4E:byte(5) == 0x04 and
                e.data:sub(13, 17) == last4E:sub(13, 17) and
                AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0).Count >= fee then
                local packet = struct.pack('bbxxbbxxbbbbbbxxbi32i11', 0x4E, 0x1E, 0x0B, slot, last4E:byte(9),
                    last4E:byte(10), last4E:byte(11), last4E:byte(12), e.data:byte(13), e.data:byte(14),
                    last4E:byte(17), 0x00, 0x00):totable()
                last4E = nil

                local id = struct.unpack('H', e.data:sub(15, 16))
                entry = {
                    type = taskTypes.confirmSell,
                    packet = packet,
                    id = id,
                    name = items[id].shortName,
                    single = e.data:byte(17)
                }
                task.preempt(entry)
            end
        elseif pType == 0x0A then
            if e.data:byte(7) == 0x01 then
                if auctioneer.auctionHouse == nil then
                    auctioneer.auctionHouse = {}
                end
                if auctioneer.auctionHouse[e.data:byte(6)] == nil then
                    auctioneer.auctionHouse[e.data:byte(6)] = {}
                end
                auctionHouse.updateAuctionHouse(e.data)
                auctioneer.auctionHouseInitialized = true
            end
        elseif pType == 0x0B or pType == 0x0C or pType == 0x0D or pType == 0x10 then
            if e.data:byte(7) == 0x01 then
                auctionHouse.updateAuctionHouse(e.data)
                auctioneer.auctionHouseInitialized = true
            end
        elseif pType == 0x0E then
            if e.data:byte(7) == 0x01 then
                print(chat.header(addon.name):append(chat.success('Bid success')))
            elseif e.data:byte(7) == 0xC5 then
                print(chat.header(addon.name):append(chat.warning('Bid Failed')))

                if auctioneer.config.removeFailedBuyTasks[1] then
                    local entry = {
                        type = taskTypes.buy,
                        index = struct.unpack('H', e.data:sub(13, 14)),
                        single = e.data:byte(17),
                        price = struct.unpack('i', e.data, 9),
                    }
                    task.filter(entry)
                end
            end
        end
    elseif e.id == 0x000A then
        if auctioneer.zoning then
            auctioneer.visible[1] = true
            auctioneer.zoning = false
        end
    elseif e.id == 0x000B then
        task.clear()
        auctioneer.eta = 0
        auctioneer.auctionHouse = {}
        auctioneer.auctionHouseInitialized = false

        if auctioneer.visible[1] then
            auctioneer.visible[1] = false
            auctioneer.zoning = true
        end
    elseif e.id == 0x01D then
        debounce(inventory.update)
        debounce(search.update, auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])
    elseif e.id == 0x01E then
        local flag = struct.unpack('i1', e.data, 0x04 + 1)
        local container = struct.unpack('i1', e.data, 0x05 + 1)

        if flag == 1 then
            debounce(inventory.update)
            debounce(search.update, auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])
        end
    end
end

return packets
