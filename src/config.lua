local config = {}

local default = T {
    text = T {
        visible = true,
        font_family = "Arial",
        font_height = 10,
        color = 0xFFFFFFFF,
        position_x = 0,
        position_y = 0,
        background = T {
            visible = true,
            color = 0x1A000000
        }
    },
    auction_list = T {
        visibility = true,
        timer = true,
        date = true,
        price = true,
        empty = true,
        slot = true
    }
}

config.load = function()
    return settings.load(default)
end

return config
