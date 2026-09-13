import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/playback/native_error_guard.dart';

void main() {
  testWidgets('successful codec fallback cancels a transient native error', (
    tester,
  ) async {
    var failures = 0;
    final guard = NativeErrorGuard(onFailure: () => failures++);
    addTearDown(guard.dispose);
    guard.reportError();
    await tester.pump(const Duration(milliseconds: 300));
    guard.progress(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(failures, 0);
  });
  testWidgets(
    'unrecovered failure is reported once and reset cancels stale failures',
    (tester) async {
      var failures = 0;
      final guard = NativeErrorGuard(onFailure: () => failures++);
      addTearDown(guard.dispose);
      guard.reportError();
      guard.reportError();
      await tester.pump(const Duration(seconds: 2));
      expect(failures, 1);
      guard.reportError();
      guard.reset();
      await tester.pump(const Duration(seconds: 3));
      expect(failures, 1);
    },
  );
}
