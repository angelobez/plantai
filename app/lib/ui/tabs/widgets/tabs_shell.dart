import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/colors.dart';
import '../../core/widgets/leaf_icon.dart';

/// The tabs of the bottom bar, in the order of the router's shell branches.
enum AppTab {
  garden('Jardim'),
  nearby('Por perto'),
  profile('Perfil');

  const AppTab(this.label);

  final String label;
}

/// The main navigation: the current tab over the bottom bar with Jardim, Por
/// perto, Perfil and the square camera button.
class TabsShell extends StatelessWidget {
  const TabsShell({
    super.key,
    required this.navigationShell,
    required this.onCamera,
  });

  final StatefulNavigationShell navigationShell;

  /// What the camera button does (identify a plant by photo).
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        current: AppTab.values[navigationShell.currentIndex],
        onTab: (tab) => navigationShell.goBranch(
          tab.index,
          // Tapping the current tab again goes back to its first screen.
          initialLocation: tab.index == navigationShell.currentIndex,
        ),
        onCamera: onCamera,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.current,
    required this.onTab,
    required this.onCamera,
  });

  final AppTab current;
  final ValueChanged<AppTab> onTab;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('bottom-bar'),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Semantics(
            container: true,
            label: 'Navegação principal',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tab in AppTab.values)
                  Expanded(
                    child: _TabButton(
                      tab: tab,
                      selected: tab == current,
                      onTap: () => onTab(tab),
                    ),
                  ),
                Expanded(child: _CameraButton(onTap: onCamera)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: IconTheme(
            data: IconThemeData(color: color, size: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                switch (tab) {
                  AppTab.garden => const LeafIcon(strokeWidth: 1.8),
                  AppTab.nearby => const Icon(Icons.location_on_outlined),
                  AppTab.profile => const Icon(Icons.person_outline),
                },
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.topCenter,
        child: Semantics(
          button: true,
          label: 'Identificar uma planta pela foto',
          excludeSemantics: true,
          child: Material(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox.square(
                dimension: 52,
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
