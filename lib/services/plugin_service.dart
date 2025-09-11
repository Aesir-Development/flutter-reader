import 'dart:io';
import 'dart:ffi';
import 'package:path/path.dart' as path;
import 'package:flutter_lua_vm/LuaVM.dart';
import 'package:flutter/foundation.dart';

class PluginService {
  static LuaVM lvm = LuaVM();

  static runTest() {
    String result = lvm.exec("http_request", "https://flamecomics.xyz");
    debugPrint(result);
  }
}
