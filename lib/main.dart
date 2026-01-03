import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/theme_mode_manager.dart'; // Import Manager Tema
import 'package:catat_uang_app/screens/home_screen.dart';
import 'package:catat_uang_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pastikan URL dan Key Supabase kamu sudah benar di sini
  await Supabase.initialize(
   url: 'https://rsqdexzywegorsgmledp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzcWRleHp5d2Vnb3JzZ21sZWRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NTY0NDEsImV4cCI6MjA4MTUzMjQ0MX0.4UpocbbB-OUiTPEw0BLwc1DzMhcX13VboP4USN8ZYR0',
  );

  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cek user login (Logic lama tetap ada)
    final user = Supabase.instance.client.auth.currentUser;

    // 1. Bungkus dengan ValueListenableBuilder agar bisa ganti tema real-time
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DompetKu',

          // 2. Pasang Mode Tema Dinamis
          themeMode: currentMode,

          // === TEMA TERANG (LIGHT) ===
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: AppColors.primary,
            useMaterial3: true,
            // Pengaturan Warna Komponen (Card, Dialog, dll ikut 'surface')
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              surface: Colors
                  .white, // [FIX] Ini bikin Card jadi Putih (Gak perlu CardTheme)
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black, // Warna Icon/Text AppBar
              elevation: 0,
            ),
          ),

          // === TEMA GELAP (DARK) ===
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212), // Hitam pekat
            primaryColor: AppColors.primary,
            useMaterial3: true,
            // Pengaturan Warna Komponen Dark Mode
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
              surface: const Color(
                0xFF1E1E1E,
              ), // [FIX] Ini bikin Card jadi Abu Gelap
            ),
            // Sesuaikan Text agar warna putih di dark mode
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            // Bottom Sheet & Dialog ikut warna surface
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),

          // 3. Konfigurasi Bahasa (Tetap Ada)
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],

          // 4. Navigasi Awal
          home: user != null ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
