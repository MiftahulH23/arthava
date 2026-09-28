import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF007AFF); // Biru sistem iOS (hero card, tombol utama)
  static const Color background = Color(0xFFF2F2F7); // Abu-abu netral grouped background iOS
  static const Color white = Colors.white;
  static const Color income = Color(0xFF2E9E68); // Hijau, dibedakan dari primary
  static const Color expense = Color(0xFFE0564F); // Merah soft
  static const Color incomeSoft = Color(0xFFE3F4EB); // Latar lembut hijau (toast sukses)
  static const Color expenseSoft = Color(0xFFFCE5E3); // Latar lembut merah (toast error)
  static const Color textPrimary = Color(0xFF1C1C1E); // Hitam iOS
  static const Color textSecondary = Color(0xFF8E8E93); // Abu-abu iOS
  static const Color accent = Color(0xFFFF9500); // Oranye hangat, aksen pelengkap
  static const Color heroGradientStart = Color(0xFF0071E3); // Awal gradasi hero card
  static const Color heroGradientEnd = Color(0xFF0047AB); // Akhir gradasi hero card
  static const Color heroLabel = Color(0xE0FFFFFF); // Putih 88% untuk label kecil di hero card (white70 kurang kontras)

  // --- Phase B (spec §4.1) ---
  static const Color surface = Color(0xFFFFFFFF); // Kartu, grouped list, field
  static const Color track = Color(0xFFE5E5EA); // Track segmented/progress, switch off
  static const Color separator = Color(0xFFD8D8DD); // Garis pemisah baris grouped list
  static const Color primarySoft = Color(0xFFE5F1FF); // Latar tombol soft, callout info
  static const Color focusRing = Color(0x21007AFF); // Cincin fokus isian bergaris tepi (biru 13%)
  static const Color accentSoft = Color(0xFFFFF1DC); // Callout rekomendasi, chip tempo
  static const Color tintRed = Color(0xFFE0564F);
  static const Color tintOrange = Color(0xFFF0913A); // Peringatan >80%, tombol Transfer/Tarik
  static const Color tintAmber = Color(0xFFD9A21B);
  static const Color tintTeal = Color(0xFF2FA39A); // Chip "Mutasi Internal"
  static const Color tintBlue = Color(0xFF4A7FE0); // Tombol edit (pensil)
  static const Color tintIndigo = Color(0xFF6A67CE);
  static const Color tintPink = Color(0xFFD8578C);
  static const Color tintBrown = Color(0xFF8A5A44);
  static const Color tintGreen = Color(0xFF2E9E68);
  static const Color tintSky = Color(0xFF3AA6D8);
  static const Color tintGray = Color(0xFF8E8E93); // Ikon netral (mutasi internal)

  // Logo "G" tombol Google (warna merek resmi).
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  // Statistik kecil di kartu hero Beranda (pastel supaya terbaca di atas gradasi biru).
  static const Color heroStatIncome = Color(0xFF9BF0C4);
  static const Color heroStatExpense = Color(0xFFFFB4AE);
  static const Color heroStatSavings = Color(0xFFBFE6FF);
  static const Color heroStatInvest = Color(0xFFFFD28A);

  // Pilihan warna dompet. Disimpan sebagai string hex di kolom wallets.color,
  // jadi urutan & nilainya jangan diubah (data lama merujuk ke nilai ini).
  static const List<String> walletColorChoices = [
    '#1E3A8A', '#00796B', '#5E35B1', '#E65100',
    '#C62828', '#2E7D32', '#37474F', '#E91E63',
  ];

  /// Warna dompet dari string hex di data (mis. "#1E3A8A"); nilai null/rusak
  /// jatuh ke pilihan pertama, sama seperti fallback layar lama.
  static Color fromWalletHex(String? hex) {
    final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
    if (value == null || (hex ?? '').replaceFirst('#', '').length != 6) {
      return const Color(0xFF1E3A8A);
    }
    return Color(0xFF000000 | value);
  }
}
