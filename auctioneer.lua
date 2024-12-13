addon.name		= "Auctioneer"
addon.version	= "1.18"
addon.author	= "Ivaar, converted by melones"
addon.desc		= 'Interact with auction house using commands.';
addon.link		= 'https://github.com/senolem/auctioneer';

-- Ashita dependencies
require "common"
settings = require("settings")
chat = require("chat")
imgui = require('imgui');

-- Local dependencies
commands = require("src/commands")
config = require("src/config")
ui = require("src/ui")
packets = require("src/packets")
auctionHouse = require("src/auctionHouse")
utils = require("src/utils")
zones = require("data/zones")
itemFlags = require("data/itemFlags")

auctioneer = {
	settings = config.load(),
	auction_box = nil
}

ashita.events.register(
	"unload",
	"unload_cb",
	function()
		AshitaCore:GetFontManager():Delete("auction_list")
		settings.save()
	end
)

ashita.events.register(
	"load",
	"load_cb",
	function()
		ui.init()
	end
)

ashita.events.register(
	"d3d_present",
	"d3d_present_cb",
	function()
		ui.updateVisibility()
		--ui.drawUI()
	end
)

ashita.events.register(
	"command",
	"command_cb",
	function(cmd, nType)
		local args = cmd.command:args()
		if (#args ~= 0) then
			commands.handleCommand(args)
		end
	end
)

ashita.events.register(
	"packet_in",
	"packet_in_cb",
	function(e)
		return packets.handleIncomingPacket(e)
	end
)