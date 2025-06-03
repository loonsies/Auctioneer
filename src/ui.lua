local ui = {}

local priceInput = { "" }
local stack = { false }

local search = {}
search.results = {}
search.input = { "" }
search.previousInput = { "" }
search.category = 999
search.previousCategory = 999
search.statuses = { noResults = 0, tooShort = 1, found = 3 }
search.statusesMessage =
{
    noResults = "No results found.",
    tooShort = "A minimum of 2 characters are required for searching."
}
search.status = search.statuses.noResults
search.selectedItem = nil
search.startup = true
search.textureCache = {}

function ui.update()
    if (auctioneer.settings.ui.visibility == true) then
        local currentInput = table.concat(search.input)
        local previousInput = table.concat(search.previousInput)

        if currentInput ~= previousInput or search.category ~= search.previousCategory or search.startup then
            ui.updateSearch()
            search.previousInput = { currentInput }
            search.previousCategory = search.category
            search.startup = false
        end
        ui.drawUI()
    end
end

function ui.updateSearch()
    search.results = {}
    input = table.concat(search.input)

    if #input < 2 and #input ~= 0 then
        search.status = search.statuses.tooShort
    else
        for id, item in pairs(items) do
            if (search.category == 999 or search.category == item.category) then
                if item.longName and string.find(item.longName:lower(), input:lower()) or item.shortName and string.find(item.shortName:lower(), input:lower()) then
                    table.insert(search.results, id)
                end
            end
        end
        if #search.results == 0 then
            search.status = search.statuses.noResults
        else
            search.status = search.statuses.found
        end
    end
end

function ui.drawFilters()
    imgui.Text("Category")
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo("##Category", categories.list[search.category]) then
        for _, id in ipairs(categories.order) do
            local category = categories.list[id]
            local is_selected = (search.category == id)
            if imgui.Selectable(category, is_selected) then
                search.category = id
            end
        end
        imgui.EndCombo()
    end
end

function ui.drawSearch()
    count = search.status == search.statuses.found and #search.results or 0
    imgui.Text("Search (" .. count .. ")")
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##Search", search.input, 48)

    if imgui.BeginChild("##Results", { 0, 100 }, true) then
        if imgui.BeginTable("##ResultsTable", 1, ImGuiTableFlags_ScrollY) then
            imgui.TableSetupColumn("Item", ImGuiTableFlags_ScrollY)
            for _, result in ipairs(search.results) do
                imgui.TableNextRow()
                imgui.TableSetColumnIndex(0)

                if (search.status == search.statuses.found) then
                    local itemLabel = items[result].shortName
                    if imgui.Selectable(itemLabel) then
                        search.selectedItem = result
                    end
                elseif search.status == search.statuses.noResults then
                    imgui.Text(search.statusesMessage.noResults)
                elseif search.status == search.statuses.tooShort then
                    imgui.Text(search.statusesMessage.tooShort)
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()
    end
end

function ui.drawItemPreview()
    if search.selectedItem ~= nil then
        id = search.selectedItem
        item = items[id]
        iconSize = 32

        if search.textureCache[id] == nil then
            search.textureCache[id] = utils.createTexture(item.bitmap, item.imageSize)
        end

        iconPointer = tonumber(ffi.cast('uint32_t', search.textureCache[id]))
        imgui.Image(iconPointer, { iconSize, iconSize })
        imgui.Text(('%s [%i]'):format(item.shortName, id))
        imgui.Text(utils.escapeString(item.description))
        imgui.Text(('Lv %i'):format(item.level))
        imgui.Text(utils.getJobs(item.jobs):join(', '))
    else
        imgui.Text("-")
        imgui.Text("-")
        imgui.Text("-")
        imgui.Text("-")
    end
end

function ui.drawCommands()
    imgui.Text("Price")
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##Price", priceInput, 48)
    imgui.Checkbox("Stack", stack)
    imgui.SameLine()
    if imgui.Button("Buy") then
        if priceInput == nil or #priceInput == 0 or priceInput[1] == nil or priceInput[1] == "" then
            print(chat.header(addon.name):append(chat.error("Please enter a price")))
        elseif search.selectedItem == nil then
            print(chat.header(addon.name):append(chat.error("Please select an item")))
        else
            auctionHouse.proposal(auctionHouse.actions.buy, items[search.selectedItem].shortName, stack[1] and "1" or "0",
                priceInput[1])
        end
    end
    imgui.SameLine()
    if imgui.Button("Sell") then
        if priceInput == nil or #priceInput == 0 or priceInput[1] == nil or priceInput[1] == "" then
            print(chat.header(addon.name):append(chat.error("Please enter a price")))
        elseif search.selectedItem == nil then
            print(chat.header(addon.name):append(chat.error("Please select an item")))
        else
            auctionHouse.proposal(auctionHouse.actions.sell, items[search.selectedItem].shortName,
                stack[1] and "1" or "0", priceInput[1])
        end
    end
end

function ui.drawPriceHistory()
    --imgui.NewLine()
    --imgui.Text("Price History")
    --if imgui.BeginTable("BuyTable", 4, ImGuiTableFlags_ScrollY) then
    --    imgui.TableSetupColumn("Date")
    --    imgui.TableSetupColumn("Seller")
    --    imgui.TableSetupColumn("Buyer")
    --    imgui.TableSetupColumn("Price")
    --    imgui.TableHeadersRow()

    --    for _, row in ipairs(buyTable) do
    --        imgui.TableNextRow()
    --        for colIndex, cell in ipairs(row) do
    --            imgui.TableSetColumnIndex(colIndex - 1)
    --            imgui.Text(cell)
    --        end
    --    end
    --    imgui.EndTable()
    --end
end

function ui.drawBuySellTab()
    ui.drawFilters()
    ui.drawSearch()
    ui.drawItemPreview()
    ui.drawCommands()
    --ui.drawPriceHistory()
end

function ui.drawAuctionHouseTab()
    if (auctioneer.auctionHouseInitialized == false) then
        imgui.Text("Auction House not initialized.")
        imgui.Text("Interact with it to initialize this tab.")
    elseif imgui.BeginTable("AuctionHouse", 5, bit.bor(ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingStretchProp)) then
        imgui.TableSetupColumn("Status")
        imgui.TableSetupColumn("Item")
        imgui.TableSetupColumn("Expires in")
        imgui.TableSetupColumn("Date")
        imgui.TableSetupColumn("Price")
        imgui.TableHeadersRow()

        for x = 0, 6 do
            data = {}
            data.status = auctioneer.AuctionHouse[x].status
            if (data.status ~= "Expired") then
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
            end
        end
        imgui.EndTable()
    end
end

function ui.drawSettingsTab()
    imgui.Text("Settings Placeholder")
end

function ui.drawUI()
    if imgui.Begin("Auctioneer") then
        if imgui.BeginTabBar("MainTabs") then
            if imgui.BeginTabItem("Buy & Sell") then
                ui.drawBuySellTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Auction House") then
                ui.drawAuctionHouseTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Settings") then
                ui.drawSettingsTab()
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
        end
        imgui.End()
    end
end

return ui
