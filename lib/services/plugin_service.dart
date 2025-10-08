import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'package:path/path.dart' as path;
import 'package:flutter_lua_vm/LuaVM.dart';
import 'package:flutter/foundation.dart';

class PluginService {
  static LuaVM lvm = LuaVM();

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

    var res = lvm.eval(libs.join("\n"));
    debugPrint("Response: $res");

    for (var path in pluginPaths["plugins"]) {
      var pluginCode = await rootBundle.loadString("$path");
      var pluginName = basenameWithoutExtension(path);

      plugins[pluginName] = pluginCode;
    }

    for (var entry in plugins.entries) {
      int status = lvm.eval(entry.value);
      debugPrint("Status: $status");
    }

    return plugins;
  }

  static runTest() async {
    List<Pointer<Variant>> args = [
      lvm.stringArg("solo"),
    ];

    var result = await lvm.exec("FLAMECOMICS.test", []);
    // lvm.eval("print(FLAMECOMICS:test())");

    debugPrint(result);
  }
}
