local chat = require('chat')
local json = require('json')
local utils = require('src/utils')
local nonBlockingRequests = require('libs/nonBlockingRequests')
local servers = require('data/servers')

local ffxiah = {}

local function finalizeFetch(success)
    if auctioneer.fetchResult then
        auctioneer.fetchResult.fetching = false
        auctioneer.fetchResult.success = success
    end
    auctioneer.ffxiah.fetching = false
end

local function addWindowFromResult(result)
    if not result then
        return
    end

    local hasSales = result.sales ~= nil
    local hasBazaar = result.bazaar ~= nil
    if not hasSales and not hasBazaar then
        return
    end

    local timestamp = os.time()
    local windowId = string.format('%i%i', result.itemId, timestamp)

    table.insert(auctioneer.ffxiah.windows, {
        windowId = windowId,
        itemId = result.itemId,
        stack = result.stack,
        server = result.server,
        fetchedOn = timestamp,
        sales = result.sales,
        stock = result.stock,
        rate = result.rate,
        salesPerDay = result.salesPerDay,
        median = result.median,
        bazaar = result.bazaar
    })
end

local function handleJsonField(body, fieldName, id, processFn)
    local jsonStr = body:match('Item%.' .. fieldName .. '%s*=%s*(null)%s*;')
        or body:match('Item%.' .. fieldName .. '%s*=%s*(%[.-%])%s*;')
    if not jsonStr then
        print(chat.header(addon.name):append(chat.error('Failed to extract Item.' .. fieldName .. ' array')))
        return nil, true
    end

    local ok, tbl = pcall(json.decode, jsonStr)
    if not ok then
        print(chat.header(addon.name):append(chat.error('Failed to decode ' .. fieldName .. ' JSON')))
        return nil, true
    end

    if tbl == nil or type(tbl) ~= 'table' or #tbl == 0 then
        print(chat.header(addon.name):append(chat.message(string.format('No %s data for item [%i]', fieldName, id))))
        return {}, false
    end

    return processFn(tbl), false
end

local function processResponse(response, id, stack, server)
    local result = auctioneer.fetchResult
    if not response then
        finalizeFetch(false)
        auctioneer.fetchResult = nil
        return
    end

    local sales, err = handleJsonField(response, 'sales', id, function (salesTable)
        local formatted = {}
        for _, sale in ipairs(salesTable) do
            if not auctioneer.config.separateFFXIAH[1] then
                auctioneer.ffxiah.windows = {}
            end

            table.insert(formatted, {
                saleon = sale.saleon or '',
                date = os.date('%Y-%m-%d %H:%M:%S', sale.saleon),
                seller = sale.seller_name or '',
                buyer = sale.buyer_name or '',
                price = sale.price or 0,
            })
        end
        return formatted
    end)

    if err then
        finalizeFetch(false)
        auctioneer.fetchResult = nil
        return
    end

    local stock = response:match('<td>%s*Stock%s*</td>%s*<td><span[^>]->(%d+)</span>')
    local rate = response:match('Rate</td>%s*<td><span[^>]->([^<]+)</span>')
    local median = response:match('<td>Median</td>%s*<td><span[^>]*>([%d,]+)</span>')

    if sales ~= nil and #sales > 0 then
        auctioneer.fetchResult.sales = sales
        auctioneer.fetchResult.stock = stock
        auctioneer.fetchResult.rate = rate
        auctioneer.fetchResult.salesPerDay = utils.calcSalesRate(os.time(), sales[#sales].saleon, #sales)
        auctioneer.fetchResult.median = median
    end

    local bazaarServerFilter = auctioneer.config.bazaarServerFilter[1]
    local currentServerName = (type(servers[server]) == 'string' and servers[server]:lower()) or nil

    local bazaar, err2 = handleJsonField(response, 'bazaar', id, function (bazaarTable)
        local formatted = {}
        for _, entry in ipairs(bazaarTable) do
            local serverAndPlayerHtml = type(entry[1]) == 'string' and entry[1] or ''
            local price = type(entry[2]) == 'number' and entry[2] or 0
            local quantity = type(entry[3]) == 'number' and entry[3] or 0
            local zone = type(entry[4]) == 'string' and entry[4] or ''
            local timestamp = type(entry[5]) == 'number' and entry[5] or 0

            local srv, player = serverAndPlayerHtml:match("([^.]+)%.<a href='.-/([^/]+)'>")
            local srvLower = srv and srv:lower()

            if srvLower and (not bazaarServerFilter or srvLower == currentServerName) then
                table.insert(formatted, {
                    server   = srv,
                    player   = player or '',
                    price    = price,
                    quantity = quantity,
                    zone     = zone,
                    time     = timestamp
                })
            end
        end
        return formatted
    end)

    if err2 then
        finalizeFetch(false)
        auctioneer.fetchResult = nil
        return
    end

    if #bazaar > 0 then
        auctioneer.fetchResult.bazaar = bazaar
    end

    finalizeFetch(true)
    addWindowFromResult(result)
    auctioneer.fetchResult = nil
end

function ffxiah.fetch(id, stack)
    local stackParam = stack and '1' or '0'
    local url = 'https://www.ffxiah.com/item/' .. tostring(id) .. '?stack=' .. stackParam
    local server = auctioneer.config.server[1]

    auctioneer.ffxiah.fetching = true
    auctioneer.fetchResult = {
        itemId = id,
        stack = stack,
        server = server,
        sales = nil,
        stock = nil,
        rate = nil,
        salesPerDay = nil,
        median = nil,
        bazaar = nil,
        fetching = true
    }

    local headers = {
        ['Cookie'] = 'sid=' .. tostring(server)
    }

    nonBlockingRequests.get(url, headers, function (response, error, statusCode)
        if error then
            print(chat.header(addon.name):append(chat.error('HTTP request failed: ' .. error)))
            finalizeFetch(false)
            auctioneer.fetchResult = nil
            return
        end

        if statusCode and statusCode >= 400 then
            print(chat.header(addon.name):append(chat.error('HTTP request failed with status: ' .. statusCode)))
            finalizeFetch(false)
            auctioneer.fetchResult = nil
            return
        end

        processResponse(response, id, stack, server)
    end)
end

return ffxiah
