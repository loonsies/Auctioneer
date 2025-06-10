commands = {}

function commands.handleBuySell(args, command)
    if #args < 4 then
        print(chat.header(addon.name):append(chat.error(
            "Invalid arguments. Usage: /[buy|sell] itemName [single,0|stack,1] price")))
        return false
    end
    local action = command == "/buy" and auctionHouseActions.buy or auctionHouseActions.sell
    local itemName = table.concat(args, " ", 2, #args - 2)
    local single = args[#args - 1]
    local price = args[#args]

    return auctionHouse.proposal(action, itemName, single, price)
end

function commands.handleOpenOutbox()
    local obox = struct.pack("bbxxbbbbbbbbbbbbbbbb", 0x4B, 0x0A, 0x0D, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF):totable()
    AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, obox)
    return true
end

function commands.handleOpenInbox()
    local ibox = struct.pack("bbxxbbbbbbbbbbbbbbbb", 0x4B, 0x0A, 0x0E, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF):totable()
    AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, ibox)
    return true
end

function commands.handleToggleUi()
    auctioneer.visible[1] = not auctioneer.visible[1]
    settings.save()
    return true
end

function commands.handleShowUi()
    auctioneer.visible[1] = true
    settings.save()
    return true
end

function commands.handleHideUi()
    auctioneer.visible[1] = false
    settings.save()
    return true
end

function commands.handleClearSales()
    return auctionHouse.clearSales()
end

function commands.handleOpenMenu()
    AshitaCore:GetPacketManager():AddIncomingPacket(0x4C,
        struct.pack("bbbbbbbi32i21", 0x4C, 0x1E, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00):totable())
    return true
end

function commands.handleCommand(args)
    local command = string.lower(args[1])
    local zone = resourceManager:GetString("zones.names", memoryManager:GetParty():GetMemberZone(0))
    local isInZone = table.hasvalue(zones, zone)

    if command ~= "/ah" and command ~= "/buy" and command ~= "/sell" and command ~= "/inbox" and command ~= "/outbox" and
        command ~= "/ibox" and command ~= "/obox" then
        return false
    end

    if command == "/sell" or command == "/buy" or command == "/outbox" or command == "/obox" or command == "/inbox" or command == "/ibox" then
        if not isInZone then
            print(chat.header(addon.name):append(chat.error(
                "You are not in an area that contains an auction house. Aborting")))
            return false
        end

        if command == "/sell" or command == "/buy" then
            return commands.handleBuySell(args, command)
        elseif command == "/outbox" or command == "/obox" then
            return commands.handleOpenOutbox()
        elseif command == "/inbox" or command == "/ibox" then
            return commands.handleOpenInbox()
        end
    end

    if command == "/ah" then
        if #args == 1 then
            return commands.handleToggleUi()
        elseif #args == 2 then
            local arg = string.lower(args[2])

            if arg == "show" then
                return commands.handleShowUi()
            elseif arg == "hide" then
                return commands.handleHideUi()
            elseif arg == "clear" then
                return commands.handleClearSales()
            elseif arg == "menu" then
                return commands.handleOpenMenu()
            end
        end
    end
    return false
end

return commands
