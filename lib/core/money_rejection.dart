/// Tolakan aturan uang dari server (RAISE P0001), mis. "Saldo dompet BCA tidak
/// cukup! Bisa dipakai: Rp 5.000". Layar menampilkan [message] apa adanya.
class MoneyRejection implements Exception {
  const MoneyRejection(this.message);
  final String message;

  @override
  String toString() => message;
}
