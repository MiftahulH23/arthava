import 'dart:convert';
import 'package:catat_uang_app/core/env.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class GeminiService {
  static String get _apiKey {
    if (!Env.hasGemini) {
      throw Exception('Fitur AI belum aktif: GEMINI_API_KEY belum diisi di env.json.');
    }
    return Env.geminiApiKey;
  }

  static Future<Map<String, dynamic>?> scanReceipts(
    List<XFile> imageFiles,
  ) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

      // Siapkan keranjang buat nampung Teks + Semua Gambar
      List<Part> promptParts = [];

      // Mantra yang lebih luwes untuk 1 atau banyak struk
      final promptText =
          '''
        Kamu adalah asisten keuangan dan akuntan cerdas. 
        Saya memberikanmu ${imageFiles.length} foto struk belanja.
        
        Tugasmu:
        1. Baca total harga akhir dari setiap struk.
        2. Jika ada lebih dari 1 struk, JUMLAHKAN semuanya menjadi satu angka GRAND TOTAL. Jika hanya 1 struk, berikan total dari struk tersebut.
        3. Tentukan kategori pengeluaran secara umum. Pilih salah satu: Makanan, Transportasi, Kesehatan, Hiburan, Belanja, atau Umum.
        
        KEMBALIKAN HANYA FORMAT JSON SEPERTI DI BAWAH INI, TANPA TEKS APAPUN SEBELUM ATAU SESUDAHNYA!
        {
          "total": 150000,
          "kategori": "Belanja"
        }
      ''';

      promptParts.add(TextPart(promptText));

      // Masukin semua gambar yang dipilih user ke dalam keranjang pengiriman
      for (var file in imageFiles) {
        final bytes = await file.readAsBytes();
        promptParts.add(DataPart('image/jpeg', bytes));
      }

      // Kirim ke Google Server
      final response = await model.generateContent([
        Content.multi(promptParts),
      ]);

      final rawText = response.text ?? '{}';
      debugPrint(
        "RAW RESPONSE AI: $rawText",
      ); // Biar gampang di-track di terminal VS Code

      // [FIX UTAMA] Ekstrak JSON secara paksa pakai Regex!
      // Jadi kalau AI jawab "Berikut hasilnya: {total: 5000}", kita cuma ambil "{total: 5000}"-nya aja.
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
      final cleanText = match != null ? match.group(0)! : '{}';

      final Map<String, dynamic> data = jsonDecode(cleanText);
      return data;
    } catch (e) {
      debugPrint("Error Gemini AI: $e");
      // Lempar pesan error aslinya ke layar HP biar kita nggak nebak-nebak
      throw Exception("AI Error: $e");
    }
  }

  static Future<String?> askFinancialAdvisor(
    String question,
    String financialContext,
  ) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      // Ini "Mantra" (System Prompt) biar AI-nya punya kepribadian dan pintar
      final promptText =
          '''
Kamu adalah "Gemi", seorang AI Financial Advisor (Konsultan Keuangan Pribadi) yang cerdas, ramah, dan asik.
Gaya bahasamu santai, profesional, dan mudah dimengerti (gunakan sapaan "aku/kamu" atau "gue/lu" yang asik).

Berikut adalah RINGKASAN DATA KEUANGAN USER sebagai konteksmu:
$financialContext

Tugasmu:
1. Jawab pertanyaan user BERDASARKAN data keuangan di atas.
2. Jika user bertanya apakah uangnya cukup untuk membeli sesuatu, Cek "Rincian Posisi Uang (Dompet)" untuk melihat di dompet mana uangnya cukup, dan berikan saran bayar pakai apa.
3. Berikan analisa, kritik membangun (roasting halus jika boros), atau pujian jika hemat.
4. Berikan tips keuangan yang praktis.
5. Jika user bertanya hal di luar topik keuangan/produktivitas, tolak dengan sopan dan arahkan kembali ke topik keuangan.

Pertanyaan User: "$question"
''';

      final response = await model.generateContent([Content.text(promptText)]);

      return response.text;
    } catch (e) {
      debugPrint("Error Gemini Advisor: $e");
      return "Waduh bos, sistemku lagi agak error nih. Coba lagi nanti ya! 🙏\n(Error: $e)";
    }
  }
}
