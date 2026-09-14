import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _payments = [];

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
    _fetchPayments();
  }

  // Utang/dompet sudah tersedia lewat debtProvider (dibagi dengan
  // DebtScreen) — layar ini hanya perlu mengambil riwayat cicilan sendiri.
  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);
    try {
      final resPayments = await _supabase
          .from('debt_payments')
          .select('*, wallets(name)')
          .eq('debt_id', widget.debt['id'])
          .order('date', ascending: false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(resPayments);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching debt detail: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPaymentSheet(BuildContext context, Map<String, dynamic> debt) {
    final remainingAmount = (debt['remaining_amount'] as num).toDouble();
    if (remainingAmount <= 0) {
      AppNotification.success(context, "Utang ini sudah lunas!");
      return;
    }

    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool affectWallet = false;
    int? selectedWalletId;
    final isPayable = debt['type'] == 'payable';

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final wallets = ref.read(debtProvider).wallets;
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
                              items: wallets.map((w) {
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

                          try {
                            await ref.read(debtProvider.notifier).addPayment(
                                  debt: debt,
                                  amount: rawAmount,
                                  date: selectedDate,
                                  affectWallet: affectWallet,
                                  walletId: selectedWalletId,
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              _fetchPayments();
                              AppNotification.success(
                                context,
                                "Pembayaran berhasil dicatat!",
                              );
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                            if (context.mounted) {
                              AppNotification.error(
                                context,
                                e.toString().replaceFirst('Exception: ', ''),
                              );
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
      await ref.read(debtProvider.notifier).deleteDebt(widget.debt['id'] as int);
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
    // Utang ini juga ditampilkan di daftar DebtScreen lewat debtProvider
    // yang sama — cari versi terkini dari state supaya perubahan
    // `remaining_amount`/`status` lewat _showAddPaymentSheet langsung
    // tercermin di sini tanpa state lokal duplikat. Fallback ke
    // widget.debt kalau item ini sudah tidak ada di state (mis. dihapus
    // dari layar lain).
    final debtState = ref.watch(debtProvider);
    final debt = debtState.allDebts.firstWhere(
      (d) => d['id'] == widget.debt['id'],
      orElse: () => widget.debt,
    );

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPayable = debt['type'] == 'payable';
    final amount = (debt['amount'] as num).toDouble();
    final remaining = (debt['remaining_amount'] as num).toDouble();
    final paid = amount - remaining;
    final isPaid = debt['status'] == 'paid' || remaining <= 0;
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
                    debt['name'],
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
                  else if (debt['due_date'] != null)
                    Text(
                      "Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(DateTime.parse(debt['due_date']))}",
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
        onPressed: () => _showAddPaymentSheet(context, debt),
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
