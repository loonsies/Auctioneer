local chat = require('chat')
local utils = require('src/utils')
local task = require('src/task')
local taskTypes = require('data/taskTypes')
local auctionHouseActions = require('data/auctionHouseActions')
local itemFlags = require('data/itemFlags')

local auctionHouse = {}

function auctionHouse.updateAuctionHouse(packet)
    local slot = packet:byte(0x05 + 1)
    local status = packet:byte(0x14 + 1)
    if auctioneer.auctionHouse ~= nil and slot ~= 7 and status ~= 0x02 and status ~= 0x04 and status ~= 0x10 then
        if status == 0x00 then
            auctioneer.auctionHouse[slot] = {}
            auctioneer.auctionHouse[slot].status = 'Empty'
            return true
        else
            if status == 0x03 then
                auctioneer.auctionHouse[slot].status = 'On auction'
            elseif status == 0x0A or status == 0x0C or status == 0x15 then
                auctioneer.auctionHouse[slot].status = 'Sold'
            elseif status == 0x0B or status == 0x0D or status == 0x16 then
                auctioneer.auctionHouse[slot].status = 'Not Sold'
            end
            auctioneer.auctionHouse[slot].item = utils.getItemName(struct.unpack('h', packet, 0x28 + 1))
            auctioneer.auctionHouse[slot].count = packet:byte(0x2A + 1)
            auctioneer.auctionHouse[slot].price = struct.unpack('i', packet, 0x2C + 1)
            auctioneer.auctionHouse[slot].timestamp = struct.unpack('i', packet, 0x38 + 1)
            return true
        end
    end
    return false
end

function auctionHouse.buy(item, single, price)
    if auctioneer.auctionHouse == nil then
        print(chat.header(addon.name):append(chat.error('Interact with auction house or use /ah menu first')))
        return false
    end

    local slot = auctionHouse.findEmptySlot() == nil and 0x07 or auctionHouse.findEmptySlot()
    local trans = struct.pack('bbxxihxx', 0x0E, slot, price, item.Id)
    local log = string.format('Sending buy packet: "%s" %s %s ID:%s', item.Name[1], utils.commaValue(price),
        single == 1 and '[Single]' or '[Stack]', item.Id)
    trans = struct.pack('bbxx', 0x4E, 0x1E) .. trans .. struct.pack('bi32i11', single, 0x00, 0x00)
    local packet = trans:totable()

    print(chat.header(addon.name):append(chat.color2(200, log)))
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, packet)
    return true
end

function auctionHouse.sell(item, single, price)
    if auctioneer.auctionHouse == nil then
        print(chat.header(addon.name):append(chat.error('Interact with auction house or use /ah menu first')))
        return false
    end

    if auctionHouse.findEmptySlot() == nil then
        print(chat.header(addon.name):append(chat.error('No empty slots available')))
        return false
    end

    local index = utils.findItem(item.Id, single == 1 and single or item.StackSize)
    if index == nil then
        print(chat.header(addon.name):append(chat.error(string.format('%s of %s not found in inventory',
            single == 1 and 'Single' or 'Stack', item.Name[1]))))
        return false
    end

    local trans = struct.pack('bxxxihh', 0x04, price, index, item.Id)
    local log = string.format('Sending sell packet: "%s" %s %s ID:%d Ind:%d', item.Name[1], utils.commaValue(price),
        single == 1 and '[Single]' or '[Stack]', item.Id, index)
    trans = struct.pack('bbxx', 0x4E, 0x1E) .. trans .. struct.pack('bi32i11', single, 0x00, 0x00)
    last4E = trans
    local packet = trans:totable()

    print(chat.header(addon.name):append(chat.color2(200, log)))
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, packet)
    return true
end

function auctionHouse.sendConfirmSell(packet, id, name, single)
    if packet ~= nil then
        local log = string.format('Sending confirm sell packet: "%s" %s ID:%s', name,
            single == 1 and '[Single]' or '[Stack]', id)

        print(chat.header(addon.name):append(chat.color2(200, log)))
        AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, packet)
        return true
    end
    return false
end

function auctionHouse.findEmptySlot()
    if auctioneer.auctionHouse ~= nil then
        for slot = 0, 6 do
            if auctioneer.auctionHouse[slot] ~= nil and auctioneer.auctionHouse[slot].status == 'Empty' then
                return slot
            end
        end
    end
    return nil
end

function auctionHouse.clearSales()
    if auctioneer.auctionHouse == nil then
        print(chat.header(addon.name):append(chat.error(
            'Interact with auction house or use /ah menu to initialize sales')))
        return false
    end
    for slot = 0, 6 do
        if auctioneer.auctionHouse[slot] ~= nil then
            if auctioneer.auctionHouse[slot].status == 'Sold' or auctioneer.auctionHouse[slot].status == 'Not Sold' then
                entry = {
                    type = taskTypes.clearSlot,
                    slot = slot
                }
                task.enqueue(entry)
            else
                print(chat.header(addon.name):append(chat.color2(200,
                    string.format('Slot %i (%s): no need to clear', slot + 1, auctioneer.auctionHouse[slot].status))))
            end
        end
    end
    return true
end

function auctionHouse.clearSlot(slot)
    if slot == nil or slot < 0 or slot > 6 then
        print(chat.header(addon.name):append(chat.error('Invalid slot number')))
        return false
    end

    local log = string.format('Slot %i (%s): sending clear packet', slot + 1, auctioneer.auctionHouse[slot].status)
    local packet = struct.pack('bbxxbbi32i22', 0x4E, 0x1E, 0x10, slot, 0x00, 0x00):totable()

    print(chat.header(addon.name):append(chat.color2(200, log)))
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, packet)
    return true
end

function auctionHouse.proposal(action, itemName, single, price, quantity)
    if action == nil or (action ~= auctionHouseActions.buy and action ~= auctionHouseActions.sell) then
        print(chat.header(addon.name):append(chat.error('Invalid action type')))
        return false
    end

    itemName = AshitaCore:GetChatManager():ParseAutoTranslate(itemName, false)
    local item = AshitaCore:GetResourceManager():GetItemByName(itemName, 2)
    if item == nil then
        print(chat.header(addon.name):append(chat.error(string.format('"%s" not a valid item name', itemName))))
        return false
    end

    if utils.hasFlag(item.Flags, itemFlags['NoAuction']) == true then
        print(chat.header(addon.name):append(chat.error(string.format(
            '%s is not purchasable via the auction house.', item.Name[1]))))
        return false
    end

    if single == '0' or single == 'single' then
        single = 1
    elseif item.StackSize ~= 1 and single == '1' or single == 'stack' then
        single = 0
    else
        print(chat.header(addon.name):append(chat.error('Specify single or stack')))
        return false
    end

    quantity = tonumber(quantity) or 1
    if quantity == nil or quantity < 1 or (action == auctionHouseActions.sell and quantity > 7) then
        print(chat.header(addon.name):append(chat.error('Invalid quantity')))
        return false
    end

    price = price:gsub('%p', '')
    if price == nil or string.match(price, '%a') ~= nil or tonumber(price) == nil or tonumber(price) < 1 or
        action == auctionHouseActions.sell and tonumber(price) > 999999999 or
        action == auctionHouseActions.buy and tonumber(price) > AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0).Count then
        print(chat.header(addon.name):append(chat.error('Invalid price')))
        return false
    end
    price = tonumber(price)

    local entry = {
        type = action == auctionHouseActions.buy and taskTypes.buy or auctionHouseActions.sell,
        item = item,
        single = single,
        price = price
    }

    if action == auctionHouseActions.buy then
        for i = 1, quantity do
            task.enqueue(entry)
        end
        return true
    elseif action == auctionHouseActions.sell then
        for i = 1, quantity do
            task.enqueue(entry)
        end
        return true
    else
        print(chat.header(addon.name):append(chat.error('Invalid bid type. Use /buy or /sell')))
        return false
    end
end

return auctionHouse
