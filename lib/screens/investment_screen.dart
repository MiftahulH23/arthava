import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/investment_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<InvestmentModel> _investments = [];
  List<Map<String, dynamic>> _wallets = [];

  double _totalCapital = 0;
  double _totalValue = 0;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final _inputFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final resWallets = await _supabase.from('wallets').select().eq('user_id', userId).order('name');
      final resInv = await _supabase.from('investments').select().eq('user_id', userId).order('created_at', ascending: false);

      double cap = 0;
      double val = 0;
      List<InvestmentModel> invs = [];

      for (var item in resInv) {
        final inv = InvestmentModel.fromJson(item);
        invs.add(inv);
        cap += inv.capitalAmount;
        val += inv.currentValue;
      }

      if (mounted) {
        setState(() {
          _wallets = List<Map<String, dynamic>>.from(resWallets);
          _investments = invs;
          _totalCapital = cap;
          _totalValue = val;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching investments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _getOrCreateCategory(String name, bool isExpense) async {
    final userId = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('categories')
        .select('id')
        .eq('user_id', userId)
        .eq('is_expense', isExpense)
        .ilike('name', '%$name%')
        .maybeSingle();
    if (res != null) return res['id'] as int;
    
    final ins = await _supabase.from('categories').insert({
      'user_id': userId,
      'name': name,
      'is_expense': isExpense,
      'icon_name': 'chart-line-up',
    }).select('id').single();
    return ins['id'] as int;
  }

  void _showAddInvestmentSheet() {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final amountController = TextEditingController();
    int? selectedWalletId = _wallets.isNotEmpty ? _wallets.first['id'] as int : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Investasi Baru", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Text("Nama Aset (Misal: Saham BBCA, Emas Antam)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Text("Jenis (Misal: Saham, Reksadana, Kripto)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typeController,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Text("Modal Awal", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
                      ),
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onChanged: (s) {
                      s = s.replaceAll(RegExp(r'[^0-9]'), '');
                      if (s.isNotEmpty) {
                        amountController.value = TextEditingValue(
                          text: _inputFormat.format(int.parse(s)),
                          selection: TextSelection.collapsed(offset: _inputFormat.format(int.parse(s)).length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  Text("Sumber Dana", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedWalletId,
                        isExpanded: true,
                        items: _wallets.map((w) => DropdownMenuItem(value: w['id'] as int, child: Text("${w['name']} (Sisa: ${_currencyFormat.format(w['balance'])})", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (v) => setSheetState(() => selectedWalletId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                      onPressed: () async {
                        if (nameController.text.isEmpty || typeController.text.isEmpty || amountController.text.isEmpty) {
                          AppNotification.error(context, "Semua kolom wajib diisi!");
                          return;
                        }
                        if (selectedWalletId == null) {
                          AppNotification.error(context, "Pilih dompet!");
                          return;
                        }
                        final amount = double.parse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                        final wallet = _wallets.firstWhere((w) => w['id'] == selectedWalletId);
                        if (amount > (wallet['balance'] as num).toDouble()) {
                          AppNotification.error(context, "Saldo dompet tidak mencukupi!");
                          return;
                        }
                        try {
                          final userId = _supabase.auth.currentUser!.id;
                          final catId = await _getOrCreateCategory('Investasi', true);
                          
                          // Insert Investment
                          final inv = await _supabase.from('investments').insert({
                            'user_id': userId,
                            'name': nameController.text.trim(),
                            'type': typeController.text.trim(),
                            'capital_amount': amount,
                            'current_value': amount,
                          }).select().single();

                          // Insert Transaction
                          await _supabase.from('transactions').insert({
                            'user_id': userId,
                            'wallet_id': selectedWalletId,
                            'category_id': catId,
                            'amount': amount,
                            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            'note': 'Beli Aset: ${nameController.text.trim()}'
                          });

                          // Update Wallet
                          await _supabase.from('wallets').update({'balance': (wallet['balance'] as num).toDouble() - amount}).eq('id', selectedWalletId!);

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchData();
                            AppNotification.success(context, "Investasi berhasil dibeli!");
                          }
                        } catch (e) {
                          if (mounted) AppNotification.error(context, "Error: $e");
                        }
                      },
                      child: Text("Beli Aset", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(InvestmentModel inv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(inv.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 5),
            Text(inv.type, style: GoogleFonts.poppins(color: Colors.grey)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(PhosphorIconsFill.plusCircle, color: Colors.green),
              title: Text("Beli Tambahan (Top Up)", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showBuySellSheet(inv, true);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsFill.minusCircle, color: Colors.red),
              title: Text("Jual Aset (Withdraw)", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showBuySellSheet(inv, false);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsFill.arrowsClockwise, color: Colors.blue),
              title: Text("Update Nilai Terkini", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text("Sesuaikan dengan harga pasar saat ini", style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showUpdateValueSheet(inv);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsFill.trash, color: Colors.grey),
              title: Text("Hapus Portofolio", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                await _supabase.from('investments').delete().eq('id', inv.id);
                _fetchData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBuySellSheet(InvestmentModel inv, bool isBuy) {
    final amountController = TextEditingController();
    int? selectedWalletId = _wallets.isNotEmpty ? _wallets.first['id'] as int : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isBuy ? "Top Up: ${inv.name}" : "Jual: ${inv.name}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Text("Nominal (Rp)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: isBuy ? Colors.green : Colors.red),
                    decoration: InputDecoration(
                      prefixIcon: Padding(padding: const EdgeInsets.all(15), child: Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey))),
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onChanged: (s) {
                      s = s.replaceAll(RegExp(r'[^0-9]'), '');
                      if (s.isNotEmpty) {
                        amountController.value = TextEditingValue(
                          text: _inputFormat.format(int.parse(s)),
                          selection: TextSelection.collapsed(offset: _inputFormat.format(int.parse(s)).length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  Text(isBuy ? "Sumber Dana" : "Masuk ke Dompet", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedWalletId,
                        isExpanded: true,
                        items: _wallets.map((w) => DropdownMenuItem(value: w['id'] as int, child: Text("${w['name']} (Sisa: ${_currencyFormat.format(w['balance'])})", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (v) => setSheetState(() => selectedWalletId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isBuy ? Colors.green : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                      onPressed: () async {
                        if (amountController.text.isEmpty) return;
                        if (selectedWalletId == null) return;
                        final amount = double.parse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                        final wallet = _wallets.firstWhere((w) => w['id'] == selectedWalletId);
                        
                        if (isBuy && amount > (wallet['balance'] as num).toDouble()) {
                          AppNotification.error(context, "Saldo dompet tidak mencukupi!");
                          return;
                        }
                        if (!isBuy && amount > inv.currentValue) {
                          AppNotification.error(context, "Nominal penarikan melebihi nilai aset saat ini!");
                          return;
                        }

                        try {
                          final userId = _supabase.auth.currentUser!.id;
                          final catId = isBuy ? await _getOrCreateCategory('Investasi', true) : await _getOrCreateCategory('Hasil Jual Investasi', false);
                          
                          // Update Investment
                          final newCapital = isBuy ? inv.capitalAmount + amount : (inv.capitalAmount - amount < 0 ? 0 : inv.capitalAmount - amount);
                          final newValue = isBuy ? inv.currentValue + amount : (inv.currentValue - amount < 0 ? 0 : inv.currentValue - amount);
                          
                          await _supabase.from('investments').update({
                            'capital_amount': newCapital,
                            'current_value': newValue,
                          }).eq('id', inv.id);

                          // Insert Transaction
                          await _supabase.from('transactions').insert({
                            'user_id': userId,
                            'wallet_id': selectedWalletId,
                            'category_id': catId,
                            'amount': amount,
                            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            'note': isBuy ? 'Top Up Aset: ${inv.name}' : ' Jual Aset: ${inv.name}'
                          });

                          // Update Wallet
                          final newBalance = isBuy ? (wallet['balance'] as num).toDouble() - amount : (wallet['balance'] as num).toDouble() + amount;
                          await _supabase.from('wallets').update({'balance': newBalance}).eq('id', selectedWalletId!);

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchData();
                            AppNotification.success(context, isBuy ? "Top up berhasil!" : "Penjualan berhasil!");
                          }
                        } catch (e) {
                          if (mounted) AppNotification.error(context, "Error: $e");
                        }
                      },
                      child: Text(isBuy ? "Proses Pembelian" : "Proses Penjualan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUpdateValueSheet(InvestmentModel inv) {
    final amountController = TextEditingController(text: _inputFormat.format(inv.currentValue));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Update Nilai: ${inv.name}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsFill.info, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text("Update nilai terkini aset sesuai harga pasar. Ini tidak akan memotong saldo dompetmu.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text("Nilai Saat Ini (Rp)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue.shade700),
                    decoration: InputDecoration(
                      prefixIcon: Padding(padding: const EdgeInsets.all(15), child: Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey))),
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onChanged: (s) {
                      s = s.replaceAll(RegExp(r'[^0-9]'), '');
                      if (s.isNotEmpty) {
                        amountController.value = TextEditingValue(
                          text: _inputFormat.format(int.parse(s)),
                          selection: TextSelection.collapsed(offset: _inputFormat.format(int.parse(s)).length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                      onPressed: () async {
                        if (amountController.text.isEmpty) return;
                        final amount = double.parse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                        
                        try {
                          await _supabase.from('investments').update({
                            'current_value': amount,
                          }).eq('id', inv.id);

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchData();
                            AppNotification.success(context, "Nilai berhasil diperbarui!");
                          }
                        } catch (e) {
                          if (mounted) AppNotification.error(context, "Error: $e");
                        }
                      },
                      child: Text("Simpan Pembaruan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalReturn = _totalCapital > 0 ? ((_totalValue - _totalCapital) / _totalCapital) * 100 : 0;
    bool isProfit = _totalValue >= _totalCapital;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Investasi", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header Dashboard
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Nilai Investasi", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(_currencyFormat.format(_totalValue), style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total Modal", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                              Text(_currencyFormat.format(_totalCapital), style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: isProfit ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                Icon(isProfit ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown, color: isProfit ? Colors.greenAccent : Colors.redAccent, size: 16),
                                const SizedBox(width: 5),
                                Text("${isProfit ? '+' : ''}${totalReturn.toStringAsFixed(2)}%", style: GoogleFonts.poppins(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                Text("Daftar Portofolio", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                const SizedBox(height: 15),

                if (_investments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      child: Column(
                        children: [
                          Icon(PhosphorIconsRegular.chartLineUp, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 15),
                          Text("Belum ada aset investasi.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._investments.map((inv) {
                    double ret = inv.capitalAmount > 0 ? ((inv.currentValue - inv.capitalAmount) / inv.capitalAmount) * 100 : 0;
                    bool profit = inv.currentValue >= inv.capitalAmount;
                    return GestureDetector(
                      onTap: () => _showActionSheet(inv),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15)),
                              child: Icon(PhosphorIconsFill.chartLineUp, color: Colors.blue.shade700, size: 24),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                  Text(inv.type, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  Text("Modal: ${_currencyFormat.format(inv.capitalAmount)}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_currencyFormat.format(inv.currentValue), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                const SizedBox(height: 5),
                                Text("${profit ? '+' : ''}${ret.toStringAsFixed(2)}%", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: profit ? Colors.green : Colors.red)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInvestmentSheet,
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(PhosphorIconsBold.plus, color: Colors.white),
      ),
    );
  }
}
