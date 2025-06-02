local ui = {}

local priceInput = { "" }
local stack = { false }

local search = {}
search.results = {}
search.input = { "" }
search.category = 999
search.previousInput = { "" }
search.previousCategory = 999
search.statuses = { noResults = 0, tooShort = 1, found = 3 }
search.statusesMessage =
{
    noResults = "No results found.",
    tooShort = "A minimum of 2 characters are required for searching."
}
search.status = search.statuses.noResults


function ui.update()
    if (auctioneer.settings.ui.visibility == true) then
        local currentInput = table.concat(search.input)
        local previousInput = table.concat(search.previousInput)

        if currentInput ~= previousInput or search.category ~= search.previousCategory then
            ui.updateSearch()
            search.previousInput = { currentInput }
            search.previousCategory = search.category
        end
        ui.drawUI()
    end
end

function ui.updateSearch()
    search.results = {}
    input = table.concat(search.input)

    if #input < 2 then
        search.results = {}
        search.status = search.statuses.tooShort
    else
        for _, item in pairs(items) do
            if (search.category == 999 or search.category == item.category) then
                if item.longName and string.find(item.longName:lower(), input:lower()) or item.shortName and string.find(item.shortName:lower(), input:lower()) then
                    table.insert(search.results, item.shortName)
                end
            end
        end
        if #search.results == 0 then
            search.results = {}
            search.status = search.statuses.noResults
        else
            search.status = search.statuses.found
        end
    end

    if search.status == search.statuses.noResults then
        search.results = { search.statusesMessage.noResults }
    elseif search.status == search.statuses.tooShort then
        search.results = { search.statusesMessage.tooShort }
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
                print(id)
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
                imgui.Text(result)
            end
            imgui.EndTable()
        end
        imgui.EndChild()
    end
    imgui.NewLine()
end

function ui.drawCommands()
    imgui.Text("Price")
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    imgui.InputText("##Price", priceInput, 48)
    imgui.Checkbox("Stack", stack)
    imgui.SameLine()
    if imgui.Button("Buy") then
        print("Buying with price: " .. priceInput[1] .. ", Stack: " .. tostring(stack[1]))
    end
    imgui.SameLine()
    if imgui.Button("Sell") then
        print("Selling with price: " .. priceInput[1] .. ", Stack: " .. tostring(stack[1]))
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
