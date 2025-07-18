addon.name = 'Auctioneer'
addon.version = "2.22"
addon.author = 'Original addon by Ivaar, ported and modified by looney'
addon.desc = 'Interact with auction house using commands.'
addon.link = 'https://github.com/loonsies/auctioneer'

-- Ashita dependencies
require 'common'
local settings = require('settings')

-- Local dependencies
local commands = require('src/commands')
local config = require('src/config')
local ui = require('src/ui')
local packets = require('src/packets')
local itemUtils = require('src/itemUtils')
local inventory = require('src/inventory')
local search = require('src/search')

-- Data
local tabData = require('data/tabData')
local tabTypes = require('data/tabTypes')

items = itemUtils.load()

auctioneer = {
    config = {},
    visible = { false },
    auctionHouse = nil,
    auctionHouseInitialized = false,
    ffxiah = {
        fetching = false,
        windows = {}
    },
    tabs = {
        [1] = tabData.new(),
        [2] = tabData.new(),
        [3] = tabData.new(),
        [4] = tabData.new(),
        [5] = tabData.new()
    },
    currentTab = tabTypes.allItems,
    eta = 0,
    lastUpdateTime = os.clock(),
    fetchResult = nil,
    zoning = false,
    containers = inventory.new()
}

ashita.events.register('load', 'load_cb', function ()
    auctioneer.config = config.load()
    inventory.update()
    search.update(auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])

    settings.register('settings', 'settings_update_cb', function (newConfig)
        auctioneer.config = newConfig
        inventory.update()
        search.update(auctioneer.currentTab, auctioneer.tabs[auctioneer.currentTab])
    end)
end)

ashita.events.register('unload', 'unload_cb', function ()
    settings.save()
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    ui.update()
    ui.updateETA()
end)

ashita.events.register('command', 'command_cb', function (cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    return packets.handleIncomingPacket(e)
end)
