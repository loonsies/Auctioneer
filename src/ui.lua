local imgui = require('imgui')
local chat = require('chat')
local ffi = require('ffi')
local settings = require('settings')

local auctionHouse = require('src/auctionHouse')
local search = require('src/search')
local task = require('src/task')
local commands = require('src/commands')
local utils = require('src/utils')
local ffxiah = require('src/ffxiah')
local inventory = require('src/inventory')
local packets = require('src/packets')
local categories = require('data/categories')
local auctionHouseActions = require('data/auctionHouseActions')
local jobs = require('data/jobs')
local searchStatus = require('data/searchStatus')
local servers = require('data/servers')
local tabTypes = require('data/tabTypes')

local ui = {}

local minSize = { 575, 400 }
local defaultSizeFFXIAH = { 600, 500 }
local minSizeFFXIAH = { 400, 400 }
local quantityInput = { 1 }
local priceInput = { '' }
local stack = { false }
local gilIcon = nil

local preview = {
    textureCache = {},
    itemBackground = nil
}

local modal = {
    visible = false
}

local bellhopDropModal = {
    visible = false,
    action = '',
    items = {}
}

function ui.updateETA()
    local now = os.clock()
    local deltaTime = now - auctioneer.lastUpdateTime
    auctioneer.lastUpdateTime = now

    if auctioneer.eta > 0 then
        auctioneer.eta = math.max(0, auctioneer.eta - deltaTime)
    end
end

function ui.update()
    if not auctioneer.visible[1] then
        return
    end

    for tabType, tabObj in pairs(auctioneer.tabs) do
        local currentInput = table.concat(tabObj.input)
        local previousInput = table.concat(tabObj.previousInput)
        local lvMinInput = table.concat(tabObj.lvMinInput)
        local previousLvMinInput = table.concat(tabObj.previousLvMinInput)
        local lvMaxInput = table.concat(tabObj.lvMaxInput)
        local previousLvMaxInput = table.concat(tabObj.previousLvMaxInput)
        local selectedJobs = table.concat(tabObj.jobSelected)
        local previousSelectedJobs = table.concat(tabObj.previousJobSelected)

        if currentInput ~= previousInput or tabObj.category ~= tabObj.previousCategory or lvMinInput ~= previousLvMinInput or lvMaxInput ~= previousLvMaxInput or selectedJobs ~= previousSelectedJobs or tabObj.startup then
            search.update(tabType, tabObj)
            tabObj.previousInput = { currentInput }
            tabObj.previousCategory = tabObj.category
            tabObj.startup = false
            tabObj.previousLvMinInput = { lvMinInput }
            tabObj.previousLvMaxInput = { lvMaxInput }
            tabObj.previousJobSelected = { selectedJobs }
        end
    end

    ui.drawUI()
end

function ui.drawGlobalCommands()
    local queueSize = task.getQueueSize()
    local queueText = 'No tasks queued'

    if queueSize > 0 then
        local mins = math.floor(auctioneer.eta / 60)
        local secs = math.floor(auctioneer.eta % 60)
        queueText = string.format('%d tasks queued - est. %d:%02d', queueSize, mins, secs)
    end

    imgui.Text(queueText)

    local function getButtonWidth(label, maxWidth)
        local textSize = imgui.CalcTextSize(label)
        local padding = 20
        local minWidth = textSize + padding
        if minWidth > maxWidth then
            return maxWidth
        else
            return minWidth
        end
    end

    local availX, _ = imgui.GetContentRegionAvail()

    local maxButtonWidth = availX / 3
    local stopWidth = getButtonWidth('Stop', maxButtonWidth)
    local openAHWidth = getButtonWidth('Open AH', maxButtonWidth)
    local clearSalesWidth = getButtonWidth('Clear Sales', maxButtonWidth)

    local buttonsWidth = stopWidth + openAHWidth + clearSalesWidth + (imgui.GetStyle().ItemSpacing.x * 2)

    imgui.SameLine()
    local cursorPosX = imgui.GetCursorPosX()
    local contentRegionX = imgui.GetContentRegionAvail() -- after Text()

    imgui.SetCursorPosX(cursorPosX + contentRegionX - buttonsWidth)

    if imgui.Button('Stop', { stopWidth, 0 }) then
        task.clear()
        auctioneer.eta = 0
    end
    imgui.SameLine()
    if imgui.Button('Open AH', { openAHWidth, 0 }) then
        commands.handleCommand({ '/ah', 'menu' })
    end
    imgui.SameLine()
    if imgui.Button('Clear Sales', { clearSalesWidth, 0 }) then
        commands.handleCommand({ '/ah', 'clear' })
    end
end

function ui.drawConfirmationModal()
    if not modal.visible then
        return
    end

    imgui.SetNextWindowSize({ 0, 0 }, ImGuiCond_Always)
    imgui.OpenPopup('Confirm transaction')

    if imgui.BeginPopupModal('Confirm transaction', nil, ImGuiWindowFlags_AlwaysAutoResize) then
        name, single, price, quantity = table.unpack(modal.args)

        imgui.Text('Are you sure you want to proceed with this transaction?')
        imgui.Separator()
        imgui.Text(string.format('%s %s of %s for %s', auctionHouseActions[modal.action],
            single == '0' and 'Single' or 'Stack', name, utils.commaValue(price)))
        imgui.Text(string.format('This task will be executed %s times', quantity))
        if imgui.Button('OK', { 120, 0 }) then
            if auctionHouse.proposal(modal.action, name, single, price, quantity) then
                quantityInput = { 1 }
            end
            modal.visible = false
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button('Cancel', { 120, 0 }) then
            modal.visible = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

function ui.drawBellhopDropConfirmationModal()
    if not bellhopDropModal.visible then
        return
    end

    imgui.SetNextWindowSize({ 0, 0 }, ImGuiCond_Always)
    imgui.OpenPopup('Confirm ' .. bellhopDropModal.action)

    if imgui.BeginPopupModal('Confirm ' .. bellhopDropModal.action, nil, ImGuiWindowFlags_AlwaysAutoResize) then
        imgui.Text('Are you sure you want to proceed with this action?')
        imgui.Separator()

        if bellhopDropModal.action == 'Bellhop Buy' then
            imgui.Text('You are about to purchase the following items:')
        elseif bellhopDropModal.action == 'Bellhop Sell' then
            imgui.Text('You are about to sell the following items:')
        elseif bellhopDropModal.action == 'Drop' then
            imgui.Text('You are about to drop the following items:')
        end

        -- Display list of items
        if imgui.BeginChild('ItemList', { 400, math.min(200, #bellhopDropModal.items * 20 + 10) }, true) then
            for _, item in ipairs(bellhopDropModal.items) do
                if bellhopDropModal.action == 'Drop' then
                    imgui.Text(string.format('-> %s (x%d) from slot %d', item.name, item.quantity, item.slot))
                else
                    imgui.Text(string.format('-> %s (x%d)', item.name, item.quantity))
                end
            end
            imgui.EndChild()
        end

        imgui.Separator()

        if imgui.Button('OK', { 120, 0 }) then
            -- Execute the action
            if bellhopDropModal.action == 'Bellhop Buy' then
                ui.executeBellhopBuy(bellhopDropModal.items)
            elseif bellhopDropModal.action == 'Bellhop Sell' then
                ui.executeBellhopSell(bellhopDropModal.items)
            elseif bellhopDropModal.action == 'Drop' then
                ui.executeDrop(bellhopDropModal.items)
            end
            bellhopDropModal.visible = false
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button('Cancel', { 120, 0 }) then
            bellhopDropModal.visible = false
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

function ui.executeBellhopBuy(items)
    for _, item in ipairs(items) do
        AshitaCore:GetChatManager():QueueCommand(-1, string.format('/bh buy "%s" %i', item.name, item.quantity))
    end
    quantityInput = { 1 }
end

function ui.executeBellhopSell(items)
    for _, item in ipairs(items) do
        AshitaCore:GetChatManager():QueueCommand(-1, string.format('/bh sell "%s" %i', item.name, item.quantity))
    end
    quantityInput = { 1 }
end

function ui.executeDrop(items)
    local dropped = 0
    for _, item in ipairs(items) do
        if packets.dropItemBySlot(item.slot, item.quantity) then
            print(chat.header(addon.name):append(chat.message(string.format('Dropping %s from slot %d', item.name, item.slot))))
            dropped = dropped + 1
        end
    end
    if dropped == 0 then
        print(chat.header(addon.name):append(chat.error('Failed to drop any items')))
    end
end

function ui.drawFilters()
    imgui.Text('Category')
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo('##CategoryCombo', categories.list[auctioneer.tabs[auctioneer.currentTab].category]) then
        for _, id in ipairs(categories.order) do
            local category = categories.list[id]
            local is_selected = (auctioneer.tabs[auctioneer.currentTab].category == id)
            if imgui.Selectable(category, is_selected) then
                auctioneer.tabs[auctioneer.currentTab].category = id
            end
        end
        imgui.EndCombo()
    end

    imgui.Text('Lv. Min')
    imgui.SameLine()
    imgui.SetNextItemWidth(100)
    if imgui.InputInt('##LvMin', auctioneer.tabs[auctioneer.currentTab].lvMinInput) then
        if auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] < 0 then
            auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] = 0
        elseif auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] > 99 then
            auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] = 99
        elseif auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] > auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] then
            auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] = auctioneer.tabs[auctioneer.currentTab].previousLvMinInput[1]
        end
    end
    imgui.SameLine()

    imgui.Text('Lv. Max')
    imgui.SameLine()
    imgui.SetNextItemWidth(100)
    if imgui.InputInt('##LvMax', auctioneer.tabs[auctioneer.currentTab].lvMaxInput) then
        if auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] < 0 then
            auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] = 0
        elseif auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] > 99 then
            auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] = 99
        elseif auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] < auctioneer.tabs[auctioneer.currentTab].lvMinInput[1] then
            auctioneer.tabs[auctioneer.currentTab].lvMaxInput[1] = auctioneer.tabs[auctioneer.currentTab].previousLvMaxInput[1]
        end
    end
    imgui.SameLine()

    if imgui.Checkbox('Show all items', auctioneer.config.tabs[auctioneer.currentTab].showAllItems) then
        search.update(auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])
    end
    imgui.ShowHelp('Displays all items, even those who are not auctionable/bazaarable', true)

    imgui.Text('Jobs')
    imgui.SetNextItemWidth(-1)
    imgui.SameLine()
    local jobComboText = ''
    if #auctioneer.tabs[auctioneer.currentTab].jobSelected == 0 then
        jobComboText = 'No jobs selected'
    else
        jobComboText = string.format('%i jobs selected', #auctioneer.tabs[auctioneer.currentTab].jobSelected)
    end
    if imgui.BeginCombo('##JobSelectCombo', jobComboText) then
        for id, jobName in ipairs(jobs) do
            local isSelected = false
            for _, selectedId in ipairs(auctioneer.tabs[auctioneer.currentTab].jobSelected) do
                if selectedId == id then
                    isSelected = true
                    break
                end
            end

            local selected = { isSelected }
            if imgui.Checkbox(jobName, selected) then
                if selected[1] then
                    table.insert(auctioneer.tabs[auctioneer.currentTab].jobSelected, id)
                else
                    for i, selectedId in ipairs(auctioneer.tabs[auctioneer.currentTab].jobSelected) do
                        if selectedId == id then
                            table.remove(auctioneer.tabs[auctioneer.currentTab].jobSelected, i)
                            break
                        end
                    end
                end
            end
        end
        imgui.EndCombo()
    end
end

function ui.drawSearch()
    local currentTab = auctioneer.tabs[auctioneer.currentTab]
    local currentTabName = tabTypes[auctioneer.currentTab]

    imgui.Text('Search (' .. #currentTab.results .. ')')

    -- Add refresh button next to search count
    if auctioneer.currentTab ~= tabTypes.allItems then
        imgui.SameLine()
        if imgui.Button('Refresh##refreshInventory') then
            inventory.update()
            search.update(auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])
        end
    end

    -- Add reset button for Mog Garden tab
    if auctioneer.currentTab == tabTypes.mogGarden then
        if imgui.Button('Reset##resetMogGarden') then
            local mogGarden = require('src/mogGarden')
            local success, message = mogGarden.resetSnapshot()
            if success then
                print(chat.header(addon.name):append(chat.message(message)))
            else
                print(chat.header(addon.name):append(chat.error(message)))
            end
        end
    end


    local showSelectButtons = (auctioneer.currentTab == tabTypes.inventory or auctioneer.currentTab == tabTypes.mogGarden)
        and auctioneer.config.bellhopCommands[1] and AshitaCore:GetPluginManager():Get('Bellhop')
    local selectButtonWidth = 70
    local unselectButtonWidth = 85
    local clearButtonWidth = 55

    -- Select/Unselect buttons
    if showSelectButtons then
        if imgui.Button('Select##selectAll', { selectButtonWidth, 0 }) then
            local currentTab = auctioneer.tabs[auctioneer.currentTab]
            currentTab.bhChecked = currentTab.bhChecked or {}
            for i = 1, #currentTab.results do
                local itemEntry = currentTab.results[i]
                local key = tostring(itemEntry.id) .. ':' .. tostring(itemEntry.index or 0)
                currentTab.bhChecked[key] = true
            end
        end
        imgui.SameLine()
        if imgui.Button('Unselect##unselectAll', { unselectButtonWidth, 0 }) then
            local currentTab = auctioneer.tabs[auctioneer.currentTab]
            if currentTab.bhChecked then
                for i = 1, #currentTab.results do
                    local itemEntry = currentTab.results[i]
                    local key = tostring(itemEntry.id) .. ':' .. tostring(itemEntry.index or 0)
                    currentTab.bhChecked[key] = nil
                end
            end
        end
        imgui.SameLine()
    end

    -- Search bar
    local availX = select(1, imgui.GetContentRegionAvail())
    local searchBarWidth = availX - clearButtonWidth - imgui.GetStyle().ItemSpacing.x
    if searchBarWidth < 100 then searchBarWidth = 100 end
    imgui.SetNextItemWidth(searchBarWidth)
    imgui.InputText('##SearchInput', currentTab.input, 48)

    imgui.SameLine()
    if imgui.Button('Clear##clearSearch', { clearButtonWidth, 0 }) then
        currentTab.input[1] = ''
        search.update(auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])
    end

    -- Calculate reserved height for lower UI
    local reservedHeight = 0
    local frameHeight = imgui.GetFontSize()
    local itemSpacing = imgui.GetStyle().ItemSpacing.y
    local framePadding = imgui.GetStyle().FramePadding.y

    -- Item preview height
    if auctioneer.config.itemPreview[1] then
        reservedHeight = reservedHeight + 150 + itemSpacing
    end

    -- Commands section
    reservedHeight = reservedHeight + frameHeight + (framePadding * 2) + itemSpacing

    -- Buy/Sell/Max/Gil
    reservedHeight = reservedHeight + frameHeight + (framePadding * 2) + itemSpacing

    -- Spacing
    reservedHeight = reservedHeight + itemSpacing

    -- Utils section
    local utilsHeight = 0
    if (auctioneer.config.bellhopCommands[1] and (auctioneer.currentTab == tabTypes.inventory or auctioneer.currentTab == tabTypes.mogGarden) and AshitaCore:GetPluginManager():Get('Bellhop')) or
        (auctioneer.config.dropButton[1] and (auctioneer.currentTab == tabTypes.inventory or auctioneer.currentTab == tabTypes.mogGarden)) or
        true then -- "Open wiki" and "Open FFXIAH" buttons are always shown
        utilsHeight = frameHeight + (framePadding * 2) + itemSpacing
    end
    reservedHeight = reservedHeight + utilsHeight

    -- FFXIAH section
    if auctioneer.config.ffxiah[1] then
        -- FFXIAH server combo
        reservedHeight = reservedHeight + frameHeight + (framePadding * 2) + itemSpacing

        -- Fetch/Clear buttons
        reservedHeight = reservedHeight + frameHeight + (framePadding * 2) + itemSpacing

        -- Inline FFXIAH display
        if not auctioneer.config.separateFFXIAH[1] and auctioneer.ffxiah.windows[1] then
            -- Item info
            reservedHeight = reservedHeight + (frameHeight * 3) + itemSpacing * 2

            -- Price history
            if auctioneer.ffxiah.windows[1].sales then
                reservedHeight = reservedHeight + 150 + itemSpacing
            end

            -- Bazaar
            if auctioneer.ffxiah.windows[1].bazaar then
                reservedHeight = reservedHeight + 150 + itemSpacing
            end
        end
    end

    -- Available height for results
    local _, availableHeight = imgui.GetContentRegionAvail()
    availableHeight = availableHeight - reservedHeight - 5 -- Extra 5px buffer to prevent scrollbar
    availableHeight = math.max(availableHeight, 60)        -- Minimum height

    imgui.SetNextWindowSizeConstraints({ 150, 0 }, { FLT_MAX, FLT_MAX })
    if imgui.BeginChild(string.format('##SearchResultsChild%s', currentTabName), { 0, availableHeight }, false) then
        -- Configurable values
        local iconSize = (auctioneer.config.itemIconSize and auctioneer.config.itemIconSize[1]) or 24
        local rowHeight = (auctioneer.config.itemRowHeight and auctioneer.config.itemRowHeight[1]) or 24

        -- No spacing for seamless rows
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 0, 0 })
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })

        if currentTab.status == searchStatus.found then
            local clipper = ImGuiListClipper.new()
            clipper:Begin(#currentTab.results, rowHeight)

            while clipper:Step() do
                for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    local itemEntry = currentTab.results[i + 1]
                    local itemId = itemEntry.id
                    local itemStack = itemEntry.stack
                    local index = itemEntry.index

                    local isSelected = (currentTab.selectedItem == itemId and currentTab.selectedIndex == index)
                    local itemLabel = items[itemId].shortName
                    local bitmap = items[itemId].bitmap
                    local imageSize = items[itemId].imageSize

                    if itemId ~= nil and preview.textureCache[itemId] == nil then
                        preview.textureCache[itemId] = utils.createTextureFromGame(bitmap, imageSize)
                    end
                    local iconPointer = tonumber(ffi.cast('uint32_t', preview.textureCache[itemId]))

                    local iconClicked = false
                    local labelClicked = false

                    -- Full-width row
                    local availWidth = imgui.GetContentRegionAvail()

                    imgui.PushID(i)

                    -- Alternating row background
                    local isEvenRow = (i + 1) % 2 == 0
                    if isEvenRow then
                        local drawList = imgui.GetWindowDrawList()
                        local min_x, min_y = imgui.GetCursorScreenPos()
                        local max_x = min_x + availWidth
                        local max_y = min_y + rowHeight
                        local bgColor = 0x22000000 -- Higher opacity dark gray for visible contrast
                        drawList:AddRectFilled({ min_x, min_y }, { max_x, max_y }, bgColor)
                    end

                    -- Bellhop checkbox
                    local showBhCheckbox = auctioneer.config.bellhopCommands[1]
                        and (auctioneer.currentTab == tabTypes.inventory or auctioneer.currentTab == tabTypes.mogGarden)
                        and AshitaCore:GetPluginManager():Get('Bellhop')

                    local checkboxSize = rowHeight * 0.8
                    local checkboxWidth = showBhCheckbox and rowHeight or 0
                    local iconWidth = rowHeight
                    local remainingWidth = availWidth - checkboxWidth - iconWidth

                    imgui.BeginGroup()

                    if showBhCheckbox then
                        auctioneer.tabs[auctioneer.currentTab].bhChecked = auctioneer.tabs[auctioneer.currentTab].bhChecked or {}
                        local key = tostring(itemId) .. ':' .. tostring(index or 0)
                        local checkedTbl = { auctioneer.tabs[auctioneer.currentTab].bhChecked[key] == true }

                        if imgui.InvisibleButton('##bhchk_btn', { rowHeight, rowHeight }) then
                            checkedTbl[1] = not checkedTbl[1]
                            auctioneer.tabs[auctioneer.currentTab].bhChecked[key] = checkedTbl[1] or nil
                        end

                        -- Draw centered checkbox
                        local btn_min_x, btn_min_y = imgui.GetItemRectMin()
                        local btn_max_x, btn_max_y = imgui.GetItemRectMax()
                        local drawList = imgui.GetWindowDrawList()
                        local btn_center_x = btn_min_x + (btn_max_x - btn_min_x) * 0.5
                        local btn_center_y = btn_min_y + (btn_max_y - btn_min_y) * 0.5

                        local half_size = checkboxSize * 0.5
                        local min_x = btn_center_x - half_size
                        local min_y = btn_center_y - half_size
                        local max_x = btn_center_x + half_size
                        local max_y = btn_center_y + half_size
                        local checkSize = checkboxSize * 0.8

                        local bgColor = checkedTbl[1] and 0xFF4080FF or 0xFF2c2c2c
                        drawList:AddRectFilled({ min_x, min_y }, { max_x, max_y }, bgColor, 2)

                        if checkedTbl[1] then
                            local markSize = checkSize * 0.3
                            local center_x = btn_center_x
                            local center_y = btn_center_y
                            drawList:AddLine({ center_x - markSize, center_y },
                                { center_x - markSize * 0.3, center_y + markSize * 0.7 },
                                0xFFFFFFFF, 2)
                            drawList:AddLine({ center_x - markSize * 0.3, center_y + markSize * 0.7 },
                                { center_x + markSize, center_y - markSize * 0.5 },
                                0xFFFFFFFF, 2)
                        end

                        imgui.SameLine(0, 2) -- 2px spacing after checkbox
                    end

                    if iconPointer then
                        if imgui.InvisibleButton('icon_btn', { iconSize, rowHeight }) then
                            iconClicked = true
                        end

                        local min_x, min_y = imgui.GetItemRectMin()
                        local iconCenterY = min_y + (rowHeight - iconSize) * 0.5
                        imgui.GetWindowDrawList():AddImage(iconPointer,
                            { min_x, iconCenterY },
                            { min_x + iconSize, iconCenterY + iconSize })

                        imgui.SameLine(0, 2) -- 2px spacing after icon
                    end

                    -- Item label
                    local baseLabel = itemLabel
                    if auctioneer.currentTab ~= tabTypes.allItems then
                        baseLabel = string.format('%s (%s)', items[itemId].shortName, itemStack)
                    end

                    -- Restriction flags
                    local flags = {}
                    if not items[itemId].isAuctionable then
                        table.insert(flags, 'Auction')
                    end
                    if not items[itemId].isBazaarable then
                        table.insert(flags, 'Bazaar')
                    end
                    if not items[itemId].isVendorable then
                        table.insert(flags, 'Vendor')
                    end
                    local flagsString = ''
                    if #flags > 0 then
                        flagsString = 'X ' .. table.concat(flags, '/')
                    end

                    -- Font scale
                    local baseFontSize = imgui.GetFontSize()
                    local fontScale = rowHeight / 24.0

                    imgui.SetWindowFontScale(fontScale)

                    -- Row position for flags
                    local itemStartX = imgui.GetCursorPosX()
                    local itemStartY = imgui.GetCursorPosY()

                    if imgui.Selectable(baseLabel .. '##' .. itemId .. (index and ('-' .. index) or ''), isSelected, nil, { remainingWidth, rowHeight }) then
                        labelClicked = true
                    end

                    -- Flags on right
                    if flagsString ~= '' then
                        local textWidth = imgui.CalcTextSize(flagsString)
                        imgui.SetCursorPosX(itemStartX + remainingWidth - textWidth - 5) -- 5px padding from right edge
                        imgui.SetCursorPosY(itemStartY + (rowHeight - imgui.GetFontSize()) * 0.5)

                        local flagColor
                        if isSelected or imgui.IsItemHovered() then
                            flagColor = { 1.0, 1.0, 1.0, 1.0 } -- White when selected/hovered
                        else
                            flagColor = { 1.0, 0.3, 0.3, 1.0 } -- Red when normal
                        end
                        imgui.TextColored(flagColor, flagsString)
                    end

                    imgui.SetWindowFontScale(1.0)

                    imgui.EndGroup()
                    imgui.PopID()

                    if iconClicked or labelClicked then
                        currentTab.selectedItem = itemId
                        currentTab.selectedIndex = index
                    end
                end
            end

            clipper:End()
        else
            imgui.Text(searchStatus[currentTab.status])
        end

        imgui.PopStyleVar(2)
        imgui.EndChild()
    end
end

function ui.drawItemPreview()
    if imgui.BeginChild('##ItemPreviewChild', { 0, 150 }, true) then
        if auctioneer.tabs[auctioneer.currentTab].selectedItem ~= nil then
            local id = auctioneer.tabs[auctioneer.currentTab].selectedItem
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

            if id ~= nil and preview.textureCache[id] == nil then
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
            imgui.Text(utils.getJobsString(item.jobs):join(', '))
            imgui.PopTextWrapPos()
            imgui.EndGroup()
        end
        imgui.EndChild()
    end
end

function ui.drawUtils()
    if auctioneer.config.bellhopCommands[1] and (auctioneer.currentTab == tabTypes.inventory or auctioneer.currentTab == tabTypes.mogGarden) and AshitaCore:GetPluginManager():Get('Bellhop') then
        if imgui.Button('Bellhop Buy##bellhopBuy') then
            if auctioneer.config.bellhopDropConfirmation[1] then
                local tab = auctioneer.tabs[auctioneer.currentTab]
                local itemList = {}

                if tab.bhChecked then
                    for _, entry in ipairs(tab.results) do
                        local key = tostring(entry.id) .. ':' .. tostring(entry.index or 0)
                        if tab.bhChecked[key] then
                            local name = items[entry.id].shortName
                            table.insert(itemList, { name = name, quantity = quantityInput[1] })
                        end
                    end
                end

                if #itemList == 0 then
                    if tab.selectedItem == nil then
                        print(chat.header(addon.name):append(chat.error('Please select an item')))
                    else
                        table.insert(itemList, { name = items[tab.selectedItem].shortName, quantity = quantityInput[1] })
                    end
                end

                if #itemList > 0 then
                    bellhopDropModal.visible = true
                    bellhopDropModal.action = 'Bellhop Buy'
                    bellhopDropModal.items = itemList
                end
            else
                local tab = auctioneer.tabs[auctioneer.currentTab]
                local queued = 0
                if tab.bhChecked then
                    for _, entry in ipairs(tab.results) do
                        local key = tostring(entry.id) .. ':' .. tostring(entry.index or 0)
                        if tab.bhChecked[key] then
                            local name = items[entry.id].shortName
                            AshitaCore:GetChatManager():QueueCommand(-1, string.format('/bh buy "%s" %i', name, quantityInput[1]))
                            queued = queued + 1
                        end
                    end
                end
                if queued == 0 then
                    if tab.selectedItem == nil then
                        print(chat.header(addon.name):append(chat.error('Please select an item')))
                    else
                        AshitaCore:GetChatManager():QueueCommand(-1, string.format('/bh buy "%s" %i', items[tab.selectedItem].shortName, quantityInput[1]))
                        queued = 1
                    end
                end
                if queued > 0 then
                    quantityInput = { 1 }
                end
            end
        end
        imgui.SameLine()

        if imgui.Button('Bellhop Sell##bellhopSell') then
            if auctioneer.config.bellhopDropConfirmation[1] then
                local tab = auctioneer.tabs[auctioneer.currentTab]
                local itemList = {}

                if tab.bhChecked then
                    for _, entry in ipairs(tab.results) do
                        local key = tostring(entry.id) .. ':' .. tostring(entry.index or 0)
                        if tab.bhChecked[key] then
                            local name = items[entry.id].shortName
                            table.insert(itemList, { name = name, quantity = quantityInput[1] })
                        end
                    end
                end

                if #itemList == 0 then
                    if tab.selectedItem == nil then
                        print(chat.header(addon.name):append(chat.error('Please select an item')))
                    else
                        table.insert(itemList, { name = items[tab.selectedItem].shortName, quantity = quantityInput[1] })
                    end
                end

                if #itemList > 0 then
                    bellhopDropModal.visible = true
                    bellhopDropModal.action = 'Bellhop Sell'
                    bellhopDropModal.items = itemList
                end
            else
                local tab = auctioneer.tabs[auctioneer.currentTab]
                local queued = 0
                if tab.bhChecked then
                    for _, entry in ipairs(tab.results) do
                        local key = tostring(entry.id) .. ':' .. tostring(entry.index or 0)
                        if tab.bhChecked[key] then
                            local name = items[entry.id].shortName
                            AshitaCore:GetChatManager():QueueCommand(-1, string.format('/bh sell "%s" %i', name, quantityInput[1]))
                            queued = queued + 1
                        end
                    end
                end
                if queued == 0 then
                    if tab.selectedItem == nil then
                        print(chat.header(addon.name):append(chat.error('Please select an item')))
                    else
                        AshitaCore:GetChatManager():QueueCommand(-1, string.format('/bh sell "%s" %i', items[tab.selectedItem].shortName, quantityInput[1]))
                        queued = 1
                    end
                end
                if queued > 0 then
                    quantityInput = { 1 }
                end
            end
        end
        imgui.SameLine()
    end

    if auctioneer.config.dropButton[1] and (auctioneer.currentTab == tabTypes.inventory or auctioneer.currentTab == tabTypes.mogGarden) then
        if imgui.Button('Drop##dropItems') then
            if auctioneer.config.bellhopDropConfirmation[1] then
                local tab = auctioneer.tabs[auctioneer.currentTab]
                local itemList = {}

                if tab.bhChecked then
                    for _, entry in ipairs(tab.results) do
                        local key = tostring(entry.id) .. ':' .. tostring(entry.index or 0)
                        if tab.bhChecked[key] and entry.index then
                            local name = items[entry.id].shortName
                            table.insert(itemList, { name = name, quantity = entry.stackCur, slot = entry.index })
                        end
                    end
                end

                if #itemList == 0 then
                    if tab.selectedItem == nil or tab.selectedIndex == nil then
                        print(chat.header(addon.name):append(chat.error('Please select an item or check items to drop')))
                    else
                        local name = items[tab.selectedItem].shortName
                        local selectedEntry = nil
                        for _, entry in ipairs(tab.results) do
                            if entry.id == tab.selectedItem and entry.index == tab.selectedIndex then
                                selectedEntry = entry
                                break
                            end
                        end
                        if selectedEntry then
                            table.insert(itemList, { name = name, quantity = selectedEntry.stackCur, slot = selectedEntry.index })
                        end
                    end
                end

                if #itemList > 0 then
                    bellhopDropModal.visible = true
                    bellhopDropModal.action = 'Drop'
                    bellhopDropModal.items = itemList
                end
            else
                local tab = auctioneer.tabs[auctioneer.currentTab]
                local dropped = 0

                if tab.bhChecked then
                    for _, entry in ipairs(tab.results) do
                        local key = tostring(entry.id) .. ':' .. tostring(entry.index or 0)
                        if tab.bhChecked[key] and entry.index then
                            local name = items[entry.id].shortName
                            if packets.dropItemBySlot(entry.index, entry.stackCur) then
                                print(chat.header(addon.name):append(chat.message(string.format('Dropping %s from slot %d', name, entry.index))))
                                dropped = dropped + 1
                            end
                        end
                    end
                end

                if dropped == 0 then
                    if tab.selectedItem == nil or tab.selectedIndex == nil then
                        print(chat.header(addon.name):append(chat.error('Please select an item or check items to drop')))
                    else
                        local name = items[tab.selectedItem].shortName
                        local selectedEntry = nil
                        for _, entry in ipairs(tab.results) do
                            if entry.id == tab.selectedItem and entry.index == tab.selectedIndex then
                                selectedEntry = entry
                                break
                            end
                        end

                        if selectedEntry and packets.dropItemBySlot(selectedEntry.index, selectedEntry.stackCur) then
                            print(chat.header(addon.name):append(chat.message(string.format('Dropping %s from slot %d', name, selectedEntry.index))))
                        end
                    end
                end
            end
        end
        imgui.SameLine()
    end

    if imgui.Button('Open wiki') then
        if auctioneer.tabs[auctioneer.currentTab].selectedItem == nil then
            print(chat.header(addon.name):append(chat.error('Please select an item')))
        else
            local shortName = (items[auctioneer.tabs[auctioneer.currentTab].selectedItem].shortName) or items[auctioneer.tabs[auctioneer.currentTab].selectedItem].longName
            shortName = string.gsub(shortName, ' ', '_')
            local url = string.format('https://bg-wiki.com/ffxi/%s', shortName)

            ashita.misc.execute('explorer', url)
        end
    end
    imgui.SameLine()

    if imgui.Button('Open FFXIAH') then
        if auctioneer.tabs[auctioneer.currentTab].selectedItem == nil then
            print(chat.header(addon.name):append(chat.error('Please select an item')))
        else
            local url = string.format('"https://www.ffxiah.com/item/%i?stack=%i"', auctioneer.tabs[auctioneer.currentTab].selectedItem, stack[1] and 1 or 0)
            ashita.misc.execute('explorer', url)
        end
    end
end

function ui.drawCommands()
    local iconSize = 20

    if gilIcon == nil then
        local path = string.format('%saddons/%s/resources/%s', AshitaCore:GetInstallPath(), addon.name,
            'gil.png')
        gilIcon = utils.createTextureFromFile(path)
        if gilIcon ~= nil then
            gilIcon.Pointer = tonumber(ffi.cast('uint32_t', gilIcon.Texture))
        end
    end

    imgui.Text('Quantity')
    imgui.SameLine()
    imgui.SetNextItemWidth(150)
    if imgui.InputInt('##QuantityInputInt', quantityInput) then
        if quantityInput[1] < 1 then
            quantityInput = { 1 }
        end
    end

    imgui.SameLine()
    imgui.Text('Price')
    imgui.SameLine()
    imgui.SetNextItemWidth(-1)
    imgui.InputText('##PriceInput', priceInput, 48)

    imgui.Checkbox('Stack', stack)
    imgui.SameLine()

    if imgui.Button('Buy') then
        if priceInput == nil or #priceInput == 0 or priceInput[1] == nil or priceInput[1] == '' then
            print(chat.header(addon.name):append(chat.error('Please enter a price')))
        elseif auctioneer.tabs[auctioneer.currentTab].selectedItem == nil then
            print(chat.header(addon.name):append(chat.error('Please select an item')))
        elseif auctioneer.auctionHouse == nil then
            print(chat.header(addon.name):append(chat.error('Interact with auction house or use /ah menu first')))
        else
            if auctioneer.config.confirmationPopup[1] then
                if not modal.visible then
                    modal.visible = true
                    modal.action = auctionHouseActions.buy
                    modal.args = {
                        items[auctioneer.tabs[auctioneer.currentTab].selectedItem].shortName,
                        stack[1] and '1' or '0',
                        priceInput[1],
                        quantityInput[1],
                    }
                end
            else
                if auctionHouse.proposal(auctionHouseActions.buy, items[auctioneer.tabs[auctioneer.currentTab].selectedItem].shortName,
                        stack[1] and '1' or '0', priceInput[1], quantityInput[1]) then
                    quantityInput = { 1 }
                end
            end
        end
    end
    imgui.SameLine()

    if imgui.Button('Sell') then
        if priceInput == nil or #priceInput == 0 or priceInput[1] == nil or priceInput[1] == '' then
            print(chat.header(addon.name):append(chat.error('Please enter a price')))
        elseif auctioneer.tabs[auctioneer.currentTab].selectedItem == nil then
            print(chat.header(addon.name):append(chat.error('Please select an item')))
        elseif auctioneer.auctionHouse == nil then
            print(chat.header(addon.name):append(chat.error('Interact with auction house or use /ah menu first')))
        else
            if auctioneer.config.confirmationPopup[1] then
                if not modal.visible then
                    modal.visible = true
                    modal.action = auctionHouseActions.sell
                    modal.args = {
                        items[auctioneer.tabs[auctioneer.currentTab].selectedItem].shortName,
                        stack[1] and '1' or '0',
                        priceInput[1],
                        quantityInput[1],
                    }
                end
            else
                if auctionHouse.proposal(auctionHouseActions.sell, items[auctioneer.tabs[auctioneer.currentTab].selectedItem].shortName,
                        stack[1] and '1' or '0', priceInput[1], quantityInput[1]) then
                    quantityInput = { 1 }
                end
            end
        end
    end
    imgui.SameLine()

    if auctioneer.currentTab ~= tabTypes.allItems then
        if imgui.Button('Max##max') then
            if auctioneer.tabs[auctioneer.currentTab].selectedItem and items[auctioneer.tabs[auctioneer.currentTab].selectedItem] then
                quantityInput = { utils.getCurrentStack() }
            end
        end
        imgui.SameLine()
    end

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

function ui.drawPriceHistory(sales, stock, rate, salesPerDay, median)
    imgui.Text('Price history')

    imgui.Text('Stock: ')
    imgui.SameLine(0, 0)
    imgui.TextColored(utils.hexToImVec4(utils.getStockColor(stock)), stock)
    imgui.Text(string.format('Rate: '))
    imgui.SameLine(0, 0)
    imgui.TextColored(utils.hexToImVec4(utils.getSalesRatingColor(rate)), utils.getSalesRatingLabel(rate))
    imgui.SameLine(0, 0)
    imgui.Text(string.format(' (%s sold /day)', salesPerDay))
    imgui.Text(string.format('Median: %s', utils.commaValue(median)))

    if imgui.BeginTable('##PriceHistoryTable', 4, bit.bor(ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_BordersV, ImGuiTableFlags_RowBg), { 0, 150 }) then
        imgui.TableSetupColumn('Date')
        imgui.TableSetupColumn('Seller')
        imgui.TableSetupColumn('Buyer')
        imgui.TableSetupColumn('Price')
        imgui.TableHeadersRow()

        for i, sale in ipairs(sales) do
            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.Text(sale.date)
            imgui.TableSetColumnIndex(1)
            imgui.Text(sale.seller)
            imgui.TableSetColumnIndex(2)
            imgui.Text(sale.buyer)
            imgui.TableSetColumnIndex(3)
            local priceStr = tostring(sale.price)
            if imgui.Selectable(utils.commaValue(sale.price) .. '##' .. i) then
                priceInput[1] = priceStr
            end
        end
        imgui.EndTable()
    end
end

function ui.drawBazaar(bazaar)
    imgui.Text('Bazaar')

    if imgui.BeginTable('##BazaarTable', 5, bit.bor(ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_BordersV, ImGuiTableFlags_RowBg), { 0, 150 }) then
        imgui.TableSetupColumn('Player')
        imgui.TableSetupColumn('Price')
        imgui.TableSetupColumn('Quantity')
        imgui.TableSetupColumn('Zone')
        imgui.TableSetupColumn('Last seen')
        imgui.TableHeadersRow()

        for i, bzr in ipairs(bazaar) do
            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.Text(string.format('%s.%s', bzr.server, bzr.player))
            imgui.TableSetColumnIndex(1)
            imgui.Text(tostring(bzr.price))
            imgui.TableSetColumnIndex(2)
            imgui.Text(tostring(bzr.quantity))
            imgui.TableSetColumnIndex(3)
            imgui.Text(bzr.zone)
            imgui.TableSetColumnIndex(4)
            imgui.Text(utils.relativeTime(bzr.time))
        end
        imgui.EndTable()
    end
end

function ui.drawFFXIAH()
    local availX, availY = imgui.GetContentRegionAvail()

    imgui.Text('FFXIAH')
    imgui.SameLine()
    imgui.Dummy({ 25, 0 })

    imgui.SameLine(availX - 200)
    imgui.Text('Server')
    imgui.SameLine()
    imgui.SetNextItemWidth(150)

    local currentServerName = servers[auctioneer.config.server[1]] or 'Unknown'

    if imgui.BeginCombo('##ServerSelectCombo', currentServerName) then
        for id, server in pairs(servers) do
            local isSelected = auctioneer.config.server[1] == id
            if imgui.Selectable(server, isSelected) and auctioneer.config.server[1] ~= id then
                auctioneer.config.server[1] = id
                settings.save()
            end
        end
        imgui.EndCombo()
    end

    if auctioneer.ffxiah.fetching then
        imgui.Text('Fetching...')
        imgui.SameLine()
    else
        if imgui.Button('Fetch prices & bazaar') then
            local selectedItem = auctioneer.tabs[auctioneer.currentTab].selectedItem
            if selectedItem == nil then
                print(chat.header(addon.name):append(chat.error('Please select an item')))
            else
                local requestedItem = selectedItem
                local requestedStack = stack[1]

                auctioneer.fetchResult = nil
                auctioneer.ffxiah.fetching = true

                ashita.tasks.oncef(2, function ()
                    ffxiah.fetch(requestedItem, requestedStack)
                end)
            end
        end
        imgui.SameLine()
    end

    if auctioneer.config.separateFFXIAH[1] and #auctioneer.ffxiah.windows > 0 and imgui.Button(string.format('Clear windows (%i)', #auctioneer.ffxiah.windows or 0)) then
        auctioneer.ffxiah.windows = {}
    end

    if not auctioneer.config.separateFFXIAH[1] and auctioneer.ffxiah.windows[1] then
        local window = auctioneer.ffxiah.windows[1]
        local data = {
            windowId = window.windowId,
            itemId = window.itemId,
            stack = window.stack,
            server = window.server,
            fetchedOn = window.fetchedOn,
            sales = window.sales,
            stock = window.stock,
            rate = window.rate,
            salesPerDay = window.salesPerDay,
            median = window.median,
            bazaar = window.bazaar
        }

        local name = items[data.itemId].shortName
        local stk = data.stack and 'Stack' or 'Single'
        local server = servers[data.server]
        local fetchedOn = os.date('%Y-%m-%d %H:%M:%S', window.fetchedOn)

        imgui.Text(string.format('Item: %s [%i] (%s)', items[data.itemId].shortName, data.itemId, stk))
        imgui.Text(string.format('Server: %s', server))
        imgui.Text(string.format('Fetched on: %s', fetchedOn))
        imgui.Separator()
        if data.sales ~= nil then
            ui.drawPriceHistory(data.sales, data.stock, data.rate, data.salesPerDay, data.median)
            if data.bazaar ~= nil then
                imgui.Separator()
            end
        end
        if data.bazaar ~= nil then
            ui.drawBazaar(data.bazaar)
        end
    end
end

function ui.drawBuySellTab()
    ui.drawGlobalCommands()
    imgui.Separator()

    if auctioneer.config.searchFilters[1] then
        ui.drawFilters()
        imgui.Dummy({ 0, 0 })
    end

    if imgui.BeginTabBar('##AuctioneerSearchTabs') then
        for i = 1, 5 do
            local tabLabel = tabTypes[i]
            if imgui.BeginTabItem(tabLabel) then
                auctioneer.currentTab = i
                ui.drawSearch()
                imgui.EndTabItem()
            end
        end

        -- Mog Garden tab (only show when active and enabled)
        if auctioneer.config.mogGarden[1] and auctioneer.mogGarden.active then
            local tabLabel = tabTypes[6]
            if imgui.BeginTabItem(tabLabel) then
                auctioneer.currentTab = 6
                ui.drawSearch()
                imgui.EndTabItem()
            end
        end

        imgui.EndTabBar()
    end

    if auctioneer.config.itemPreview[1] then
        ui.drawItemPreview()
    end

    ui.drawCommands()

    imgui.Dummy({ 0, 0 })

    ui.drawUtils()

    if auctioneer.config.ffxiah[1] then
        imgui.Separator()
        ui.drawFFXIAH()
    end
end

function ui.drawAuctionHouseTab()
    ui.drawGlobalCommands()
    imgui.Separator()
    if auctioneer.auctionHouseInitialized == false then
        imgui.Text('Auction House not initialized.')
        imgui.Text('Interact with it to initialize this tab.')
    else
        if imgui.BeginTable('##AuctionHouseTable', 5, bit.bor(ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_BordersV, ImGuiTableFlags_RowBg)) then
            imgui.TableSetupColumn('Status')
            imgui.TableSetupColumn('Item')
            imgui.TableSetupColumn('Expires in')
            imgui.TableSetupColumn('Date')
            imgui.TableSetupColumn('Price')
            imgui.TableHeadersRow()

            for x = 0, 6 do
                data = {}
                data.status = auctioneer.auctionHouse[x].status
                if data.status ~= 'Expired' and data.status ~= 'Empty' then
                    data.timer = auctioneer.auctionHouse[x].status == 'On auction' and
                        auctioneer.auctionHouse[x].timestamp + 829440 or auctioneer.auctionHouse[x].timestamp
                    data.expiresIn = string.format('%s',
                        (auctioneer.auctionHouse[x].status == 'On auction' and os.time() - data.timer > 0) and 'Expired' or
                        utils.timef(math.abs(os.time() - data.timer)))
                    data.date = os.date('%c', data.timer)
                    data.count = tostring(auctioneer.auctionHouse[x].count)
                    data.item = auctioneer.auctionHouse[x].item .. ' (' .. data.count .. ')'
                    data.price = utils.commaValue(auctioneer.auctionHouse[x].price)
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
                elseif data.status == 'Empty' then
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
    -- Initialize default settings if they don't exist
    if not auctioneer.config.itemRowHeight then
        auctioneer.config.itemRowHeight = { 24 }
    end
    if not auctioneer.config.itemIconSize then
        auctioneer.config.itemIconSize = { 24 }
    end

    -- UI Appearance Settings
    imgui.Text('UI Appearance')
    imgui.Separator()

    if imgui.Checkbox('Display item preview', auctioneer.config.itemPreview) then
        settings.save()
    end

    if imgui.Checkbox('Enable search filters', auctioneer.config.searchFilters) then
        settings.save()
    end

    imgui.Text('Item List Row Height')
    imgui.SameLine()
    imgui.SetNextItemWidth(100)
    if imgui.InputInt('##RowHeight', auctioneer.config.itemRowHeight) then
        if auctioneer.config.itemRowHeight[1] < 16 then
            auctioneer.config.itemRowHeight[1] = 16
        elseif auctioneer.config.itemRowHeight[1] > 64 then
            auctioneer.config.itemRowHeight[1] = 64
        end
        -- Ensure icon size doesn't exceed row height
        if auctioneer.config.itemIconSize[1] > auctioneer.config.itemRowHeight[1] then
            auctioneer.config.itemIconSize[1] = auctioneer.config.itemRowHeight[1]
        end
        settings.save()
    end
    imgui.SameLine()
    imgui.Text('(16-64)')

    imgui.Text('Item Icon Size')
    imgui.SameLine()
    imgui.SetNextItemWidth(100)
    if imgui.InputInt('##IconSize', auctioneer.config.itemIconSize) then
        if auctioneer.config.itemIconSize[1] < 12 then
            auctioneer.config.itemIconSize[1] = 12
        elseif auctioneer.config.itemIconSize[1] > auctioneer.config.itemRowHeight[1] then
            auctioneer.config.itemIconSize[1] = auctioneer.config.itemRowHeight[1]
        end
        settings.save()
    end
    imgui.SameLine()
    imgui.Text(string.format('(12-%d)', auctioneer.config.itemRowHeight[1]))

    imgui.Dummy({ 0, 10 })

    -- Transaction Settings
    imgui.Text('Transaction Settings')
    imgui.Separator()

    if imgui.Checkbox('Enable transaction confirmation popup', auctioneer.config.confirmationPopup) then
        settings.save()
    end

    if imgui.Checkbox('Enable Bellhop/drop confirmation popup', auctioneer.config.bellhopDropConfirmation) then
        settings.save()
    end

    if imgui.Checkbox('Remove next buy tasks from queue if a task fails', auctioneer.config.removeFailedBuyTasks) then
        settings.save()
    end

    imgui.Dummy({ 0, 10 })

    -- Feature Toggles
    imgui.Text('Features')
    imgui.Separator()

    if imgui.Checkbox('Display auction house tab', auctioneer.config.auctionHouse) then
        settings.save()
    end

    if imgui.Checkbox('Display price history', auctioneer.config.ffxiah) then
        settings.save()
    end

    if imgui.Checkbox('Separate FFXIAH results in new windows', auctioneer.config.separateFFXIAH) then
        auctioneer.ffxiah.windows = {}
        settings.save()
    end

    if imgui.Checkbox('Show Bellhop commands', auctioneer.config.bellhopCommands) then
        settings.save()
    end

    if imgui.Checkbox('Show drop button', auctioneer.config.dropButton) then
        settings.save()
    end

    if imgui.Checkbox('Enable Mog Garden tracking', auctioneer.config.mogGarden) then
        if not auctioneer.config.mogGarden[1] and auctioneer.mogGarden.active then
            -- If disabled while active, deactivate tracking
            auctioneer.mogGarden.active = false
            auctioneer.mogGarden.inventorySnapshot = {}
            auctioneer.mogGarden.newItems = {}
        end
        settings.save()
    end
end

function ui.drawFFXIAHWindows()
    local removeIndices = {}

    for id, window in ipairs(auctioneer.ffxiah.windows) do
        local open = { true }
        local data = {
            windowId = window.windowId,
            itemId = window.itemId,
            stack = window.stack,
            server = window.server,
            fetchedOn = window.fetchedOn,
            sales = window.sales,
            stock = window.stock,
            rate = window.rate,
            salesPerDay = window.salesPerDay,
            median = window.median,
            bazaar = window.bazaar
        }

        local name = items[data.itemId].shortName
        local stk = data.stack and 'Stack' or 'Single'
        local server = servers[data.server]
        local fetchedOn = os.date('%Y-%m-%d %H:%M:%S', window.fetchedOn)
        imgui.SetNextWindowSizeConstraints(minSizeFFXIAH, { FLT_MAX, FLT_MAX })
        imgui.SetNextWindowSize(defaultSizeFFXIAH, ImGuiCond_FirstUseEver)
        if imgui.Begin(string.format('FFXIAH Data | %s [%i] (%s) | %s | %s##%s', name, data.itemId, stk, server, fetchedOn, data.windowId), open, ImGuiWindowFlags_NoSavedSettings) then
            imgui.Text(string.format('Item: %s [%i] (%s)', items[data.itemId].shortName, data.itemId, stk))
            imgui.Text(string.format('Server: %s', server))
            imgui.Text(string.format('Fetched on: %s', fetchedOn))
            imgui.Separator()
            if data.sales ~= nil then
                ui.drawPriceHistory(data.sales, data.stock, data.rate, data.salesPerDay, data.median)
                if data.bazaar ~= nil then
                    imgui.Separator()
                end
            end
            if data.bazaar ~= nil then
                ui.drawBazaar(data.bazaar)
            end
        end
        imgui.End()

        if not open[1] then
            table.insert(removeIndices, id)
        end
    end

    for i = #removeIndices, 1, -1 do
        table.remove(auctioneer.ffxiah.windows, removeIndices[i])
    end
end

function ui.drawUI()
    imgui.SetNextWindowSizeConstraints(minSize, { FLT_MAX, FLT_MAX })
    if imgui.Begin('Auctioneer', auctioneer.visible) then
        if imgui.BeginTabBar('##TabBar') then
            if imgui.BeginTabItem('Buy & Sell') then
                ui.drawBuySellTab()
                imgui.EndTabItem()
            end

            if auctioneer.config.auctionHouse[1] and imgui.BeginTabItem('Auction House') then
                ui.drawAuctionHouseTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Settings') then
                ui.drawSettingsTab()
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
        end
        ui.drawConfirmationModal()
        ui.drawBellhopDropConfirmationModal()
        imgui.End()
    end

    if auctioneer.config.separateFFXIAH[1] then
        ui.drawFFXIAHWindows()
    end
end

return ui
