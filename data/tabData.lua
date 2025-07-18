local searchStatus = require('data/searchStatus')

local function new()
    return {
        input = { '' },
        previousInput = { '' },
        category = 999,
        previousCategory = 999,
        lvMinInput = { 0 },
        previousLvMinInput = { 0 },
        lvMaxInput = { 99 },
        previousLvMaxInput = { 99 },
        jobSelected = {},
        previousJobSelected = {},
        status = searchStatus and searchStatus.noResults or 0,
        selectedItem = nil,
        selectedIndex = nil,
        showAllItems = { false },
        startup = true
    }
end

return {
    new = new
}
