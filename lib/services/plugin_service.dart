import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';

class PluginService {
  static JavascriptRuntime? _jsRuntime;

  static Future<void> initialize() async {
    _jsRuntime = getJavascriptRuntime();
    _jsRuntime?.enableFetch();
    print('JavaScript runtime initialized for plugins');
  }

  static JavascriptRuntime? get jsRuntime => _jsRuntime;


  testPlugin() {
    // load plugin from ../plugins/flamecomics.ts
    jsRuntime?.evaluate("""
      console.log("test");
    """);
  }
}