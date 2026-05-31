import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebtDetailScreen extends StatefulWidget {
  final int debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _debt;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _wallets = [];

  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final resDebt = await _supabase
          .from('debts')
          .select()
          .eq('id', widget.debtId)
          .eq('user_id', userId)
          .maybeSingle();

      if (resDebt == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final resPayments = await _supabase
          .from('debt_payments')
          .select('*, wallets(name)')
          .eq('debt_id', widget.debtId)
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      final resWallets =
          await _supabase.from('wallets').select().eq('user_id', userId);

      if (mounted) {
        setState(() {
          _debt = resDebt;
          _payments = List<Map<String, dynamic>>.from(resPayments);
          _wallets = List<Map<String, dynamic>>.from(resWallets);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching debt detail: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPaymentSheet(BuildContext context) {
    if (_debt == null) return;
    
    final remainingAmount = (_debt!['remaining_amount'] as num).toDouble();
    if (remainingAmount <= 0) {
      AppNotification.success(context, "Utang ini sudah lunas!");
      return;
    }

    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool affectWallet = false;
    int? selectedWalletId;
    final isPayable = _debt!['type'] == 'payable';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPayable ? "Bayar Cicilan Utang" : "Terima Pembayaran",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(PhosphorIconsRegular.x),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Sisa Tagihan Saat Ini",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            currencyFormat.format(remainingAmount),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isPayable ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Jumlah Uang",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            "Rp",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        final s = val.replaceAll(RegExp(r'[^0-9]'), '');
                        if (s.isNotEmpty) {
                          final formatted = currencyFormat.format(int.parse(s));
                          amountController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      "Tanggal Pembayaran",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setSheetState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.calendarBlank,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Opsi Sinkron Dompet
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "Catat ke Dompet?",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: affectWallet,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setSheetState(() => affectWallet = val);
                                },
                              ),
                            ],
                          ),
                          if (affectWallet) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              value: selectedWalletId,
                              hint: Text(
                                "Pilih Dompet",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                              ),
                              items: _wallets.map((w) {
                                return DropdownMenuItem<int>(
                                  value: w['id'],
                                  child: Text(
                                    w['name'],
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setSheetState(() => selectedWalletId = val);
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isPayable
                                  ? "Info: Saldo dompet akan BERKURANG karena Anda membayar utang."
                                  : "Info: Saldo dompet akan BERTAMBAH karena Anda menerima pembayaran.",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          if (amountController.text.isEmpty) return;
                          
                          if (affectWallet && selectedWalletId == null) {
                            AppNotification.error(
                              context,
                              "Silakan pilih dompet!",
                            );
                            return;
                          }

                          final rawAmount = double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );

                          if (rawAmount > remainingAmount) {
                            AppNotification.error(
                              context,
                              "Jumlah bayar tidak boleh melebihi sisa utang!",
                            );
                            return;
                          }

                          try {
                            final userId = _supabase.auth.currentUser!.id;
                            
                            if (affectWallet && selectedWalletId != null) {
                              final w = _wallets.firstWhere((w) => w['id'] == selectedWalletId);
                              final currentBalance = (w['balance'] as num).toDouble();
                              double newBalance = currentBalance;
                              if (isPayable) {
                                if (currentBalance < rawAmount) {
                                  AppNotification.error(context, "Saldo dompet tidak mencukupi!");
                                  return;
                                }
                                newBalance = currentBalance - rawAmount;
                              } else {
                                newBalance = currentBalance + rawAmount;
                              }
                              
                              await _supabase.from('wallets').update({
                                'balance': newBalance
                              }).eq('id', selectedWalletId!);
                              
                              final catRes = await _supabase.from('categories').select().eq('user_id', userId).eq('name', 'Sistem: Utang/Piutang').maybeSingle();
                              int? sysCatId;
                              if (catRes == null) {
                                final insertedCat = await _supabase.from('categories').insert({
                                  'user_id': userId,
                                  'name': 'Sistem: Utang/Piutang',
                                  'icon': 'PhosphorIconsFill.handCoins',
                                  'color': '#009688',
                                  'is_expense': isPayable, 
                                }).select().single();
                                sysCatId = insertedCat['id'];
                              } else {
                                sysCatId = catRes['id'];
                              }
                              
                              await _supabase.from('transactions').insert({
                                'user_id': userId,
                                'wallet_id': selectedWalletId,
                                'category_id': sysCatId,
                                'amount': rawAmount,
                                'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                                'note': isPayable ? 'Bayar utang ke ${_debt!['name']}' : 'Menerima bayaran dari ${_debt!['name']}'
                              });
                            }

                            // Insert payment record
                            await _supabase.from('debt_payments').insert({
                              'debt_id': widget.debtId,
                              'user_id': userId,
                              'wallet_id': selectedWalletId,
                              'amount': rawAmount,
                              'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                            });

                            // Update remaining amount and status
                            final newRemaining = remainingAmount - rawAmount;
                            await _supabase.from('debts').update({
                              'remaining_amount': newRemaining,
                              'status': newRemaining <= 0 ? 'paid' : 'active',
                            }).eq('id', widget.debtId);

                            if (context.mounted) {
                              Navigator.pop(context);
                              _fetchDetail();
                              AppNotification.success(
                                context,
                                "Pembayaran berhasil dicatat!",
                              );
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                            if (context.mounted) {
                              AppNotification.error(context, "Terjadi kesalahan sistem");
                            }
                          }
                        },
                        child: Text(
                          "Simpan",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

  Future<void> _deleteDebt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("Hapus Catatan?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text("Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen. Saldo dompet tidak akan dikembalikan otomatis.", style: GoogleFonts.poppins(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Batal", style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Hapus", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _supabase.from('debts').delete().eq('id', widget.debtId);
      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(context, "Data berhasil dihapus!");
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_debt == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text("Data tidak ditemukan.")),
      );
    }

    final isPayable = _debt!['type'] == 'payable';
    final amount = (_debt!['amount'] as num).toDouble();
    final remaining = (_debt!['remaining_amount'] as num).toDouble();
    final paid = amount - remaining;
    final isPaid = _debt!['status'] == 'paid' || remaining <= 0;
    final percentage = amount > 0 ? (paid / amount) : 0.0;
    final mainColor = isPayable ? Colors.red : Colors.green;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: mainColor,
        title: Text(
          isPayable ? "Detail Utang" : "Detail Piutang",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _deleteDebt,
            icon: const Icon(PhosphorIconsRegular.trash),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER BOX
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: mainColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPayable ? PhosphorIconsFill.handCoins : PhosphorIconsFill.handHeart,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _debt!['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (isPaid)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "LUNAS",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    )
                  else if (_debt!['due_date'] != null)
                    Text(
                      "Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(DateTime.parse(_debt!['due_date']))}",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  // Stats Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total Awal",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(amount),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Sisa Tagihan",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(remaining),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid ? Colors.green : mainColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isPaid ? Colors.green : mainColor,
                            ),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${(percentage * 100).toStringAsFixed(1)}% Terbayar",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Payment History List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Riwayat Cicilan",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            if (_payments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  "Belum ada riwayat pembayaran.",
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final pay = _payments[index];
                  final payAmount = (pay['amount'] as num).toDouble();
                  final walletName = pay['wallets'] != null ? pay['wallets']['name'] : 'Tanpa Dompet';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPayable ? Colors.green.shade50 : Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPayable ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown,
                            color: isPayable ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(DateTime.parse(pay['date'])),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                walletName,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(payAmount),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
      floatingActionButton: !isPaid ? FloatingActionButton.extended(
        onPressed: () => _showAddPaymentSheet(context),
        backgroundColor: mainColor,
        icon: const Icon(PhosphorIconsBold.money, color: Colors.white),
        label: Text(
          isPayable ? "Bayar Cicilan" : "Terima Pembayaran",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
