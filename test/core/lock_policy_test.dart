import 'package:catat_uang_app/core/lock_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kunci tampil hanya bila aktif, bukan web, dan perangkat mendukung', () {
    expect(shouldShowLock(enabled: true, isWeb: false, deviceSupported: true), isTrue);
    expect(shouldShowLock(enabled: false, isWeb: false, deviceSupported: true), isFalse);
    expect(shouldShowLock(enabled: true, isWeb: true, deviceSupported: true), isFalse);
    expect(shouldShowLock(enabled: true, isWeb: false, deviceSupported: false), isFalse);
  });
}
