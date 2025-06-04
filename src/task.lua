task = {}

local last_run_time = 0
local task_queue = {}
local throttle_interval = 8

function task.packet(packet)
    packetManager:AddOutgoingPacket(0x4E, packet)
end

function task.throttle(task_name, task_func, task_arg)
    local current_time = os.clock()
    local elapsed = current_time - last_run_time

    if elapsed >= throttle_interval then
        last_run_time = current_time
        task_func(task_arg)
        task.processQueue()
    else
        local wait_time = throttle_interval - elapsed
        local position_in_queue = #task_queue + 1
        local estimated_delay = wait_time + ((position_in_queue - 1) * throttle_interval)

        print(chat.header(addon.name):append(chat.warning(
            string.format('%s task throttled, will run in %.2f seconds (queue position %d).', task_name, estimated_delay, position_in_queue)
        )))

        table.insert(task_queue, { name = task_name, func = task_func, arg = task_arg })
    end
end

function task.processQueue()
    if #task_queue == 0 then return end

    local current_time = os.clock()
    local elapsed = current_time - last_run_time

    if elapsed >= throttle_interval then
        local next = table.remove(task_queue, 1)
        last_run_time = current_time

        print(chat.header(addon.name):append(chat.color2(200, string.format('Running %s', next.name))))
        next.func(next.arg)

        ashita.tasks.once(throttle_interval, task.processQueue)
    else
        local delay = throttle_interval - elapsed
        ashita.tasks.once(delay, task.processQueue)
    end
end

return task
