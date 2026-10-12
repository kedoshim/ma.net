import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import 'juicy_widgets.dart';

/// Shows what Windows sees as game controllers next to MaNet's own pads, so
/// the host can spot leftovers, real controllers and stolen XInput slots.
class ControllersPanelDialog extends StatefulWidget {
  final HostApiService api;
  final ControllerInventory? initialInventory;
  final ValueChanged<ControllerInventory>? onInventoryChanged;

  const ControllersPanelDialog({
    super.key,
    required this.api,
    this.initialInventory,
    this.onInventoryChanged,
  });

  @override
  State<ControllersPanelDialog> createState() => _ControllersPanelDialogState();
}

class _ControllersPanelDialogState extends State<ControllersPanelDialog> {
  ControllerInventory? _inventory;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _inventory = widget.initialInventory;
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
      maxWidth: 560,
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
    final isXinputMode = inventory.controllerMode == 'x360';

    return [
      Text(
        strings.summary(inventory.devices.length, inventory.ownPads.length),
        style: _bodyStyle,
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        _Banner(icon: Icons.error_outline_rounded, text: _error!),
      ],
      if (inventory.otherServers > 0) ...[
        const SizedBox(height: 12),
        _Banner(
          icon: Icons.warning_amber_rounded,
          text: strings.staleServersWarning(inventory.otherServers),
          action: JuicyButton(
            onPressed: _busy ? null : _closeStaleServers,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(strings.closeStaleServers, style: _buttonStyle),
          ),
        ),
      ],
      if (isXinputMode && inventory.playersWithoutXinput > 0) ...[
        const SizedBox(height: 12),
        _Banner(
          icon: Icons.warning_amber_rounded,
          text: strings.noXinputWarning(inventory.playersWithoutXinput),
        ),
      ],
      if (inventory.foreignVirtual > 0) ...[
        const SizedBox(height: 12),
        _Banner(
          icon: Icons.info_outline_rounded,
          text: strings.foreignWarning(inventory.foreignVirtual),
        ),
      ],
      const SizedBox(height: 20),
      Text(strings.xinputTitle, style: _sectionStyle),
      const SizedBox(height: 4),
      Text(strings.xinputSubtitle, style: _captionStyle),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final slot in inventory.xinputSlots) _XinputSlotChip(slot: slot),
        ],
      ),
      if (isXinputMode && inventory.ownPads.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final pad in inventory.ownPads)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              pad.xinputIndex != null
                  ? strings.playerMapping(pad.slot + 1, pad.xinputIndex! + 1)
                  : strings.playerNoXinput(pad.slot + 1),
              style: _bodyStyle.copyWith(
                color: pad.xinputIndex == null ? Colors.red.shade700 : null,
              ),
            ),
          ),
      ],
      const SizedBox(height: 20),
      Text(strings.devicesTitle, style: _sectionStyle),
      const SizedBox(height: 8),
      if (inventory.devices.isEmpty)
        Text(strings.devicesEmpty, style: _captionStyle)
      else
        for (final device in inventory.devices) _DeviceRow(device: device),
    ];
  }
}

class _XinputSlotChip extends StatelessWidget {
  final XinputSlotInfo slot;

  const _XinputSlotChip({required this.slot});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.controllers;
    final (label, color) = switch (slot.owner) {
      'manet' => (strings.xinputPlayer((slot.slot ?? 0) + 1), AppColors.highlightColor),
      'other' => (strings.xinputOther, Colors.orange.shade300),
      _ => (strings.xinputFree, AppColors.lightColor),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${slot.index + 1}', style: _sectionStyle),
          Text(label, style: _bodyStyle, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final ControllerDeviceInfo device;

  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n.controllers;
    final origin = switch (device.origin) {
      'vigem' when device.own => 'ma•net',
      'vigem' => strings.originVirtual,
      'steam' => strings.originSteam,
      _ => strings.originPhysical,
    };
    final api = device.api == 'xinput' ? 'x•input' : 'd•input';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.sports_esports_rounded, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.deviceLabel(device.vendor),
                  style: _bodyStyle.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  device.name,
                  style: _captionStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Tag(text: origin),
          const SizedBox(width: 6),
          _Tag(text: api),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: _bodyStyle)),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: action!),
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
