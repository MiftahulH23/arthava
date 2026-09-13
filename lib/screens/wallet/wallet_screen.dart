import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:catat_uang_app/widgets/app_button.dart';
import 'package:catat_uang_app/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const List<String> _colorOptions = [
    '#1E3A8A', '#00796B', '#5E35B1', '#E65100',
    '#C62828', '#2E7D32', '#37474F', '#E91E63',
  ];

  void _showTransferSheet(BuildContext context, WidgetRef ref, List<WalletModel> wallets) {
    if (wallets.length < 2) {
      AppNotification.error(context, "Minimal butuh 2 dompet untuk transfer.");
      return;
    }

    int? sourceId = wallets[0].id;
    int? destId = wallets[1].id;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final amountController = TextEditingController();

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AppCard(
                title: Text("Transfer Antar Dompet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Dari Dompet (Sumber)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: sourceId,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
                        items: wallets.map((w) {
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
                    const SizedBox(height: 15),
                    const Center(child: Icon(PhosphorIconsBold.arrowDown, color: AppColors.primary, size: 24)),
                    const SizedBox(height: 15),
                    Text("Ke Dompet (Tujuan)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: destId,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
                        items: wallets.map((w) {
                          return DropdownMenuItem<int>(value: w.id, child: Text(w.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)));
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
                    const SizedBox(height: 20),
                    Text("Nominal Transfer", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                      onChanged: (value) {
                        final cleanValue = value.replaceAll('.', '');
                        if (cleanValue.isNotEmpty) {
                          final formatted = currencyFormatter.format(int.parse(cleanValue));
                          amountController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }
                      },
                      decoration: const InputDecoration(hintText: "0", prefixText: "Rp "),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: "Transfer Sekarang",
                        onPressed: () async {
                          if (amountController.text.isEmpty) {
                            AppNotification.error(context, "Nominal tidak boleh kosong!");
                            return;
                          }
                          final cleanAmount = double.parse(amountController.text.replaceAll('.', ''));
                          try {
                            await ref.read(walletProvider.notifier).transfer(
                                  sourceId: sourceId!,
                                  destId: destId!,
                                  amount: cleanAmount,
                                );
                            if (context.mounted) {
                              AppNotification.success(context, "Transfer Rp ${currencyFormatter.format(cleanAmount)} berhasil!");
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
            );
          },
        );
      },
    );
  }

  void _showAddEditWalletSheet(BuildContext context, WidgetRef ref, {WalletModel? wallet}) {
    final isEdit = wallet != null;
    final nameController = TextEditingController(text: isEdit ? wallet.name : '');
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final balanceController = TextEditingController(text: isEdit ? currencyFormatter.format(wallet.balance) : '');
    String selectedColor = isEdit && wallet.color != null ? wallet.color! : _colorOptions[0];

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AppCard(
                title: Text(isEdit ? "Edit Dompet" : "Tambah Dompet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nama Dompet (cth: BCA, GoPay, Tunai)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(controller: nameController, decoration: const InputDecoration(hintText: "Masukkan nama dompet")),
                    const SizedBox(height: 20),
                    Text("Saldo Saat Ini", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        final cleanValue = value.replaceAll('.', '');
                        if (cleanValue.isNotEmpty) {
                          final formatted = currencyFormatter.format(int.parse(cleanValue));
                          balanceController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                        }
                      },
                      decoration: const InputDecoration(hintText: "0", prefixText: "Rp "),
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
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.black54, width: 3) : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: "Simpan Dompet",
                        onPressed: () async {
                          if (nameController.text.isEmpty || balanceController.text.isEmpty) {
                            AppNotification.error(context, "Harap isi semua data!");
                            return;
                          }
                          final cleanBalance = double.parse(balanceController.text.replaceAll('.', ''));
                          try {
                            if (isEdit) {
                              await ref.read(walletProvider.notifier).updateWallet(
                                    id: wallet.id,
                                    name: nameController.text.trim(),
                                    balance: cleanBalance,
                                    color: selectedColor,
                                  );
                            } else {
                              await ref.read(walletProvider.notifier).addWallet(
                                    name: nameController.text.trim(),
                                    balance: cleanBalance,
                                    color: selectedColor,
                                  );
                            }
                            if (context.mounted) {
                              AppNotification.success(context, isEdit ? "Dompet diperbarui!" : "Dompet berhasil ditambahkan!");
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) AppNotification.error(context, "Gagal menyimpan dompet.");
                          }
                        },
                      ),
                    ),
                  ],
                ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletProvider);
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Dompet Saya", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.wallets.isEmpty
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  itemCount: state.wallets.length,
                  itemBuilder: (itemContext, index) {
                    final wallet = state.wallets[index];
                    final colorHex = wallet.color ?? '#1E3A8A';
                    final walletColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

                    // Kartu gradient per-wallet TETAP dipertahankan seperti desain
                    // asli (bukan AppCard) — ini bukan bagian dari masalah
                    // konsistensi tab/card generik yang dilaporkan user. Shadow +
                    // ornamen dekoratif dikembalikan sesuai desain asli (review I-1).
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [walletColor, walletColor.withOpacity(0.8)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: walletColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -20,
                              top: -20,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -15,
                              bottom: -15,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 16),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            wallet.name.toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Theme(
                                        data: Theme.of(itemContext).copyWith(iconTheme: const IconThemeData(color: Colors.white, size: 20)),
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 120),
                                          offset: const Offset(0, 30),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showAddEditWalletSheet(itemContext, ref, wallet: wallet);
                                            } else if (value == 'delete') {
                                              showDialog(
                                                context: itemContext,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                  backgroundColor: Colors.white,
                                                  title: Text("Hapus Dompet?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                                  content: Text("Yakin ingin menghapus ${wallet.name}?", style: GoogleFonts.poppins()),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                                                    TextButton(
                                                      onPressed: () async {
                                                        Navigator.pop(ctx);
                                                        // Pakai context milik build() (bukan context
                                                        // baris list-item), karena baris ini bisa
                                                        // unmount begitu list menyusut setelah hapus
                                                        // (temuan review I-3) — supaya toast tetap
                                                        // tampil walau dompet yang dihapus baris
                                                        // terakhir/satu-satunya di list.
                                                        try {
                                                          await ref.read(walletProvider.notifier).deleteWallet(wallet.id);
                                                          if (context.mounted) {
                                                            AppNotification.success(context, "Dompet berhasil dihapus!");
                                                          }
                                                        } catch (_) {
                                                          if (context.mounted) {
                                                            AppNotification.error(context, "Gagal menghapus dompet. Pastikan tidak ada transaksi di dompet ini.");
                                                          }
                                                        }
                                                      },
                                                      child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(value: 'edit', child: Row(children: [const Icon(PhosphorIconsRegular.pencilSimple, color: Colors.blue, size: 18), const SizedBox(width: 8), Text("Edit", style: GoogleFonts.poppins(fontSize: 13))])),
                                            PopupMenuItem(value: 'delete', child: Row(children: [const Icon(PhosphorIconsRegular.trash, color: Colors.red, size: 18), const SizedBox(width: 8), Text("Hapus", style: GoogleFonts.poppins(color: Colors.red, fontSize: 13))])),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "TOTAL SALDO",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(wallet.balance),
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: state.wallets.isEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditWalletSheet(context, ref),
              backgroundColor: AppColors.primary,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.wallets.length >= 2) ...[
                    GestureDetector(
                      onTap: () => _showTransferSheet(context, ref, state.wallets),
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsBold.arrowsLeftRight, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Transfer",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                  GestureDetector(
                    onTap: () => _showAddEditWalletSheet(context, ref),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Tambah",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
