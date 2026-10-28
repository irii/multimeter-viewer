import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../about/app_info.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../settings_dialog.dart';

/// An app bar action of a page.
class BarAction {
  const BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.pinned = false,
  });

  final IconData icon;

  /// Menu entry text; also the tooltip unless [tooltip] is set.
  final String label;
  final String? tooltip;

  /// `null` disables the action.
  final VoidCallback? onPressed;

  /// Stays an icon button on narrow screens instead of moving into the menu.
  final bool pinned;
}

/// The actions of an app bar plus "Settings" and "About": all as icon
/// buttons on wide screens; on narrow ones (phones) only the [pinned]
/// actions, the rest in an overflow menu.
class BarActions extends StatelessWidget {
  const BarActions({
    super.key,
    this.leading = const [],
    this.actions = const [],
  });

  /// Widgets always shown before the actions (indicators, buttons with
  /// their own state such as the record button).
  final List<Widget> leading;
  final List<BarAction> actions;

  /// Below this width the unpinned actions go into the menu.
  static const narrowWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appActions = [
      BarAction(
        icon: Icons.settings_outlined,
        label: l10n.settings,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const SettingsDialog(),
        ),
      ),
      BarAction(
        icon: Icons.info_outline,
        label: l10n.about,
        tooltip: l10n.aboutTooltip(AppInfo.version),
        onPressed: () => context.push(Routes.about),
      ),
    ];
    final narrow = MediaQuery.sizeOf(context).width < narrowWidth;
    final shown = narrow ? actions.where((a) => a.pinned) : actions;
    final inMenu = narrow ? actions.where((a) => !a.pinned).toList() : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...leading,
        for (final action in shown) _button(action),
        if (inMenu == null)
          for (final action in appActions.reversed) _button(action)
        else
          _OverflowMenu(groups: [inMenu, appActions]),
        const SizedBox(width: 8),
      ],
    );
  }

  static Widget _button(BarAction action) => IconButton(
    tooltip: action.tooltip ?? action.label,
    icon: Icon(action.icon),
    onPressed: action.onPressed,
  );
}

/// "⋮" menu with the [groups] separated by dividers.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.groups});

  final List<List<BarAction>> groups;

  @override
  Widget build(BuildContext context) {
    final nonEmpty = groups.where((g) => g.isNotEmpty).toList();
    return PopupMenuButton<BarAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => action.onPressed?.call(),
      itemBuilder: (context) => [
        for (final (i, group) in nonEmpty.indexed) ...[
          if (i > 0) const PopupMenuDivider(),
          for (final action in group)
            PopupMenuItem(
              value: action,
              enabled: action.onPressed != null,
              child: Row(
                children: [
                  Icon(action.icon),
                  const SizedBox(width: 12),
                  Text(action.label),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
