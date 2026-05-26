import 'package:flutter/material.dart';

enum QuickActionGroup { volumeMedia, windowsSystem }

class QuickActionDefinition {
  final String id;
  final String title;
  final IconData icon;
  final QuickActionGroup group;

  const QuickActionDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.group,
  });
}

const List<QuickActionDefinition> quickActionDefinitions = [
  QuickActionDefinition(
    id: 'mute_toggle',
    title: 'Mute/Unmute',
    icon: Icons.volume_off,
    group: QuickActionGroup.volumeMedia,
  ),
  QuickActionDefinition(
    id: 'volume_down',
    title: 'Volume Down',
    icon: Icons.volume_down,
    group: QuickActionGroup.volumeMedia,
  ),
  QuickActionDefinition(
    id: 'volume_up',
    title: 'Volume Up',
    icon: Icons.volume_up,
    group: QuickActionGroup.volumeMedia,
  ),
  QuickActionDefinition(
    id: 'previous_track',
    title: 'Previous Track',
    icon: Icons.skip_previous,
    group: QuickActionGroup.volumeMedia,
  ),
  QuickActionDefinition(
    id: 'play_pause',
    title: 'Play/Pause',
    icon: Icons.play_arrow,
    group: QuickActionGroup.volumeMedia,
  ),
  QuickActionDefinition(
    id: 'next_track',
    title: 'Next Track',
    icon: Icons.skip_next,
    group: QuickActionGroup.volumeMedia,
  ),
  QuickActionDefinition(
    id: 'windows_key',
    title: 'Windows Key',
    icon: Icons.home_outlined,
    group: QuickActionGroup.windowsSystem,
  ),
  QuickActionDefinition(
    id: 'windows_tab',
    title: 'Windows Tab',
    icon: Icons.tab,
    group: QuickActionGroup.windowsSystem,
  ),
  QuickActionDefinition(
    id: 'show_desktop',
    title: 'Show Desktop',
    icon: Icons.desktop_windows_outlined,
    group: QuickActionGroup.windowsSystem,
  ),
  QuickActionDefinition(
    id: 'task_manager',
    title: 'Task Manager',
    icon: Icons.data_thresholding_outlined,
    group: QuickActionGroup.windowsSystem,
  ),
  QuickActionDefinition(
    id: 'escape',
    title: 'Escape',
    icon: Icons.arrow_back_rounded,
    group: QuickActionGroup.windowsSystem,
  ),
  // QuickActionDefinition(
  //   id: 'virtual_keyboard',
  //   title: 'Virtual Keyboard',
  //   icon: Icons.keyboard,
  //   group: QuickActionGroup.windowsSystem,
  // ),
  QuickActionDefinition(
    id: 'maximize_window',
    title: 'Maximize Window',
    icon: Icons.open_in_full,
    group: QuickActionGroup.windowsSystem,
  ),
  QuickActionDefinition(
    id: 'minimize_window',
    title: 'Minimize Window',
    icon: Icons.minimize,
    group: QuickActionGroup.windowsSystem,
  ),
];

String quickActionGroupLabel(QuickActionGroup group) {
  switch (group) {
    case QuickActionGroup.volumeMedia:
      return 'Volume & Media';
    case QuickActionGroup.windowsSystem:
      return 'Windows / System';
  }
}

List<QuickActionDefinition> quickActionsForGroup(QuickActionGroup group) {
  return quickActionDefinitions
      .where((action) => action.group == group)
      .toList(growable: false);
}
