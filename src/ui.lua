local ui = {}

function ui.updateText()
    local outstr = ""
    for x = 0, 6 do
        if (auctioneer.auction_box[x] ~= nil) then
            local str = ""
            if (auctioneer.settings.auction_list.empty == true or auctioneer.auction_box[x].status ~= "Empty") then
                if (auctioneer.settings.auction_list.slot) == true then
                    str = str .. string.format(" Slot:%s", x + 1)
                end
                str = str .. string.format(" %s", auctioneer.auction_box[x].status)
            end
            if (auctioneer.auction_box[x].status ~= "Empty") then
                local timer = auctioneer.auction_box[x].status == "On auction" and auctioneer.auction_box[x].timestamp +
                                  829440 or auctioneer.auction_box[x].timestamp
                if (auctioneer.settings.auction_list.timer) then
                    str = str ..
                              string.format(" %s",
                            (auctioneer.auction_box[x].status == "On auction" and os.time() - timer > 0) and "Expired" or
                                utils.timef(math.abs(os.time() - timer)))
                end
                if (auctioneer.settings.auction_list.date) then
                    str = str .. string.format(" [%s]", os.date("%c", timer))
                end
                str = str .. string.format(" %s ", auctioneer.auction_box[x].item)
                if (auctioneer.auction_box[x].count ~= 1) then
                    str = str .. string.format("x%d ", auctioneer.auction_box[x].count)
                end
                if (auctioneer.settings.auction_list.price) then
                    str = str .. string.format("[%s] ", utils.commaValue(auctioneer.auction_box[x].price))
                end
            end
            if (str ~= "") then
                outstr = outstr ~= "" and outstr .. "\n" .. str or str
            end
        end
    end
    return outstr
end

function ui.init()
    auction_list = AshitaCore:GetFontManager():Create("auction_list")
    auction_list:SetFontFamily(auctioneer.settings.text.font_family)
    auction_list:SetFontHeight(auctioneer.settings.text.font_height)
    auction_list:SetColor(auctioneer.settings.text.color)
    auction_list:SetPositionX(auctioneer.settings.text.position_x)
    auction_list:SetPositionY(auctioneer.settings.text.position_y)
    auction_list:SetVisible(auctioneer.settings.auction_list.visibility)
    auction_list:GetBackground():SetVisible(true)
    auction_list:GetBackground():SetColor(auctioneer.settings.text.background.color)
end

function ui.update(packet)
    local slot = packet:byte(0x05 + 1)
    local status = packet:byte(0x14 + 1)
    if (auctioneer.auction_box ~= nil and slot ~= 7 and status ~= 0x02 and status ~= 0x04 and status ~= 0x10) then
        if (status == 0x00) then
            auctioneer.auction_box[slot] = {}
            auctioneer.auction_box[slot].status = "Empty"
        else
            if (status == 0x03) then
                auctioneer.auction_box[slot].status = "On auction"
            elseif (status == 0x0A or status == 0x0C or status == 0x15) then
                auctioneer.auction_box[slot].status = "Sold"
            elseif (status == 0x0B or status == 0x0D or status == 0x16) then
                auctioneer.auction_box[slot].status = "Not Sold"
            end
            auctioneer.auction_box[slot].item = utils.getItemName(struct.unpack("h", packet, 0x28 + 1))
            auctioneer.auction_box[slot].count = packet:byte(0x2A + 1)
            auctioneer.auction_box[slot].price = struct.unpack("i", packet, 0x2C + 1)
            auctioneer.auction_box[slot].timestamp = struct.unpack("i", packet, 0x38 + 1)
        end
    end
end

function ui.updateVisibility()
    if (auctioneer.auction_box ~= nil and auctioneer.settings.auction_list.visibility == true) then
        auction_list:SetText(ui.updateText())
        auction_list:SetVisible(true)
    else
        auction_list:SetVisible(false)
    end
end

local currentTab = {"Buy"}
local buyCategory = ""
local sellCategory = ""
local buySearch = {""}
local sellSearch = {""}
local buyPrice = {""}
local sellPrice = {""}
local buyStack = {false}
local sellStack = {false}
local buyResults = {"Item 1", "Item 2", "Item 3"}
local sellResults = {"Item A", "Item B", "Item C"}
local buyTable = {{"12/12/2024", "Seller1", "Buyer1", "100"}, {"11/12/2024", "Seller2", "Buyer2", "200"},
                  {"10/12/2024", "Seller3", "Buyer3", "300"}}
local sellTable = {{"12/12/2024", "Seller1", "Buyer1", "100"}, {"11/12/2024", "Seller2", "Buyer2", "200"},
                   {"10/12/2024", "Seller3", "Buyer3", "300"}}

function ui.drawBuyTab()
    imgui.Text("Category")
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo("##BuyCategory", buyCategory) then
        for _, category in ipairs({"Weapons", "Armor", "Potions"}) do
            if imgui.Selectable(category, category == buyCategory) then
                buyCategory = category
            end
        end
        imgui.EndCombo()
    end

    imgui.Text("Search")
    local changed
    imgui.SetNextItemWidth(-1)
    changed = imgui.InputText("##BuySearch", buySearch, 100)

    if imgui.BeginChild("##BuyResults", {0, 100}, true) then
        imgui.BeginTable("BuyResultsTable", 1, ImGuiTableFlags_ScrollY)
        imgui.TableSetupColumn("Item", ImGui)
        for _, result in ipairs(buyResults) do
            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.Text(result)
        end
        imgui.EndTable()
        imgui.EndChild()
    end

    imgui.NewLine()
    imgui.Text("Price")
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    changed = imgui.InputText("##BuyPrice", buyPrice, 50)
    changed = imgui.Checkbox("Stack", buyStack)
    imgui.SameLine()
    if imgui.Button("Buy") then
        print("Buying with price: " .. buyPrice[1] .. ", Stack: " .. tostring(buyStack[1]))
    end

    imgui.NewLine()
    imgui.Text("Price History")
    if imgui.BeginTable("BuyTable", 4, ImGuiTableFlags_ScrollY) then
        imgui.TableSetupColumn("Date")
        imgui.TableSetupColumn("Seller")
        imgui.TableSetupColumn("Buyer")
        imgui.TableSetupColumn("Price")
        imgui.TableHeadersRow()

        for _, row in ipairs(buyTable) do
            imgui.TableNextRow()
            for colIndex, cell in ipairs(row) do
                imgui.TableSetColumnIndex(colIndex - 1)
                imgui.Text(cell)
            end
        end
        imgui.EndTable()
    end
end

function ui.drawSellTab()
    imgui.Text("Category")
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo("##SellCategory", sellCategory) then
        for _, category in ipairs({"Weapons", "Armor", "Potions"}) do
            if imgui.Selectable(category, category == sellCategory) then
                sellCategory = category
            end
        end
        imgui.EndCombo()
    end

    imgui.Text("Search")
    local changed
    imgui.SetNextItemWidth(-1)
    changed = imgui.InputText("##SellSearch", sellSearch, 100)

    if imgui.BeginChild("##SellResults", {0, 100}, true) then
        imgui.BeginTable("SellResultsTable", 1, ImGuiTableFlags_ScrollY)
        for _, result in ipairs(sellResults) do
            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.Text(result)
        end
        imgui.EndTable()
        imgui.EndChild()
    end

    imgui.NewLine()
    imgui.Text("Price")
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    changed = imgui.InputText("##SellPrice", sellPrice, 50)
    changed = imgui.Checkbox("Stack", sellStack)
    imgui.SameLine()
    if imgui.Button("Sell") then
        print("Selling with price: " .. sellPrice[1] .. ", Stack: " .. tostring(sellStack[1]))
    end

    imgui.NewLine()
    imgui.Text("Price History")
    if imgui.BeginTable("SellTable", 4, ImGuiTableFlags_ScrollY) then
        imgui.TableSetupColumn("Date")
        imgui.TableSetupColumn("Seller")
        imgui.TableSetupColumn("Buyer")
        imgui.TableSetupColumn("Price")
        imgui.TableHeadersRow()

        for _, row in ipairs(sellTable) do
            imgui.TableNextRow()
            for colIndex, cell in ipairs(row) do
                imgui.TableSetColumnIndex(colIndex - 1)
                imgui.Text(cell)
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
            if imgui.BeginTabItem("Buy") then
                currentTab = "Buy"
                ui.drawBuyTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Sell") then
                currentTab = "Sell"
                ui.drawSellTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Settings") then
                currentTab = "Settings"
                ui.drawSettingsTab()
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
        end
        imgui.End()
    end
end

return ui
