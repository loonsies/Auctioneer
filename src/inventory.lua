local ffi = require('ffi')
local utils = require('src/utils')
local containerTypes = require('data/containerTypes')
local tabTypes = require('data/tabTypes')

local inventory = {}
local containers = {
    { id = 0,  hasAccess = false, isGearOnly = false, name = 'inventory' },
    { id = 5,  hasAccess = false, isGearOnly = false, name = 'satchel' },
    { id = 6,  hasAccess = false, isGearOnly = false, name = 'sack' },
    { id = 7,  hasAccess = false, isGearOnly = false, name = 'case' },
    { id = 8,  hasAccess = false, isGearOnly = true,  name = 'wardrobe 1' },
    { id = 10, hasAccess = false, isGearOnly = true,  name = 'wardrobe 2' },
    { id = 11, hasAccess = false, isGearOnly = true,  name = 'wardrobe 3' },
    { id = 12, hasAccess = false, isGearOnly = true,  name = 'wardrobe 4' },
    { id = 13, hasAccess = false, isGearOnly = true,  name = 'wardrobe 5' },
    { id = 14, hasAccess = false, isGearOnly = true,  name = 'wardrobe 6' },
    { id = 15, hasAccess = false, isGearOnly = true,  name = 'wardrobe 7' },
    { id = 16, hasAccess = false, isGearOnly = true,  name = 'wardrobe 8' },
}

local function updateContainer(ctr, res, ctrId)
    local temp = T {}
    local itemCount = ctr:GetContainerCountMax(ctrId)

    for i = 0, itemCount do
        local containerItem = ctr:GetContainerItem(ctrId, i)
        local itemRes = res:GetItemById(containerItem.Id)

        if itemRes ~= nil and containerItem.Id ~= 65535 then
            local item = {
                id = containerItem.Id,
                sortId = itemRes.ResourceId,
                stack = nil,
                stackCur = containerItem.Count,
                stackMax = itemRes.StackSize,
                index = containerItem.Index
            }

            if item.stackMax > 1 then
                item.stack = ('%i/%i'):format(item.stackCur, item.stackMax)
            else
                item.stack = '1/1'
            end

            temp:append(item)
        end
    end

    return temp
end

local function hasBagAccess(index)
    local contentPtr = ashita.memory.find('FFXiMain.dll', 0, 'A1????????8B88B4000000C1E907F6C101E9', 0, 0)

    local inv = AshitaCore:GetMemoryManager():GetInventory()
    if contentPtr == 0 or inv == nil then
        return false
    end

    local ptr = ashita.memory.read_uint32(contentPtr + 1)
    if ptr == 0 then
        return false
    end

    local flagsPtr = ashita.memory.read_uint32(ptr)
    if flagsPtr == 0 then
        return false
    end

    local val = ashita.memory.read_uint8(flagsPtr + 0xB4)

    return switch(index, {
        -- Inventory
        [0] = function ()
            return true
        end,
        -- Wardrobe 3
        [11] = function ()
            return bit.band(bit.rshift(val, 0x02), 0x01) ~= 0
        end,
        -- Wardrobe 4
        [12] = function ()
            return bit.band(bit.rshift(val, 0x03), 0x01) ~= 0
        end,
        -- Wardrobe 5
        [13] = function ()
            return bit.band(bit.rshift(val, 0x04), 0x01) ~= 0
        end,
        -- Wardrobe 6
        [14] = function ()
            return bit.band(bit.rshift(val, 0x05), 0x01) ~= 0
        end,
        -- Wardrobe 7
        [15] = function ()
            return bit.band(bit.rshift(val, 0x06), 0x01) ~= 0
        end,
        -- Wardrobe 8
        [16] = function ()
            return bit.band(bit.rshift(val, 0x07), 0x01) ~= 0
        end,
        [switch.default] = function ()
            -- Safe to Wardrobe 2..
            if (index >= 1 and index <= 10) then
                return inv:GetContainerCountMax(index) > 0
            end

            -- Consider rest invalid..
            return false
        end,
    })
end

local function sortContainer(lhs, rhs)
    if lhs.sortId == rhs.sortId then
        if lhs.id == rhs.id then
            return lhs.stackCur > rhs.stackCur
        end

        return lhs.id < rhs.id
    end

    return lhs.sortId < rhs.sortId
end

function inventory.update()
    if not GetPlayerEntity() then
        return
    end

    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local res = AshitaCore:GetResourceManager()
    local gil = inv:GetContainerItem(0, 0)
    local invSize = inv:GetContainerCountMax(0)
    if gil == nil or invSize == 0 then return end

    for _, ctr in ipairs(containers) do
        if ctr.id > 10 then
            ctr.hasAccess = hasBagAccess(ctr.id)
        else
            ctr.hasAccess = inv:GetContainerCountMax(ctr.id) > 0
        end
    end

    auctioneer.containers.inventory.inv = updateContainer(inv, res, containerTypes.inventory):sort(sortContainer)
    auctioneer.containers.inventory.temp = updateContainer(inv, res, containerTypes.tempItems):sort(sortContainer)
    auctioneer.containers.mog.satchel = updateContainer(inv, res, containerTypes.mogSatchel):sort(sortContainer)
    auctioneer.containers.mog.case = updateContainer(inv, res, containerTypes.mogCase):sort(sortContainer)
    auctioneer.containers.mog.sack = updateContainer(inv, res, containerTypes.mogSack):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe1 = updateContainer(inv, res, containerTypes.wardrobe):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe2 = updateContainer(inv, res, containerTypes.wardrobe2):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe3 = updateContainer(inv, res, containerTypes.wardrobe3):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe4 = updateContainer(inv, res, containerTypes.wardrobe4):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe5 = updateContainer(inv, res, containerTypes.wardrobe5):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe6 = updateContainer(inv, res, containerTypes.wardrobe6):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe7 = updateContainer(inv, res, containerTypes.wardrobe7):sort(sortContainer)
    auctioneer.containers.wardrobes.wardrobe8 = updateContainer(inv, res, containerTypes.wardrobe8):sort(sortContainer)
    auctioneer.containers.house.mogSafe1 = updateContainer(inv, res, containerTypes.mogSafe):sort(sortContainer)
    auctioneer.containers.house.mogSafe2 = updateContainer(inv, res, containerTypes.mogSafe2):sort(sortContainer)
    auctioneer.containers.house.storage = updateContainer(inv, res, containerTypes.storage):sort(sortContainer)
    auctioneer.containers.house.locker = updateContainer(inv, res, containerTypes.mogLocker):sort(sortContainer)

    auctioneer.containers.inventory.all = T {}
        :extend(auctioneer.containers.inventory.inv)
        :extend(auctioneer.containers.inventory.temp)
        :sort(sortContainer)

    auctioneer.containers.mog.all = T {}
        :extend(auctioneer.containers.mog.satchel)
        :extend(auctioneer.containers.mog.case)
        :extend(auctioneer.containers.mog.sack)
        :sort(sortContainer)

    auctioneer.containers.wardrobes.all = T {}
        :extend(auctioneer.containers.wardrobes.wardrobe1)
        :extend(auctioneer.containers.wardrobes.wardrobe2)
        :extend(auctioneer.containers.wardrobes.wardrobe3)
        :extend(auctioneer.containers.wardrobes.wardrobe4)
        :extend(auctioneer.containers.wardrobes.wardrobe5)
        :extend(auctioneer.containers.wardrobes.wardrobe6)
        :extend(auctioneer.containers.wardrobes.wardrobe7)
        :extend(auctioneer.containers.wardrobes.wardrobe8)
        :sort(sortContainer)

    auctioneer.containers.house.all = T {}
        :extend(auctioneer.containers.house.mogSafe1)
        :extend(auctioneer.containers.house.mogSafe2)
        :extend(auctioneer.containers.house.storage)
        :extend(auctioneer.containers.house.locker)
        :sort(sortContainer)
end

function inventory.new()
    return {
        inventory = T {
            all  = T {},
            inv  = T {},
            temp = T {},
        },
        mog = T {
            all = T {},
            satchel = T {},
            case = T {},
            sack = T {},
        },
        wardrobes = T {
            all = T {},
            wardrobe1 = T {},
            wardrobe2 = T {},
            wardrobe3 = T {},
            wardrobe4 = T {},
            wardrobe5 = T {},
            wardrobe6 = T {},
            wardrobe7 = T {},
            wardrobe8 = T {},
        },
        house = T {
            all = T {},
            mogSafe1 = T {},
            mogSafe2 = T {},
            storage = T {},
            mogLocker = T {},
        }
    }
end

function inventory.getItemSet(tabType)
    local itemSet = {}

    if tabType == tabTypes.allItems then
        itemSet = items
    elseif tabType == tabTypes.inventory then
        itemSet = auctioneer.containers.inventory.all
    elseif tabType == tabTypes.mog then
        itemSet = auctioneer.containers.mog.all
    elseif tabType == tabTypes.wardrobes then
        itemSet = auctioneer.containers.wardrobes.all
    elseif tabType == tabTypes.house then
        itemSet = auctioneer.containers.house.all
    elseif tabType == tabTypes.mogGarden then
        itemSet = auctioneer.mogGarden.newItems
    end

    return itemSet
end

return inventory
