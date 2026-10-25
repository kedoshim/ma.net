import 'package:flutter/material.dart';

import '../models/controller_branding.dart';
import '../models/controller_left_zone.dart';
import '../models/layout_draft.dart';
import '../theme/app_colors.dart';
import 'layout_preview_widgets.dart';

/// The editor's controller preview. Click a button to tweak it on the side
/// panel; drag it above the movement to put it on the left side, back to the
/// right to undo, or onto another button to swap places.
class EditableLayoutPreview extends StatelessWidget {
  const EditableLayoutPreview({
    super.key,
    required this.brandingMode,
    required this.draft,
    required this.selectedId,
    required this.dragging,
    required this.onSelect,
    required this.onDragChanged,
    required this.onDropLeft,
    required this.onDropRight,
  });

  final ControllerBrandingMode brandingMode;
  final LayoutDraft draft;
  final String? selectedId;

  /// A button is being dragged (here or from the tray): the empty left-row
  /// slots show up so it's clear they take a drop.
  final bool dragging;
  final ValueChanged<String> onSelect;
  final ValueChanged<bool> onDragChanged;
  final void Function(String id, int slot) onDropLeft;
  final void Function(String id, String? target) onDropRight;

  static List<List<String>> _split(List<String> buttons, {required bool rows}) {
    final first = <String>[];
    final second = <String>[];
    for (final button in buttons) {
      (first.length <= second.length ? first : second).add(button);
    }
    if (rows) return first.length < second.length ? [second, first] : [first, second];
    return first.length > second.length ? [second, first] : [first, second];
  }

  @override
  Widget build(BuildContext context) {
    final layout = draft.toLayout();
    final isRows = draft.rightLayoutMode == 'rows';
    final groups = _split(layout.rightButtons, rows: isRows);

    Widget group(List<String> ids) => Expanded(
          child: Flex(
            direction: isRows ? Axis.horizontal : Axis.vertical,
            children: [
              for (final id in ids)
                Expanded(
                  flex: draft.sizeOf(id),
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (d) => d.data != id,
                    onAcceptWithDetails: (d) => onDropRight(d.data, id),
                    builder: (context, candidates, _) => _tile(
                      id,
                      hovered: candidates.isNotEmpty,
                    ),
                  ),
                ),
            ],
          ),
        );

    return Center(
      child: AspectRatio(
        aspectRatio: 2.2 / 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.textPrimary, width: 5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _leftSide(layout.shownLeftButtons)),
              const SizedBox(width: 12),
              const Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'ma•net',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'momo',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                // Dropping on empty space sends a button to the right side.
                child: DragTarget<String>(
                  onAcceptWithDetails: (d) => onDropRight(d.data, null),
                  builder: (context, candidates, _) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: candidates.isNotEmpty
                          ? AppColors.highlightColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                    child: Flex(
                      direction: isRows ? Axis.vertical : Axis.horizontal,
                      children: [
                        group(groups[0]),
                        const SizedBox(width: 6, height: 6),
                        group(groups[1]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leftSide(List<String> left) {
    final movement = (draft.movementMode == 'dpad'
            ? const PreviewDpad()
            : PreviewStick(floating: draft.movementMode == 'floatingJoystick'))
        .scale(1.15);
    final showRow = left.isNotEmpty || dragging;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: SizedBox(
            height: showRow ? null : 0,
            child: showRow
                ? AspectRatio(
                    aspectRatio: kLeftZoneMax * 1.6,
                    child: Row(
                      children: [
                        for (var i = 0; i < kLeftZoneMax; i++)
                          Expanded(child: _leftSlot(left, i)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Expanded(child: movement),
      ],
    );
  }

  Widget _leftSlot(List<String> left, int slot) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => isLeftZoneEligible(d.data),
      onAcceptWithDetails: (d) => onDropLeft(d.data, slot),
      builder: (context, candidates, _) {
        if (slot < left.length) {
          return _tile(left[slot], hovered: candidates.isNotEmpty);
        }
        if (!dragging) return const SizedBox.shrink();
        final hot = candidates.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: AppColors.highlightColor.withValues(alpha: hot ? 0.5 : 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hot
                    ? AppColors.textPrimary
                    : AppColors.highlightColor,
                width: 2.5,
              ),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded, size: 16, color: AppColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  Widget _tile(String id, {bool hovered = false}) {
    final selected = id == selectedId;
    final face = _face(id, selected: selected, hovered: hovered);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Draggable<String>(
            data: id,
            onDragStarted: () => onDragChanged(true),
            onDragEnd: (_) => onDragChanged(false),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 54,
                height: 34,
                child: _face(id, selected: true, hovered: false),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: face),
            child: AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: face,
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(String id, {required bool selected, required bool hovered}) {
    final Widget inner;
    if (id == 'RS_FIXED') {
      inner = const RightStickFixedPreview();
    } else if (id == 'RS_BUTTON') {
      inner = const RightStickFloatingPreview(faded: false);
    } else if (id == 'RS_SWIPE') {
      inner = const RightStickSwipePreview();
    } else {
      inner = Center(
        child: ControllerButtonBrand(
          presentation: ControllerBranding.presentationFor(id, brandingMode),
          size: 14,
          textColor: AppColors.textPrimary,
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      height: double.infinity,
      padding: LayoutDraft.isStick(id) ? const EdgeInsets.all(3) : null,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.highlightColor
            : hovered
            ? AppColors.highlightColor.withValues(alpha: 0.35)
            : LayoutDraft.isStick(id)
            ? Colors.transparent
            : AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected || hovered
              ? AppColors.textPrimary
              : AppColors.textPrimary.withValues(alpha: 0.3),
          width: selected ? 3 : 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: inner),
          // At a glance: this one aims when dragged.
          if (draft.isAim(id))
            Positioned(
              right: 2,
              top: 2,
              child: Icon(
                draft.isReleaseAim(id)
                    ? Icons.ads_click_rounded
                    : Icons.my_location_rounded,
                size: 10,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
