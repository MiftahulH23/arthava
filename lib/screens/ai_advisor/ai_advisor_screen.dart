import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AiSessionManager {
  static final AiSessionManager _instance = AiSessionManager._internal();
  factory AiSessionManager() => _instance;
  AiSessionManager._internal();

  List<Map<String, dynamic>> messages = [];
  DateTime? lastActive;

  void clearSession() {
    messages.clear();
    lastActive = null;
  }
}

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String _financialContext = ""; 
  
  final _session = AiSessionManager(); 

  @override
  void initState() {
    super.initState();
    _fetchFinancialContext();
    _loadChatSession();
  }

  void _loadChatSession() {
    final now = DateTime.now();
    if (_session.lastActive != null && now.difference(_session.lastActive!).inMinutes < 10) {
      _messages.addAll(_session.messages);
    } else {
      _session.clearSession();
      final greeting = {
        'isUser': false,
        'text': "Halo bos! 👋 Aku Gemi. Aku udah dapet akses VIP ke seluruh brankas tabungan dan riwayat keuanganmu nih! Mau bahas target nabung atau cek pengeluaran hari ini?"
      };
      _messages.add(greeting);
      _session.messages.add(greeting);
      _session.lastActive = now;
    }
  }

  
 // [UPDATE BIKIN GEMI MAKIN PINTER] Rincian Tabungan & Dompet Dibongkar Habis!
  Future<void> _fetchFinancialContext() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final res = await _supabase
          .from('transactions')
          .select('amount, date, note, categories(name, is_expense)') 
          .eq('user_id', userId)
          .order('date', ascending: false);

      final savingsRes = await _supabase
          .from('savings')
          .select('name, amount')
          .eq('user_id', userId);

      // [NEW] Ambil Data Dompet Asli User
      final walletsRes = await _supabase
          .from('wallets')
          .select('name, balance')
          .eq('user_id', userId);

      double totalSavings = 0; 
      Map<String, double> savingsBreakdown = {};

      for (var row in savingsRes as List) {
        final amount = (row['amount'] as num).toDouble();
        final name = row['name']?.toString() ?? 'Tabungan Umum';
        
        totalSavings += amount;
        savingsBreakdown[name] = (savingsBreakdown[name] ?? 0) + amount;
      }

      // [NEW] Hitung Rincian Dompet
      double totalWalletBalance = 0;
      Map<String, double> walletBreakdown = {};
      for (var row in walletsRes as List) {
        final amount = (row['balance'] as num).toDouble();
        final name = row['name']?.toString() ?? 'Dompet Tak Bernama';
        totalWalletBalance += amount;
        walletBreakdown[name] = amount;
      }

      Map<String, Map<String, dynamic>> monthlyStats = {};
      double totalRawIncomeAllTime = 0;
      double totalRawExpenseAllTime = 0;

      for (var item in res) {
        final date = DateTime.parse(item['date']);
        final monthKey = DateFormat('MMMM yyyy', 'id_ID').format(date);
        
        if (!monthlyStats.containsKey(monthKey)) {
          monthlyStats[monthKey] = {
            'realIncome': 0.0,
            'realExpense': 0.0,
            'expenseByCategory': <String, double>{},
            'incomeByCategory': <String, double>{},
          };
        }

        final amount = (item['amount'] as num).toDouble();
        final isExpense = item['categories']['is_expense'] as bool;
        final catName = item['categories']['name'].toString();
        final note = item['note']?.toString() ?? '';

        final hasSavingMarker = note.contains('[SAVING_ID:');
        final isSystemCat = catName.toLowerCase().contains('tabung') || catName.toLowerCase().contains('cair');
        final isPureMutation = hasSavingMarker && isSystemCat;

        if (isExpense) {
          totalRawExpenseAllTime += amount;
        } else {
          totalRawIncomeAllTime += amount;
        }

        if (!isPureMutation) {
          if (isExpense) {
            monthlyStats[monthKey]!['realExpense'] += amount;
            monthlyStats[monthKey]!['expenseByCategory'][catName] = 
                (monthlyStats[monthKey]!['expenseByCategory'][catName] ?? 0) + amount;
          } else {
            monthlyStats[monthKey]!['realIncome'] += amount;
            monthlyStats[monthKey]!['incomeByCategory'][catName] = 
                (monthlyStats[monthKey]!['incomeByCategory'][catName] ?? 0) + amount;
          }
        }
      }

      final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
      
      String contextStr = "=== INFORMASI KEKAYAAN SAAT INI ===\n";
      // [NEW] Kasih tau Gemi saldo berdasarkan Dompet Fisik/Digital
      contextStr += "- Total Kekayaan (Semua Dompet): ${currency.format(totalWalletBalance)}\n";
      if (walletBreakdown.isNotEmpty) {
        contextStr += "- Rincian Posisi Uang (Dompet):\n";
        for (var wallet in walletBreakdown.entries) {
          contextStr += "  * ${wallet.key}: ${currency.format(wallet.value)}\n";
        }
      } else {
        contextStr += "  (Belum ada dompet yang dibuat)\n";
      }
      contextStr += "\n";
      
      contextStr += "=== RINCIAN TABUNGAN (TUJUAN KEUANGAN) ===\n";
      contextStr += "- Total Keseluruhan Tabungan: ${currency.format(totalSavings)}\n";
      
      var sortedSavings = savingsBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (sortedSavings.isEmpty || totalSavings <= 0) {
        contextStr += "  (Belum ada tabungan yang aktif)\n";
      } else {
        contextStr += "- Daftar Tujuan Tabungan:\n";
        for (var saving in sortedSavings) {
          if (saving.value > 0) { 
            contextStr += "  * ${saving.key}: ${currency.format(saving.value)}\n";
          }
        }
      }
      contextStr += "\n";
      
      contextStr += "=== REKAPAN KEUANGAN PER BULAN ===\n";
      
      int monthCount = 0;
      for (var entry in monthlyStats.entries) {
        if (monthCount >= 6) break;
        
        final monthName = entry.key;
        final stats = entry.value;
        
        contextStr += "[Bulan: $monthName]\n";
        contextStr += "- Total Pemasukan: ${currency.format(stats['realIncome'])}\n";
        contextStr += "- Total Pengeluaran: ${currency.format(stats['realExpense'])}\n";
        
        var sortedExpense = (stats['expenseByCategory'] as Map<String, double>).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (sortedExpense.isNotEmpty) {
          contextStr += "  * Rincian Pengeluaran:\n";
          for (var cat in sortedExpense) {
            contextStr += "    - ${cat.key}: ${currency.format(cat.value)}\n";
          }
        }
        
        var sortedIncome = (stats['incomeByCategory'] as Map<String, double>).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (sortedIncome.isNotEmpty) {
          contextStr += "  * Rincian Pemasukan:\n";
          for (var cat in sortedIncome) {
            contextStr += "    - ${cat.key}: ${currency.format(cat.value)}\n";
          }
        }
        contextStr += "\n";
        monthCount++;
      }

      _financialContext = contextStr;
      debugPrint("Kertas Contekan Multi-Bulan, Tabungan, & Dompet:\n$_financialContext");
    } catch (e) {
      _financialContext = "Data keuangan belum tersedia atau gagal dimuat.";
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': text});
      _isLoading = true;
    });
    
    _session.messages = List.from(_messages);
    _session.lastActive = DateTime.now();

    _chatController.clear();
    _scrollToBottom();

    final response = await GeminiService.askFinancialAdvisor(text, _financialContext);

    setState(() {
      _isLoading = false;
      if (response != null) {
        _messages.add({'isUser': false, 'text': response});
        
        _session.messages = List.from(_messages);
        _session.lastActive = DateTime.now();
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsFill.robot, color: Colors.indigo, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AI Advisor", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black), overflow: TextOverflow.ellipsis),
                  Text("Gemi - Siap bantu atur duitmu!", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.broom),
            tooltip: "Mulai Chat Baru",
            onPressed: () {
              setState(() {
                _session.clearSession();
                _messages.clear();
                _loadChatSession();
              });
              AppNotification.success(context, "Sesi chat diulang!");
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 5),
                        bottomRight: Radius.circular(isUser ? 5 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: isUser 
                      ? Text(
                          msg['text'],
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                        )
                      : MarkdownBody(
                          data: msg['text'],
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                            strong: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
                            listBullet: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo)),
                      const SizedBox(width: 10),
                      Text("Gemi sedang menganalisa...", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Tanya soal keuanganmu...",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.grey : Colors.indigo,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}