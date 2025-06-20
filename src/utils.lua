local utils = {}

function utils.commaValue(n)
    local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function utils.getCurrentGils()
    if AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetInventory() and AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0) then
        return AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0).Count
    else
        return 0
    end
end

function utils.hasFlag(n, flag)
    return bit.band(n, flag) == flag
end

function utils.findItem(item_id, item_count)
    local items = AshitaCore:GetMemoryManager():GetInventory()
    for ind = 1, items:GetContainerCountMax(0) do
        local item = items:GetContainerItem(0, ind)
        if item ~= nil and item.Id == item_id and item.Flags == 0 and item.Count >= item_count then
            return item.Index
        end
    end
    return nil
end

function utils.getItem(id)
    return AshitaCore:GetResourceManager():GetItemById(tonumber(id))
end

function utils.getItemName(id)
    return AshitaCore:GetResourceManager():GetItemById(tonumber(id)).Name[1]
end

function utils.getItemById(id)
    return AshitaCore:GetResourceManager():GetItemById(tonumber(id))
end

function utils.timef(ts)
    return string.format("%d days %.2d:%.2d:%.2d", ts / (60 * 60 * 24), ts / (60 * 60) % 24, ts / 60 % 60, ts % 60)
end

function utils.escapeString(str)
    -- shamelessly stolen from Shinzaku's GearFinder
    if str then
        return str:
        replace('\x81\x60', '~'):
        replace('\xEF\x1F', 'Fire Res'):
        replace('\xEF\x20', 'Ice Res'):
        replace('\xEF\x21', 'Wind Res'):
        replace('\xEF\x22', 'Earth Res'):
        replace('\xEF\x23', 'Ltng Res'):
        replace('\xEF\x24', 'Water Res'):
        replace('\xEF\x25', 'Light Res'):
        replace('\xEF\x26', 'Dark Res'):
        replace('\x25', '%')
    end

    return ''
end

function utils.getJobsString(bitfield)
    if bitfield == 8388606 then
        return T { 'All jobs' }
    end

    local jobList = T {}
    for i = 1, 23 do
        if bit.band(1, bit.rshift(bitfield, i)) == 1 then
            table.insert(jobList, jobs[i])
        end
    end
    return jobList
end

function utils.getJobs(bitfield)
    if bitfield == 8388606 then
        return T { 999 }
    end

    local jobList = T {}
    for i = 1, 23 do
        if bit.band(1, bit.rshift(bitfield, i)) == 1 then
            table.insert(jobList, i)
        end
    end
    return jobList
end

function utils.createTextureFromGame(bitmap, size)
    local c = ffi.C
    local texturePtr = ffi.new('IDirect3DTexture8*[1]')

    local width = 0xFFFFFFFF
    local height = 0xFFFFFFFF
    local mipLevels = 1
    local usage = 0
    local colorKey = 0xFF000000
    local gfxDevice = d3d8.get_device()

    local textureSuccess = c.D3DXCreateTextureFromFileInMemoryEx(
        gfxDevice,
        bitmap,
        size,
        width,
        height,
        mipLevels,
        usage,
        c.D3DFMT_A8R8G8B8,
        c.D3DPOOL_MANAGED,
        c.D3DX_DEFAULT,
        c.D3DX_DEFAULT,
        colorKey,
        nil,
        nil,
        texturePtr)

    if textureSuccess == c.S_OK then
        return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', texturePtr[0]))
    else
        return nil
    end
end

function utils.createTextureFromFile(path)
    if (path ~= nil) then
        local dx_texture_ptr = ffi.new('IDirect3DTexture8*[1]')
        local d3d8_device = d3d8.get_device()
        if (ffi.C.D3DXCreateTextureFromFileA(d3d8_device, path, dx_texture_ptr) == ffi.C.S_OK) then
            local texture = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', dx_texture_ptr[0]))
            local result, desc = texture:GetLevelDesc(0)
            if result == 0 then
                tx         = {}
                tx.Texture = texture
                tx.Width   = desc.Width
                tx.Height  = desc.Height
                return tx
            end
            return
        end
    end
end

function utils.rgbaToU32(r, g, b, a)
    local function to255(x) return math.floor(x * 255 + 0.5) end
    return bit.lshift(to255(a), 24)
        + bit.lshift(to255(b), 16)
        + bit.lshift(to255(g), 8)
        + to255(r)
end

function utils.relativeTime(epoch)
    local diff = os.time() - epoch

    if diff < 60 then
        return "just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes == 1 and "a minute ago" or (minutes .. " minutes ago")
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours == 1 and "about an hour ago" or (hours .. " hours ago")
    elseif diff < 172800 then
        return "yesterday"
    else
        local days = math.floor(diff / 86400)
        return days == 1 and "1 day ago" or (days .. " days ago")
    end
end

function utils.getSalesRatingLabel(rate)
    local r = tonumber(rate)
    if not r then return nil end

    for _, t in ipairs(salesRating.thresholds) do
        if r >= t[1] then
            return salesRating.labels[t[2]]
        end
    end
end

function utils.getSalesRatingColor(rate)
    local r = tonumber(rate)
    if not r then return nil end

    for _, t in ipairs(salesRating.thresholds) do
        if r >= t[1] then
            return salesRating.colors[t[2]]
        end
    end
end

function utils.getStockColor(stock)
    local s = tonumber(stock)
    if s > 0 then
        return salesRating.colors[#salesRating.colors]
    else
        return salesRating.colors[2]
    end
end

function utils.calcSalesRate(now, oldestSaleTimestamp, numSales)
    if numSales == 0 or now <= oldestSaleTimestamp then
        return 0
    end
    local timeDiff = now - oldestSaleTimestamp
    local salesPerDay = numSales * 86400 / timeDiff
    return string.format("%.3f", salesPerDay)
end

function utils.hexToImVec4(hex)
    hex = hex:gsub("#", "")
    local r = tonumber("0x" .. hex:sub(1, 2)) / 255
    local g = tonumber("0x" .. hex:sub(3, 4)) / 255
    local b = tonumber("0x" .. hex:sub(5, 6)) / 255
    return { r, g, b, 1.0 }
end

function utils.findCommonElements(table1, table2)
    local commonTable = {}
    local tempSet = {}

    for _, value in ipairs(table2) do
        tempSet[value] = true
    end

    for _, value in ipairs(table1) do
        if tempSet[value] then
            commonTable[#commonTable + 1] = value
        end
    end

    return commonTable
end

return utils
