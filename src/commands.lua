commands = {}

function commands.handleCommand(args)
	args[1] = string.lower(args[1])
	if (args[1] ~= "/ah" and args[1] ~= "/buy" and args[1] ~= "/sell" and args[1] ~= "/inbox" and
        args[1] ~= "/outbox" and
        args[1] ~= "/ibox" and
        args[1] ~= "/obox")
    then
        return false
    end

    local zone =
        AshitaCore:GetResourceManager():GetString(
        "zones.names",
        AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    )
    local now = os.clock()
    if (table.hasvalue(zones, zone) == true and (lclock == nil or lclock < now)) then
        if (args[1] == "/sell" or args[1] == "/buy") then
            if (#args < 4) then
                return true
            end
            if (auctionHouse.proposal(string.lower(args[1]), table.concat(args, " ", 2, #args - 2), args[#args - 1], args[#args]) == true)
            then
                lclock = now + 3
            end
            return true
        end

        if (args[1] == "/outbox" or args[1] == "/obox") then
            local obox =
                struct.pack(
                "bbxxbbbbbbbbbbbbbbbb",
                0x4B,
                0x0A,
                0x0D,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0x01,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF
            ):totable()
            AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, obox)
            return true
        end

        if (args[1] == "/inbox" or args[1] == "/ibox") then
            local ibox =
                struct.pack(
                "bbxxbbbbbbbbbbbbbbbb",
                0x4B,
                0x0A,
                0x0E,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0x01,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF,
                0xFF
            ):totable()
            AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, ibox)
            return true
        end

        if (#args == 1 or string.lower(args[2]) == "menu") then
            lclock = now + 3
            AshitaCore:GetPacketManager():AddIncomingPacket(
                0x4C,
                struct.pack("bbbbbbbi32i21", 0x4C, 0x1E, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00):totable()
            )
            return true
        elseif (string.lower(args[2]) == "clear") then
            lclock = now + 3
            auctionHouse.lear_sales()
            return true
        end
    end

    if (args[1] ~= "/ah") then
        return false
    end

    if (#args == 1) then
        return false
    end

    args[2] = string.lower(args[2])
    if (args[2] == "show") then
        if (#args == 2) then
            auctioneer.settings.auction_list.visibility = true
        elseif auctioneer.settings.auction_list[string.lower(args[3])] ~= nil then
            auctioneer.settings.auction_list[string.lower(args[3])] = true
        end
        settings.save()
    elseif (args[2] == "hide") then
        if (#args == 2) then
            auctioneer.settings.auction_list.visibility = false
        elseif auctioneer.settings.auction_list[string.lower(args[3])] ~= nil then
            auctioneer.settings.auction_list[string.lower(args[3])] = false
        end
        settings.save()
    end

	return true
end

return commands