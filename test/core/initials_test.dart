import 'package:catat_uang_app/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initialsOf', () {
    expect(initialsOf('Akun Tes'), 'AT');
    expect(initialsOf('miftahul huda ramadhan'), 'MH');
    expect(initialsOf('Budi'), 'B');
    expect(initialsOf('   '), '?');
  });
}
