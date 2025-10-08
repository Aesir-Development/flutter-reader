function FilterSearch(results, query, limit)
    local normalized_query = Normalize(query)
    local filtered = {}

    for i, entry in ipairs(results) do
        local title = entry.title or ""
        -- string.find returns the start index if found, or nil otherwise
        if string.find(Normalize(title), normalized_query, 1, true) then
            table.insert(filtered, entry)
            if #filtered >= limit then
                break
            end
        end
    end

    return filtered
end

function Normalize(s)
    s = string.lower(s)
    s = string.gsub(s, "[^a-z0-9]", "")
    return s
end
