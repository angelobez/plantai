import 'package:flutter/material.dart';

import 'plantai_logo.dart';

/// The frame of a tab screen: the logo header over [body]. The bottom bar
/// belongs to the shell around it (`TabsShell`).
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 18,
        title: const PlantaiLogo(),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}
