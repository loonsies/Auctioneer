ffxiah = {}

local function getBaseUrl(url)
    return url:match("^(https?://[^/]+)")
end

local function fetchUrlAsync(url, callback, maxRedirects)
    coroutine.wrap(function()
        maxRedirects = maxRedirects or 5
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
                return
            end

            if statusCode >= 300 and statusCode < 400 then
                local location = headers.location
                if type(location) ~= "string" then
                    print(chat.header(addon.name):append(chat.error("Redirect status but no Location header")))
                    return
                end

                if not location:match("^https?://") then
                    local base = getBaseUrl(url)
                    location = base .. location
                end

                url = location
                redirects = redirects + 1
            else
                callback(body, statusCode, headers)
                return
            end
        end

        print(chat.header(addon.name):append(chat.error("Too many redirections")))
    end)()
end

function ffxiah.fetchSales(id)
    local url = "https://www.ffxiah.com/item/" .. tostring(id)

    fetchUrlAsync(url, function(body, status, headers)
        local salesJson = body:match("Item%.sales%s*=%s*(%[.-%])%s*;")
        if not salesJson then
            auctioneer.priceHistory.fetching = false
            print(chat.header(addon.name):append(chat.error("Failed to extract Item.sales array")))
            return
        end

        local ok, salesTable = pcall(json.decode, salesJson)
        if not ok then
            auctioneer.priceHistory.fetching = false
            print(chat.header(addon.name):append(chat.error("Failed to decode JSON")))
            return
        end

        local formattedSales = {}
        for _, sale in ipairs(salesTable) do
            table.insert(formattedSales, {
                date = os.date("%Y-%m-%d %H:%M:%S", sale.saleon),
                seller = sale.seller_name or "",
                buyer = sale.buyer_name or "",
                price = sale.price or 0,
            })
        end

        auctioneer.priceHistory.sales = formattedSales
    end)
end

return ffxiah
