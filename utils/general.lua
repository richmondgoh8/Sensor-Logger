local M = {}


local function compare( a, b )
    return a < b  -- Note "<" as the operator
end

local function myBoko(a)
    return 5 * a
end

M.compare = compare
M.myBoko = myBoko

return M
