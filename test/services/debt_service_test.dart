import 'package:arthava/services/debt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('runDebtRpc mengubah PostgrestException jadi DebtActionException dengan pesan server', () async {
    await expectLater(
      runDebtRpc<void>(() async {
        throw const PostgrestException(message: 'Jumlah bayar tidak boleh melebihi sisa utang!');
      }),
      throwsA(isA<DebtActionException>().having(
        (e) => e.message,
        'message',
        'Jumlah bayar tidak boleh melebihi sisa utang!',
      )),
    );
  });

  test('runDebtRpc meneruskan hasil bila sukses', () async {
    expect(await runDebtRpc(() async => 42), 42);
  });

  test('DebtActionException.toString hanya pesan', () {
    expect(const DebtActionException('Saldo dompet tidak mencukupi!').toString(),
        'Saldo dompet tidak mencukupi!');
  });
}
