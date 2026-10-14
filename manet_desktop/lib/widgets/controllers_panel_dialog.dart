import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/strings.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';

/// Windows only has 4 XInput slots.
const int _xinputSlots = 4;

/// What the controllers panel warns about. Shared with the header button so
/// its alert badge and the panel always agree.
class ControllerDiagnosis {
  final ControllerInventory? inventory;
  final String controllerMode;

  /// Pads MaNet runs (or is about to create) in the current mode; 0 uses
  /// the pads that exist now (console mode creates them per game).
  final int plannedPads;

  /// Last "couldn't create a controller" message from the server.
  final String? limitMessage;

  const ControllerDiagnosis({
    required this.inventory,
    required this.controllerMode,
    required this.plannedPads,
    this.limitMessage,
  });

  int get freeXinput =>
      (_xinputSlots - (inventory?.xinputTakenByOthers ?? 0)).clamp(0, _xinputSlots);

  /// MaNet players that get (or will get) no XInput slot: already measured,
  /// or predicted from the slots other controllers took.
  int get xinputOut {
    if (controllerMode != 'x360') return 0;
    final pads = plannedPads > 0 ? plannedPads : (inventory?.ownPads.length ?? 0);
    final predicted = pads - freeXinput;
    final measured = inventory?.playersWithoutXinput ?? 0;
    return predicted > measured ? predicted : measured;
  }

  bool get needsAttention =>
      xinputOut > 0 || limitMessage != null || (inventory?.hasConflicts ?? false);
}

/// Shows what Windows sees as game controllers next to MaNet's own pads, so
/// the host can spot leftovers, real controllers and stolen XInput slots.
class ControllersPanelDialog extends StatefulWidget {
  final HostApiService api;
  final ControllerInventory? initialInventory;
  final ValueChanged<ControllerInventory>? onInventoryChanged;
  final int plannedPads;
  final String? limitMessage;
  final VoidCallback? onDismissLimit;

  const ControllersPanelDialog({
    super.key,
    required this.api,
    this.initialInventory,
    this.onInventoryChanged,
    this.plannedPads = 0,
    this.limitMessage,
    this.onDismissLimit,
  });

  @override
  State<ControllersPanelDialog> createState() => _ControllersPanelDialogState();
}

class _ControllersPanelDialogState extends State<ControllersPanelDialog> {
  ControllerInventory? _inventory;
  String? _limitMessage;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _inventory = widget.initialInventory;
    _limitMessage = widget.limitMessage;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inventory = await widget.api.fetchControllerInventory();
      if (!mounted) return;
      setState(() => _inventory = inventory);
      widget.onInventoryChanged?.call(inventory);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.controllers.loadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _notice = message);
    } catch (_) {
      if (mounted) setState(() => _notice = context.l10n.controllers.actionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Windows needs a moment to finish plugging/unplugging devices.
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) await _refresh();
  }

  Future<void> _recreate() => _runAction(() async {
        final strings = context.l10n.controllers;
        await widget.api.recreateControllers();
        return strings.recreated;
      });

  Future<void> _closeStaleServers() => _runAction(() async {
        final strings = context.l10n.controllers;
        final closed = await widget.api.closeStaleServers();
        return strings.closedServers(closed);
      });

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.controllers;
    final inventory = _inventory;

    return JuicyDialog(
      title: strings.title,
      maxWidth: 760,
      actions: [
        JuicyButton(
          onPressed: _loading || _busy ? null : _refresh,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.refresh, style: _buttonStyle),
        ),
        JuicyButton(
          onPressed: _busy || inventory == null ? null : _recreate,
          backgroundColor: AppColors.highlightColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(strings.recreate, style: _buttonStyle),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading && inventory == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (inventory == null)
            _Banner(icon: Icons.error_outline_rounded, text: _error ?? strings.loadError)
          else
            ..._buildContent(context, inventory),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(_notice!, style: _bodyStyle),
          ],
          const SizedBox(height: 8),
          Text(strings.recreateHint, style: _captionStyle),
        ],
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, ControllerInventory inventory) {
    final strings = context.l10n.controllers;
    final mode = inventory.controllerMode ?? 'x360';
    final diagnosis = ControllerDiagnosis(
      inventory: inventory,
      controllerMode: mode,
      plannedPads: widget.plannedPads,
      limitMessage: _limitMessage,
    );
    final suspects = inventory.virtualPadApps.map((a) => a.name).join(', ');
    final outPads = [
      for (final pad in inventory.ownPads)
        if (pad.type == 'x360' && pad.xinputIndex == null) pad,
    ];

    final issues = <Widget>[
      if (_error != null) _Banner(icon: Icons.error_outline_rounded, text: _error!),
      if (_limitMessage != null)
        _Banner(
          icon: Icons.warning_amber_rounded,
          text: _limitMessage!,
          action: widget.onDismissLimit == null
              ? null
              : JuicyButton(
                  onPressed: () {
                    widget.onDismissLimit!();
                    setState(() => _limitMessage = null);
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Icon(Icons.check_rounded, size: 18, color: AppColors.textPrimary),
                ),
        ),
      if (diagnosis.xinputOut > 0)
        _Banner(
          icon: Icons.warning_amber_rounded,
          text: strings.predictionWarning(
            diagnosis.plannedPads > 0 ? diagnosis.plannedPads : inventory.ownPads.length,
            diagnosis.freeXinput,
            diagnosis.xinputOut,
          ),
        ),
      if (inventory.otherServers > 0)
        _Banner(
          icon: Icons.warning_amber_rounded,
          text: strings.staleServersWarning(inventory.otherServers),
          action: JuicyButton(
            onPressed: _busy ? null : _closeStaleServers,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(strings.closeStaleServers, style: _buttonStyle),
          ),
        ),
      if (inventory.foreignVirtual > 0)
        _Banner(
          icon: Icons.info_outline_rounded,
          text: [
            strings.foreignWarning(inventory.foreignVirtual),
            if (suspects.isNotEmpty) strings.likelySources(suspects),
          ].join(' '),
        ),
    ];

    return [
      Text(
        strings.summary(inventory.devices.length, inventory.ownPads.length),
        style: _bodyStyle,
      ),
      const SizedBox(height: 16),
      _SectionTitle(icon: Icons.health_and_safety_rounded, text: strings.diagnosticsTitle),
      const SizedBox(height: 8),
      if (issues.isEmpty)
        _Banner(icon: Icons.check_circle_rounded, text: strings.allGood)
      else
        for (final issue in issues)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: issue),
      const SizedBox(height: 16),
      _SectionTitle(icon: Icons.grid_view_rounded, text: strings.xinputTitle),
      const SizedBox(height: 2),
      Text(strings.xinputSubtitle, style: _captionStyle),
      const SizedBox(height: 10),
      Row(
        children: [
          for (final slot in inventory.xinputSlots) ...[
            if (slot.index > 0) const SizedBox(width: 8),
            Expanded(child: _XinputSlotCell(slot: slot, inventory: inventory)),
          ],
        ],
      ),
      if (outPads.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(strings.outOfXinput, style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)),
            for (final pad in outPads)
              _Tag(
                text: _playerLabel(strings, pad),
                color: Colors.red.shade200,
              ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      _SectionTitle(icon: Icons.visibility_rounded, text: strings.windowsSeesTitle),
      const SizedBox(height: 2),
      Text(strings.windowsSeesHint, style: _captionStyle),
      const SizedBox(height: 10),
      if (inventory.devices.isEmpty)
        Text(strings.devicesEmpty, style: _captionStyle)
      else
        _DevicesTable(devices: inventory.devices, suspects: suspects),
      const SizedBox(height: 20),
      _SectionTitle(icon: Icons.apps_rounded, text: strings.appsTitle),
      const SizedBox(height: 2),
      Text(strings.appsHint, style: _captionStyle),
      const SizedBox(height: 10),
      if (inventory.virtualPadApps.isEmpty)
        Text(strings.appsEmpty, style: _captionStyle)
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final app in inventory.virtualPadApps)
              _Tag(text: '${app.name}  ·  ${app.exe}  ·  PID ${app.pid}'),
          ],
        ),
    ];
  }
}

String _playerLabel(ControllersStrings strings, OwnPadInfo pad) {
  final player = strings.xinputPlayer(pad.slot + 1);
  final name = pad.playerName;
  return name == null || name.isEmpty ? player : '$player · $name';
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Text(text, style: _sectionStyle),
      ],
    );
  }
}

/// One of the 4 Windows XInput slots, like the light ring on a pad.
class _XinputSlotCell extends StatelessWidget {
  final XinputSlotInfo slot;
  final ControllerInventory inventory;

  const _XinputSlotCell({required this.slot, required this.inventory});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.controllers;
    final pad = inventory.ownPads.where((p) => p.slot == slot.slot).firstOrNull;
    final (label, detail, color, icon) = switch (slot.owner) {
      'manet' => (
          strings.xinputPlayer((slot.slot ?? 0) + 1),
          pad?.playerName ?? 'ma•net',
          AppColors.highlightColor,
          Icons.smartphone_rounded,
        ),
      'other' => (
          strings.xinputOther,
          strings.sourceUnknown,
          Colors.orange.shade300,
          Icons.warning_amber_rounded,
        ),
      _ => (strings.xinputFree, '', AppColors.lightColor, Icons.radio_button_unchecked_rounded),
    };

    return Container(
      height: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${slot.index + 1}', style: _sectionStyle.copyWith(fontSize: 22)),
              const Spacer(),
              Icon(icon, size: 20, color: AppColors.textPrimary),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          if (detail.isNotEmpty)
            Text(detail, style: _captionStyle.copyWith(color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Every device Windows reports: what it is, its API and who made it.
class _DevicesTable extends StatelessWidget {
  final List<ControllerDeviceInfo> devices;
  final String suspects;

  const _DevicesTable({required this.devices, required this.suspects});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.controllers;
    const border = BorderSide(color: AppColors.textPrimary, width: 1.5);

    Widget cell(Widget child) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: child);
    Widget header(String text) => cell(Text(text, style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)));

    final sorted = [...devices]
      ..sort((a, b) {
        int rank(ControllerDeviceInfo d) => d.own ? 0 : (d.origin == 'vigem' ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: IntrinsicColumnWidth(),
          2: FlexColumnWidth(2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(horizontalInside: border),
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.08)),
            children: [header(strings.colDevice), header(strings.colType), header(strings.colSource)],
          ),
          for (final device in sorted)
            TableRow(
              decoration: BoxDecoration(
                color: device.origin == 'vigem' && !device.own
                    ? Colors.orange.shade100
                    : null,
              ),
              children: [
                cell(Row(
                  children: [
                    const Icon(Icons.sports_esports_rounded, size: 20, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.deviceLabel(device.vendor),
                            style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(device.name, style: _captionStyle, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                )),
                cell(_Tag(text: device.api == 'xinput' ? 'x•input' : 'd•input')),
                cell(_source(strings, device)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _source(ControllersStrings strings, ControllerDeviceInfo device) {
    final (text, detail) = switch (device.origin) {
      'vigem' when device.own => (strings.sourceManet, null),
      'vigem' => (strings.sourceUnknown, suspects.isEmpty ? null : strings.likelySources(suspects)),
      'steam' => (strings.sourceSteam, null),
      _ => (strings.sourcePhysical, null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: _bodyStyle),
        if (detail != null) Text(detail, style: _captionStyle),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;

  const _Tag({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? AppColors.lightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
      ),
      child: Text(text, style: _captionStyle.copyWith(color: AppColors.textPrimary)),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Banner({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _bodyStyle)),
          if (action != null) ...[
            const SizedBox(width: 10),
            action!,
          ],
        ],
      ),
    );
  }
}

const TextStyle _sectionStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 16,
  color: AppColors.textPrimary,
);

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 14,
  color: AppColors.textPrimary,
);

const TextStyle _buttonStyle = TextStyle(
  fontFamily: 'momo',
  fontWeight: FontWeight.bold,
  fontSize: 14,
  color: AppColors.textPrimary,
);

final TextStyle _captionStyle = TextStyle(
  fontFamily: 'momo',
  fontSize: 12,
  color: AppColors.textPrimary.withValues(alpha: 0.6),
);
