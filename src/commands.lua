commands = {}

itemUtils = require("src/itemUtils")

function commands.handleBuySell(args, command, now)
    if #args < 4 then
        print(chat.header(addon.name):append(chat.error("Invalid arguments. Usage: /[buy|sell] itemName [single,0|stack,1] price")))
        return
    end
    local action = command == "/buy" and auctionHouse.actions.buy or auctionHouse.actions.sell
    local itemName = table.concat(args, " ", 2, #args - 2)
    local single = args[#args - 1]
    local price = args[#args]

    auctionHouse.proposal(action, itemName, single, price)
end

function commands.handleOpenOutbox()
    local obox = struct.pack("bbxxbbbbbbbbbbbbbbbb", 0x4B, 0x0A, 0x0D, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF):totable()
    AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, obox)
end

function commands.handleOpenInbox()
    local ibox = struct.pack("bbxxbbbbbbbbbbbbbbbb", 0x4B, 0x0A, 0x0E, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF):totable()
    AshitaCore:GetPacketManager():AddIncomingPacket(0x4B, ibox)
end

function commands.handleToggleUi()
    auctioneer.config.ui.visible[1] = not auctioneer.config.ui.visible[1]
    settings.save()
end

function commands.handleShowUi()
    auctioneer.config.ui.visible[1] = true
    settings.save()
end

function commands.handleHideUi()
    auctioneer.config.ui.visible[1] = false
    settings.save()
end

function commands.handleClearSales(now)
    auctionHouse.clearSales()
end

function commands.handleOpenMenu(now)
    AshitaCore:GetPacketManager():AddIncomingPacket(0x4C, struct.pack("bbbbbbbi32i21", 0x4C, 0x1E, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00):totable())
end

function commands.handleCommand(args)
    local command = string.lower(args[1])
    local zone = resourceManager:GetString("zones.names", AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
    local isInZone = table.hasvalue(zones, zone)
    local now = os.clock()

    if command ~= "/ah" and command ~= "/buy" and command ~= "/sell" and command ~= "/inbox" and command ~= "/outbox" and
        command ~= "/ibox" and command ~= "/obox" then
        return
    end

    if command == "/sell" or command == "/buy" or command == "/outbox" or command == "/obox" or command == "/inbox" or command == "/ibox" then
        if not isInZone then
            print(chat.header(addon.name):append(chat.error("You are not in an area that contains an auction house. Aborting")))
            return
        end

        if command == "/sell" or command == "/buy" then
            commands.handleBuySell(args, command, now)
        elseif command == "/outbox" or command == "/obox" then
            commands.handleOpenOutbox()
        elseif command == "/inbox" or command == "/ibox" then
            commands.handleOpenInbox()
        end
    end

    if command == "/ah" then
        if #args == 1 then
            commands.handleToggleUi()
        elseif #args == 2 then
            local arg = string.lower(args[2])

            if arg == "show" then
                commands.handleShowUi()
            elseif arg == "hide" then
                commands.handleHideUi()
            elseif arg == "clear" then
                commands.handleClearSales(now)
            elseif arg == "menu" then
                commands.handleOpenMenu(now)
            end
        end
    end
end

return commands
