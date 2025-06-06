addon.name = "Auctioneer"
addon.version = "2.10"
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
http = require("socket.http")
ltn12 = require("socket.ltn12")
json = require("json")
resourceManager = AshitaCore:GetResourceManager()
packetManager = AshitaCore:GetPacketManager()
memoryManager = AshitaCore:GetMemoryManager()

-- Local dependencies
commands = require("src/commands")
config = require("src/config")
ui = require("src/ui")
packets = require("src/packets")
auctionHouse = require("src/auctionHouse")
utils = require("src/utils")
task = require("src/task")
ffxiah = require("src/ffxiah")
zones = require("data/zones")
itemIds = require("data/itemIds")
itemFlags = require("data/itemFlags")
categories = require("data/categories")
jobs = require("data/jobs")
servers = require("data/servers")
items = {}

local categoryLookup = {}
for _, pair in ipairs(itemIds) do
    categoryLookup[pair[1]] = pair[2]
end

for id = 1, 25601 do
    local category = categoryLookup[id] or 0
    local item = resourceManager:GetItemById(id)

    if item and item.Name[1] ~= "." then -- Get rid of all the empty items
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
    visible = { false },
    AuctionHouse = nil,
    auctionHouseInitialized = false,
    priceHistory = {
        sales = nil,
        bazaar = nil,
        fetching = false,
    }
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
