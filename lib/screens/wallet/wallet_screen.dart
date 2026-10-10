import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/core/wallet_rules.dart';
import 'package:arthava/models/wallet_model.dart';
import 'package:arthava/providers/user_settings_provider.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_dialogs.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:arthava/widgets/app_create_row.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_hero_card.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_searchable_group.dart';
import 'package:arthava/widgets/app_sheet.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:arthava/screens/wallet/wallet_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const double cardHeight = 176;
  static const double cardStep = 116;

  /// Tambahan strip untuk kartu bertumpuk yang menampilkan "Bisa dipakai".
  static const double spendableStep = 28;


  /// Sheet pilih dompet (pengganti DropdownButton lama). Mengembalikan id atau null.
  Future<int?> _pickWallet(
    BuildContext context,
    List<WalletModel> wallets, {
    required String title,
    required int selectedId,
    bool showBalance = false,
  }) {
    // -1 = "+ Dompet Baru" dipilih (pemanggil membuka form dompet).
    return showAppFormSheet<int>(
      context: context,
      title: title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchableGroup<WalletModel>(
            items: wallets,
            searchText: (w) => w.name,
            hint: 'Cari dompet',
            rowBuilder: (_, w) =>
              AppListRow(
                leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: w.displayColor, filled: true),
                title: w.name,
                value: showBalance ? formatRupiah(w.balance) : null,
                trailing: w.id == selectedId
                    ? const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 18)
                    : null,
                onTap: () => Navigator.pop(sheetContext, w.id),
              ),
          ),
          const SizedBox(height: 12),
          AppGroupedSection(children: [
            AppCreateRow(label: 'Dompet Baru', onTap: () => Navigator.pop(sheetContext, -1)),
          ]),
        ],
      ),
    );
  }

  Future<void> _showTransferSheet(BuildContext context, WidgetRef ref, List<WalletModel> wallets) async {
    Future<int?> createWallet(BuildContext ctx) async {
      final id = await showWalletFormSheet(ctx, onSaved: ref.read(walletProvider.notifier).fetchWallets);
      wallets = ref.read(walletProvider).wallets;
      return id;
    }

    if (wallets.length < 2) {
      final ok = await showAppConfirmDialog(
        context: context,
        title: 'Butuh 2 dompet',
        message: 'Transfer butuh minimal 2 dompet. Buat dompet baru sekarang?',
        confirmLabel: 'Buat Dompet',
        destructive: false,
      );
      if (!ok || !context.mounted) return;
      final id = await createWallet(context);
      // Sudah 2 dompet: langsung lanjut ke Transfer.
      if (id != null && wallets.length >= 2 && context.mounted) {
        await _showTransferSheet(context, ref, wallets);
      }
      return;
    }

    int sourceId = wallets[0].id;
    int destId = wallets[1].id;
    final amountController = TextEditingController();
    var isSubmitting = false;

    showAppFormSheet<void>(
      context: context,
      title: 'Transfer Antar Dompet',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final source = wallets.firstWhere((w) => w.id == sourceId);
          final dest = wallets.firstWhere((w) => w.id == destId);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppGroupedSection(
                children: [
                  AppListRow(
                    leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: source.displayColor, filled: true),
                    title: 'Dari Dompet (Sumber)',
                    subtitle: '${source.name} (Sisa: ${formatRupiah(source.balance)})',
                    showChevron: true,
                    onTap: () async {
                      var picked = await _pickWallet(
                        sheetContext,
                        wallets,
                        title: 'Dari Dompet (Sumber)',
                        selectedId: sourceId,
                        showBalance: true,
                      );
                      if (picked == -1 && sheetContext.mounted) picked = await createWallet(sheetContext);
                      final chosen = picked;
                      if (chosen == null || !sheetContext.mounted) return;
                      setSheetState(() {
                        if (chosen == destId) destId = sourceId; // tukar otomatis
                        sourceId = chosen;
                      });
                    },
                  ),
                  Center(
                    heightFactor: 1,
                    child: IconButton(
                      tooltip: 'Tukar arah',
                      icon: const Icon(PhosphorIconsBold.arrowsDownUp, color: AppColors.primary),
                      onPressed: () => setSheetState(() {
                        final s = sourceId;
                        sourceId = destId;
                        destId = s;
                      }),
                    ),
                  ),
                  AppListRow(
                    leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: dest.displayColor, filled: true),
                    title: 'Ke Dompet (Tujuan)',
                    subtitle: '${dest.name} (Sisa: ${formatRupiah(dest.balance)})',
                    showChevron: true,
                    onTap: () async {
                      var picked = await _pickWallet(
                        sheetContext,
                        wallets,
                        title: 'Ke Dompet (Tujuan)',
                        selectedId: destId,
                      );
                      if (picked == -1 && sheetContext.mounted) picked = await createWallet(sheetContext);
                      final chosen = picked;
                      if (chosen == null || !sheetContext.mounted) return;
                      setSheetState(() {
                        if (chosen == sourceId) sourceId = destId; // tukar otomatis
                        destId = chosen;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Nominal Transfer', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              AppTextField(
                controller: amountController,
                hint: '0',
                icon: PhosphorIconsRegular.money,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Transfer Sekarang',
                loading: isSubmitting,
                onPressed: () async {
                  if (amountController.text.isEmpty) {
                    AppNotification.error(sheetContext, "Nominal tidak boleh kosong!");
                    return;
                  }
                  final cleanAmount = parseRupiah(amountController.text).toDouble();
                  final error = validateTransfer(source: source, dest: dest, amount: cleanAmount);
                  if (error != null) {
                    AppNotification.error(sheetContext, error);
                    return;
                  }
                  setSheetState(() => isSubmitting = true);
                  try {
                    await ref.read(walletProvider.notifier).transfer(
                          sourceId: sourceId,
                          destId: destId,
                          amount: cleanAmount,
                        );
                    if (sheetContext.mounted) {
                      AppNotification.success(sheetContext, "Transfer ${formatRupiah(cleanAmount)} berhasil!");
                      Navigator.pop(sheetContext);
                    }
                  } catch (e) {
                    if (sheetContext.mounted) {
                      setSheetState(() => isSubmitting = false);
                      AppNotification.error(sheetContext, e.toString().replaceFirst('Exception: ', ''));
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

  void _showWalletActions(BuildContext context, WidgetRef ref, WalletModel wallet) {
    showAppFormSheet<void>(
      context: context,
      title: wallet.name,
      builder: (sheetContext) => AppGroupedSection(
        children: [
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsRegular.pencilSimple, color: AppColors.tintBlue),
            title: 'Edit',
            onTap: () {
              Navigator.pop(sheetContext);
              showWalletFormSheet(context, wallet: wallet, onSaved: ref.read(walletProvider.notifier).fetchWallets);
            },
          ),
          AppListRow(
            leading: AppIconTile(
              icon: wallet.isFavorite ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
              color: AppColors.tintAmber,
            ),
            title: wallet.isFavorite ? 'Hapus dari Favorit' : 'Jadikan Favorit',
            subtitle: 'Dompet favorit tampil di Beranda',
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await ref.read(walletProvider.notifier).setFavorite(wallet.id, !wallet.isFavorite);
              } catch (_) {
                if (context.mounted) AppNotification.error(context, 'Gagal mengubah favorit.');
              }
            },
          ),
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsRegular.trash, color: AppColors.expense),
            title: 'Hapus',
            titleColor: AppColors.expense,
            onTap: () async {
              Navigator.pop(sheetContext);
              final ok = await showAppConfirmDialog(
                context: context,
                title: "Hapus Dompet?",
                message: "Yakin ingin menghapus ${wallet.name}?",
              );
              if (!ok) return;
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletProvider);
    final includeMinBalance = ref.watch(userSettingsProvider).includeMinBalance;

    final List<Widget> children;
    if (state.isLoading) {
      children = const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    } else if (state.wallets.isEmpty) {
      children = const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: AppEmptyState(
            icon: PhosphorIconsRegular.wallet,
            title: "Belum ada dompet",
            subtitle: "Ketuk Tambah di bawah untuk membuat dompet pertama.",
          ),
        ),
      ];
    } else {
      children = [
        _WalletStack(
          wallets: state.wallets,
          includeMinBalance: includeMinBalance,
          onTap: (w) => _showWalletActions(context, ref, w),
        ),
        Text(
          'Ketuk kartu untuk edit, favorit, atau hapus',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ];
    }

    return AppPageScaffold(
      title: 'Dompet Saya',
      backLabel: 'Beranda',
      bottomBar: Center(
        heightFactor: 1,
        child: _WalletActionPill(
          showTransfer: state.wallets.isNotEmpty, // < 2 dompet: ditawari membuat dompet kedua
          onTransfer: () => _showTransferSheet(context, ref, state.wallets),
          onAdd: () => showWalletFormSheet(context, onSaved: ref.read(walletProvider.notifier).fetchWallets),
        ),
      ),
      children: children,
    );
  }
}

/// Kartu dompet bertumpuk ala Apple Wallet: tiap kartu menutupi bagian bawah
/// kartu sebelumnya, menyisakan strip atas (nama + saldo) yang bisa diketuk.
class _WalletStack extends StatelessWidget {
  const _WalletStack({required this.wallets, required this.includeMinBalance, required this.onTap});

  final List<WalletModel> wallets;
  final bool includeMinBalance;
  final ValueChanged<WalletModel> onTap;

  bool _showsSpendable(WalletModel wallet) => !includeMinBalance && wallet.minBalance > 0;

  @override
  Widget build(BuildContext context) {
    // Strip tiap kartu setinggi isinya, supaya baris "Bisa dipakai" tidak
    // tertutup kartu berikutnya.
    final tops = <double>[];
    var top = 0.0;
    for (final wallet in wallets) {
      tops.add(top);
      top += WalletScreen.cardStep + (_showsSpendable(wallet) ? WalletScreen.spendableStep : 0);
    }
    final height = wallets.isEmpty ? 0.0 : tops.last + WalletScreen.cardHeight;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < wallets.length; i++)
            Positioned(
              top: tops[i],
              left: 0,
              right: 0,
              height: WalletScreen.cardHeight,
              child: _WalletCard(
                wallet: wallets[i],
                showSpendable: _showsSpendable(wallets[i]),
                onTap: () => onTap(wallets[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.showSpendable, required this.onTap});

  final WalletModel wallet;
  final bool showSpendable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = wallet.displayColor;
    return Semantics(
      button: true,
      label: 'Dompet ${wallet.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.25)!],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, -4)),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(PhosphorIconsFill.wallet, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wallet.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(color: Colors.white, letterSpacing: 1.2),
                    ),
                  ),
                  if (wallet.isFavorite) ...[
                    const Icon(PhosphorIconsFill.star, color: Colors.white, size: 16, semanticLabel: 'Favorit'),
                    const SizedBox(width: 8),
                  ],
                  const Icon(PhosphorIconsBold.dotsThree, color: Colors.white, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              const AppHeroLabel('TOTAL SALDO'),
              const SizedBox(height: 2),
              AppHeroAmount(formatRupiah(wallet.balance), fontSize: 24),
              if (showSpendable) ...[
                const SizedBox(height: 6),
                AppHeroLabel('Bisa dipakai ${formatRupiah(spendableOf(wallet))}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletActionPill extends StatelessWidget {
  const _WalletActionPill({required this.showTransfer, required this.onTransfer, required this.onAdd});

  final bool showTransfer;
  final VoidCallback onTransfer;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      // scaleDown: ukuran asli bila muat; di teks besar (aksesibilitas) pill
      // mengecil, bukan meluap.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTransfer) ...[
              AppPillButton(
                label: 'Transfer',
                icon: PhosphorIconsBold.arrowsLeftRight,
                color: AppColors.tintOrange,
                large: true,
                onPressed: onTransfer,
              ),
              const SizedBox(width: 10),
            ],
            AppPillButton(
              label: 'Tambah',
              icon: PhosphorIconsBold.plus,
              filled: true,
              large: true,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
