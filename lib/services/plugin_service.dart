import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:path/path.dart';
import 'dart:convert';

class PluginService {
  static JavascriptRuntime? _jsRuntime;

  static Future<void> initialize() async {
    _jsRuntime = getJavascriptRuntime();
    _jsRuntime?.enableFetch();
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

    return plugins;
  }

  static JavascriptRuntime? get jsRuntime => _jsRuntime;

  static testPlugin() async {
    await initialize();
    await loadPlugins();

    var res = await jsRuntime?.evaluateAsync("""
          async function test() {

            let flame = pluginMap["flamecomics"];
            return flame.plugin_details();
          }
          test();
          """, sourceUrl: "plugins.js");
    if (res == null) return;
    jsRuntime?.executePendingJob();
    JsEvalResult result = await jsRuntime!.handlePromise(res);
    if (result.isError) {
      debugPrint("Error running plugin: ${result.stringResult}");
    } else {
      debugPrint("Plugin result: ${result.stringResult}");
    }
  }
}
