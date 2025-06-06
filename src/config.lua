local config = {}

local default = T {
    confirmationPopup = { true },
    duplicatePopup = { true },
    itemPreview = { true },
    priceHistory = { true },
    auctionHouse = { true },
    server = { 1 }
}

config.load = function()
    return settings.load(default)
end

return config
