local config = {}

local default = T {
    ui = T {
        visible = { true },
    }
}

config.load = function()
    return settings.load(default)
end

return config
