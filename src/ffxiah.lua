local chat = require('chat')
local json = require('json')
local http = require('socket.http')
local ltn12 = require('socket.ltn12')
local utils = require('src/utils')

local ffxiah = {}

local function getBaseUrl(url)
    return url:match('^(https?://[^/]+)')
end

local function fetchUrl(url, server)
    local maxRedirects = 5
    local redirects = 0

    while redirects < maxRedirects do
        local response_body = {}
        local _, statusCode, headers = http.request {
            url = url,
            headers = {
                ['Cookie'] = 'sid=' .. tostring(server)
            },
            sink = ltn12.sink.table(response_body)
        }

        local body = table.concat(response_body)

        if not body then
            print(chat.header(addon.name):append(chat.error('HTTP request failed')))
            return nil, statusCode, headers
        end

        if statusCode >= 300 and statusCode < 400 then
            local location = headers.location
            if type(location) ~= 'string' then
                print(chat.header(addon.name):append(chat.error('Redirect status but no Location header')))
                return nil, statusCode, headers
            end

            if not location:match('^https?://') then
                local base = getBaseUrl(url)
                location = base .. location
            end

            url = location
            redirects = redirects + 1
        else
            return body, statusCode, headers
        end
    end

    print(chat.header(addon.name):append(chat.error('Too many redirections')))
    return nil, nil, nil
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

function ffxiah.fetch(id, stack)
    local stackParam = stack and '1' or '0'
    local url = 'https://www.ffxiah.com/item/' .. tostring(id) .. '?stack=' .. stackParam
    local server = auctioneer.config.server[1]

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
        fetching = false
    }

    local response = fetchUrl(url, server)
    if not response then
        return
    end
    local ciphers = {}

    if response then
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

        local bazaar, err2 = handleJsonField(response, 'bazaar', id, function (bazaarTable)
            local formatted = {}
            for _, entry in ipairs(bazaarTable) do
                local serverAndPlayerHtml = type(entry[1]) == 'string' and entry[1] or ''
                local price = type(entry[2]) == 'number' and entry[2] or 0
                local quantity = type(entry[3]) == 'number' and entry[3] or 0
                local zone = type(entry[4]) == 'string' and entry[4] or ''
                local timestamp = type(entry[5]) == 'number' and entry[5] or 0

                local srv, player = serverAndPlayerHtml:match("([^.]+)%.<a href='.-/([^/]+)'>")
                table.insert(formatted, {
                    server = srv or '',
                    player = player or '',
                    price = price or 0,
                    quantity = quantity or 0,
                    zone = zone or '',
                    time = timestamp or 0
                })
            end
            return formatted
        end)

        if err2 then
            return
        end

        if #bazaar > 0 then
            auctioneer.fetchResult.bazaar = bazaar
        end
    end
end

return ffxiah
