import 'dart:io';
import 'dart:ffi';
import 'package:path/path.dart' as path;
import 'package:flutter_lua_vm/LuaVM.dart';

import 'package:flutter/foundation.dart';

class PluginService {
  static LuaVM lvm = LuaVM();

  static runTest() {
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
    lvm.eval("""
      for i = 0, 9 do
        _G["co"..i] = coroutine.create(function()
          local res = http_request("https://flamecomics.xyz")
          print(res)
        end)
      end

      for i = 0, 9 do
        if coroutine.status(_G["co"..i]) ~= "dead" then
          coroutine.resume(_G["co"..i])
        end
      end


      """);

    // debugPrint(result);
  }
}
