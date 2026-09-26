import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tolakan server (pesan aslinya ditampilkan apa adanya), mis. "Saldo dompet
/// tidak mencukupi!" atau "Dompet tidak ditemukan.".
class ZakatRejection implements Exception {
  const ZakatRejection(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Bayar zakat maal / sedekah dari dompet. Satu transaksi database (RPC
/// `pay_zakat_sedekah`, migration 202609260008): kategori, transaksi, dan
/// potong saldo sekaligus — dulu layar membaca saldo lalu menulis saldo baru.
class ZakatService {
  ZakatService(this._db);

  final SupabaseClient _db;

  /// Tolakan server dilempar sebagai [ZakatRejection]; galat lain apa adanya.
  Future<void> pay({
    required bool isZakat,
    required int walletId,
    required double amount,
    required String note,
  }) async {
    try {
      await _db.rpc('pay_zakat_sedekah', params: {
        'p_is_zakat': isZakat,
        'p_wallet_id': walletId,
        'p_amount': amount,
        'p_note': note,
        'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw ZakatRejection(e.message);
      rethrow;
    }
  }
}
