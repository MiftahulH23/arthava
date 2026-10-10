import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/services/zakat_service.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:catat_uang_app/widgets/app_wallet_select_row.dart';
import 'package:catat_uang_app/screens/wallet/wallet_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/widgets/app_swipe_tabs.dart';

class ZakatSedekahScreen extends StatefulWidget {
  const ZakatSedekahScreen({super.key});

  @override
  State<ZakatSedekahScreen> createState() => _ZakatSedekahScreenState();
}

class _ZakatSedekahScreenState extends State<ZakatSedekahScreen> {
  bool _isZakat = true;
  SupabaseClient get _supabase => Supabase.instance.client;

  final _zakatWealthController = TextEditingController();
  final _sedekahAmountController = TextEditingController();
  final _sedekahNoteController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _wallets = [];
  int? _selectedWalletId;
  double _calculatedZakat = 0;

  @override
  void initState() {
    super.initState();
    _fetchWallets();

    _zakatWealthController.addListener(() {
      final cleanText = _zakatWealthController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanText.isNotEmpty) {
        final amount = double.parse(cleanText);
        setState(() {
          _calculatedZakat = amount * 0.025; // 2.5% zakat maal
        });
      } else {
        setState(() {
          _calculatedZakat = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _zakatWealthController.dispose();
    _sedekahAmountController.dispose();
    _sedekahNoteController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase.from('wallets').select().eq('user_id', userId).order('name');

      if (mounted) {
        setState(() {
          _wallets = List<Map<String, dynamic>>.from(res);
          if (_wallets.isNotEmpty && _selectedWalletId == null) {
            _selectedWalletId = _wallets.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetch wallets: $e");
    }
  }

  Future<void> _processPayment({required bool isZakat}) async {
    if (_wallets.isEmpty) {
      AppNotification.error(context, "Anda belum membuat dompet.");
      return;
    }
    if (_selectedWalletId == null) {
      AppNotification.error(context, "Pilih dompet sumber dana!");
      return;
    }

    double amountToPay = 0;
    String note = "";
    String categoryName = "";

    if (isZakat) {
      if (_calculatedZakat <= 0) {
        AppNotification.error(context, "Masukkan total harta yang valid!");
        return;
      }
      amountToPay = _calculatedZakat;
      note = "Pembayaran Zakat Maal (2.5% dari harta)";
      categoryName = "Zakat";
    } else {
      final cleanAmount = _sedekahAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanAmount.isEmpty || double.parse(cleanAmount) <= 0) {
        AppNotification.error(context, "Masukkan nominal sedekah yang valid!");
        return;
      }
      amountToPay = double.parse(cleanAmount);
      note = _sedekahNoteController.text.trim().isNotEmpty ? _sedekahNoteController.text.trim() : "Sedekah";
      categoryName = "Sedekah";
    }

    // Saldo & saldo minimal dicek server (pesan tolakan lewat ZakatRejection).
    setState(() => _isLoading = true);

    try {
      // Atomik di database (RPC pay_zakat_sedekah, migration 202609260008):
      // kategori, transaksi, dan potong saldo sekaligus.
      await ZakatService(
        _supabase,
      ).pay(isZakat: isZakat, walletId: _selectedWalletId!, amount: amountToPay, note: note);

      if (mounted) {
        AppNotification.success(context, "$categoryName berhasil dibayarkan! Semoga berkah.");
        Navigator.pop(context, true);
      }
    } on ZakatRejection catch (e) {
      // Tolakan server (mis. saldo berubah sejak layar dibuka) memakai pesan aslinya.
      if (mounted) AppNotification.error(context, e.message);
      if (mounted) _fetchWallets();
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal memproses pembayaran: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSwipeTabs(
      index: _isZakat ? 0 : 1,
      count: 2,
      onChanged: (index) => setState(() => _isZakat = index == 0),
      child: AppPageScaffold(
        title: 'Zakat & Sedekah',
        backLabel: 'Beranda',
        bottomBar: AppPrimaryButton(
          label: _isZakat ? 'Bayar Zakat' : 'Bayar Sedekah',
          loading: _isLoading,
          onPressed: () => _processPayment(isZakat: _isZakat),
        ),
        children: [
          AppSegmentedControl(
            labels: const ['Zakat', 'Sedekah'],
            selectedIndex: _isZakat ? 0 : 1,
            onChanged: (index) {
              final wantZakat = index == 0;
              if (_isZakat != wantZakat) {
                setState(() => _isZakat = wantZakat);
              }
            },
          ),
          AppSwipeTabBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: _isZakat ? _buildZakatSection() : _buildSedekahSection(),
            ),
          ),
          AppWalletSelectRow(
            header: 'Pilih Dompet Sumber Dana',
            wallets: _wallets,
            selectedId: _selectedWalletId,
            onChanged: (val) => setState(() => _selectedWalletId = val),
            onCreate: () => showWalletFormSheet(context, onSaved: _fetchWallets),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildZakatSection() {
    return [
      AppCallout(
        icon: PhosphorIconsFill.info,
        child: Text(
          "Kalkulator Zakat Maal secara otomatis menghitung 2.5% dari total harta (emas, perak, uang tunai, tabungan) yang telah mencapai nisab.",
          style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, height: 1.5),
        ),
      ),
      AppSurfaceCard(
        child: AppAmountField(controller: _zakatWealthController, label: 'Total Harta Anda (Rp)'),
      ),
      AppHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeroLabel('Zakat yang Harus Dibayar'),
            const SizedBox(height: 6),
            AppHeroAmount(formatRupiah(_calculatedZakat)),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSedekahSection() {
    return [
      AppCallout(
        icon: PhosphorIconsFill.handHeart,
        child: Text(
          "Sedekah tidak akan mengurangi harta, melainkan menambah keberkahannya. Yuk sedekah hari ini!",
          style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary, height: 1.5),
        ),
      ),
      AppSurfaceCard(
        child: AppAmountField(controller: _sedekahAmountController, label: 'Nominal Sedekah (Rp)'),
      ),
      AppGroupedSection(
        header: 'Catatan / Niat (Opsional)',
        children: [
          AppTextField(
            controller: _sedekahNoteController,
            hint: 'Misal: Sedekah Jumat, Untuk Masjid, dll',
            maxLines: 2,
          ),
        ],
      ),
    ];
  }
}
