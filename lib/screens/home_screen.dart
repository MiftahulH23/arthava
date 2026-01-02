import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/manage_category_screen.dart';
import 'package:catat_uang_app/screens/settings_screen.dart';
import 'package:catat_uang_app/screens/stats_screen.dart';
import 'package:catat_uang_app/screens/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/screens/export_screen.dart';
import 'package:catat_uang_app/screens/budget_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  String _userName = "Memuat...";
  List<TransactionModel> _recentTransactions = [];

  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  double _monthlyBalance = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Future.wait([_getUserProfile(), _fetchHomeData()]);
  }

  Future<void> _getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(
          () => _userName = data != null
              ? data['name']
              : (user.userMetadata?['name'] ?? "User"),
        );
      }
    } catch (e) {
      debugPrint("Error user: $e");
    }
  }

  Future<void> _fetchHomeData() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();

      final allTrxResponse = await _supabase
          .from('transactions')
          .select('amount, date, categories(is_expense)')
          .eq('user_id', userId);

      double income = 0;
      double expense = 0;

      for (var item in allTrxResponse) {
        final amount = (item['amount'] as num).toDouble();
        final date = DateTime.parse(item['date']);
        final isExpense = item['categories']['is_expense'] as bool;

        if (date.year == now.year && date.month == now.month) {
          if (isExpense) {
            expense += amount;
          } else {
            income += amount;
          }
        }
      }

      final recentResponse = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _recentTransactions = (recentResponse as List)
              .map((json) => TransactionModel.fromJson(json))
              .toList();
          _monthlyIncome = income;
          _monthlyExpense = expense;
          _monthlyBalance = income - expense;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- WIDGET HOME CONTENT UPDATE ---
  Widget _buildHomeContent() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final currentMonthLabel = DateFormat(
      'MMMM yyyy',
      'id_ID',
    ).format(DateTime.now());

    return SafeArea(
      child: Column(
        children: [
          // === BAGIAN 1: HEADER & CARD (STATIS) ===
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // HEADER (Halo Bos + Setting)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Halo, Bos!",
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _userName,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // TOMBOL SETTING (Icon Gerigi)
                    GestureDetector(
                      onTap: () async {
                        // Tambah async
                        // Tunggu sampai user kembali dari Settings
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        // Setelah kembali, refresh data user (biar nama ke-update)
                        _getUserProfile();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings_outlined, // Icon Gerigi
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // CARD SALDO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2C3E50).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sisa Saldo ($currentMonthLabel)",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(_monthlyBalance),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsFill.arrowDown,
                                    color: AppColors.income,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Pemasukan",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(_monthlyIncome),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsFill.arrowUp,
                                    color: AppColors.expense,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Pengeluaran",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(_monthlyExpense),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // === MENU FITUR (4 TOMBOL BARU) ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Biar teks panjang aman
                  children: [
                    // 1. KATEGORI
                    _buildFeatureButton(
                      icon: PhosphorIconsFill.squaresFour,
                      label: "Kategori",
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageCategoryScreen(),
                        ),
                      ),
                    ),
                    // 2. EXPORT (Coming Soon)
                    _buildFeatureButton(
                      icon: PhosphorIconsFill.filePdf,
                      label: "Export",
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExportScreen(),
                          ),
                        );
                      },
                    ),
                    // 3. ANGGARAN (Coming Soon)
                    _buildFeatureButton(
                      icon: PhosphorIconsFill.chartDonut, 
                      label: "Anggaran",
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BudgetScreen()),
                        );
                      },
                    ),
                    // 4. TARGET (Coming Soon)
                    _buildFeatureButton(
                      icon: PhosphorIconsFill.target,
                      label: "Target",
                      color: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Fitur Target segera hadir!"),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // JUDUL TERBARU
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Terbaru",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // === BAGIAN 2: SCROLLABLE LIST ===
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recentTransactions.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Center(
                          child: Text(
                            "Belum ada transaksi",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recentTransactions.length,
                      itemBuilder: (context, index) {
                        final trx = _recentTransactions[index];
                        final isExpense = trx.category?.isExpense ?? true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isExpense
                                      ? AppColors.expense.withOpacity(0.1)
                                      : AppColors.income.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isExpense
                                      ? PhosphorIcons.arrowUp()
                                      : PhosphorIcons.arrowDown(),
                                  color: isExpense
                                      ? AppColors.expense
                                      : AppColors.income,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trx.category?.name ?? "Umum",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                        'id_ID',
                                      ).format(trx.date),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                (isExpense ? "- " : "+ ") +
                                    currencyFormat.format(trx.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExpense
                                      ? AppColors.expense
                                      : AppColors.income,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET TOMBOL FITUR (KOTAK PUTIH + ICON WARNA)
  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, // Ukuran kotak
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      const TransactionHistoryScreen(
        key: ValueKey('pemasukan'),
        isExpense: false,
      ),
      const TransactionHistoryScreen(
        key: ValueKey('pengeluaran'),
        isExpense: true,
      ),
      const StatsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_selectedIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InputTransactionScreen(),
            ),
          );
          if (result == true) {
            _refreshData();
            setState(() {});
          }
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: AppColors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: "Home",
                icon: Icon(
                  _selectedIndex == 0
                      ? PhosphorIcons.house(PhosphorIconsStyle.fill)
                      : PhosphorIcons.house(),
                  color: _selectedIndex == 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              IconButton(
                tooltip: "Pemasukan",
                icon: Icon(
                  _selectedIndex == 1
                      ? PhosphorIcons.wallet(PhosphorIconsStyle.fill)
                      : PhosphorIcons.wallet(),
                  color: _selectedIndex == 1
                      ? AppColors.income
                      : AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
              const SizedBox(width: 40),
              IconButton(
                tooltip: "Pengeluaran",
                icon: Icon(
                  _selectedIndex == 2
                      ? PhosphorIcons.receipt(PhosphorIconsStyle.fill)
                      : PhosphorIcons.receipt(),
                  color: _selectedIndex == 2
                      ? AppColors.expense
                      : AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _selectedIndex = 2),
              ),
              IconButton(
                tooltip: "Laporan",
                icon: Icon(
                  _selectedIndex == 3
                      ? PhosphorIcons.chartPieSlice(PhosphorIconsStyle.fill)
                      : PhosphorIcons.chartPieSlice(),
                  color: _selectedIndex == 3
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
