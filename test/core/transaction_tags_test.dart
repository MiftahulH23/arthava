import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mutasi tabungan butuh tag DAN kategori tabung/cair (perilaku lama)', () {
    expect(isSavingMutation('Setor [SAVING_ID:3]', 'Tabungan'), isTrue);
    expect(isSavingMutation('Cair [SAVING_ID:3]', 'Pencairan'), isTrue);
    expect(isSavingMutation('Beli [SAVING_ID:3]', 'Makan'), isFalse);
    expect(isSavingMutation('Setor', 'Tabungan'), isFalse);
    expect(isSavingMutation(null, null), isFalse);
  });

  test('mutasi utang cukup tag, termasuk penanda legacy', () {
    expect(isDebtMutation('Bayar utang ke Budi [DEBT_ID:12]'), isTrue);
    expect(isDebtMutation('Pinjaman lama [DEBT_ID:legacy]'), isTrue);
    expect(isDebtMutation('Makan siang'), isFalse);
    expect(isDebtMutation(null), isFalse);
  });

  test('isInternalMutation menggabungkan keduanya', () {
    expect(isInternalMutation('x [DEBT_ID:1]', 'Sistem: Uang Keluar (Utang/Piutang)'), isTrue);
    expect(isInternalMutation('x [SAVING_ID:1]', 'Tabungan'), isTrue);
    expect(isInternalMutation('x', 'Makan'), isFalse);
  });

  test('strip tag membersihkan teks catatan', () {
    expect(stripDebtTag('Bayar utang ke Budi [DEBT_ID:12]'), 'Bayar utang ke Budi');
    expect(stripTransactionTags('Setor [SAVING_ID:3] [DEBT_ID:legacy]'), 'Setor');
    expect(stripTransactionTags(null), '');
    expect(debtTag(12), '[DEBT_ID:12]');
  });
}
