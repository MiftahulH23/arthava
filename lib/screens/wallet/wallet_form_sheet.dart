import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final NumberFormat _walletThousands = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

/// Form Tambah/Edit Dompet (dipakai layar Dompet dan semua "+ Dompet Baru").
/// Mengembalikan id dompet yang disimpan, atau null bila dibatalkan.
/// [onSaved] menyegarkan daftar dompet milik layar pemanggil.
Future<int?> showWalletFormSheet(
  BuildContext context, {
  WalletModel? wallet,
  required Future<void> Function() onSaved,
  @visibleForTesting Future<int> Function(String name, double balance, String color, double minBalance)? insertOverride,
}) {
  final isEdit = wallet != null;
  final nameController = TextEditingController(text: isEdit ? wallet.name : '');
  final balanceController = TextEditingController(text: isEdit ? _walletThousands.format(wallet.balance) : '');
  final minBalanceController = TextEditingController(
    text: isEdit && wallet.minBalance > 0 ? _walletThousands.format(wallet.minBalance) : '',
  );
  String selectedColor =
      isEdit && wallet.color != null ? wallet.color! : AppColors.walletColorChoices[0];
  var isSubmitting = false;

  return showAppFormSheet<int>(
    context: context,
    title: isEdit ? "Edit Dompet" : "Tambah Dompet",
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Nama Dompet (cth: BCA, GoPay, Tunai)", style: AppTextStyles.caption),
            const SizedBox(height: 8),
            AppTextField(
              controller: nameController,
              hint: "Masukkan nama dompet",
              icon: PhosphorIconsRegular.wallet,
            ),
            const SizedBox(height: 16),
            Text("Saldo Saat Ini", style: AppTextStyles.caption),
            const SizedBox(height: 8),
            AppTextField(
              controller: balanceController,
              hint: "0",
              icon: PhosphorIconsRegular.money,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
            ),
            const SizedBox(height: 16),
            Text("Saldo Minimal (Opsional)", style: AppTextStyles.caption),
            const SizedBox(height: 8),
            AppTextField(
              controller: minBalanceController,
              hint: "0",
              icon: PhosphorIconsRegular.lockSimple,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
            ),
            const SizedBox(height: 6),
            Text(
              'Saldo yang ditahan bank. Dipakai untuk menghitung uang yang bisa dipakai.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            Text("Pilih Warna", style: AppTextStyles.caption),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AppColors.walletColorChoices.map((hexColor) {
                  final color = AppColors.fromWalletHex(hexColor);
                  final isSelected = selectedColor == hexColor;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = hexColor),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: AppColors.textPrimary, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(PhosphorIconsBold.check, color: Colors.white, size: 22) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: "Simpan Dompet",
              loading: isSubmitting,
              onPressed: () async {
                if (isSubmitting) return; // ketuk ganda: jangan membuat dompet kembar
                if (nameController.text.isEmpty || balanceController.text.isEmpty) {
                  AppNotification.error(sheetContext, "Harap isi semua data!");
                  return;
                }
                final cleanBalance = parseRupiah(balanceController.text).toDouble();
                final minBalance = parseRupiah(minBalanceController.text).toDouble();
                setSheetState(() => isSubmitting = true);
                try {
                  int id;
                  if (isEdit) {
                    await updateWalletRow(
                      id: wallet.id,
                      name: nameController.text.trim(),
                      balance: cleanBalance,
                      color: selectedColor,
                      minBalance: minBalance,
                    );
                    id = wallet.id;
                  } else {
                    id = insertOverride != null
                        ? await insertOverride(nameController.text.trim(), cleanBalance, selectedColor, minBalance)
                        : await insertWallet(
                            name: nameController.text.trim(),
                            balance: cleanBalance,
                            color: selectedColor,
                            minBalance: minBalance,
                          );
                  }
                  // Dompet sudah tersimpan: gagal menyegarkan daftar bukan kegagalan
                  // (kalau dianggap gagal, user bisa menyimpan ulang → dompet kembar).
                  try {
                    await onSaved();
                  } catch (e) {
                    debugPrint('Refresh dompet gagal: $e');
                  }
                  if (sheetContext.mounted) {
                    AppNotification.success(sheetContext, isEdit ? "Dompet diperbarui!" : "Dompet berhasil ditambahkan!");
                    Navigator.pop(sheetContext, id);
                  }
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSubmitting = false);
                    AppNotification.error(sheetContext, "Gagal menyimpan dompet.");
                  }
                }
              },
            ),
          ],
        );
      },
    ),
  );
}
