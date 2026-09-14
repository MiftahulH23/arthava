import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ZakatSedekahScreen extends StatefulWidget {
  const ZakatSedekahScreen({super.key});

  @override
  State<ZakatSedekahScreen> createState() => _ZakatSedekahScreenState();
}

class _ZakatSedekahScreenState extends State<ZakatSedekahScreen> {
  bool _isZakat = true;
  final SupabaseClient _supabase = Supabase.instance.client;

  final _zakatWealthController = TextEditingController();
  final _sedekahAmountController = TextEditingController();
  final _sedekahNoteController = TextEditingController();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  
  final _plainCurrencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

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
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('name');

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

  Future<int> _getOrCreateCategory(String categoryName, String iconName) async {
    final userId = _supabase.auth.currentUser!.id;
    // Check if exists
    final checkRes = await _supabase
        .from('categories')
        .select('id')
        .eq('is_expense', true)
        .ilike('name', '%$categoryName%')
        .eq('user_id', userId)
        .maybeSingle();
        
    if (checkRes != null) return checkRes['id'] as int;
    
    // Create new
    final insertRes = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': categoryName,
          'is_expense': true,
          'icon_name': iconName,
        })
        .select('id')
        .single();
        
    return insertRes['id'] as int;
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
    String iconName = "";

    if (isZakat) {
      if (_calculatedZakat <= 0) {
        AppNotification.error(context, "Masukkan total harta yang valid!");
        return;
      }
      amountToPay = _calculatedZakat;
      note = "Pembayaran Zakat Maal (2.5% dari harta)";
      categoryName = "Zakat";
      iconName = "hand-heart";
    } else {
      final cleanAmount = _sedekahAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanAmount.isEmpty || double.parse(cleanAmount) <= 0) {
        AppNotification.error(context, "Masukkan nominal sedekah yang valid!");
        return;
      }
      amountToPay = double.parse(cleanAmount);
      note = _sedekahNoteController.text.trim().isNotEmpty ? _sedekahNoteController.text.trim() : "Sedekah";
      categoryName = "Sedekah";
      iconName = "hand-coins";
    }

    // Cek saldo dompet
    final selectedWallet = _wallets.firstWhere((w) => w['id'] == _selectedWalletId);
    final double currentBalance = (selectedWallet['balance'] as num).toDouble();
    if (amountToPay > currentBalance) {
      AppNotification.error(context, "Saldo dompet tidak mencukupi!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final categoryId = await _getOrCreateCategory(categoryName, iconName);

      // Insert transaction
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'category_id': categoryId,
        'amount': amountToPay,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'note': note,
        'wallet_id': _selectedWalletId,
      });

      // Update wallet balance
      await _supabase
          .from('wallets')
          .update({'balance': currentBalance - amountToPay})
          .eq('id', _selectedWalletId!);

      if (mounted) {
        AppNotification.success(context, "$categoryName berhasil dibayarkan! Semoga berkah.");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal memproses pembayaran: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Zakat & Sedekah",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _buildToggleBtn("Zakat", true),
                  _buildToggleBtn("Sedekah", false),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isZakat ? _buildZakatTab() : _buildSedekahTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String title, bool isZakatBtn) {
    final bool isSelected = _isZakat == isZakatBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isZakat != isZakatBtn) {
            setState(() {
              _isZakat = isZakatBtn;
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
              color: isSelected
                  ? (isZakatBtn ? Colors.green.shade700 : Colors.blue.shade700)
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZakatTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIconsFill.info, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Kalkulator Zakat Maal secara otomatis menghitung 2.5% dari total harta (emas, perak, uang tunai, tabungan) yang telah mencapai nisab.",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade900, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          
          Text(
            "Total Harta Anda (Rp)",
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _zakatWealthController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 20, right: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Rp",
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              hintText: "0",
            ),
            onChanged: (value) {
              final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (clean.isNotEmpty) {
                final formatted = _plainCurrencyFormat.format(int.parse(clean));
                _zakatWealthController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          
          const SizedBox(height: 25),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Zakat yang Harus Dibayar",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(_calculatedZakat),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          _buildWalletSelector(),
          
          const SizedBox(height: 40),
          _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : ElevatedButton(
                onPressed: () => _processPayment(isZakat: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: Text(
                  "Bayar Zakat",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSedekahTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIconsFill.handHeart, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Sedekah tidak akan mengurangi harta, melainkan menambah keberkahannya. Yuk sedekah hari ini!",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          
          Text(
            "Nominal Sedekah (Rp)",
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sedekahAmountController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 20, right: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Rp",
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              hintText: "0",
            ),
            onChanged: (value) {
              final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (clean.isNotEmpty) {
                final formatted = _plainCurrencyFormat.format(int.parse(clean));
                _sedekahAmountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          
          const SizedBox(height: 20),
          Text(
            "Catatan / Niat (Opsional)",
            style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sedekahNoteController,
            style: GoogleFonts.poppins(fontSize: 14),
            maxLines: 2,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Misal: Sedekah Jumat, Untuk Masjid, dll",
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.all(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 30),
          _buildWalletSelector(),
          
          const SizedBox(height: 40),
          _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : ElevatedButton(
                onPressed: () => _processPayment(isZakat: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: Text(
                  "Bayar Sedekah",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildWalletSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pilih Dompet Sumber Dana",
          style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              dropdownColor: Colors.white,
              value: _selectedWalletId,
              hint: Text(
                _wallets.isEmpty ? "Belum ada dompet" : "Pilih Dompet...",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              isExpanded: true,
              icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.grey),
              items: _wallets.map((wallet) {
                return DropdownMenuItem<int>(
                  value: wallet['id'],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsFill.wallet,
                            color: Color(int.parse((wallet['color'] ?? '#1E3A8A').replaceFirst('#', '0xFF'))),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            wallet['name'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ],
                      ),
                      Text(
                        _currencyFormat.format(wallet['balance']),
                        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedWalletId = val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
