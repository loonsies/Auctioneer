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
    separateFFXIAH = { true }
}

config.load = function ()
    return settings.load(default)
end

return config
