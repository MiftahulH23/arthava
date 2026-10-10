import 'package:arthava/models/debt_model.dart';
import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/widgets/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Konfirmasi + hapus utang (dipakai daftar & detail). Pilihan "kembalikan
/// saldo" hanya untuk utang yang menyentuh dompet; riwayat cicilan dimuat dulu
/// bila belum ada (dari daftar belum pernah dibuka).
/// null = batal; true = dihapus & saldo dikembalikan; false = dihapus saja.
/// Error provider dilempar apa adanya — pemanggil yang menampilkan toast.
Future<bool?> confirmAndDeleteDebt(
  BuildContext context,
  WidgetRef ref,
  DebtModel debt, {
  VoidCallback? onConfirmed,
}) async {
  const intro = 'Data utang ini dan seluruh riwayat cicilannya akan dihapus permanen.';
  if (ref.read(debtProvider).payments[debt.id] == null) {
    await runWithAppLoading(context, () => ref.read(debtProvider.notifier).fetchPayments(debt.id));
    if (!context.mounted) return null;
  }
  // fetchPayments menelan error; bila riwayat tetap tidak diketahui, jangan
  // dianggap kosong (pilihan kembalikan saldo bisa hilang) — batalkan.
  final payments = ref.read(debtProvider).payments[debt.id];
  if (payments == null) throw Exception('Gagal memuat cicilan. Coba lagi.');
  final linkedToWallet =
      (debt.transactionId != null && debt.walletId != null) || payments.any((p) => p.affectsWallet);

  final bool? refund;
  if (linkedToWallet) {
    refund = await showAppChoiceDialog<bool>(
      context: context,
      title: 'Hapus Catatan?',
      message: '$intro Kembalikan saldo dompet seperti sebelum utang ini dicatat?',
      choices: const [
        AppDialogChoice(label: 'Hapus & kembalikan saldo', value: true),
        AppDialogChoice(label: 'Hapus saja', value: false, destructive: true),
      ],
    );
  } else {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Hapus Catatan?',
      message: '$intro Utang ini tidak terhubung ke saldo dompet, jadi saldo tidak berubah.',
    );
    refund = confirm ? false : null;
  }
  if (refund == null || !context.mounted) return null;
  onConfirmed?.call();
  await ref.read(debtProvider.notifier).deleteDebt(debt.id, refundWallet: refund);
  return refund;
}
