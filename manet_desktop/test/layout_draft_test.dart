import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/models/layout_draft.dart';

void main() {
  test('hiding a button takes it out of the left row and aiming', () {
    final draft = LayoutDraft.from(null)
      ..moveToLeft('LB', 0)
      ..setAim('A', true)
      ..setReleaseAim('A', true);
    draft
      ..setVisible('LB', false)
      ..setVisible('A', false);
    expect(draft.leftButtons, isEmpty);
    expect(draft.aimButtons, isEmpty);
    expect(draft.releaseAimButtons, isEmpty);
  });

  test('going to the left row stops aiming', () {
    final draft = LayoutDraft.from(null)
      ..setAim('RB', true)
      ..setReleaseAim('RB', true)
      ..moveToLeft('RB', 0);
    expect(draft.leftButtons, ['RB']);
    expect(draft.isAim('RB'), isFalse);
    expect(draft.isReleaseAim('RB'), isFalse);
    draft.setAim('RB', true);
    expect(draft.isAim('RB'), isFalse);
  });

  test('a full left row swaps out the button in that slot', () {
    final draft = LayoutDraft.from(null)
      ..moveToLeft('LB', 0)
      ..moveToLeft('LT', 1)
      ..moveToLeft('A', 1);
    expect(draft.leftButtons, ['LB', 'A']);
    expect(draft.isVisible('LT'), isTrue);
  });

  test('moving inside the left row swaps places', () {
    final draft = LayoutDraft.from(null)
      ..moveToLeft('LB', 0)
      ..moveToLeft('LT', 1)
      ..moveToLeft('LT', 0);
    expect(draft.leftButtons, ['LT', 'LB']);
  });

  test('sticks never go to the left row', () {
    final draft = LayoutDraft.from(null);
    expect(draft.moveToLeft('RS_FIXED', 0), isFalse);
    expect(draft.leftButtons, isEmpty);
  });

  test('a hidden button dropped on the pad shows up', () {
    final draft = LayoutDraft.from(null)..moveToRight('RT', target: 'A');
    expect(draft.isVisible('RT'), isTrue);
    expect(
      draft.buttonOrder.indexOf('RT'),
      lessThan(draft.buttonOrder.indexOf('A')),
    );
  });

  test('release needs aim, and turning aim off clears it', () {
    final draft = LayoutDraft.from(null)..setReleaseAim('A', true);
    expect(draft.isReleaseAim('A'), isFalse);
    draft
      ..setAim('A', true)
      ..setReleaseAim('A', true)
      ..setAim('A', false);
    expect(draft.isReleaseAim('A'), isFalse);
  });
}
