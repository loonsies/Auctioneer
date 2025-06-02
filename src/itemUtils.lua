local itemUtils = {}

itemIds = require("data/itemIds")
categories = require("data/categories")

-- https://github.com/mousseng/xitools/blob/ecf735bbafe0ce46b2f32591836ec33c435d2a77/addons/xitools/inv.lua#L271

function itemUtils.exportData()
    local res = AshitaCore:GetResourceManager()
    local csvContent = 'Name\n'
    local filePath = ('%s\\addons\\' .. addon.name .. '\\items.csv'):fmt(AshitaCore:GetInstallPath())
    local file = io.open(filePath, 'w+');
    if (file == nil) then
        print(chat.header(addon.name):append(chat.error('Could not write to file ' .. file)));
        return;
    end

    for index, itemId in ipairs(itemIds) do
        local item = res:GetItemById(itemId)
        local shortName = item.Name[1]
        local longName = item.LogNameSingular[1]
        local category = categories[bit.rshift(item.ResourceId, 10)]

        if shortName or longName then
            csvContent = csvContent ..
                string.format('%s, %s, %s, %s, %s\n', itemId, shortName, longName, category, item.ResourceId)
        else
            print(chat.header(addon.name):append(chat.success('Item not found for ID:' .. itemId)))
        end
    end

    -- Write the CSV content to a file
    file:write(csvContent)
    file:close()
    print(chat.header(addon.name):append(chat.success('Wrote items to ' .. filePath)))
end

return itemUtils
