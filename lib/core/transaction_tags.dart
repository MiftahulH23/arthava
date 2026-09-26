/// Penanda di `transactions.note` untuk transaksi yang memindahkan uang
/// tanpa menjadi pemasukan/pengeluaran sungguhan. Satu-satunya tempat logika
/// ini — screen/provider lain wajib memanggil helper di sini.
library;

final RegExp _savingTag = RegExp(r'\s*\[SAVING_ID:[^\]]*\]');
final RegExp _debtTag = RegExp(r'\s*\[DEBT_ID:[^\]]*\]');

/// Mutasi tabungan: bertag `[SAVING_ID:` dan kategori sistem tabungan
/// (nama mengandung "tabung"/"cair"). Sama persis dengan cek lama di tiap provider.
bool isSavingMutation(String? note, String? categoryName) {
  final n = note ?? '';
  final c = (categoryName ?? '').toLowerCase();
  return n.contains('[SAVING_ID:') && (c.contains('tabung') || c.contains('cair'));
}

/// Transaksi dari fitur Utang & Piutang (termasuk data lama bertanda `legacy`).
bool isDebtMutation(String? note) => (note ?? '').contains('[DEBT_ID:');

bool isInternalMutation(String? note, String? categoryName) =>
    isSavingMutation(note, categoryName) || isDebtMutation(note);

String stripDebtTag(String? note) => (note ?? '').replaceAll(_debtTag, '').trim();

String stripTransactionTags(String? note) =>
    (note ?? '').replaceAll(_savingTag, '').replaceAll(_debtTag, '').trim();

String debtTag(int debtId) => '[DEBT_ID:$debtId]';
