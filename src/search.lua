local utils = require('src/utils')
local inventory = require('src/inventory')
local jobs = require('data/jobs')
local searchStatus = require('data/searchStatus')
local tabTypes = require('data/tabTypes')

local search = {}

function search.update(tabType, tab)
    local input = table.concat(tab.input)
    local itemSet = inventory.getItemSet(tabType)
    tab.results = {}

    for id, item in pairs(itemSet) do
        local itemId = id
        local itemStack = '0/0'
        if tabType ~= tabTypes.allItems then
            itemId = item.id
            itemStack = item.stack
        end

        local itemData = items[itemId]

        if (itemData.isBazaarable or itemData.isAuctionable or tab.showAllItems[1]) then
            if tab.category == 999 or tab.category == itemData.category then
                if itemData.longName and string.find(itemData.longName:lower(), input:lower(), 1, true) or itemData.shortName and
                    string.find(itemData.shortName:lower(), input:lower(), 1, true) then
                    if auctioneer.config.searchFilters[1] then
                        if itemData.level >= tab.lvMinInput[1] and itemData.level <= tab.lvMaxInput[1] then
                            if #tab.jobSelected > 0 then
                                local itemJobs = utils.getJobs(itemData.jobs)
                                local common = utils.findCommonElements(itemJobs, tab.jobSelected)
                                if #common > 0 or jobs[1] == 999 then
                                    table.insert(tab.results, { id = itemId, stack = itemStack })
                                end
                            else
                                table.insert(tab.results, { id = itemId, stack = itemStack })
                            end
                        end
                    else
                        table.insert(tab.results, { id = itemId, stack = itemStack })
                    end
                end
            end
        end
    end

    if #tab.results == 0 then
        tab.status = searchStatus.noResults
    else
        tab.status = searchStatus.found
    end
end

return search
