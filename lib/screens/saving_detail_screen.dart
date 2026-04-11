import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavingDetailScreen extends StatefulWidget {
  final String savingName;
  const SavingDetailScreen({super.key, required this.savingName});

  @override
  State<SavingDetailScreen> createState() => _SavingDetailScreenState();
}

class _SavingDetailScreenState extends State<SavingDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<SavingModel> _history = [];
  double _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('savings')
          .select()
          .eq('user_id', userId)
          .ilike('name', widget.savingName)
          .order('created_at', ascending: false);

      double total = 0;
      List<SavingModel> loadedData = [];
      for (var item in res) {
        final saving = SavingModel.fromJson(item);
        loadedData.add(saving);
        total += saving.amount;
      }

      if (mounted) {
        setState(() {
          _history = loadedData;
          _currentBalance = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [UPDATE LOGIKA] Hapus Tabungan & Kembalikan Saldo Dompet
  Future<void> _deleteSaving(SavingModel item) async {
    try {
      final noteMarker = "[SAVING_ID:${item.id}]";
      
      // 1. Cari transaksi terkait buat ngecek ini pakai dompet mana
      final trxRes = await _supabase.from('transactions').select('id, amount, wallet_id').like('note', '%$noteMarker%').maybeSingle();

      if (trxRes != null && trxRes['wallet_id'] != null) {
        final walletId = trxRes['wallet_id'];
        final trxAmount = (trxRes['amount'] as num).toDouble(); // Nominal transaksi (selalu positif)
        
        // 2. Ambil saldo dompet saat ini
        final walletRes = await _supabase.from('wallets').select('balance').eq('id', walletId).single();
        double currentBal = (walletRes['balance'] as num).toDouble();
        
        // 3. Logika Refund: 
        // Jika setor (item.amount > 0), dompet dulu berkurang. Skrg dihapus -> Dompet Bertambah
        // Jika tarik (item.amount < 0), dompet dulu bertambah. Skrg dihapus -> Dompet Berkurang
        double refundAmount = item.amount > 0 ? trxAmount : -trxAmount;
        
        await _supabase.from('wallets').update({'balance': currentBal + refundAmount}).eq('id', walletId);
      }

      // 4. Hapus Transaksi & Data Tabungan
      await _supabase.from('transactions').delete().like('note', '%$noteMarker%');
      await _supabase.from('savings').delete().eq('id', item.id);
      
      _fetchDetail();
      if (mounted) AppNotification.success(context, "Data dihapus & Saldo Dompet dikembalikan!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data.");
    }
  }

  // [UX UPGRADE] Ubah Dialog jadi Bottom Sheet Modern
  void _showEditSheet(SavingModel saving) {
    bool isDeposit = saving.amount >= 0;
    final amountController = TextEditingController();
    final locationController = TextEditingController(text: saving.location ?? '');
    final notesController = TextEditingController(text: saving.notes ?? '');
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    
    amountController.text = currencyFormat.format(saving.amount.abs());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Edit ${isDeposit ? 'Setoran' : 'Tarikan'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Nominal", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: isDeposit ? Colors.black : Colors.orange),
                              decoration: InputDecoration(
                                hintText: "0",
                                filled: true, fillColor: Colors.grey.shade50,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 15, right: 10),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey))]),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF009688))),
                              ),
                              onChanged: (s) {
                                s = s.replaceAll(RegExp(r'[^0-9]'), '');
                                if (s.isNotEmpty) {
                                  amountController.value = TextEditingValue(text: currencyFormat.format(int.parse(s)), selection: TextSelection.collapsed(offset: currencyFormat.format(int.parse(s)).length));
                                }
                              },
                            ),
                            const SizedBox(height: 15),

                            Text("Tempat Simpan", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: locationController,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "Contoh: Bank BCA",
                                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                                filled: true, fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(PhosphorIconsFill.bank, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF009688))),
                              ),
                            ),
                            const SizedBox(height: 15),

                            Text("Catatan", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: notesController,
                              maxLines: 4, minLines: 1,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "Tulis catatan...",
                                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                                filled: true, fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(PhosphorIconsFill.notePencil, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF009688))),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009688),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          double rawAmount = double.parse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                          final finalAmount = isDeposit ? rawAmount : -rawAmount;

                          try {
                            // [UPDATE LOGIKA] Sesuaikan Ulang Saldo Dompet
                            final noteMarker = "[SAVING_ID:${saving.id}]";
                            final trxRes = await _supabase.from('transactions').select('id, amount, wallet_id').like('note', '%$noteMarker%').maybeSingle();

                            if (trxRes != null && trxRes['wallet_id'] != null) {
                              final walletId = trxRes['wallet_id'];
                              final oldTrxAmount = (trxRes['amount'] as num).toDouble();
                              
                              final walletRes = await _supabase.from('wallets').select('balance').eq('id', walletId).single();
                              double currentBal = (walletRes['balance'] as num).toDouble();
                              
                              // 1. Revert efek lama
                              double revertAmount = saving.amount > 0 ? oldTrxAmount : -oldTrxAmount;
                              double balanceAfterRevert = currentBal + revertAmount;
                              
                              // 2. Terapkan efek baru
                              double applyAmount = isDeposit ? rawAmount : -rawAmount;
                              double finalWalletBalance = balanceAfterRevert - applyAmount;
                              
                              await _supabase.from('wallets').update({'balance': finalWalletBalance}).eq('id', walletId);
                            }

                            // Update Transaksi & Tabungan
                            await _supabase.from('savings').update({
                              'amount': finalAmount,
                              'location': locationController.text.trim(),
                              'notes': notesController.text.trim(),
                            }).eq('id', saving.id);

                            await _supabase.from('transactions').update({'amount': rawAmount}).like('note', '%$noteMarker%');

                            if (context.mounted) {
                              Navigator.pop(context);
                              _fetchDetail();
                              AppNotification.success(context, "Perubahan disimpan!");
                            }
                          } catch (e) {
                            if (context.mounted) AppNotification.error(context, "Gagal update data.");
                          }
                        },
                        child: Text("Simpan Perubahan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.savingName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context, true)),
      ),
      body: Column(
        children: [
          // [UX UPGRADE] Kartu Total Saldo Jadi Premium Gradient
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF009688), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF009688).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Saldo Tabungan", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(_currentBalance),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsFill.piggyBank, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // LIST HISTORY
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final isWithdrawal = item.amount < 0;
                      final Color cardColor = isWithdrawal ? AppColors.expense : AppColors.income;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: cardColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: Icon(
                                isWithdrawal ? PhosphorIconsFill.arrowUpRight : PhosphorIconsFill.downloadSimple,
                                size: 24, color: cardColor,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isWithdrawal ? "Penarikan Dana" : "Setoran Tabungan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                  if (item.location != null && item.location!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(PhosphorIconsFill.mapPin, size: 12, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(item.location!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                  if (item.notes != null && item.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(item.notes!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt), style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  (isWithdrawal ? "- " : "+ ") + currency.format(item.amount.abs()),
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: cardColor, fontSize: 15),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showEditSheet(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.edit_outlined, color: Colors.blue, size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: Colors.white,
                                            title: Text("Hapus Histori?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                            content: Text("Catatan ini dihapus dan saldonya dikembalikan ke dompet.", style: GoogleFonts.poppins()),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteSaving(item);
                                                },
                                                child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}