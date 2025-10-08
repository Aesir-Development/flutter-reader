import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterreader/models/chapter.dart';
import 'package:flutterreader/models/manwha.dart';
import 'package:path/path.dart';
import 'package:flutter_lua_vm/lua_vm.dart';

class PluginService {
  static LuaVM lvm = LuaVM();

  static List<String>? _cachedPlugins;

  static Future<Map<String, String>> loadPlugins() async {
    Map<String, String> plugins = {};
    var pluginPaths = JsonDecoder()
        .convert(await rootBundle.loadString('plugins/PluginManifest.json'));

    List<String> libs = [];
    try {
      for (var path in pluginPaths["libs"]) {
        libs.add(await rootBundle.loadString('$path'));
      }
    } catch (err) {
      debugPrint("$err");
    }

    lvm.eval(libs.join("\n"));

    for (var path in pluginPaths["plugins"]) {
      var pluginCode = await rootBundle.loadString("$path");
      var pluginName = basenameWithoutExtension(path);
      plugins[pluginName] = pluginCode;
      lvm.eval(pluginCode);
    }

    return plugins;
  }

  static Future<List<String>> getPluginNames() async {
    if (_cachedPlugins != null) return _cachedPlugins!;
    try {
      var pluginPaths = JsonDecoder().convert(await rootBundle.loadString('plugins/PluginManifest.json'));
      _cachedPlugins = pluginPaths["plugins"]
          .map<String>((path) => basenameWithoutExtension(path).toUpperCase())
          .toList();
      return _cachedPlugins!;
    } catch (e) {
      debugPrint("Error loading plugin names: $e");
      return [];
    }
  }

  static Future<List<Manhwa>> searchManhwa(String query) async {
  List<Manhwa> allResults = [];
  try {
    // Get all plugin names
    List<String> pluginNames = await getPluginNames();

    // Iterate over each plugin and search
    for (var pluginName in pluginNames) {
      try {
        List<Pointer<Variant>> args = [lvm.stringArg(query)];
        final resultJson = await lvm.exec("$pluginName.GetSearch", args);

        if (resultJson == null || resultJson.isEmpty) continue;

        final resultData = jsonDecode(resultJson) as List<dynamic>;

        for (var item in resultData) {
          allResults.add(
            Manhwa(
              id: item['id'].toString() ?? '',
              name: item['title'] ?? '',
              coverImageUrl: item['thumbnail'] ?? null,
              pluginName: pluginName,
              description: item['description'] ?? '',
              genres: List<String>.from(item['genres'] ?? []),
              chapters: [], 
              rating: 0.0,
              status: item['status'] ?? '',
              author: item['author'] ?? '',
              artist: item['artist'] ?? '',
            ),
          );
        }
      } catch (e) {
        debugPrint("Failed to search plugin $pluginName: $e");
      }
    }
  } catch (e) {
    debugPrint("Global search failed: $e");
  }
  return allResults;
}
static runTest() async {
    List<Pointer<Variant>> args = [
      lvm.stringArg("solo"),
    ];

    var result = await lvm.exec("FLAMECOMICS.GetSearch", args);
    // lvm.eval("print(FLAMECOMICS:test())");

    debugPrint(result);
  }


  static Future<Manhwa> getManhwaDetails(String pluginName, String manhwaId, {String? name}) async {
    try {
      List<Pointer<Variant>> args = [lvm.stringArg(manhwaId)];

      // Fetch title details
      final titleResult = await lvm.exec("$pluginName.GetTitleDetails", args);
      if (titleResult == null || titleResult.isEmpty) {
        throw Exception("No title details found for $manhwaId");
      }
      final titleData = jsonDecode(titleResult);

      // Fetch chapter list
      final chapterResult = await lvm.exec("$pluginName.GetChapterList", args);
      if (chapterResult == null || chapterResult.isEmpty) {
        throw Exception("No chapters found for $manhwaId");
      }
      final chapterData = jsonDecode(chapterResult) as List<dynamic>;

      // Map chapters
      final chapters = chapterData.map((item) => Chapter(
        number: (item['chapterNumber'] ?? 0).toDouble(),
        title: item['title'] ?? '',
        releaseDate: item['releaseDate'] != null ? DateTime.parse(item['releaseDate'].toString()) : DateTime.now(),
        isRead: false,
        isDownloaded: false,
        images: List<String>.from(item['images'] ?? []),
      )).toList();

      return Manhwa(
        id: manhwaId,
        name: titleData['title'] ?? name ?? 'Unknown',
        description: titleData['description'] ?? '',
        genres: List<String>.from(titleData['genres'] ?? []),
        rating: 0.0,
        status: titleData['status'] ?? '',
        author: titleData['author'] ?? '',
        artist: titleData['artist'] ?? '',
        lastUpdated: null,
        chapters: chapters,
        coverImageUrl: titleData['cover_image'],
      );
    } catch (e) {
      throw Exception("Failed to fetch manhwa details: $e");
    }
  }
}
