local chat = require('chat')
local utils = require('src/utils')
local taskTypes = require('data/taskTypes')

local task = {}

local queue = {}
local throttleTimer = 0
local throttleInterval = 8
local isExecutingTask = false

local function handleEntry(entry)
    local auctionHouse = require('src/auctionHouse')
    local interval = entry.interval or throttleInterval

    isExecutingTask = true

    if entry.type == taskTypes.buy then
        if auctionHouse.buy(entry.item, entry.single, entry.price) then
            throttleTimer = os.clock() + interval
        end
    elseif entry.type == taskTypes.sell then
        if auctionHouse.sell(entry.item, entry.single, entry.price) then
            throttleTimer = os.clock() + interval
        end
    elseif entry.type == taskTypes.confirmSell then
        if auctionHouse.sendConfirmSell(entry.packet, entry.id, entry.name, entry.single) then
            throttleTimer = os.clock() + interval
        end
    elseif entry.type == taskTypes.clearSlot then
        if auctionHouse.clearSlot(entry.slot) then
            throttleTimer = os.clock() + interval
        end
    elseif entry.type == taskTypes.salesStatus then
        if auctionHouse.sendSalesStatus(entry.attempts) then
            throttleTimer = os.clock() + interval
        end
    else
        print(chat.header(addon.name):append(chat.error('Invalid task type')))
    end

    isExecutingTask = false
end

local function handleQueue()
    while #queue > 0 and os.clock() > throttleTimer do
        local entry = queue[1]
        local interval = entry.interval or throttleInterval

        handleEntry(entry)
        table.remove(queue, 1)

        if auctioneer.eta then
            auctioneer.eta = math.max(0, auctioneer.eta - interval)
        end
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
    local interval = entry.interval or throttleInterval
    local silent = entry.silent or false

    entry.interval = interval

    throttleTimer = os.clock() + interval
    auctioneer.eta = (auctioneer.eta or 0) + interval
    table.insert(queue, 1, entry)
    if not silent then
        print(chat.header(addon.name):append(chat.warning(string.format('%s task %s, will run after %.2f seconds', taskTypes[entry.type], action, interval))))
    end
end

function task.enqueue(entry)
    local queueSize = #queue
    local silent = entry.silent or false

    if queueSize == 0 and os.clock() > throttleTimer and not isExecutingTask then
        handleEntry(entry)
    else
        local interval = entry.interval or throttleInterval

        entry.interval = interval

        auctioneer.eta = (auctioneer.eta or 0) + interval
        queue[queueSize + 1] = entry

        local totalQueueTime = 0
        for i = 1, queueSize do
            totalQueueTime = totalQueueTime + (queue[i].interval or throttleInterval)
        end

        local throttleRemaining = math.max(0, throttleTimer - os.clock())
        local delay = throttleRemaining + totalQueueTime + interval

        if not silent then
            print(chat.header(addon.name):append(chat.warning(string.format('%s task throttled, will run in %.2f seconds (queue position %d)', taskTypes[entry.type], delay, queueSize + 1))))
        end
    end
end

function task.filter(entry)
    local doReset = false

    for i = #queue, 1, -1 do
        local queueEntry = queue[i]
        if entry.type == queueEntry.type and entry.index == queueEntry.item.Id and entry.single == queueEntry.single and entry.price == queueEntry.price then
            doReset = true
            table.remove(queue, i)
            print(chat.header(addon.name):append(chat.warning(string.format('Task removed: %s "%s" %s %s ID:%s', taskTypes[entry.type], queueEntry.item.Name[1], utils.commaValue(queueEntry.price), queueEntry.single == '1' and '[Single]' or '[Stack]', queueEntry.item.Id))))
        end
    end

    local queueSize = #queue
    if doReset and queueSize > 0 then
        local interval = entry.interval or throttleInterval

        throttleTimer = os.clock() + interval

        local totalQueueTime = 0
        for i = 1, queueSize do
            totalQueueTime = totalQueueTime + (queue[i].interval or throttleInterval)
        end
        auctioneer.eta = totalQueueTime

        local throttleRemaining = math.max(0, throttleTimer - os.clock())
        local delay = throttleRemaining + totalQueueTime

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
