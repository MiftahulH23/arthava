import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'debt_detail_screen.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isMyDebt = true;

  bool _isLoading = true;
  List<Map<String, dynamic>> _myDebts = [];
  List<Map<String, dynamic>> _theirDebts = [];

  List<Map<String, dynamic>> _wallets = [];

  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final inputFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final resWallets =
          await _supabase.from('wallets').select().eq('user_id', userId);

      final resDebts = await _supabase
          .from('debts')
          .select()
          .eq('user_id', userId)
          .order('status', ascending: true) // 'active' comes before 'paid'
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> myDebts = [];
      List<Map<String, dynamic>> theirDebts = [];

      for (var item in resDebts as List) {
        if (item['type'] == 'payable') {
          myDebts.add(Map<String, dynamic>.from(item));
        } else {
          theirDebts.add(Map<String, dynamic>.from(item));
        }
      }

      if (mounted) {
        setState(() {
          _wallets = List<Map<String, dynamic>>.from(resWallets);
          _myDebts = myDebts;
          _theirDebts = theirDebts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching debts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDebtSheet(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate;
    String debtType = _isMyDebt ? 'payable' : 'receivable';
    bool affectWallet = false;
    int? selectedWalletId;

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
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
                          "Catat Utang / Piutang",
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
                    const SizedBox(height: 20),

                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => debtType = 'payable'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: debtType == 'payable' ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: debtType == 'payable' ? [
                                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Utang",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: debtType == 'payable' ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => debtType = 'receivable'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: debtType == 'receivable' ? Colors.green : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: debtType == 'receivable' ? [
                                    BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Piutang",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: debtType == 'receivable' ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Nama Peminjam / Pemberi Pinjaman",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: debtType == 'payable'
                            ? "Contoh: Budi, Bank, dll"
                            : "Contoh: Andi, Teman, dll",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                          final formatted = inputFormat.format(int.parse(s)).trim();
                          amountController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        } else {
                          amountController.value = const TextEditingValue(text: '');
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Jatuh Tempo (Opsional)",
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
                          initialDate: DateTime.now(),
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
                              selectedDate == null
                                  ? "Pilih Tanggal Jatuh Tempo"
                                  : DateFormat('dd MMM yyyy')
                                      .format(selectedDate!),
                              style: GoogleFonts.poppins(
                                color: selectedDate == null
                                    ? Colors.grey
                                    : Colors.black,
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
                                  "Catat transaksi ini ke Dompet?",
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
                              debtType == 'payable'
                                  ? "Info: Saldo dompet akan BERTAMBAH karena Anda menerima uang pinjaman."
                                  : "Info: Saldo dompet akan BERKURANG karena Anda meminjamkan uang.",
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
                          if (nameController.text.trim().isEmpty) {
                            AppNotification.error(
                              context,
                              "Nama tidak boleh kosong!",
                            );
                            return;
                          }
                          if (amountController.text.isEmpty) {
                            AppNotification.error(
                              context,
                              "Jumlah tidak boleh kosong!",
                            );
                            return;
                          }
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

                          try {
                            final userId = _supabase.auth.currentUser!.id;
                            
                            if (affectWallet && selectedWalletId != null) {
                              final w = _wallets.firstWhere((w) => w['id'] == selectedWalletId);
                              final currentBalance = (w['balance'] as num).toDouble();
                              double newBalance = currentBalance;
                              if (debtType == 'payable') {
                                newBalance = currentBalance + rawAmount;
                              } else {
                                if (currentBalance < rawAmount) {
                                  AppNotification.error(context, "Saldo dompet tidak mencukupi untuk dipinjamkan!");
                                  return;
                                }
                                newBalance = currentBalance - rawAmount;
                              }
                              
                              await _supabase.from('wallets').update({
                                'balance': newBalance
                              }).eq('id', selectedWalletId!);
                              
                              // Create Transaction history for the wallet
                              // We should find a category or create a system category for debt
                              bool isExp = debtType == 'receivable';
                              String catName = isExp ? 'Utang/Piutang' : 'Utang/Piutang';
                              final catRes = await _supabase.from('categories').select().eq('user_id', userId).eq('name', catName).maybeSingle();
                              int? sysCatId;
                              if (catRes == null) {
                                final insertedCat = await _supabase.from('categories').insert({
                                  'user_id': userId,
                                  'name': catName,
                                  'icon_name': 'bank',
                                  'is_expense': isExp, 
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
                                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                'note': debtType == 'payable' ? 'Pinjaman diterima dari ${nameController.text.trim()}' : 'Memberi pinjaman ke ${nameController.text.trim()}'
                              });
                            }

                            await _supabase.from('debts').insert({
                              'user_id': userId,
                              'name': nameController.text.trim(),
                              'type': debtType,
                              'amount': rawAmount,
                              'remaining_amount': rawAmount,
                              'due_date': selectedDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(selectedDate!)
                                  : null,
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              _fetchData();
                              AppNotification.success(
                                context,
                                "Utang/Piutang berhasil dicatat!",
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

  Widget _buildDebtList(List<Map<String, dynamic>> debts, String emptyMsg) {
    if (debts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.handCoins,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        final amount = (debt['amount'] as num).toDouble();
        final remaining = (debt['remaining_amount'] as num).toDouble();
        final paid = amount - remaining;
        final percentage = amount > 0 ? (paid / amount) : 0.0;
        final isPaid = debt['status'] == 'paid' || remaining <= 0;
        
        final isPayable = debt['type'] == 'payable';
        final mainColor = isPayable ? Colors.red : Colors.green;
        final label = isPayable ? "Saya berutang ke:" : "Piutang dari:";

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DebtDetailScreen(debtId: debt['id']),
              ),
            );
            _fetchData();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "LUNAS",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )
                    else if (debt['due_date'] != null)
                      Text(
                        "Tempo: ${DateFormat('dd MMM yyyy').format(DateTime.parse(debt['due_date']))}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  debt['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Uang",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currencyFormat.format(amount),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isPaid ? "Sudah lunas" : "Sisa Tagihan",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currencyFormat.format(remaining),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
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
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "Utang & Piutang",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _buildToggleBtn("Utang Saya", true),
                  _buildToggleBtn("Piutang", false),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDebtList(
                    _isMyDebt ? _myDebts : _theirDebts,
                    _isMyDebt 
                        ? "Belum ada utang yang dicatat.\nAlhamdulillah!"
                        : "Belum ada orang yang ngutang ke kamu.",
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDebtSheet(context),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(PhosphorIconsBold.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildToggleBtn(String title, bool isMyDebtBtn) {
    final bool isSelected = _isMyDebt == isMyDebtBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isMyDebt != isMyDebtBtn) {
            setState(() {
              _isMyDebt = isMyDebtBtn;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
