local packets = {}

function packets.handleIncomingPacket(e)
    if e.id == 0x04C then
        local pType = e.data:byte(5)
        if pType == 0x04 then
            local slot = auctionHouse.findEmptySlot()
            local fee = struct.unpack("i", e.data, 9)
            if last4E ~= nil and e.data:byte(7) == 0x01 and slot ~= nil and last4E ~= nil and last4E:byte(5) == 0x04 and
                e.data:sub(13, 17) == last4E:sub(13, 17) and
                memoryManager:GetInventory():GetContainerItem(0, 0).Count >= fee then
                local packet = struct.pack("bbxxbbxxbbbbbbxxbi32i11", 0x4E, 0x1E, 0x0B, slot, last4E:byte(9),
                    last4E:byte(10), last4E:byte(11), last4E:byte(12), e.data:byte(13), e.data:byte(14),
                    last4E:byte(17), 0x00, 0x00):totable()
                last4E = nil

                entry = {
                    type = task.type.confirmSell,
                    packet = packet
                }
                task.enqueue(entry)
            end
        elseif pType == 0x0A then
            if e.data:byte(7) == 0x01 then
                if auctioneer.AuctionHouse == nil then
                    auctioneer.AuctionHouse = {}
                end
                if auctioneer.AuctionHouse[e.data:byte(6)] == nil then
                    auctioneer.AuctionHouse[e.data:byte(6)] = {}
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
                print(chat.header(addon.name):append(chat.success("Bid success")))
            elseif e.data:byte(7) == 0xC5 then
                print(chat.header(addon.name):append(chat.warning("Bid Failed")))
            end
        end
    elseif e.id == 0x00B then
        if e.data:byte(5) == 0x01 then
            auctioneer.AuctionHouse = nil
            auctioneer.auctionHouseInitialized = false
        end
    end
    return false
end

return packets
