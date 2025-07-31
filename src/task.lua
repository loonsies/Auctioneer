local chat = require('chat')
local utils = require('src/utils')
local taskTypes = require('data/taskTypes')

local task = {}

local queue = {}
local throttleTimer = 0
local throttleInterval = 8
local throttleSalesStatusInterval = 2

local function handleEntry(entry)
    local auctionHouse = require('src/auctionHouse')

    if entry.type == taskTypes.buy then
        if auctionHouse.buy(entry.item, entry.single, entry.price) then
            throttleTimer = os.clock() + throttleInterval
        end
    elseif entry.type == taskTypes.sell then
        if auctionHouse.sell(entry.item, entry.single, entry.price) then
            throttleTimer = os.clock() + throttleInterval
        end
    elseif entry.type == taskTypes.confirmSell then
        if auctionHouse.sendConfirmSell(entry.packet, entry.id, entry.name, entry.single) then
            throttleTimer = os.clock() + throttleInterval
        end
    elseif entry.type == taskTypes.clearSlot then
        if auctionHouse.clearSlot(entry.slot) then
            throttleTimer = os.clock() + throttleInterval
        end
    elseif entry.type == taskTypes.salesStatus then
        if auctionHouse.sendSalesStatus(entry.attempts) then
            throttleTimer = os.clock() + throttleSalesStatusInterval
        end
    else
        print(chat.header(addon.name):append(chat.error('Invalid task type')))
    end
end

local function handleQueue()
    while #queue > 0 and os.clock() > throttleTimer do
        handleEntry(queue[1])
        table.remove(queue, 1)
    end
end

function task.clear()
    if #queue > 0 then
        print(chat.header(addon.name):append(chat.warning(string.format('Removed %i tasks from queue', #queue))))
    end

    queue = {}
    throttleTimer = 0
end

function task.preempt(entry)
    local action = #queue > 0 and 'prioritized' or 'throttled'
    throttleTimer = os.clock() + throttleInterval
    auctioneer.eta = (auctioneer.eta or 0) + throttleInterval
    table.insert(queue, 1, entry)
    print(chat.header(addon.name):append(chat.warning(
        string.format('%s task %s, will run after %.2f seconds',
            taskTypes[entry.type], action, throttleInterval)
    )))
end

function task.enqueue(entry)
    local queueSize = #queue
    if queueSize == 0 and os.clock() > throttleTimer then
        handleEntry(entry)
    else
        auctioneer.eta = (auctioneer.eta or 0) + throttleInterval
        queue[queueSize + 1] = entry
        local delay = (throttleInterval * queueSize) + (throttleTimer - os.clock())
        print(chat.header(addon.name):append(chat.warning(
            string.format('%s task throttled, will run in %.2f seconds (queue position %d)', taskTypes[entry.type],
                delay,
                queueSize + 1)
        )))
    end
end

function task.filter(entry)
    local doReset = false

    for i = #queue, 1, -1 do
        local queueEntry = queue[i]
        if entry.type == queueEntry.type and entry.index == queueEntry.item.Id and entry.single == queueEntry.single and entry.price == queueEntry.price then
            doReset = true
            table.remove(queue, i)
            print(chat.header(addon.name):append(chat.warning(string.format('Task removed: %s "%s" %s %s ID:%s',
                taskTypes[entry.type], queueEntry.item.Name[1], utils.commaValue(queueEntry.price),
                queueEntry.single == '1' and '[Single]' or '[Stack]', queueEntry.item.Id))))
        end
    end

    local queueSize = #queue
    if doReset and queueSize > 0 then
        throttleTimer = os.clock() + throttleInterval
        auctioneer.eta = throttleInterval * queueSize
        local delay = (throttleInterval * queueSize) + (throttleTimer - os.clock())
        print(chat.header(addon.name):append(chat.warning(string.format('Queue timer set to %.2f seconds', delay))))
    end
end

function task.getQueueSize()
    return queue and #queue or 0
end

ashita.events.register('packet_out', 'packet_out_cb', function (e)
    if (e.id == 0x15) then
        handleQueue()
    end
end)

return task
