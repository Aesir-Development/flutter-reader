// interface SearchResult {
//   id: string;
//   title: string;
//   thumbnail: string;
//   status: string;
//   chapter_count: number;
// }

// interface Details {
//   title: string;
//   status: string;
//   artist: string;
//   author: string;
//   chapter_count: number;
//   description: string;
//   genres: string[];
//   cover_image: string;
// }

// interface Chapter {
//   manhwa_id: string;
//   title: string;
//   chapter_number: number;
//   images: string[];
//   release_date: string | null;
// }

// interface PluginDetails {
//   site_name: string;
//   site_url: string;
//   site_logo: string;
//   site_description: string;
//   plugin_developer: string;
//   plugin_version: string;
//   compatible_with: string;
// }

// interface IPlugin {
//   plugin_details(): PluginDetails;
//   get_search(query: string): Promise<SearchResult[]>;
//   get_title_details(id: string): Promise<Details>;
//   get_chapter_list(id: string): Promise<Chapter[]>;
//   get_chapter(manhwa_id: string, chapter_num: number): Promise<Chapter>;
//   // get_chapter_images(html: string): Promise<string[]>;
// }

/**
 * Normalises string for searching
 * @param {string} s
 * @returns {string}
 */
function normalize(s) {
  return s.toLowerCase().replace(/[^a-z0-9]/gi, "");
}

/**
 * Common filter/search function
 * @param { {title: string}[] } results
 * @param {string} query
 * @param {number} limit
 * @returns
 */
function filter_search(results, query, limit) {
  const normalized_query = normalize(query);
  const filtered = [];

  for (const entry of results) {
    const title = entry.title || "";
    if (normalize(title).includes(normalized_query)) {
      filtered.push(entry);
      if (filtered.length >= limit) {
        break;
      }
    }
  }

  return filtered;
}

/**
 * This function parses JSON using native dart functions.
 * This just provides a standard way to do it.
 * @param {string} jsonString
 */
function parseJSONSafe(jsonString) {
  let res = sendMessage("test", JSON.stringify({ jsonString: jsonString }));
  return res;
}
