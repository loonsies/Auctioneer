search = {}

function search.update()
    auctioneer.search.results = {}
    input = table.concat(auctioneer.search.input)

    for id, item in pairs(items) do
        if auctioneer.search.category == 999 or auctioneer.search.category == item.category then
            if item.longName and string.find(item.longName:lower(), input:lower(), 1, true) or item.shortName and
                string.find(item.shortName:lower(), input:lower(), 1, true) then
                if auctioneer.config.searchFilters[1] then
                    if item.level >= auctioneer.search.lvMinInput[1] and item.level <= auctioneer.search.lvMaxInput[1] then
                        if #auctioneer.search.jobSelected > 0 then
                            local itemJobs = utils.getJobs(item.jobs)
                            local common = utils.findCommonElements(itemJobs, auctioneer.search.jobSelected)
                            if #common > 0 or jobs[1] == 999 then
                                table.insert(auctioneer.search.results, id)
                            end
                        else
                            table.insert(auctioneer.search.results, id)
                        end
                    end
                else
                    table.insert(auctioneer.search.results, id)
                end
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
