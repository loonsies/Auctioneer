local auctionHouse = {}

function auctionHouse.buy(item, single, price)
    local slot = auctionHouse.findEmptySlot() == nil and 0x07 or auctionHouse.findEmptySlot()
    local trans = struct.pack("bbxxihxx", 0x0E, slot, price, item.Id)
    print(chat.header(addon.name):append(chat.message(string.format('/buy "%s" %s %s ID:%s', item.Name[0],
        utils.commaValue(price), single == 1 and "[Single]" or "[Stack]", item.Id))))
    trans = struct.pack("bbxx", 0x4E, 0x1E) .. trans .. struct.pack("bi32i11", single, 0x00, 0x00)
    trans = trans:totable()
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, trans)
    return true
end

function auctionHouse.sell(item, single, price)
    if (auctioneer.auction_box == nil) then
        print(chat.header(addon.name):append(chat.message(
            "AH Error: Click auction counter or use /ah to initialize sales.")))
        return false
    end

    if (auctionHouse.findEmptySlot() == nil) then
        print(chat.header(addon.name):append(chat.message("AH Error: No empty slots available.")))
        return false
    end

    local index = utils.findItem(item.Id, single == 1 and single or item.StackSize)
    if (index == nil) then
        print(chat.header(addon.name):append(chat.message(string.format("AH Error: %s of %s not found in inventory.",
            single == 1 and "Single" or "Stack", item.Name[1]))))
        return false
    end

    local trans = struct.pack("bxxxihh", 0x04, price, index, item.Id)
    print(chat.header(addon.name):append(chat.message(string.format('/sell "%s" %s %s ID:%d Ind:%d', item.Name[0],
        utils.commaValue(price), single == 1 and "[Single]" or "[Stack]", item.Id, index))))

    trans = struct.pack("bbxx", 0x4E, 0x1E) .. trans .. struct.pack("bi32i11", single, 0x00, 0x00)
    last4E = trans
    trans = trans:totable()
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, trans)
    return true
end

function auctionHouse.findEmptySlot()
    if (auctioneer.auction_box ~= nil) then
        for slot = 0, 6 do
            if (auctioneer.auction_box[slot] ~= nil and auctioneer.auction_box[slot].status == "Empty") then
                return slot
            end
        end
    end
    return nil
end

function auctionHouse.clearSales()
    if (auctioneer.auction_box == nil) then
        return false
    end
    for slot = 0, 6 do
        if (auctioneer.auction_box[slot] ~= nil) and
            (auctioneer.auction_box[slot].status == "Sold" or auctioneer.auction_box[slot].status == "Not Sold") then
            local isold = struct.pack("bbxxbbi32i22", 0x4E, 0x1E, 0x10, slot, 0x00, 0x00):totable()
            AshitaCore:GetPacketManager():AddOutgoingPacket(0x4E, isold)
        end
    end
end

function auctionHouse.proposal(bid, name, vol, price)
    name = AshitaCore:GetChatManager():ParseAutoTranslate(name, false)
    local item = AshitaCore:GetResourceManager():GetItemByName(name, 2)
    if (item == nil) then
        print(chat.header(addon.name):append(chat.message(string.format('AH Error: "%s" not a valid item name.', name))))
        return false
    end

    if (utils.hasFlag(item.Flags, itemFlags["NoAuction"]) == true) then
        print(chat.header(addon.name):append(chat.message(string.format(
            "AH Error: %s is not purchasable via the auction house.", item.Name[1]))))
        return false
    end

    local single
    if (item.StackSize ~= 1) and (vol == "1" or vol == "stack") then
        single = 0
    elseif (vol == "0" or vol == "single") then
        single = 1
    else
        print(chat.header(addon.name):append(chat.message("AH Error: Specify single or stack.")))
        return false
    end

    price = price:gsub("%p", "")
    if (price == nil) or (string.match(price, "%a") ~= nil) or (tonumber(price) == nil) or (tonumber(price) < 1) or
        (bid == "/sell" and tonumber(price) > 999999999) or
        (bid == "/buy" and tonumber(price) > AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0).Count) then
        print(chat.header(addon.name):append(chat.message("AH Error: Invalid price.")))
        return false
    end
    price = tonumber(price)

    if (bid == "/buy") then
        return auctionHouse.buy(item, single, price)
    elseif (bid == "/sell") then
        return auctionHouse.sell(item, single, price)
    else
        print(chat.header(addon.name):append(chat.message("AH Error: Invalid bid type. Use /buy or /sell.")))
        return false
    end
end

return auctionHouse
