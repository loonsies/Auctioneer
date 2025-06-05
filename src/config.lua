local config = {}

local default = T {
    confirmationPopup = { true },
    duplicatePopup = { true },
    server = { 1 }
}

config.load = function()
    return settings.load(default)
end

return config
