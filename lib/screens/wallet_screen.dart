import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<WalletModel> _wallets = [];
  bool _isLoading = true;

  final List<String> _colorOptions = [
    '#1E3A8A', // Blue (BCA/Mandiri)
    '#00796B', // Teal (GoPay/Tokped)
    '#5E35B1', // Purple (OVO)
    '#E65100', // Orange (ShopeePay)
    '#C62828', // Red (LinkAja)
    '#2E7D32', // Green (Cash/Tunai)
    '#37474F', // Dark Blue Grey
    '#E91E63', // Pink
  ];

  @override
  void initState() {
    super.initState();
    _fetchWallets();
  }

  Future<void> _fetchWallets() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _wallets = (res as List).map((e) => WalletModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetch wallets: $e");
    }
  }

  Future<void> _deleteWallet(int id) async {
    try {
      await _supabase.from('wallets').delete().eq('id', id);
      AppNotification.success(context, "Dompet berhasil dihapus!");
      _fetchWallets();
    } catch (e) {
      AppNotification.error(context, "Gagal menghapus dompet. Pastikan tidak ada transaksi di dompet ini.");
    }
  }

  // =========================================================
  // [NEW] BOTTOM SHEET UNTUK TRANSFER / MUTASI ANTAR DOMPET
  // =========================================================
  void _showTransferSheet() {
    if (_wallets.length < 2) {
      AppNotification.error(context, "Minimal butuh 2 dompet untuk transfer.");
      return;
    }

    int? sourceId = _wallets[0].id;
    int? destId = _wallets[1].id;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final amountController = TextEditingController();

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Transfer Antar Dompet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // DROPDOWN DARI DOMPET MANA
                    Text("Dari Dompet (Sumber)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(15)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: sourceId,
                          isExpanded: true,
                          icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
                          items: _wallets.map((w) {
                            return DropdownMenuItem<int>(
                              value: w.id,
                              child: Text("${w.name} (Sisa: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(w.balance)})", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == destId) {
                              AppNotification.error(context, "Dompet asal dan tujuan tidak boleh sama!");
                              return;
                            }
                            setSheetState(() => sourceId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ICON PANAH KE BAWAH
                    const Center(child: Icon(PhosphorIconsBold.arrowDown, color: AppColors.primary, size: 24)),
                    const SizedBox(height: 15),

                    // DROPDOWN KE DOMPET MANA
                    Text("Ke Dompet (Tujuan)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(15)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: destId,
                          isExpanded: true,
                          icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
                          items: _wallets.map((w) {
                            return DropdownMenuItem<int>(
                              value: w.id,
                              child: Text(w.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == sourceId) {
                              AppNotification.error(context, "Dompet tujuan dan asal tidak boleh sama!");
                              return;
                            }
                            setSheetState(() => destId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // INPUT NOMINAL TRANSFER
                    Text("Nominal Transfer", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      onChanged: (value) {
                        String cleanValue = value.replaceAll('.', '');
                        if (cleanValue.isNotEmpty) {
                          String formatted = currencyFormatter.format(int.parse(cleanValue));
                          amountController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "0",
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 15, right: 10),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black))]),
                        ),
                        filled: true, fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // TOMBOL PROSES TRANSFER
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (amountController.text.isEmpty) {
                            AppNotification.error(context, "Nominal tidak boleh kosong!");
                            return;
                          }
                          
                          final cleanAmount = double.parse(amountController.text.replaceAll('.', ''));
                          if (cleanAmount <= 0) return;

                          final sourceWallet = _wallets.firstWhere((w) => w.id == sourceId);
                          final destWallet = _wallets.firstWhere((w) => w.id == destId);

                          if (sourceWallet.balance < cleanAmount) {
                            AppNotification.error(context, "Saldo di ${sourceWallet.name} tidak cukup!");
                            return;
                          }

                          try {
                            // 1. Kurangi Saldo Asal
                            await _supabase.from('wallets').update({'balance': sourceWallet.balance - cleanAmount}).eq('id', sourceId!);
                            // 2. Tambah Saldo Tujuan
                            await _supabase.from('wallets').update({'balance': destWallet.balance + cleanAmount}).eq('id', destId!);

                            AppNotification.success(context, "Transfer Rp ${currencyFormatter.format(cleanAmount)} berhasil!");
                            Navigator.pop(context);
                            _fetchWallets(); // Refresh UI Dompet
                          } catch (e) {
                            AppNotification.error(context, "Gagal memproses transfer.");
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: Text("Transfer Sekarang", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

  // BOTTOM SHEET BUAT TAMBAH / EDIT DOMPET
  void _showAddEditWalletSheet({WalletModel? wallet}) {
    final isEdit = wallet != null;
    final nameController = TextEditingController(text: isEdit ? wallet.name : '');
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final balanceController = TextEditingController(text: isEdit ? currencyFormatter.format(wallet.balance) : '');
    String selectedColor = isEdit && wallet.color != null ? wallet.color! : _colorOptions[0];

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEdit ? "Edit Dompet" : "Tambah Dompet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text("Nama Dompet (cth: BCA, GoPay, Tunai)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: "Masukkan nama dompet",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                        prefixIcon: const Icon(PhosphorIconsRegular.wallet, color: Colors.grey),
                        filled: true, fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text("Saldo Saat Ini", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      onChanged: (value) {
                        String cleanValue = value.replaceAll('.', '');
                        if (cleanValue.isNotEmpty) {
                          String formatted = currencyFormatter.format(int.parse(cleanValue));
                          balanceController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "0",
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 15, right: 10),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black))]),
                        ),
                        filled: true, fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text("Pilih Warna", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _colorOptions.map((hexColor) {
                          final color = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
                          final isSelected = selectedColor == hexColor;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedColor = hexColor),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.black54, width: 3) : null,
                                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))] : [],
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty || balanceController.text.isEmpty) {
                            AppNotification.error(context, "Harap isi semua data!");
                            return;
                          }

                          final userId = _supabase.auth.currentUser!.id;
                          final cleanBalance = double.parse(balanceController.text.replaceAll('.', ''));
                          final data = {
                            'user_id': userId, 'name': nameController.text.trim(),
                            'balance': cleanBalance, 'color': selectedColor, 'icon': 'wallet',
                          };

                          try {
                            if (isEdit) {
                              await _supabase.from('wallets').update(data).eq('id', wallet.id);
                              AppNotification.success(context, "Dompet diperbarui!");
                            } else {
                              await _supabase.from('wallets').insert(data);
                              AppNotification.success(context, "Dompet berhasil ditambahkan!");
                            }
                            Navigator.pop(context);
                            _fetchWallets();
                          } catch (e) {
                            AppNotification.error(context, "Gagal menyimpan dompet.");
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: Text("Simpan Dompet", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Dompet Saya", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsRegular.wallet, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 15),
                      Text("Belum ada dompet", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = _wallets[index];
                    final colorHex = wallet.color ?? '#1E3A8A';
                    final walletColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(colors: [walletColor, walletColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(color: walletColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Stack(
                        children: [
                          Positioned(right: -20, top: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1))),
                          Positioned(right: 50, bottom: -40, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(0.1))),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 20)),
                                        const SizedBox(width: 12),
                                        Text(wallet.name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Theme(
                                      data: Theme.of(context).copyWith(iconTheme: const IconThemeData(color: Colors.white)),
                                      child: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showAddEditWalletSheet(wallet: wallet);
                                          } else if (value == 'delete') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor: Colors.white,
                                                title: Text("Hapus Dompet?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                                content: Text("Yakin ingin menghapus ${wallet.name}?", style: GoogleFonts.poppins()),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                                                  TextButton(onPressed: () { Navigator.pop(ctx); _deleteWallet(wallet.id); }, child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem(value: 'edit', child: Row(children: [const Icon(PhosphorIconsRegular.pencilSimple, color: Colors.blue, size: 20), const SizedBox(width: 10), Text("Edit", style: GoogleFonts.poppins())])),
                                          PopupMenuItem(value: 'delete', child: Row(children: [const Icon(PhosphorIconsRegular.trash, color: Colors.red, size: 20), const SizedBox(width: 10), Text("Hapus", style: GoogleFonts.poppins(color: Colors.red))])),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Total Saldo", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                    Text(currencyFormat.format(wallet.balance), style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      
      // [UPDATE] Floating Action Button Ganda (Transfer & Tambah)
      floatingActionButton: _wallets.length < 2
          ? FloatingActionButton(
              onPressed: () => _showAddEditWalletSheet(),
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'btn_transfer',
                  onPressed: () => _showTransferSheet(),
                  backgroundColor: Colors.orange,
                  icon: const Icon(PhosphorIconsBold.arrowsLeftRight, color: Colors.white),
                  label: Text("Transfer", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 15),
                FloatingActionButton.extended(
                  heroTag: 'btn_add',
                  onPressed: () => _showAddEditWalletSheet(),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text("Tambah", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
    );
  }
}