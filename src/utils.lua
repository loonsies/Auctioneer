local utils = {}

function utils.commaValue(n)
    local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function utils.hasFlag(n, flag)
    return bit.band(n, flag) == flag
end

function utils.findItem(item_id, item_count)
    local items = AshitaCore:GetMemoryManager():GetInventory()
    for ind = 1, items:GetContainerCountMax(0) do
        local item = items:GetContainerItem(0, ind)
        if (item ~= nil and item.Id == item_id and item.Flags == 0 and item.Count >= item_count) then
            return item.Index
        end
    end
    return nil
end

function utils.getItemName(id)
    return AshitaCore:GetResourceManager():GetItemById(tonumber(id)).Name[1]
end

function utils.timef(ts)
    return string.format("%d days %.2d:%.2d:%.2d", ts / (60 * 60 * 24), ts / (60 * 60) % 24, ts / 60 % 60, ts % 60)
end

return utils
