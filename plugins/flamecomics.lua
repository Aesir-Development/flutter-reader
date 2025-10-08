FLAMECOMICS = {}

function FLAMECOMICS:GetBuildID()
    local data = fetch("https://flamecomics.xyz")

    local content = selector(data, "script#__NEXT_DATA__")
    local table = json.decode(content)

    return table.buildId
end

function FLAMECOMICS:DataApiRequestBuilder()
    local buildId = self:GetBuildID()
    return "https://flamecomics.xyz/_next/data/" .. buildId
end

function FLAMECOMICS:ImageApiUrlBuilder()
    return "https://cdn.flamecomics.xyz/uploads/images/series"
end

function FLAMECOMICS:GetSearch(query)
    local response = fetch("https://flamecomics.xyz/api/series")
    local data = json.decode(response)

    local results = {}

    for i, item in ipairs(data) do
        local url = self:ImageApiUrlBuilder() .. "/" .. item.id .. "/" .. item.image .. "&w=384&q=75"
        -- If you need to encode the URL, you can use a custom encodeURI function or a library
        -- local encoded_url = encodeURI(url)
        local encoded_url = url -- Replace with actual encoding if needed

        table.insert(results, {
            id = item.id,
            title = item.label,
            thumbnail = "https://flamecomics.xyz/_next/image?url=" .. encoded_url,
            status = item.status,
            chapter_count = tonumber(item.chapter_count),
        })
    end

    local search = FilterSearch(results, query, 10)
    local searchEncoded = json.encode(search)

    -- print("search" .. searchEncoded)

    return searchEncoded
end

function FLAMECOMICS:GetTitleDetails(id)
    local idString = tostring(id)
    local url = self:DataApiRequestBuilder() .. "/series/" .. idString .. ".json?id=" .. idString
    local res = fetch(url)
    local data = json.decode(res)

    local item = {
        title = data.pageProps.series.title,
        status = data.pageProps.series.status,
        artist = table.concat(data.pageProps.series.artist, ", "),
        author = table.concat(data.pageProps.series.author, ", "),
        chapter_count = #data.pageProps.chapters,
        description = data.pageProps.series.description,
        genres = data.pageProps.series.tags,
        cover_image = self:ImageApiUrlBuilder() .. "/" .. id .. "/" .. data.pageProps.series.cover,
    }

    local itemJson = json.encode(item)
    return itemJson
end

function FLAMECOMICS:GetChapter(titleId, chapterNum)
    local url = self:DataApiRequestBuilder() .. "/series/" .. tostring(titleId) .. ".json?id=" .. tostring(titleId)
    print(url)
    local res = fetch(url)
    local data = json.decode(res)

    local chapter = {}
    for k, v in pairs(data.pageProps.chapters) do
        if tonumber(chapterNum) == tonumber(v.chapter) then
            chapter = v
        end
    end

    local images = {}
    for _, v in pairs(chapter.images) do
        table.insert(images, self:ImageApiUrlBuilder() ..
            "/" .. titleId .. "/" .. chapter.token .. "/" .. v.name)
    end

    local fChapter = {
        titleId = titleId,
        title = chapter.title,
        chapterNumber = chapterNum,
        images = images,
        releaseDate = chapter.release_date or nil
    }

    local jsonChapter = json.encode(fChapter)
    return jsonChapter
end

function FLAMECOMICS:GetChapterList(id)
    local url = self:DataApiRequestBuilder() .. "/series/" .. tostring(id) .. ".json?id=" .. tostring(id)
    local res = fetch(url)
    local data = json.decode(res)

    local chapters = {}
    for k, v in pairs(data.pageProps.chapters) do
        table.insert(chapters, {
            titleId = id,
            title = v.title,
            chapterNumber = tonumber(v.chapter),
            images = {},
            releaseDate = v.release_date or nil,
        })
    end

    local jsonChapters = json.encode(chapters)

    return jsonChapters
end

function FLAMECOMICS:test()
    local search = self:GetSearch("Solo")
    local titleDetails = self:GetTitleDetails(2)
    local chapterDetails = self:GetChapter(2, 2) -- ORV chapter 2
    local chapterList = self:GetChapterList(2)

    print("Search: " .. search)
    print("Title Details: " .. titleDetails)
    print("Chapter details: " .. chapterDetails)
    print("Chapter list: " .. chapterList)

    return "success"
end
