import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/manage_category/manage_category_screen.dart';
import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:catat_uang_app/screens/stats_screen.dart';
import 'package:catat_uang_app/screens/transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/screens/export/export_screen.dart';
import 'package:catat_uang_app/screens/budget/budget_screen.dart';
import 'package:catat_uang_app/screens/target_screen.dart';
import 'package:catat_uang_app/screens/savings/savings_screen.dart';
import 'package:catat_uang_app/screens/recurring/recurring_screen.dart';
import 'package:catat_uang_app/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:catat_uang_app/screens/calendar/calendar_screen.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:catat_uang_app/screens/investment/investment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  String _userName = "Memuat...";

  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  double _totalSavings = 0;
  double _totalInvestments = 0;

  List<Map<String, dynamic>> _wallets = [];
  double _totalWalletBalance = 0;

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
          .select('*, categories(is_expense)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .lte('next_run_date', todayStr);

      final List<dynamic> dueTransactions = response;

      for (var item in dueTransactions) {
        DateTime nextRun = DateTime.parse(item['next_run_date']);
        String freq = item['frequency'];
        final walletId = item['wallet_id'];
        final isExpense = item['categories']?['is_expense'] ?? true;
        final amount = (item['amount'] as num).toDouble();
        int executionCount = 0;

        while (nextRun.isBefore(today) ||
            nextRun.isAtSameMomentAs(
              DateTime(today.year, today.month, today.day),
            )) {
          await _supabase.from('transactions').insert({
            'user_id': item['user_id'],
            'category_id': item['category_id'],
            'wallet_id': walletId,
            'amount': amount,
            'date': DateFormat('yyyy-MM-dd').format(nextRun),
            'note': '${item['note'] ?? ''} (Otomatis: $freq)'.trim(),
          });
          executionCount++;
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

        if (executionCount > 0 && walletId != null) {
          final walletRes = await _supabase
              .from('wallets')
              .select('balance')
              .eq('id', walletId)
              .single();
          double currentBal = (walletRes['balance'] as num).toDouble();
          double totalAmountToProcess = amount * executionCount;
          double newBalance = isExpense
              ? currentBal - totalAmountToProcess
              : currentBal + totalAmountToProcess;
          await _supabase
              .from('wallets')
              .update({'balance': newBalance})
              .eq('id', walletId);
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

      final allTrxResponse = await _supabase
          .from('transactions')
          .select('amount, date, note, categories(name, is_expense)')
          .eq('user_id', userId);
      final savingsResponse = await _supabase
          .from('savings')
          .select('amount')
          .eq('user_id', userId);
      final invResponse = await _supabase
          .from('investments')
          .select('current_value')
          .eq('user_id', userId);
      final walletsResponse = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      double tempTotalSavings = 0;
      for (var row in savingsResponse as List) {
        tempTotalSavings += (row['amount'] as num).toDouble();
      }

      double tempTotalInv = 0;
      for (var row in invResponse as List) {
        tempTotalInv += (row['current_value'] as num).toDouble();
      }

      double tempTotalWallet = 0;
      for (var w in walletsResponse as List) {
        tempTotalWallet += (w['balance'] as num).toDouble();
      }

      double displayIncome = 0;
      double displayExpense = 0;

      for (var item in allTrxResponse) {
        final amount = (item['amount'] as num).toDouble();
        final date = DateTime.parse(item['date']);
        final isExpense = item['categories']['is_expense'] as bool;
        final note = item['note']?.toString() ?? '';
        final catName = item['categories']['name'].toString().toLowerCase();

        final isPureMutation =
            note.contains('[SAVING_ID:') &&
            (catName.contains('tabung') || catName.contains('cair'));

        if (date.year == now.year && date.month == now.month) {
          if (isExpense) {
            if (!isPureMutation) displayExpense += amount;
          } else {
            if (!isPureMutation) displayIncome += amount;
          }
        }
      }

      if (mounted) {
        setState(() {
          _monthlyIncome = displayIncome;
          _monthlyExpense = displayExpense;
          _totalSavings = tempTotalSavings;
          _totalInvestments = tempTotalInv;
          _wallets = List<Map<String, dynamic>>.from(walletsResponse);
          _totalWalletBalance = tempTotalWallet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tombol Coming Soon
  void _showComingSoon(BuildContext context, String feature) {
    AppNotification.success(context, "Fitur $feature sedang dikembangkan! 👨‍💻");
  }

  Widget _buildCardStatItem({
    required IconData icon,
    required Color color,
    required String title,
    required double amount,
    required NumberFormat currencyFormat,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
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
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHomeContent() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ), // [FIX] Margin X Global Sejajar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER PROFIL
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Saldo Keseluruhan",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const Icon(
                            PhosphorIconsFill.wallet,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(_totalWalletBalance),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 15),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildCardStatItem(
                                  icon: PhosphorIconsFill.arrowDown,
                                  color: AppColors.income,
                                  title: "Masuk",
                                  amount: _monthlyIncome,
                                  currencyFormat: currencyFormat,
                                ),
                                _buildCardStatItem(
                                  icon: PhosphorIconsFill.arrowUp,
                                  color: AppColors.expense,
                                  title: "Keluar",
                                  amount: _monthlyExpense,
                                  currencyFormat: currencyFormat,
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                _buildCardStatItem(
                                  icon: PhosphorIconsFill.piggyBank,
                                  color: Colors.tealAccent,
                                  title: "Tabungan",
                                  amount: _totalSavings,
                                  currencyFormat: currencyFormat,
                                ),
                                _buildCardStatItem(
                                  icon: PhosphorIconsFill.chartLineUp,
                                  color: Colors.orangeAccent,
                                  title: "Investasi",
                                  amount: _totalInvestments,
                                  currencyFormat: currencyFormat,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // SLIDER DOMPET
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Dompet Saya",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                        _refreshData();
                      },
                      child: Text(
                        "Kelola",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                if (_wallets.isEmpty)
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                      _refreshData();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.plusCircle,
                            color: AppColors.primary,
                            size: 30,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Buat Dompet Pertama",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _wallets.length,
                      itemBuilder: (context, index) {
                        final wallet = _wallets[index];
                        final colorHex = wallet['color'] ?? '#1E3A8A';
                        final walletColor = Color(
                          int.parse(colorHex.replaceFirst('#', '0xFF')),
                        );
                        return Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: walletColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: walletColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsFill.wallet,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      wallet['name'],
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                currencyFormat.format(wallet['balance']),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 35),

                // ==========================================
                // GRID MENU (SIMETRIS)
                // ==========================================
                Column(
                  children: [
                    // ROW 1
                    Row(
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
                            _refreshData();
                            setState(() => _refreshCounter++);
                          },
                        ),
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
                            _refreshData();
                            setState(() => _refreshCounter++);
                          },
                        ),
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
                      ],
                    ),
                    const SizedBox(height: 25),
                    // ROW 2
                    Row(
                      children: [
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.squaresFour,
                          label: "Kategori",
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ManageCategoryScreen(),
                            ),
                          ),
                        ),
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
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.robot,
                          label: "AI Advisor",
                          color: Colors.indigo,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AiAdvisorScreen(),
                            ),
                          ),
                        ),
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.calendar,
                          label: "Kalender",
                          color: Colors.pinkAccent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CalendarScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // ROW 3 (DOMPET & COMING SOON)
                    Row(
                      children: [
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.wallet,
                          label: "Dompet",
                          color: Colors.brown,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WalletScreen(),
                              ),
                            );
                            _refreshData();
                          },
                        ),
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.handCoins,
                          label: "Utang",
                          color: Colors.teal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DebtScreen(),
                            ),
                          ),
                        ),
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.chartLineUp,
                          label: "Investasi",
                          color: Colors.orangeAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const InvestmentScreen(),
                              ),
                            ).then((_) => _refreshData());
                          },
                        ),
                        _buildFeatureButton(
                          icon: PhosphorIconsFill.handHeart,
                          label: "Zakat",
                          color: Colors.green.shade700,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ZakatSedekahScreen(),
                            ),
                          ).then((_) => _refreshData()),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebFeatureButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebHomeContent() {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER PROFIL
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Halo, Bos!",
                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
                        ),
                        Text(
                          _userName,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                        _getUserProfile();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.settings_outlined, color: Colors.black, size: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // TOP SECTION: ROW (Card Saldo + Dompet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SALDO CARD
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2C3E50).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total Saldo Keseluruhan",
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                                ),
                                const Icon(PhosphorIconsFill.wallet, color: Colors.white54, size: 28),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Text(
                              currencyFormat.format(_totalWalletBalance),
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.only(top: 20),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.arrowDown, color: AppColors.income, title: "Masuk", amount: _monthlyIncome, currencyFormat: currencyFormat,
                                      ),
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.arrowUp, color: AppColors.expense, title: "Keluar", amount: _monthlyExpense, currencyFormat: currencyFormat,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.piggyBank, color: Colors.tealAccent, title: "Tabungan", amount: _totalSavings, currencyFormat: currencyFormat,
                                      ),
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.chartLineUp, color: Colors.orangeAccent, title: "Investasi", amount: _totalInvestments, currencyFormat: currencyFormat,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // DOMPET LIST
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Dompet Saya",
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                                  _refreshData();
                                },
                                child: Text(
                                  "Kelola",
                                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_wallets.isEmpty)
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                                _refreshData();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(PhosphorIconsRegular.plusCircle, color: AppColors.primary, size: 40),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Buat Dompet Pertama",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.8,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                              ),
                              itemCount: _wallets.length > 4 ? 4 : _wallets.length,
                              itemBuilder: (context, index) {
                                final wallet = _wallets[index];
                                final colorHex = wallet['color'] ?? '#1E3A8A';
                                final walletColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                                return Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: walletColor,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: walletColor.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(PhosphorIconsFill.wallet, color: Colors.white70, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              wallet['name'],
                                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        currencyFormat.format(wallet['balance']),
                                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),

                // GRID MENU (WEB VERSION)
                Text(
                  "Menu & Fitur",
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 25),
                Wrap(
                  spacing: 25,
                  runSpacing: 25,
                  children: [
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.calendarPlus, label: "Tagihan", color: Colors.redAccent,
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringScreen())); _refreshData(); setState(() => _refreshCounter++); },
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.piggyBank, label: "Tabungan", color: const Color(0xFF009688),
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const SavingsScreen())); _refreshData(); setState(() => _refreshCounter++); },
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.chartDonut, label: "Anggaran", color: Colors.purple,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.target, label: "Target", color: Colors.green,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TargetScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.squaresFour, label: "Kategori", color: Colors.orange,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCategoryScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.filePdf, label: "Export", color: Colors.blue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExportScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.robot, label: "AI Advisor", color: Colors.indigo,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AiAdvisorScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.calendar, label: "Kalender", color: Colors.pinkAccent,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.wallet, label: "Dompet", color: Colors.brown,
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen())); _refreshData(); },
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.handCoins, label: "Utang", color: Colors.teal,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DebtScreen())),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.chartLineUp,
                      label: "Investasi",
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InvestmentScreen(),
                          ),
                        ).then((_) => _refreshData());
                      },
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.handHeart, label: "Zakat", color: Colors.green.shade700,
                      onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ZakatSedekahScreen(),
                            ),
                          ).then((_) => _refreshData()),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    final activeColor = AppColors.primary;
    final inactiveColor = Colors.grey;
    final List<Widget> pages = [
      _buildMobileHomeContent(),
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
          bool isPengeluaran = _selectedIndex == 2;
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
                icon: Icon(
                  _selectedIndex == 0
                      ? PhosphorIcons.house(PhosphorIconsStyle.fill)
                      : PhosphorIcons.house(),
                  color: _selectedIndex == 0 ? activeColor : inactiveColor,
                ),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              IconButton(
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

  Widget _buildWebLayout() {
    final activeColor = AppColors.primary;
    final inactiveColor = Colors.grey;
    final List<Widget> pages = [
      _buildWebHomeContent(),
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            extended: true,
            minExtendedWidth: 250,
            backgroundColor: Colors.white,
            selectedIconTheme: IconThemeData(color: activeColor),
            selectedLabelTextStyle: GoogleFonts.poppins(color: activeColor, fontWeight: FontWeight.bold),
            unselectedIconTheme: IconThemeData(color: inactiveColor),
            unselectedLabelTextStyle: GoogleFonts.poppins(color: inactiveColor, fontWeight: FontWeight.w500),
            leading: Column(
              children: [
                const SizedBox(height: 20),
                Text("DompetKu", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: activeColor)),
                const SizedBox(height: 30),
              ],
            ),
            destinations: [
              NavigationRailDestination(
                icon: Icon(PhosphorIcons.house()),
                selectedIcon: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
                label: const Text('Beranda'),
              ),
              NavigationRailDestination(
                icon: Icon(PhosphorIcons.wallet()),
                selectedIcon: Icon(PhosphorIcons.wallet(PhosphorIconsStyle.fill), color: AppColors.income),
                label: const Text('Pemasukan'),
              ),
              NavigationRailDestination(
                icon: Icon(PhosphorIcons.receipt()),
                selectedIcon: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.fill), color: AppColors.expense),
                label: const Text('Pengeluaran'),
              ),
              NavigationRailDestination(
                icon: Icon(PhosphorIcons.chartPieSlice()),
                selectedIcon: Icon(PhosphorIcons.chartPieSlice(PhosphorIconsStyle.fill)),
                label: const Text('Statistik'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: pages[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          bool isPengeluaran = _selectedIndex == 2;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InputTransactionScreen(initialIsExpense: isPengeluaran),
            ),
          );
          _refreshData();
          setState(() => _refreshCounter++);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text("Tambah Transaksi", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildWebLayout();
        }
        return _buildMobileLayout();
      },
    );
  }
}
