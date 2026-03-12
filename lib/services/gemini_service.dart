import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyBHB1wrOJcJ8Ucy-z7IDWKPBHpjWBcdXhk';

  static Future<Map<String, dynamic>?> scanReceipt(XFile imageFile) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      // PROMPT SAKTI VERSI 2.0 (Minta JSON)
      final prompt = TextPart('''
        Kamu adalah asisten keuangan cerdas. 
        Tugasmu menganalisa foto struk belanja ini dan mengembalikan data dalam format JSON murni.
        
        Carilah:
        1. "total": Angka total harga akhir (Grand Total) yang harus dibayar. (Hanya angka, tanpa titik/koma/Rp).
        2. "kategori": Analisa barang yang dibeli (misal: indomie, beras, minyak) dan tentukan ini masuk kategori apa. Pilih salah satu dari nama ini: Makanan, Transportasi, Kesehatan, Hiburan, Belanja, atau Umum.
        
        WAJIB kembalikan format JSON murni seperti ini tanpa teks lain, tanpa awalan ```json:
        {
          "total": 50000,
          "kategori": "Makanan"
        }
      ''');

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      // Bersihkan teks balasan AI dari sisa-sisa markdown (kalau ada)
      final rawText = response.text ?? '{}';
      final cleanText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Ubah teks JSON jadi Map (Data Flutter)
      final Map<String, dynamic> data = jsonDecode(cleanText);
      return data;

    } catch (e) {
      debugPrint("Error Gemini AI: $e");
      return null;
    }
  }
}