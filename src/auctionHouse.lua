local auctionHouse = {}

auctionHouse.actions = {
    buy = 1,
    sell = 2,
    [1] = "Buy",
    [2] = "Sell"
}

function auctionHouse.updateAuctionHouse(packet)
    local slot = packet:byte(0x05 + 1)
    local status = packet:byte(0x14 + 1)
    if auctioneer.AuctionHouse ~= nil and slot ~= 7 and status ~= 0x02 and status ~= 0x04 and status ~= 0x10 then
        if status == 0x00 then
            auctioneer.AuctionHouse[slot] = {}
            auctioneer.AuctionHouse[slot].status = "Empty"
        else
            if status == 0x03 then
                auctioneer.AuctionHouse[slot].status = "On auction"
            elseif status == 0x0A or status == 0x0C or status == 0x15 then
                auctioneer.AuctionHouse[slot].status = "Sold"
            elseif status == 0x0B or status == 0x0D or status == 0x16 then
                auctioneer.AuctionHouse[slot].status = "Not Sold"
            end
            auctioneer.AuctionHouse[slot].item = utils.getItemName(struct.unpack("h", packet, 0x28 + 1))
            auctioneer.AuctionHouse[slot].count = packet:byte(0x2A + 1)
            auctioneer.AuctionHouse[slot].price = struct.unpack("i", packet, 0x2C + 1)
            auctioneer.AuctionHouse[slot].timestamp = struct.unpack("i", packet, 0x38 + 1)
        end
    end
end

function auctionHouse.buy(item, single, price)
    if auctioneer.AuctionHouse == nil then
        print(chat.header(addon.name):append(chat.error("Interact with auction house or use /ah menu first")))
        return false
    end

    local slot = auctionHouse.findEmptySlot() == nil and 0x07 or auctionHouse.findEmptySlot()
    local trans = struct.pack("bbxxihxx", 0x0E, slot, price, item.Id)
    local command = string.format('/buy "%s" %s %s ID:%s', item.Name[1], utils.commaValue(price),
        single == 1 and "[Single]" or "[Stack]", item.Id)


    trans = struct.pack("bbxx", 0x4E, 0x1E) .. trans .. struct.pack("bi32i11", single, 0x00, 0x00)
    packet = trans:totable()

    print(chat.header(addon.name):append(chat.color2(200, command)))
    packetManager:AddOutgoingPacket(0x4E, packet)
    return true
end

function auctionHouse.sell(item, single, price)
    if auctioneer.AuctionHouse == nil then
        print(chat.header(addon.name):append(chat.error("Interact with auction house or use /ah menu first")))
        return false
    end

    if auctionHouse.findEmptySlot() == nil then
        print(chat.header(addon.name):append(chat.error("No empty slots available")))
        return false
    end

    local index = utils.findItem(item.Id, single == 1 and single or item.StackSize)
    if index == nil then
        print(chat.header(addon.name):append(chat.error(string.format("%s of %s not found in inventory",
            single == 1 and "Single" or "Stack", item.Name[1]))))
        return false
    end

    local trans = struct.pack("bxxxihh", 0x04, price, index, item.Id)
    local command = string.format('/sell "%s" %s %s ID:%d Ind:%d', item.Name[1], utils.commaValue(price),
        single == 1 and "[Single]" or "[Stack]", item.Id, index)

    trans = struct.pack("bbxx", 0x4E, 0x1E) .. trans .. struct.pack("bi32i11", single, 0x00, 0x00)
    last4E = trans
    local packet = trans:totable()

    print(chat.header(addon.name):append(chat.color2(200, command)))
    packetManager:AddOutgoingPacket(0x4E, packet)
    return true
end

function auctionHouse.sendConfirmSell(packet)
    if packet ~= nil then
        packetManager:AddOutgoingPacket(0x4E, packet)
        return true
    end
    return false
end

function auctionHouse.findEmptySlot()
    if auctioneer.AuctionHouse ~= nil then
        for slot = 0, 6 do
            if auctioneer.AuctionHouse[slot] ~= nil and auctioneer.AuctionHouse[slot].status == "Empty" then
                return slot
            end
        end
    end
    return nil
end

function auctionHouse.clearSales()
    cleared = false
    if auctioneer.AuctionHouse == nil then
        print(chat.header(addon.name):append(chat.error(
            "Interact with auction house or use /ah menu to initialize sales")))
        return false
    end
    for slot = 0, 6 do
        if auctioneer.AuctionHouse[slot] ~= nil then
            if auctioneer.AuctionHouse[slot].status == "Sold" or auctioneer.AuctionHouse[slot].status == "Not Sold" then
                entry = {
                    type = task.type.clearSlot,
                    slot = slot
                }
                task.enqueue(entry)
            else
                print(chat.header(addon.name):append(chat.color2(200,
                    string.format('Slot %i (%s): no need to clear', slot + 1, auctioneer.AuctionHouse[slot].status))))
            end
        end
    end
    return true
end

function auctionHouse.clearSlot(slot)
    if slot == nil or slot < 0 or slot > 6 then
        print(chat.header(addon.name):append(chat.error("Invalid slot number")))
    end

    print(chat.header(addon.name):append(chat.color2(200,
        string.format('Slot %i (%s): clearing...', slot + 1, auctioneer.AuctionHouse[slot].status))))
    local packet = struct.pack("bbxxbbi32i22", 0x4E, 0x1E, 0x10, slot, 0x00, 0x00):totable()
    packetManager:AddOutgoingPacket(0x4E, packet)
end

function auctionHouse.proposal(action, itemName, single, price, quantity)
    if action == nil or (action ~= auctionHouse.actions.buy and action ~= auctionHouse.actions.sell) then
        print(chat.header(addon.name):append(chat.error("Invalid action type")))
        return false
    end

    itemName = AshitaCore:GetChatManager():ParseAutoTranslate(itemName, false)
    local item = resourceManager:GetItemByName(itemName, 2)
    if item == nil then
        print(chat.header(addon.name):append(chat.error(string.format('"%s" not a valid item name', itemName))))
        return false
    end

    if utils.hasFlag(item.Flags, itemFlags["NoAuction"]) == true then
        print(chat.header(addon.name):append(chat.error(string.format(
            "%s is not purchasable via the auction house.", item.Name[1]))))
        return false
    end

    if single == "0" or single == "single" then
        single = 1
    elseif item.StackSize ~= 1 and single == "1" or single == "stack" then
        single = 0
    else
        print(chat.header(addon.name):append(chat.error("Specify single or stack")))
        return false
    end

    quantity = tonumber(quantity) or 1
    if quantity == nil or quantity < 1 or (action == auctionHouse.actions.sell and quantity > 7) then
        print(chat.header(addon.name):append(chat.error("Invalid quantity")))
        return false
    end

    price = price:gsub("%p", "")
    if price == nil or string.match(price, "%a") ~= nil or tonumber(price) == nil or tonumber(price) < 1 or
        action == auctionHouse.actions.sell and tonumber(price) > 999999999 or
        action == auctionHouse.actions.buy and tonumber(price) > memoryManager:GetInventory():GetContainerItem(0, 0).Count then
        print(chat.header(addon.name):append(chat.error("Invalid price")))
        return false
    end
    price = tonumber(price)

    entry = {
        type = action == auctionHouse.actions.buy and task.type.buy or auctionHouse.actions.sell,
        item = item,
        single = single,
        price = price
    }

    if action == auctionHouse.actions.buy then
        for i = 1, quantity do
            task.enqueue(entry)
        end
        return true
    elseif action == auctionHouse.actions.sell then
        for i = 1, quantity do
            task.enqueue(entry)
        end
        return true
    else
        print(chat.header(addon.name):append(chat.error("Invalid bid type. Use /buy or /sell")))
        return false
    end
end

return auctionHouse
