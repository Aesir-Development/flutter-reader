FLAMECOMICS = {}

function FLAMECOMICS:GetBuildID()
    local data = http_request("https://flamecomics.xyz")

    local content = selector(data, "script#__NEXT_DATA__")
    print(data)

    -- local data = "GetBuildID"
    -- print(data)

    -- local root = parse(data, 2000)
    -- local nextData = root:select("script#__NEXT_DATA__")[0]:getcontent()
    -- -- local nextData = root:getcontent() -- Just a test
    -- print("nextData" .. nextData)

    return data
end

function FLAMECOMICS:search(query)
    local url = "test"
end

function FLAMECOMICS:test()
    local buildID = self:GetBuildID()
    return buildID
end
