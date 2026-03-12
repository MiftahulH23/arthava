import 'package:catat_uang_app/core/app_notification.dart';
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
import 'package:catat_uang_app/screens/target_screen.dart';
import 'package:catat_uang_app/screens/savings_screen.dart';
import 'package:catat_uang_app/screens/recurring_screen.dart';

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
  double _totalSavings = 0; // [NEW] Variabel untuk nyimpan Total Tabungan

  bool _isLoading = true;
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _checkRecurringTransactions();
    await Future.wait([_getUserProfile(), _fetchHomeData()]);
  }

  Future<void> _checkRecurringTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);

      final response = await _supabase
          .from('recurring_transactions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .lte('next_run_date', todayStr);

      final List<dynamic> dueTransactions = response;

      for (var item in dueTransactions) {
        DateTime nextRun = DateTime.parse(item['next_run_date']);
        String freq = item['frequency'];

        while (nextRun.isBefore(today) ||
            nextRun.isAtSameMomentAs(
              DateTime(today.year, today.month, today.day),
            )) {
          await _supabase.from('transactions').insert({
            'user_id': item['user_id'],
            'category_id': item['category_id'],
            'amount': item['amount'],
            'date': DateFormat('yyyy-MM-dd').format(nextRun),
            'note': '${item['note'] ?? ''} (Otomatis: $freq)'.trim(),
          });

          if (freq == 'Harian') {
            nextRun = nextRun.add(const Duration(days: 1));
          } else if (freq == 'Mingguan') {
            nextRun = nextRun.add(const Duration(days: 7));
          } else if (freq == 'Bulanan') {
            nextRun = DateTime(nextRun.year, nextRun.month + 1, nextRun.day);
          } else if (freq == 'Tahunan') {
            nextRun = DateTime(nextRun.year + 1, nextRun.month, nextRun.day);
          }
        }

        await _supabase
            .from('recurring_transactions')
            .update({'next_run_date': DateFormat('yyyy-MM-dd').format(nextRun)})
            .eq('id', item['id']);
      }
    } catch (e) {
      debugPrint("Error Recurring Executor: $e");
    }
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

      // 1. Ambil data transaksi
      final allTrxResponse = await _supabase
          .from('transactions')
          .select('amount, date, note, categories(name, is_expense)')
          .eq('user_id', userId);

      // 2. [NEW] Ambil total tabungan (Semua uang yang nyangkut di tabungan)
      final savingsResponse = await _supabase
          .from('savings')
          .select('amount')
          .eq('user_id', userId);

      double tempTotalSavings = 0;
      for (var row in savingsResponse as List) {
        tempTotalSavings += (row['amount'] as num).toDouble();
      }

      double displayIncome = 0;
      double displayExpense = 0;
      double calcIncome = 0;
      double calcExpense = 0;

      for (var item in allTrxResponse) {
        final amount = (item['amount'] as num).toDouble();
        final date = DateTime.parse(item['date']);
        final isExpense = item['categories']['is_expense'] as bool;

        final note = item['note']?.toString() ?? '';
        final catName =
            item['categories']['name']?.toString().toLowerCase() ?? '';

        final hasSavingMarker = note.contains('[SAVING_ID:');
        final isSystemCat =
            catName.contains('tabung') || catName.contains('cair');
        final isPureMutation = hasSavingMarker && isSystemCat;

        if (date.year == now.year && date.month == now.month) {
          if (isExpense) {
            calcExpense += amount;
            if (!isPureMutation) displayExpense += amount;
          } else {
            calcIncome += amount;
            if (!isPureMutation) displayIncome += amount;
          }
        }
      }

      final recentResponse = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .order('id', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _recentTransactions = (recentResponse as List)
              .map((json) => TransactionModel.fromJson(json))
              .toList();
          _monthlyIncome = displayIncome;
          _monthlyExpense = displayExpense;
          _monthlyBalance = calcIncome - calcExpense;
          _totalSavings = tempTotalSavings; // Simpan total tabungan ke state
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [NEW] Widget khusus untuk memecah card info jadi 3 kolom (Vertical Stack biar hemat tempat)
  Widget _buildCardStatItem({
    required IconData icon,
    required Color color,
    required String title,
    required double amount,
    required NumberFormat currencyFormat,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            currencyFormat.format(amount),
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
    );
  }

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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Halo, Bos!",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _userName,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        _getUserProfile();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // ==========================================
                // [UPDATE] CARD SALDO 3 KOLOM SUPER ESTETIK
                // ==========================================
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
                        "Sisa Saldo Kas Utama ($currentMonthLabel)",
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

                      // Garis pembatas elegan
                      Container(
                        padding: const EdgeInsets.only(top: 15),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCardStatItem(
                              icon: PhosphorIconsFill.arrowDown,
                              color: AppColors.income,
                              title: "Pemasukan",
                              amount: _monthlyIncome,
                              currencyFormat: currencyFormat,
                            ),
                            _buildCardStatItem(
                              icon: PhosphorIconsFill.arrowUp,
                              color: AppColors.expense,
                              title: "Pengeluaran",
                              amount: _monthlyExpense,
                              currencyFormat: currencyFormat,
                            ),
                            // Ini dia Bintang Utamanya bro! 🌟
                            _buildCardStatItem(
                              icon: PhosphorIconsFill.piggyBank,
                              color: Colors.tealAccent,
                              title: "Tabungan",
                              amount: _totalSavings,
                              currencyFormat: currencyFormat,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // MENU FITUR
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureButton(
                        icon: PhosphorIconsFill.calendarPlus,
                        label: "Tagihan",
                        color: Colors.redAccent,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecurringScreen(),
                            ),
                          );
                          _refreshData(); // Refresh paksa
                          setState(() => _refreshCounter++);
                        },
                      ),
                      const SizedBox(width: 20),
                      _buildFeatureButton(
                        icon: PhosphorIconsFill.piggyBank,
                        label: "Tabungan",
                        color: const Color(0xFF009688),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavingsScreen(),
                            ),
                          );
                          _refreshData(); // Refresh paksa
                          setState(() => _refreshCounter++);
                        },
                      ),
                      const SizedBox(width: 20),
                      _buildFeatureButton(
                        icon: PhosphorIconsFill.chartDonut,
                        label: "Anggaran",
                        color: Colors.purple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BudgetScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      _buildFeatureButton(
                        icon: PhosphorIconsFill.target,
                        label: "Target",
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TargetScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
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
                      const SizedBox(width: 20),
                      _buildFeatureButton(
                        icon: PhosphorIconsFill.filePdf,
                        label: "Export",
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExportScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

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
                            color: Colors.white,
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
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                        'id_ID',
                                      ).format(trx.date),
                                      style: const TextStyle(
                                        color: Colors.grey,
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
            width: 60,
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
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = Colors.grey;

    final List<Widget> pages = [
      _buildHomeContent(),
      TransactionHistoryScreen(
        key: ValueKey('pemasukan_$_refreshCounter'),
        isExpense: false,
      ),
      TransactionHistoryScreen(
        key: ValueKey('pengeluaran_$_refreshCounter'),
        isExpense: true,
      ),
      StatsScreen(key: ValueKey('stats_$_refreshCounter')),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool isPengeluaran = false;
          if (_selectedIndex == 2) isPengeluaran = true;
          // [UPDATE] Tunggu layar selesai, lalu PAKSA REFRESH tanpa peduli result
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  InputTransactionScreen(initialIsExpense: isPengeluaran),
            ),
          );
          _refreshData();
          setState(() => _refreshCounter++);
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: Colors.white,
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
                  color: _selectedIndex == 0 ? activeColor : inactiveColor,
                ),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              IconButton(
                tooltip: "Pemasukan",
                icon: Icon(
                  _selectedIndex == 1
                      ? PhosphorIcons.wallet(PhosphorIconsStyle.fill)
                      : PhosphorIcons.wallet(),
                  color: _selectedIndex == 1 ? AppColors.income : inactiveColor,
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
                      : inactiveColor,
                ),
                onPressed: () => setState(() => _selectedIndex = 2),
              ),
              IconButton(
                tooltip: "Laporan",
                icon: Icon(
                  _selectedIndex == 3
                      ? PhosphorIcons.chartPieSlice(PhosphorIconsStyle.fill)
                      : PhosphorIcons.chartPieSlice(),
                  color: _selectedIndex == 3 ? activeColor : inactiveColor,
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
