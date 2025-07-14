local itemIds = require('data/itemIds')

local itemUtils = {}

function itemUtils.load()
    local items = {}
    local categoryLookup = {}

    for _, pair in ipairs(itemIds) do
        categoryLookup[pair[1]] = pair[2]
    end

    for id = 1, 65534 do -- 65535 is gil
        local category = categoryLookup[id] or 0
        local item = AshitaCore:GetResourceManager():GetItemById(id)
        if item then
            local isBazaarable = (bit.band(item.Flags, 0x4000) == 0)
            local isAuctionable = isBazaarable and (bit.band(item.Flags, 0x40) == 0)

            if item.Name[1] ~= '.' then -- Get rid of all the empty items
                if not items[id] then
                    items[id] = {}
                end

                items[id].shortName = item.Name[1] or ''
                items[id].longName = item.LogNameSingular[1] or ''
                items[id].description = item.Description[1] or ''
                items[id].category = category
                items[id].level = item.Level
                items[id].jobs = item.Jobs
                items[id].bitmap = item.Bitmap
                items[id].imageSize = item.ImageSize
                items[id].isBazaarable = isBazaarable
                items[id].isAuctionable = isAuctionable
            end
        end
    end
    return items
end

return itemUtils
