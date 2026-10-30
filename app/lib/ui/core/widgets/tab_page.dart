import 'package:flutter/material.dart';

import 'plantai_logo.dart';

/// The frame of a tab screen: the logo header over [body], with [trailing]
/// at its right end (such as "4 plantas"). The bottom bar belongs to the
/// shell around it (`TabsShell`).
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.body, this.trailing});

  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 18,
        title: const PlantaiLogo(),
        actions: [
          if (trailing case final trailing?)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(child: trailing),
            ),
        ],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}
