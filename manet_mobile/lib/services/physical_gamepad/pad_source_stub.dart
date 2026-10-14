import 'pad_source.dart';

class UnsupportedPadSource implements PadSource {
  @override
  bool get supported => false;

  @override
  Stream<List<PadInfo>> get devices => const Stream.empty();

  @override
  Stream<PadSnapshot> get states => const Stream.empty();

  @override
  void start() {}

  @override
  void setCapture(bool active) {}

  @override
  void rumble(String id, double weak, double strong) {}
}

PadSource createPadSource() => UnsupportedPadSource();
