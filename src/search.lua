search = {}

function search.update()
    auctioneer.search.results = {}
    input = table.concat(auctioneer.search.input)

    for id, item in pairs(items) do
        if auctioneer.search.category == 999 or auctioneer.search.category == item.category then
            if item.longName and string.find(item.longName:lower(), input:lower()) or item.shortName and string.find(item.shortName:lower(), input:lower()) then
                table.insert(auctioneer.search.results, id)
            end
        end
    end
    if #auctioneer.search.results == 0 then
        auctioneer.search.status = searchStatus.noResults
    else
        auctioneer.search.status = searchStatus.found
    end
end

return search
