commands = {}

itemUtils = require("src/itemUtils")

function commands.handleCommand(args)
    args[1] = string.lower(args[1])
    if (args[1] ~= "/ah" and args[1] ~= "/buy" and args[1] ~= "/sell" and args[1] ~= "/inbox" and args[1] ~= "/outbox" and
            args[1] ~= "/ibox" and args[1] ~= "/obox") then
        return false
    end

    local zone = resourceManager:GetString("zones.names",
        AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
    local now = os.clock()
    if (table.hasvalue(zones, zone) == true and (lclock == nil or lclock < now)) then
        if (args[1] == "/sell" or args[1] == "/buy") then
            if (#args < 4) then
                return true
            end
            local action = args[1] == "/buy" and auctionHouse.actions.buy or auctionHouse.actions.sell
            local itemName = table.concat(args, " ", 2, #args - 2)
            local single = args[#args - 1]
            local price = args[#args]

            if (auctionHouse.proposal(action, itemName, single, price) == true) then
                lclock = now + 3
            end
            return true
        end

        if (args[1] == "/outbox" or args[1] == "/obox") then
            local obox = struct.pack("bbxxbbbbbbbbbbbbbbbb", 0x4B, 0x0A, 0x0D, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF):totable()
            AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, obox)
            return true
        end

        if (args[1] == "/inbox" or args[1] == "/ibox") then
            local ibox = struct.pack("bbxxbbbbbbbbbbbbbbbb", 0x4B, 0x0A, 0x0E, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF):totable()
            AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, ibox)
            return true
        end
    end

    if (args[1] ~= "/ah") then
        return false
    end

    if (#args == 1) then
        auctioneer.settings.ui.visibility = not auctioneer.settings.uii.visibility
        settings.save()
    end

    args[2] = string.lower(args[2])
    if (args[2] == "show") then
        if (#args == 2) then
            auctioneer.settings.ui.visibility = true
            settings.save()
        end
    elseif (args[2] == "hide") then
        if (#args == 2) then
            auctioneer.settings.ui.visibility = false
            settings.save()
        end
    elseif (args[2] == "clear") then
        lclock = now + 3
        auctionHouse.clearSales()
    elseif (args[2] == "menu") then
        lclock = now + 3
        AshitaCore:GetPacketManager():AddIncomingPacket(0x4C,
            struct.pack("bbbbbbbi32i21", 0x4C, 0x1E, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00):totable())
    end

    return true
end

return commands
