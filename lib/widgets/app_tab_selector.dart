import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Selector tab standar aplikasi, membungkus [FTabs] milik forui.
///
/// Dibuat khusus untuk konsistensi tab lintas screen — sebelumnya
/// setiap screen bikin tab manual sendiri-sendiri (Row + GestureDetector)
/// dengan tampilan yang berbeda-beda. Pakai widget ini, jangan bikin
/// tab manual lagi di screen baru.
///
/// Catatan implementasi: widget ini memakai `FTabControl.managed(initial:,
/// onChange:)`, BUKAN `FTabControl.lifted(index:, onChange:)`. Mode `lifted`
/// membuat index tab dikontrol sepenuhnya oleh parent — seleksi visualnya
/// tidak pernah berpindah sendiri setelah di-tap kecuali parent mengirim
/// balik `index` baru lewat rebuild. Itu bertentangan dengan nama parameter
/// [initialIndex] yang mengesankan widget ini mengelola state-nya sendiri.
/// Mode `managed` membuat forui mengelola controller-nya sendiri di dalam,
/// jadi tap langsung memindahkan seleksi visual sekaligus tetap memanggil
/// [onChanged] untuk pemanggil di luar.
class AppTabSelector extends StatelessWidget {
  final List<String> labels;
  final int initialIndex;
  final ValueChanged<int> onChanged;

  /// Warna latar indikator tab terpilih untuk instance ini saja, mengganti
  /// warna default dari tema global. Dipakai oleh screen yang punya sinyal
  /// warna dinamis (mis. merah untuk pengeluaran, hijau untuk pemasukan).
  final Color? activeColor;

  const AppTabSelector({
    required this.labels,
    required this.initialIndex,
    required this.onChanged,
    this.activeColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FTabs(
      control: FTabControl.managed(initial: initialIndex, onChange: onChanged),
      style: activeColor == null
          ? null
          : (style) => style.copyWith(
                indicatorDecoration: style.indicatorDecoration.copyWith(color: activeColor),
                selectedLabelTextStyle: style.selectedLabelTextStyle.copyWith(color: Colors.white),
              ),
      children: [
        for (final label in labels) FTabEntry.entry(label: Text(label), child: const SizedBox.shrink()),
      ],
    );
  }
}
