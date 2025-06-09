task = {}
local queue = {}
local throttle_timer = 0
local throttle_interval = 8

task.type = {
    buy = 1,
    sell = 2,
    confirmSell = 3,
    clearSlot = 4,
    [1] = "Buy",
    [2] = "Sell",
    [3] = "Confirm sell",
    [4] = "Clear slot"
}

local function handleEntry(entry)
    --Could do validation on whether player has stepped away from AH or zoned here if desired, or check other things like that

    if entry.type == task.type.buy then
        if auctionHouse.buy(entry.item, entry.single, entry.price) then
            throttle_timer = os.clock() + throttle_interval
        end
    elseif entry.type == task.type.sell then
        if auctionHouse.sell(entry.item, entry.single, entry.price) then
            throttle_timer = os.clock() + throttle_interval
        end
    elseif entry.type == task.type.confirmSell then
        if auctionHouse.sendConfirmSell(entry.packet, entry.id, entry.name, entry.single) then
            throttle_timer = os.clock() + throttle_interval
        end
    elseif entry.type == task.type.clearSlot then
        if auctionHouse.clearSlot(entry.slot) then
            throttle_timer = os.clock() + throttle_interval
        end
    else
        print(chat.header(addon.name):append(chat.error("Invalid task type")))
    end
end

local function handleQueue()
    while #queue > 0 and os.clock() > throttle_timer do
        handleEntry(queue[1])
        table.remove(queue, 1)
    end
end

function task.clear()
    queue = {}
end

function task.preempt(entry)
    local action = "prioritized" and #queue > 0 or "throttled"
    throttle_timer = os.clock() + throttle_interval
    table.insert(queue, 1, entry)
    print(chat.header(addon.name):append(chat.warning(
        string.format('%s task %s, will run after %.2f seconds.',
            task.type[entry.type], action, throttle_interval)
    )))
end

function task.enqueue(entry)
    local queueCount = #queue
    if queueCount == 0 and os.clock() > throttle_timer then
        handleEntry(entry)
    else
        queue[queueCount + 1] = entry
        local delay = (throttle_interval * queueCount) + (throttle_timer - os.clock())
        print(chat.header(addon.name):append(chat.warning(
            string.format('%s task throttled, will run in %.2f seconds (queue position %d).', task.type[entry.type],
                delay,
                queueCount + 1)
        )))
    end
end

ashita.events.register("packet_out", "packet_out_cb", function(e)
    if (e.id == 0x15) then
        handleQueue();
    end
end)

return task
