import 'package:flutter/material.dart';

// Variabel global untuk menyimpan status tema
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Fungsi untuk mengganti tema (Dipanggil dari Settings)
void toggleTheme(bool isDark) {
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}
