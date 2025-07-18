local delay = ashita.time.qpf()
local bounces = T {}

local function debounce(fn, ...)
    local args = { ... }
    bounces[fn] = ashita.time.qpc()
    ashita.tasks.once(1, function ()
        local time = ashita.time.qpc()
        if bounces[fn] and time.q >= (bounces[fn].q + delay.q) then
            fn(table.unpack(args))
            bounces[fn] = nil
        end
    end)
end

return debounce
