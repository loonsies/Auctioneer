local ui = {}

local minSize = { 400, 350 }
local quantityInput = { 1 }
local priceInput = { "" }
local stack = { false }
local gilIcon = nil

local preview = {}
preview.textureCache = {}
preview.itemBackground = nil

local modal = {
    visible = false
}

function ui.update()
    if not auctioneer.visible[1] then
        return
    end

    local currentInput = table.concat(auctioneer.search.input)
    local previousInput = table.concat(auctioneer.search.previousInput)

    if currentInput ~= previousInput or auctioneer.search.category ~= auctioneer.search.previousCategory or auctioneer.search.startup then
        search.update()
        auctioneer.search.previousInput = { currentInput }
        auctioneer.search.previousCategory = auctioneer.search.category
        auctioneer.search.startup = false
    end

    if auctioneer.search.selectedItem ~= auctioneer.search.previousSelectedItem then
        ffxiah.reset(false)
        auctioneer.search.previousSelectedItem = auctioneer.search.selectedItem
    end

    ui.drawUI()
end

function ui.drawGlobalCommands()
    if imgui.Button("Open AH") then
        commands.handleCommand({ "/ah", "menu" })
    end
    imgui.SameLine()
    if imgui.Button("Clear Sales") then
        commands.handleCommand({ "/ah", "clear" })
    end
end

function ui.drawConfirmationModal()
    if not modal.visible then
        return
    end

    imgui.SetNextWindowSize({ 0, 0 }, ImGuiCond_Always)
    imgui.OpenPopup("Confirm transaction")

    if imgui.BeginPopupModal("Confirm transaction", nil, ImGuiWindowFlags_AlwaysAutoResize) then
        name, single, price, quantity = table.unpack(modal.args)

        imgui.Text("Are you sure you want to proceed with this transaction?")
        imgui.Separator()
        imgui.Text(string.format("%s %s of %s for %s", auctionHouseActions[modal.action],
            single == "0" and "Single" or "Stack", name, price))
        imgui.Text(string.format("This task will be executed %s times", quantity))
        if imgui.Button("OK", { 120, 0 }) then
            if auctionHouse.proposal(modal.action, name, single, price, quantity) then
                quantityInput = { 1 }
            end
            modal.visible = false
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button("Cancel", { 120, 0 }) then
            modal.visible = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

function ui.drawFilters()
    imgui.Text("Category")
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo("##Category", categories.list[auctioneer.search.category]) then
        for _, id in ipairs(categories.order) do
            local category = categories.list[id]
            local is_selected = (auctioneer.search.category == id)
            if imgui.Selectable(category, is_selected) then
                auctioneer.search.category = id
            end
        end
        imgui.EndCombo()
    end
end

function ui.drawSearch()
    imgui.Text("Search (" .. #auctioneer.search.results .. ")")
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##Search", auctioneer.search.input, 48)

    if imgui.BeginTable("##SearchResultsTableChild", 1, ImGuiTableFlags_ScrollY, { 0, 150 }) then
        imgui.TableSetupColumn("##Item", ImGuiTableFlags_ScrollY)

        if auctioneer.search.status == searchStatus.found then
            local clipper = ImGuiListClipper.new()
            clipper:Begin(#auctioneer.search.results, -1);

            while clipper:Step() do
                for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0)

                    local item = auctioneer.search.results[i + 1]
                    local itemLabel = items[item].shortName
                    local isSelected = (auctioneer.search.selectedItem == item)
                    if imgui.Selectable(itemLabel, isSelected) then
                        auctioneer.search.selectedItem = item
                    end
                end
            end

            clipper:End()
        else
            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.Text(searchStatus[auctioneer.search.status])
        end
        imgui.EndTable()
    end
end

function ui.drawItemPreview()
    if imgui.BeginChild("##ItemPreview", { 0, 150 }, true) then
        if auctioneer.search.selectedItem ~= nil then
            local id = auctioneer.search.selectedItem
            local item = items[id]
            local iconSize = 40

            if preview.itemBackground == nil then
                local path = string.format('%saddons/%s/resources/%s', AshitaCore:GetInstallPath(), addon.name,
                    'item.png')
                preview.itemBackground = utils.createTextureFromFile(path)
                if preview.itemBackground ~= nil then
                    preview.itemBackground.Pointer = tonumber(ffi.cast('uint32_t', preview.itemBackground.Texture))
                end
            end

            if preview.textureCache[id] == nil then
                preview.textureCache[id] = utils.createTextureFromGame(item.bitmap, item.imageSize)
            end
            local iconPointer = tonumber(ffi.cast('uint32_t', preview.textureCache[id]))

            imgui.BeginGroup()
            imgui.Dummy({ 0, 4 })
            local posX, posY = imgui.GetCursorScreenPos()
            if preview.itemBackground and preview.itemBackground.Pointer then
                imgui.Image(preview.itemBackground.Pointer, { iconSize, iconSize })
            end
            imgui.SetCursorScreenPos({ posX, posY })
            if iconPointer then
                imgui.Image(iconPointer, { iconSize, iconSize })
            end
            imgui.EndGroup()
            imgui.SameLine()

            imgui.BeginGroup()
            local cursorX = select(1, imgui.GetCursorPos())
            local regionMaxX = select(1, imgui.GetContentRegionAvail())
            imgui.PushTextWrapPos(cursorX + regionMaxX)
            imgui.Text(('%s [%i]'):format(item.shortName, id))
            imgui.TextWrapped(utils.escapeString(item.description))
            imgui.Text(('Lv %i'):format(item.level))
            imgui.Text(utils.getJobs(item.jobs):join(', '))
            imgui.PopTextWrapPos()
            imgui.EndGroup()
        end
        imgui.EndChild()
    end
end

function ui.drawBuySellCommands()
    local iconSize = 20

    if gilIcon == nil then
        local path = string.format('%saddons/%s/resources/%s', AshitaCore:GetInstallPath(), addon.name,
            'gil.png')
        gilIcon = utils.createTextureFromFile(path)
        if gilIcon ~= nil then
            gilIcon.Pointer = tonumber(ffi.cast('uint32_t', gilIcon.Texture))
        end
    end

    imgui.Text("Quantity")
    imgui.SameLine()
    imgui.SetNextItemWidth(150)
    if imgui.InputInt("##Quantity", quantityInput) then
        if quantityInput[1] < 1 then
            quantityInput = { 1 }
        end
    end

    imgui.SameLine()
    imgui.Text("Price")
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##Price", priceInput, 48)

    if imgui.Checkbox("Stack", stack) then
        ffxiah.reset(false)
    end
    imgui.SameLine()

    if imgui.Button("Buy") then
        if priceInput == nil or #priceInput == 0 or priceInput[1] == nil or priceInput[1] == "" then
            print(chat.header(addon.name):append(chat.error("Please enter a price")))
        elseif auctioneer.search.selectedItem == nil then
            print(chat.header(addon.name):append(chat.error("Please select an item")))
        elseif auctioneer.AuctionHouse == nil then
            print(chat.header(addon.name):append(chat.error("Interact with auction house or use /ah menu first")))
        else
            if auctioneer.config.confirmationPopup[1] then
                if not modal.visible then
                    modal.visible = true
                    modal.action = auctionHouseActions.buy
                    modal.args = {
                        items[auctioneer.search.selectedItem].shortName,
                        stack[1] and "1" or "0",
                        priceInput[1],
                        quantityInput[1],
                    }
                end
            else
                if auctionHouse.proposal(auctionHouseActions.buy, items[auctioneer.search.selectedItem].shortName,
                        stack[1] and "1" or "0", priceInput[1], quantityInput[1]) then
                    quantityInput = { 1 }
                end
            end
        end
    end
    imgui.SameLine()

    if imgui.Button("Sell") then
        if priceInput == nil or #priceInput == 0 or priceInput[1] == nil or priceInput[1] == "" then
            print(chat.header(addon.name):append(chat.error("Please enter a price")))
        elseif auctioneer.search.selectedItem == nil then
            print(chat.header(addon.name):append(chat.error("Please select an item")))
        elseif auctioneer.AuctionHouse == nil then
            print(chat.header(addon.name):append(chat.error("Interact with auction house or use /ah menu first")))
        else
            if auctioneer.config.confirmationPopup[1] then
                if not modal.visible then
                    modal.visible = true
                    modal.action = auctionHouseActions.sell
                    modal.args = {
                        items[auctioneer.search.selectedItem].shortName,
                        stack[1] and "1" or "0",
                        priceInput[1],
                        quantityInput[1],
                    }
                end
            else
                if auctionHouse.proposal(auctionHouseActions.sell, items[auctioneer.search.selectedItem].shortName,
                        stack[1] and "1" or "0", priceInput[1], quantityInput[1]) then
                    quantityInput = { 1 }
                end
            end
        end
    end
    imgui.SameLine()

    local spacing = 5
    local gilText = utils.commaValue(utils.getCurrentGils())
    local textWidth = imgui.CalcTextSize(gilText)
    local totalWidth = iconSize + spacing + textWidth
    local availX, availY = imgui.GetContentRegionAvail()
    local posX = imgui.GetCursorPosX()

    imgui.SetCursorPosX(posX + availX - totalWidth)

    if gilIcon and gilIcon.Pointer then
        imgui.Image(gilIcon.Pointer, { iconSize, iconSize })
        imgui.SameLine()
    end

    imgui.Text(gilText)
end

function ui.drawPriceHistory()
    local availX, availY = imgui.GetContentRegionAvail()

    imgui.NewLine()
    imgui.Text("FFXIAH")
    imgui.SameLine()
    imgui.Dummy({ 25, 0 })

    imgui.SameLine(availX - 200)
    imgui.Text("Server")
    imgui.SameLine()
    imgui.SetNextItemWidth(150)

    local currentServerName = "Unknown"
    for _, server in ipairs(servers) do
        if server.id == auctioneer.config.server[1] then
            currentServerName = server.name
            break
        end
    end

    if imgui.BeginCombo("##ServerSelectCombo", currentServerName) then
        for _, server in ipairs(servers) do
            local isSelected = auctioneer.config.server[1] == server.id
            if imgui.Selectable(server.name, isSelected) and auctioneer.config.server[1] ~= server.id then
                ffxiah.reset(false)
                auctioneer.config.server[1] = server.id
                settings.save()
            end
        end
        imgui.EndCombo()
    end

    if auctioneer.priceHistory.fetching == false then
        if imgui.Button("Fetch prices & bazaar") then
            if auctioneer.search.selectedItem == nil then
                print(chat.header(addon.name):append(chat.error("Please select an item")))
            else
                ffxiah.reset(true)
                ffxiah.fetch(auctioneer.search.selectedItem, stack[1])
            end
        end
    else
        if auctioneer.priceHistory.sales == nil and auctioneer.priceHistory.bazaar == nil then
            imgui.Text("Fetching...")
        else
            if auctioneer.priceHistory.sales ~= nil then
                imgui.Text("Price history")

                imgui.Text("Stock: ")
                imgui.SameLine(0, 0)
                imgui.TextColored(utils.hexToImVec4(utils.getStockColor(auctioneer.priceHistory.stock)),
                    auctioneer.priceHistory.stock)
                imgui.Text(string.format("Rate: "))
                imgui.SameLine(0, 0)
                imgui.TextColored(utils.hexToImVec4(utils.getSalesRatingColor(auctioneer.priceHistory.rate)),
                    utils.getSalesRatingLabel(auctioneer.priceHistory.rate))
                imgui.SameLine(0, 0)
                imgui.Text(string.format(" (%s sold /day)", auctioneer.priceHistory.salesPerDay))
                imgui.Text(string.format("Median: %s", utils.commaValue(auctioneer.priceHistory.median)))

                if imgui.BeginTable("##PriceHistoryTable", 4, bit.bor(ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_BordersV, ImGuiTableFlags_RowBg), { 0, 150 }) then
                    imgui.TableSetupColumn("Date")
                    imgui.TableSetupColumn("Seller")
                    imgui.TableSetupColumn("Buyer")
                    imgui.TableSetupColumn("Price")
                    imgui.TableHeadersRow()

                    for i, sale in ipairs(auctioneer.priceHistory.sales) do
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.Text(sale.date)
                        imgui.TableSetColumnIndex(1)
                        imgui.Text(sale.seller)
                        imgui.TableSetColumnIndex(2)
                        imgui.Text(sale.buyer)
                        imgui.TableSetColumnIndex(3)
                        local priceStr = tostring(sale.price)
                        if imgui.Selectable(utils.commaValue(sale.price) .. "##" .. i) then
                            priceInput[1] = priceStr
                        end
                    end
                    imgui.EndTable()
                end
            end

            if auctioneer.priceHistory.bazaar ~= nil then
                imgui.Text("Bazaar")

                if imgui.BeginTable("##BazaarTable", 5, bit.bor(ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_BordersV, ImGuiTableFlags_RowBg), { 0, 150 }) then
                    imgui.TableSetupColumn("Player")
                    imgui.TableSetupColumn("Price")
                    imgui.TableSetupColumn("Quantity")
                    imgui.TableSetupColumn("Zone")
                    imgui.TableSetupColumn("Last seen")
                    imgui.TableHeadersRow()

                    for i, bazaar in ipairs(auctioneer.priceHistory.bazaar) do
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.Text(string.format("%s.%s", bazaar.server, bazaar.player))
                        imgui.TableSetColumnIndex(1)
                        imgui.Text(tostring(bazaar.price))
                        imgui.TableSetColumnIndex(2)
                        imgui.Text(tostring(bazaar.quantity))
                        imgui.TableSetColumnIndex(3)
                        imgui.Text(bazaar.zone)
                        imgui.TableSetColumnIndex(4)
                        imgui.Text(utils.relativeTime(bazaar.time))
                    end
                    imgui.EndTable()
                end
            end
        end
    end
end

function ui.drawBuySellTab()
    ui.drawGlobalCommands()
    ui.drawFilters()
    ui.drawSearch()
    if auctioneer.config.itemPreview[1] then
        ui.drawItemPreview()
    end
    ui.drawBuySellCommands()
    if auctioneer.config.priceHistory[1] then
        ui.drawPriceHistory()
    end
end

function ui.drawAuctionHouseTab()
    ui.drawGlobalCommands()
    if auctioneer.auctionHouseInitialized == false then
        imgui.Text("Auction House not initialized.")
        imgui.Text("Interact with it to initialize this tab.")
    else
        if imgui.BeginTable("##AuctionHouseTable", 5, bit.bor(ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_BordersV, ImGuiTableFlags_RowBg)) then
            imgui.TableSetupColumn("Status")
            imgui.TableSetupColumn("Item")
            imgui.TableSetupColumn("Expires in")
            imgui.TableSetupColumn("Date")
            imgui.TableSetupColumn("Price")
            imgui.TableHeadersRow()

            for x = 0, 6 do
                data = {}
                data.status = auctioneer.AuctionHouse[x].status
                if data.status ~= "Expired" and data.status ~= "Empty" then
                    data.timer = auctioneer.AuctionHouse[x].status == "On auction" and
                        auctioneer.AuctionHouse[x].timestamp + 829440 or auctioneer.AuctionHouse[x].timestamp
                    data.expiresIn = string.format("%s",
                        (auctioneer.AuctionHouse[x].status == "On auction" and os.time() - data.timer > 0) and "Expired" or
                        utils.timef(math.abs(os.time() - data.timer)))
                    data.date = os.date("%c", data.timer)
                    data.count = tostring(auctioneer.AuctionHouse[x].count)
                    data.item = auctioneer.AuctionHouse[x].item .. ' (' .. data.count .. ')'
                    data.price = utils.commaValue(auctioneer.AuctionHouse[x].price)
                    imgui.TableNextRow()

                    imgui.TableSetColumnIndex(0)
                    imgui.Text(data.status)
                    imgui.TableSetColumnIndex(1)
                    imgui.Text(data.item)
                    imgui.TableSetColumnIndex(2)
                    imgui.Text(data.expiresIn)
                    imgui.TableSetColumnIndex(3)
                    imgui.Text(data.date)
                    imgui.TableSetColumnIndex(4)
                    imgui.Text(data.price)
                elseif data.status == "Empty" then
                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0)
                    imgui.Text(data.status)
                end
            end
            imgui.EndTable()
        end
    end
end

function ui.drawSettingsTab()
    if imgui.Checkbox("Enable transaction confirmation popup", auctioneer.config.confirmationPopup) then
        settings.save()
    end

    if imgui.Checkbox("Display item preview", auctioneer.config.itemPreview) then
        settings.save()
    end

    if imgui.Checkbox("Display price history", auctioneer.config.priceHistory) then
        settings.save()
    end

    if imgui.Checkbox("Display auction house tab", auctioneer.config.auctionHouse) then
        settings.save()
    end

    if imgui.Checkbox("Remove next buy tasks from queue if a task fails", auctioneer.config.removeFailedBuyTasks) then
        settings.save()
    end
end

function ui.drawUI()
    imgui.SetNextWindowSizeConstraints(minSize, { FLT_MAX, FLT_MAX });
    if imgui.Begin("Auctioneer", auctioneer.visible) then
        if imgui.BeginTabBar("##TabBar") then
            if imgui.BeginTabItem("Buy & Sell") then
                ui.drawBuySellTab()
                imgui.EndTabItem()
            end

            if auctioneer.config.auctionHouse[1] and imgui.BeginTabItem("Auction House") then
                ui.drawAuctionHouseTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Settings") then
                ui.drawSettingsTab()
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
        end
        ui.drawConfirmationModal()
        imgui.End()
    end
end

return ui
