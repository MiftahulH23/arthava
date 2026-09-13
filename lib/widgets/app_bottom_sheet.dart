import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Helper standar untuk menampilkan bottom sheet aplikasi, membungkus
/// [showFSheet] milik forui dengan konfigurasi yang konsisten (muncul dari
/// bawah layar, bisa ditutup dengan gestur drag ke bawah — forui tidak
/// menggambar elemen handle yang terlihat, jadi jangan berasumsi ada
/// garis handle di atas sheet — dan mengikuti tema global).
///
/// Ganti semua pemanggilan `showModalBottomSheet` di screen dengan ini
/// supaya padding/radius/perilaku konsisten di semua screen.
///
/// `mainAxisMaxRatio: null` mematikan batas tinggi 9/16 bawaan forui, dan
/// isi sheet dibatasi setinggi layar dikurangi inset keyboard supaya tombol
/// submit di bagian bawah tidak tertutup keyboard saat sedang mengetik.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showFSheet<T>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: null,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(child: builder(context)),
    ),
  );
}
