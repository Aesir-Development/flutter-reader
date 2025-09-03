import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/extensions/xhr.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class PluginService {
  static JavascriptRuntime? _jsRuntime;

  static Future<void> initialize() async {
    _jsRuntime = getJavascriptRuntime();
    _jsRuntime?.enableFetch();
    _jsRuntime?.enableXhr();
    _jsRuntime?.enableHandlePromises();

    if (_jsRuntime == null) {
      throw Exception("Failed to initialize JavaScript runtime");
    }
  }

  static Future<Map<String, String>> loadPlugins() async {
    Map<String, String> plugins = {};

    var plugin_paths = JsonDecoder()
        .convert(await rootBundle.loadString('plugins/PluginManifest.json'));

    List<String> libs = [];
    for (var path in plugin_paths["libs"]) {
      libs.add(await rootBundle.loadString('$path'));
      debugPrint("Loading lib: $path");
    }

    var res = jsRuntime?.evaluate(libs.join("\n"), sourceUrl: "libs.js");
    if (res?.isError == true) {
      debugPrint("Error loading libs: ${res?.stringResult}");
      return {};
    }

    for (var path in plugin_paths["plugins"]) {
      var pluginCode = await rootBundle.loadString('$path');
      var pluginName = basenameWithoutExtension(path);

      plugins[pluginName] = pluginCode;
    }

    for (var entry in plugins.entries) {
      var result =
          jsRuntime?.evaluate(entry.value, sourceUrl: "${entry.key}.js");
      if (result?.isError == true) {
        debugPrint(
            "Error loading plugin ${entry.key}: ${result?.stringResult}");
        return {};
      } else {
        var err = jsRuntime?.evaluate("""
          if (typeof tmp_plugin == undefined) {
            var tmp_plugin = {};
          }

          tmp_plugin = new ${entry.key}();
          pluginMap["${entry.key}"] = tmp_plugin;
          """);
        if (err?.isError == true) {
          debugPrint(err?.stringResult);
        }
        debugPrint("Loaded plugin: ${entry.key}");
      }
    }

    jsRuntime?.onMessage("test", (dynamic args) {
      // debugPrint('Received message from JS: ${args["jsonString"]}');

      JsonDecoder decoder = JsonDecoder();

      var map = decoder.convert(args["jsonString"]);
      // debugPrint("Message data: $map");
      return map;
    });

    return plugins;
  }

  static JavascriptRuntime? get jsRuntime => _jsRuntime;

  static testPlugin() async {
    await initialize();
    await loadPlugins();

    var res = await jsRuntime?.evaluateAsync("""
          async function test() {
            const xhr = new XMLHttpRequest();

            xhr.onreadystatechange = function() {
              if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("XHR DONE, status:", xhr.status);
              }
            };

            xhr.open("GET", "https://flamecomics.xyz/", false);
            xhr.send(null);

            while (xhr.readyState !== XMLHttpRequest.DONE) {
              await new Promise(resolve => setTimeout(resolve, 100));
            }

            if (xhr.status !== 200) {
              console.error("Failed to fetch page, status:", xhr.status);
              return null;
            }

            const data = xhr.responseText;

            // let stringData = "";
            // const uint8Array = new Uint8Array(data);
            // for (let i = 0; i < uint8Array.length; i++) {
            //   stringData += String.fromCharCode(uint8Array[i]);
            // }
            //

            // console.log("DATA:", data);

            const { document } = parseHTML(data);

            let nextData = document.querySelector("script#__NEXT_DATA__")?.textContent;
            let obj = parseJSONSafe(nextData);
            console.log(obj);
            // console.log("NEXT DATA:", nextData);

            // nextData = nextData
            //   .replace(`/"[/g, "["`)
            //   .replace(`/]"/g, "]"`);
            nextData.trim();

            let cleaned_json = nextData.replace(/"altTitles":"\\[.*?\\]",?/gs, "");

            let buildId = cleaned_json ? JSON.parse(cleaned_json).buildId : null;
            console.log("Build ID:", buildId);
            return buildId;
          }
          test();
          """, sourceUrl: "plugins.js");
    if (res == null) return;
    jsRuntime?.executePendingJob();
    JsEvalResult result = await jsRuntime!.handlePromise(res);
    if (result.isError) {
      debugPrint("Error running plugin: ${result.stringResult}");
    } else {
      // debugPrint("Plugin result: ${result.stringResult}");
      // Write this to a debug file
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'plugin_debug.txt');
      final file = File(path);
      await file.writeAsString(result.stringResult);
      debugPrint("Wrote plugin debug to $path");
    }
  }
}
