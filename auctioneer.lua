addon.name = "Auctioneer"
addon.version = "2.17"
addon.author = "Original addon by Ivaar, ported and modified by looney"
addon.desc = 'Interact with auction house using commands.'
addon.link = 'https://github.com/loonsies/auctioneer'

-- Ashita dependencies
require "common"
settings = require("settings")
chat = require("chat")
imgui = require('imgui')
ffi = require('ffi')
d3d8 = require('d3d8')
http = require("socket.http")
ltn12 = require("socket.ltn12")
json = require("json")

-- Local dependencies
commands = require("src/commands")
config = require("src/config")
ui = require("src/ui")
packets = require("src/packets")
auctionHouse = require("src/auctionHouse")
utils = require("src/utils")
task = require("src/task")
ffxiah = require("src/ffxiah")
search = require("src/search")
itemUtils = require("src/itemUtils")

-- Data
zones = require("data/zones")
itemIds = require("data/itemIds")
itemFlags = require("data/itemFlags")
categories = require("data/categories")
jobs = require("data/jobs")
servers = require("data/servers")
salesRating = require("data/salesRating")
searchStatus = require("data/searchStatus")
taskTypes = require("data/taskTypes")
auctionHouseActions = require("data/auctionHouseActions")

items = itemUtils.load()

auctioneer = {
    config = config.load(),
    visible = { false },
    AuctionHouse = nil,
    auctionHouseInitialized = false,
    priceHistory = {
        sales = nil,
        stock = nil,
        rate = nil,
        salesPerDay = nil,
        median = nil,
        bazaar = nil,
        fetching = false,
    },
    search = {
        input = { "" },
        previousInput = { "" },
        category = 999,
        previousCategory = 999,
        lvMinInput = { 0 },
        previousLvMinInput = { 0 },
        lvMaxInput = { 99 },
        previousLvMaxInput = { 99 },
        jobSelected = {},
        previousJobSelected = {},
        status = searchStatus.noResults,
        selectedItem = nil,
        previousSelectedItem = nil,
        startup = true
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
