import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:flutter_lua_vm/lua_vm.dart';

import 'package:flutter/foundation.dart';

class PluginService {
  static LuaVM lvm = LuaVM();

  static Future<Map<String, String>> loadPlugins() async {
    Map<String, String> plugins = {};
    var pluginPaths = JsonDecoder()
        .convert(await rootBundle.loadString('plugins/PluginManifest.json'));

    List<String> libs = [];
    for (var path in pluginPaths["libs"]) {
      libs.add(await rootBundle.loadString('$path'));
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
    // String result = lvm.exec("http_request", "https://flamecomics.xyz");

    // Test to check blocking

    lvm.eval('local result = ""');

    // int count = 10;
    // for (int i = 0; i < count; i++) {
    //   lvm.eval("""
    //     local co$i = coroutine.create(function()
    //       http_request("https://flamecomics.xyz")
    //       print($i);
    //     end)

    //     if coroutine.status(co${i - 1}) ~= "dead" or $i == 0 then
    //       coroutine.resume(co$i)
    //     end
    //   """);
    // }
    // lvm.eval("""
    //   function Test()
    //     for i = 0, 9 do
    //       _G["co"..i] = coroutine.create(function()
    //         local res = http_request("https://flamecomics.xyz")
    //         print(res)
    //       end)
    //     end

    //     for i = 0, 9 do
    //       if coroutine.status(_G["co"..i]) ~= "dead" then
    //         coroutine.resume(_G["co"..i])
    //       end
    //     end
    //   end

    //   function Test2(s1, s2)
    //     print(s1..s2)
    //     return "Success"
    //   end

    //   """);

    List<Pointer<Variant>> args = [
      lvm.stringArg("Hello"),
      lvm.stringArg("World!")
    ];

    var result = await lvm.exec("FLAMECOMICS.test", []);
    // lvm.eval("print(FLAMECOMICS:test())");

    debugPrint("Response length: ${result.length}");
  }
}
