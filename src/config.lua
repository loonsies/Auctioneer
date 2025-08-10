local settings = require('settings')

local config = {}

local default = T {
    confirmationPopup = { true },
    duplicatePopup = { true },
    itemPreview = { true },
    ffxiah = { true },
    auctionHouse = { true },
    removeFailedBuyTasks = { true },
    searchFilters = { true },
    server = { 1 },
    separateFFXIAH = { true },
    bellhopCommands = { true },
    dropButton = { false },
    tabs = {
        [1] = {
            showAllItems = { false }
        },
        [2] = {
            showAllItems = { false }
        },
        [3] = {
            showAllItems = { false }
        },
        [4] = {
            showAllItems = { false }
        },
        [5] = {
            showAllItems = { false }
        }
    }
}

config.load = function ()
    return settings.load(default)
end

return config
