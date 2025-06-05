local config = {}

local default = T {
    confirmationPopup = { true },
    duplicatePopup = { true }
}

config.load = function()
    return settings.load(default)
end

return config
