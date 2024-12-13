local ui = {}

function ui.updateText()
    local outstr = ""
    for x = 0, 6 do
        if (auctioneer.auction_box[x] ~= nil) then
            local str = ""
            if (auctioneer.settings.auction_list.empty == true or auctioneer.auction_box[x].status ~= "Empty") then
                if (auctioneer.settings.auction_list.slot) == true then
                    str = str .. string.format(" Slot:%s", x + 1)
                end
                str = str .. string.format(" %s", auctioneer.auction_box[x].status)
            end
            if (auctioneer.auction_box[x].status ~= "Empty") then
                local timer =
                    auctioneer.auction_box[x].status == "On auction" and auctioneer.auction_box[x].timestamp + 829440 or
                    auctioneer.auction_box[x].timestamp
                if (auctioneer.settings.auction_list.timer) then
                    str =
                        str ..
                        string.format(
                            " %s",
                            (auctioneer.auction_box[x].status == "On auction" and os.time() - timer > 0) and "Expired" or
                                utils.timef(math.abs(os.time() - timer))
                        )
                end
                if (auctioneer.settings.auction_list.date) then
                    str = str .. string.format(" [%s]", os.date("%c", timer))
                end
                str = str .. string.format(" %s ", auctioneer.auction_box[x].item)
                if (auctioneer.auction_box[x].count ~= 1) then
                    str = str .. string.format("x%d ", auctioneer.auction_box[x].count)
                end
                if (auctioneer.settings.auction_list.price) then
                    str = str .. string.format("[%s] ", utils.commaValue(auctioneer.auction_box[x].price))
                end
            end
            if (str ~= "") then
                outstr = outstr ~= "" and outstr .. "\n" .. str or str
            end
        end
    end
    return outstr
end

function ui.init()
	auction_list = AshitaCore:GetFontManager():Create("auction_list")
	auction_list:SetFontFamily(auctioneer.settings.text.font_family)
	auction_list:SetFontHeight(auctioneer.settings.text.font_height)
	auction_list:SetColor(auctioneer.settings.text.color)
	auction_list:SetPositionX(auctioneer.settings.text.position_x)
	auction_list:SetPositionY(auctioneer.settings.text.position_y)
	auction_list:SetVisible(auctioneer.settings.auction_list.visibility)
	auction_list:GetBackground():SetVisible(true)
	auction_list:GetBackground():SetColor(auctioneer.settings.text.background.color)
end

function ui.update(packet)
    local slot = packet:byte(0x05 + 1)
    local status = packet:byte(0x14 + 1)
    if (auctioneer.auction_box ~= nil and slot ~= 7 and status ~= 0x02 and status ~= 0x04 and status ~= 0x10) then
        if (status == 0x00) then
            auctioneer.auction_box[slot] = {}
            auctioneer.auction_box[slot].status = "Empty"
        else
            if (status == 0x03) then
                auctioneer.auction_box[slot].status = "On auction"
            elseif (status == 0x0A or status == 0x0C or status == 0x15) then
                auctioneer.auction_box[slot].status = "Sold"
            elseif (status == 0x0B or status == 0x0D or status == 0x16) then
                auctioneer.auction_box[slot].status = "Not Sold"
            end
            auctioneer.auction_box[slot].item = utils.getItemName(struct.unpack("h", packet, 0x28 + 1))
            auctioneer.auction_box[slot].count = packet:byte(0x2A + 1)
            auctioneer.auction_box[slot].price = struct.unpack("i", packet, 0x2C + 1)
            auctioneer.auction_box[slot].timestamp = struct.unpack("i", packet, 0x38 + 1)
        end
    end
end

function ui.updateVisibility()
	if (auctioneer.auction_box ~= nil and auctioneer.settings.auction_list.visibility == true) then
		auction_list:SetText(ui.updateText())
		auction_list:SetVisible(true)
	else
		auction_list:SetVisible(false)
	end
end

return ui
