import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Selector tab standar aplikasi, membungkus [FTabs] milik forui.
///
/// Dibuat khusus untuk konsistensi tab lintas screen — sebelumnya
/// setiap screen bikin tab manual sendiri-sendiri (Row + GestureDetector)
/// dengan tampilan yang berbeda-beda. Pakai widget ini, jangan bikin
/// tab manual lagi di screen baru.
///
/// Catatan implementasi: forui 0.17.0 tidak mengekspos konstruktor publik
/// `FTabController(vsync: ...)` / `FTabManagedControl(controller: ...)`
/// seperti yang diasumsikan awalnya (`FTabController` butuh `vsync` dari
/// `TickerProvider` yang harus datang dari `FTabs` sendiri, bukan dari
/// widget pembungkus ini). forui menyediakan mode "lifted" yang lebih
/// simpel lewat `FTabControl.lifted(index:, onChange:)` — index tab
/// dikontrol sepenuhnya oleh parent (lihat
/// lib/src/widgets/tabs/tab_controller.dart), jadi [AppTabSelector] cukup
/// jadi StatelessWidget tanpa perlu mengelola TickerProvider/controller
/// sendiri.
class AppTabSelector extends StatelessWidget {
  final List<String> labels;
  final int initialIndex;
  final ValueChanged<int> onChanged;

  const AppTabSelector({
    required this.labels,
    required this.initialIndex,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FTabs(
      control: FTabControl.lifted(index: initialIndex, onChange: onChanged),
      children: [
        for (final label in labels) FTabEntry.entry(label: Text(label), child: const SizedBox.shrink()),
      ],
    );
  }
}
