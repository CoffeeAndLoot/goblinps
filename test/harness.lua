local harness = {}

local current = nil
local failures = {}
local passed = 0

function harness.describe(name, fn)
    current = name
    fn()
    current = nil
end

function harness.it(name, fn)
    local label = (current and (current .. " :: ") or "") .. name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = label .. "\n    " .. tostring(err)
    end
end

local function render(value)
    if type(value) == "table" then
        local parts = {}
        for i = 1, #value do
            parts[#parts + 1] = render(value[i])
        end
        local keys = {}
        for k, v in pairs(value) do
            if type(k) ~= "number" then
                keys[#keys + 1] = tostring(k) .. "=" .. render(v)
            end
        end
        table.sort(keys)
        for i = 1, #keys do
            parts[#parts + 1] = keys[i]
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return string.format("%q", tostring(value))
end

function harness.eq(actual, expected, label)
    if actual ~= expected then
        error((label or "values differ") .. "\n    expected: " .. render(expected)
              .. "\n    actual:   " .. render(actual), 2)
    end
end

function harness.truthy(value, label)
    if not value then
        error((label or "expected a truthy value") .. ", got " .. render(value), 2)
    end
end

function harness.falsy(value, label)
    if value then
        error((label or "expected a falsy value") .. ", got " .. render(value), 2)
    end
end

function harness.run()
    print(string.format("%d passed, %d failed", passed, #failures))
    for i = 1, #failures do
        print("FAIL: " .. failures[i])
    end
    return (#failures == 0) and 0 or 1
end

return harness
