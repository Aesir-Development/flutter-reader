import 'package:flutter/material.dart';
import '../services/plugin_service.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({Key? key}) : super(key: key);

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            PluginService.runTest();
          },
          child: Text('Run Test'),
        ),
      ],
    );
  }
}
