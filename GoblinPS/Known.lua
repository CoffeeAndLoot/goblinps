local _, ns = ...

-- Pure: which flight paths this character has discovered. The client only
-- tells the truth while a flight master's map is open (isUndiscovered is
-- dead on build 1.60.1.69913), so the answer is remembered between visits.
-- Flight paths are never unlearned, so the store only ever grows.
local Known = {}
ns.Known = Known

-- store: { [nodeID] = true }. nodes: { { nodeID, name, flyable }, ... } as
-- seen at a flight master. Returns how many were new.
function Known.Learn(store, nodes)
    local added = 0
    for _, node in ipairs(nodes) do
        if node.flyable and not store[node.nodeID] then
            store[node.nodeID] = true
            added = added + 1
        end
    end
    return added
end

function Known.Count(store)
    local count = 0
    for _ in pairs(store) do
        count = count + 1
    end
    return count
end

return Known
