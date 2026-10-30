import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/widgets/tab_page.dart';

/// The inner tabs of the Por perto tab.
enum ListingsTab {
  nearby('Por perto'),
  mine('Meus anúncios');

  const ListingsTab(this.label);

  final String label;
}

/// The frame of the Por perto tab, as in the Claude Design screens
/// (`M-perto`, `M-meus-anuncios`): the logo header with [trailing] at its
/// right end, the segmented "Por perto | Meus anúncios" control under it and
/// the [selected] tab's [body] below. [onSelect] switches tabs.
class ListingsTabPage extends StatelessWidget {
  const ListingsTabPage({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.body,
    this.trailing,
  });

  final ListingsTab selected;
  final ValueChanged<ListingsTab> onSelect;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TabPage(
      trailing: trailing,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: _SegmentedTabs(selected: selected, onSelect: onSelect),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onSelect});

  final ListingsTab selected;
  final ValueChanged<ListingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final tab in ListingsTab.values)
            Expanded(
              child: _SegmentedTab(
                label: tab.label,
                isSelected: tab == selected,
                onTap: tab == selected ? null : () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentedTab extends StatelessWidget {
  const _SegmentedTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        elevation: isSelected ? 1 : 0,
        shadowColor: const Color(0x331F2A22),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small mist pill of the header, such as "até 30 km"; with [onTap], a
/// button, such as "Doar mudas".
class HeaderPill extends StatelessWidget {
  const HeaderPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: onTap != null,
      child: Material(
        color: AppColors.mist,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.forest),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
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
