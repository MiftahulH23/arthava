import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Helper standar untuk menampilkan bottom sheet aplikasi, membungkus
/// [showFSheet] milik forui dengan konfigurasi yang konsisten (dari
/// bawah layar, bisa di-drag, mengikuti tema global).
///
/// Ganti semua pemanggilan `showModalBottomSheet` di screen dengan ini
/// supaya padding/radius/drag-handle konsisten di semua screen.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showFSheet<T>(
    context: context,
    side: FLayout.btt,
    builder: builder,
  );
}
