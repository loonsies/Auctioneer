addon.name = "Auctioneer"
addon.version = "1.18"
addon.author = "Original addon by Ivaar, ported and modified by melones"
addon.desc = 'Interact with auction house using commands.';
addon.link = 'https://github.com/senolem/auctioneer';

-- Ashita dependencies
require "common"
settings = require("settings")
chat = require("chat")
imgui = require('imgui');
ffi = require('ffi')
d3d8 = require('d3d8')

-- Local dependencies
commands = require("src/commands")
config = require("src/config")
ui = require("src/ui")
packets = require("src/packets")
auctionHouse = require("src/auctionHouse")
utils = require("src/utils")
task = require("src/task")
zones = require("data/zones")
itemIds = require("data/itemIds")
itemFlags = require("data/itemFlags")
categories = require("data/categories")
jobs = require("data/jobs")
resourceManager = AshitaCore:GetResourceManager()
packetManager = AshitaCore:GetPacketManager()
items = {}

for _, pair in ipairs(itemIds) do
    local id = pair[1]
    local category = pair[2]
    local item = resourceManager:GetItemById(id)

    if item then
        if not items[id] then
            items[id] = {}
        end

        items[id].shortName = item.Name[1] or ""
        items[id].longName = item.LogNameSingular[1] or ""
        items[id].description = item.Description[1] or ""
        items[id].category = category
        items[id].level = item.Level
        items[id].jobs = item.Jobs
        items[id].bitmap = item.Bitmap
        items[id].imageSize = item.ImageSize
    end
end

auctioneer = {
    config = config.load(),
    AuctionHouse = nil,
    auctionHouseInitialized = false
}

ashita.events.register("unload", "unload_cb", function()
    settings.save()
end)

ashita.events.register("d3d_present", "d3d_present_cb", function()
    ui.update()
end)

ashita.events.register("command", "command_cb", function(cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register("packet_in", "packet_in_cb", function(e)
    return packets.handleIncomingPacket(e)
end)
