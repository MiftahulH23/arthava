import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/providers/home_provider.dart';
import 'package:arthava/providers/user_settings_provider.dart';
import 'package:arthava/providers/wallet_provider.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Baris switch "Hitung saldo minimal di total saldo" (spec §7.3).
/// Aktif (default) = total saldo apa adanya; nonaktif = dikurangi saldo minimal.
class IncludeMinBalanceRow extends ConsumerWidget {
  const IncludeMinBalanceRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final include = ref.watch(userSettingsProvider).includeMinBalance;
    return AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsFill.scales, color: AppColors.tintTeal, filled: true),
      title: 'Hitung saldo minimal di total saldo',
      subtitle: include ? 'Total saldo = semua saldo dompet' : 'Total saldo dikurangi saldo minimal',
      trailing: AppSwitch(
        value: include,
        onChanged: (value) async {
          try {
            await ref.read(userSettingsProvider.notifier).setIncludeMinBalance(value);
            ref.invalidate(homeProvider);
            ref.invalidate(walletProvider);
          } catch (_) {
            if (context.mounted) AppNotification.error(context, 'Gagal menyimpan pengaturan.');
          }
        },
      ),
    );
  }
}
