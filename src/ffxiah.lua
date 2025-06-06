ffxiah = {}

local function getBaseUrl(url)
    return url:match("^(https?://[^/]+)")
end

local function fetchUrl(url)
    local maxRedirects = 5
    local redirects = 0

    while redirects < maxRedirects do
        local response_body = {}
        local _, statusCode, headers = http.request {
            url = url,
            headers = {
                ["Cookie"] = "sid=" .. tostring(auctioneer.config.server[1])
            },
            sink = ltn12.sink.table(response_body)
        }

        local body = table.concat(response_body)

        if not body then
            print(chat.header(addon.name):append(chat.error("HTTP request failed")))
            return nil, statusCode, headers
        end

        if statusCode >= 300 and statusCode < 400 then
            local location = headers.location
            if type(location) ~= "string" then
                print(chat.header(addon.name):append(chat.error("Redirect status but no Location header")))
                return nil, statusCode, headers
            end

            if not location:match("^https?://") then
                local base = getBaseUrl(url)
                location = base .. location
            end

            url = location
            redirects = redirects + 1
        else
            return body, statusCode, headers
        end
    end

    print(chat.header(addon.name):append(chat.error("Too many redirections")))
    return nil, nil, nil
end

local function handleJsonField(body, fieldName, id, processFn)
    local jsonStr = body:match("Item%." .. fieldName .. "%s*=%s*(null)%s*;")
        or body:match("Item%." .. fieldName .. "%s*=%s*(%[.-%])%s*;")
    if not jsonStr then
        print(chat.header(addon.name):append(chat.error("Failed to extract Item." .. fieldName .. " array")))
        return nil, true
    end

    local ok, tbl = pcall(json.decode, jsonStr)
    if not ok then
        print(chat.header(addon.name):append(chat.error("Failed to decode " .. fieldName .. " JSON")))
        return nil, true
    end

    if tbl == nil or type(tbl) ~= "table" or #tbl == 0 then
        print(chat.header(addon.name):append(chat.message(string.format("No %s data for item [%i]", fieldName, id))))
        return {}, false
    end

    return processFn(tbl), false
end

function ffxiah.fetchSales(id)
    local url = "https://www.ffxiah.com/item/" .. tostring(id)

    local body, statusCode, headers = fetchUrl(url)
    if not body then
        auctioneer.priceHistory.fetching = false
        return
    end

    local sales, err = handleJsonField(body, "sales", id, function(salesTable)
        local formatted = {}
        for _, sale in ipairs(salesTable) do
            table.insert(formatted, {
                date = os.date("%Y-%m-%d %H:%M:%S", sale.saleon),
                seller = sale.seller_name or "",
                buyer = sale.buyer_name or "",
                price = sale.price or 0,
            })
        end
        return formatted
    end)
    if err then
        auctioneer.priceHistory.fetching = false
        return
    end

    if #sales > 0 then
        auctioneer.priceHistory.sales = sales
    end

    local bazaar, err2 = handleJsonField(body, "bazaar", id, function(bazaarTable)
        local formatted = {}
        for _, entry in ipairs(bazaarTable) do
            local serverAndPlayerHtml = entry[1]
            local price = entry[2]
            local quantity = entry[3]
            local zone = entry[4]
            local timestamp = entry[5]

            local server, player = serverAndPlayerHtml:match("([^.]+)%.<a href='.-/([^/]+)'>")
            table.insert(formatted, {
                server = server or "",
                player = player or "",
                price = price or 0,
                quantity = quantity or 0,
                zone = zone or "",
                time = timestamp or 0
            })
        end
        return formatted
    end)
    if err2 then
        return
    end

    if #bazaar > 0 then
        auctioneer.priceHistory.bazaar = bazaar
    end

    if auctioneer.priceHistory.sales == nil and auctioneer.priceHistory.bazaar == nil then
        auctioneer.priceHistory.fetching = false
    end
end

return ffxiah
