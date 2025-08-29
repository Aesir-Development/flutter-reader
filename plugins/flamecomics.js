class flamecomics {
  plugin_details() {
    return {
      site_name: "Flame Comics",
      site_url: "https://flamecomics.xyz/",
      site_logo: "https://flamecomics.xyz/favicon.ico",
      site_description: "Unofficial webtoon/comic translations",
      plugin_developer: "HollowHuu",
      plugin_version: "0.1.0",
      compatible_with: "1.0.0", // This signifies the plugin system version, and not client version.
    };
  }

  // The Build ID is needed to construct the API request URLs
  async GetBuildId() {
    const res = await fetch("https://flamecomics.xyz/");
    const data = await res.text();
    const { document } = parseHTML(data);
    let nextData = document.querySelector("script#__NEXT_DATA__")?.textContent;
    // console.log("NEXT DATA:", nextData)
    return nextData ? JSON.parse(nextData).buildId : "";
  }

  // Where most of the API requests are constructed
  async DataApiReqBuilder() {
    const buildId = await this.GetBuildId();
    return `https://flamecomics.xyz/_next/data/${buildId}`;
  }

  ImageApiUrlBuilder() {
    return `https://cdn.flamecomics.xyz/uploads/images/series`;
  }

  async get_search(query) {
    console.log("Searching for:", query);

    const res = await fetch(`https://flamecomics.xyz/api/series`);
    const data = await res.json();

    // Map the API response to the SearchResult format
    const results = data.map((item) => ({
      id: item.id,
      title: item.label,
      thumbnail:
        "https://flamecomics.xyz/_next/image?url=" +
        encodeURI(
          `${this.ImageApiUrlBuilder()}/${item.id}/${item.image}&w=384&q=75`,
        ),
      status: item.status,
      chapter_count: parseInt(item.chapter_count),
    }));

    let search = filter_search(results, query, 10);

    return search;
  }

  async get_title_details() {
    let url = `${await this.DataApiReqBuilder()}/series/${id}.json?id=${id}`;
    let res = await fetch(url);
    let data = await res.json();

    return {
      title: data.pageProps.series.title,
      status: data.pageProps.series.status,
      artist: data.pageProps.series.artist.map((a) => a).join(", "),
      author: data.pageProps.series.author.map((a) => a).join(", "),
      chapter_count: data.pageProps.chapters.length,
      description: data.pageProps.series.description,
      genres: data.pageProps.series.tags,
      cover_image: `${this.ImageApiUrlBuilder()}/${id}/${data.pageProps.series.cover}`,
    };
  }

  async get_chapter(manhwa_id, chapter_num) {
    let url = await this.DataApiReqBuilder();
    let res = await fetch(`${url}/series/${manhwa_id}.json?id=${manhwa_id}`);
    let data = await res.json();

    let chapter = data.pageProps.chapters.find(
      (c) => Number.parseFloat(c.chapter) === chapter_num,
    );

    let images = [];
    for (let image in chapter.images) {
      images.push(
        `${this.ImageApiUrlBuilder()}/${manhwa_id}/${chapter.token}/${chapter.images[image].name}`,
      );
    }

    return {
      manhwa_id: manhwa_id,
      title: chapter.title,
      chapter_number: chapter_num,
      images: images,
      release_date: chapter.release_date || null,
    };
  }

  async get_chapter_list(id) {
    let url = await this.DataApiReqBuilder();
    let res = await fetch(`${url}/series/${id}.json?id=${id}`);
    let data = await res.json();

    return data.pageProps.chapters.map((chapter) => ({
      manhwa_id: id,
      title: chapter.title,
      chapter_number: Number.parseFloat(chapter.chapter),
      images: [], // We don't need the images here, we get those when fetching chapter details
      release_date: chapter.release_date || null,
    }));
  }
}
