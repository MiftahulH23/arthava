import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/providers/home_provider.dart';
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/providers/transaction_history_provider.dart';
import 'package:catat_uang_app/screens/input_transaction/input_transaction_screen.dart';
import 'package:catat_uang_app/screens/manage_category/manage_category_screen.dart';
import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:catat_uang_app/screens/stats/stats_screen.dart';
import 'package:catat_uang_app/screens/transaction_history/transactions_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:catat_uang_app/screens/export/export_screen.dart';
import 'package:catat_uang_app/screens/budget/budget_screen.dart';
import 'package:catat_uang_app/screens/target/target_screen.dart';
import 'package:catat_uang_app/screens/savings/savings_screen.dart';
import 'package:catat_uang_app/screens/recurring/recurring_screen.dart';
import 'package:catat_uang_app/screens/ai_advisor/ai_advisor_screen.dart';
import 'package:catat_uang_app/screens/calendar/calendar_screen.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:catat_uang_app/screens/debt/debt_screen.dart';
import 'package:catat_uang_app/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:catat_uang_app/screens/investment/investment_screen.dart';
import 'package:catat_uang_app/widgets/app_bottom_nav.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _transactionsIsExpense = false;

  // [FIX] Setelah migrasi TransactionHistoryScreen/StatsScreen ke provider
  // autoDispose, mengganti ValueKey saja tidak lagi cukup untuk memaksa
  // refetch: Flutter membangun child baru sebelum subscription provider
  // child lama benar-benar ditutup (baru selesai di finalizeTree()),
  // sehingga autoDispose tidak sempat trigger dan build() tidak rerun.
  // Setiap tempat yang menaikkan _refreshCounter sekarang juga meng-
  // invalidate ketiga provider terkait secara eksplisit; ValueKey
  // dipertahankan sebagai mekanisme lama tapi sudah tidak jadi satu-
  // satunya jalur refresh.
  void _bumpRefreshCounter() {
    setState(() => _refreshCounter++);
    ref.invalidate(transactionHistoryProvider(true));
    ref.invalidate(transactionHistoryProvider(false));
    ref.invalidate(statsProvider);
  }

  int _refreshCounter = 0;

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
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
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
    final homeState = ref.watch(homeProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (homeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).padding.bottom,
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
                          homeState.userName,
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
                        ref.read(homeProvider.notifier).getUserProfile();
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
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
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
                        currencyFormat.format(homeState.totalWalletBalance),
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
                                  amount: homeState.monthlyIncome,
                                  currencyFormat: currencyFormat,
                                ),
                                _buildCardStatItem(
                                  icon: PhosphorIconsFill.arrowUp,
                                  color: AppColors.expense,
                                  title: "Keluar",
                                  amount: homeState.monthlyExpense,
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
                                  amount: homeState.totalSavings,
                                  currencyFormat: currencyFormat,
                                ),
                                _buildCardStatItem(
                                  icon: PhosphorIconsFill.chartLineUp,
                                  color: Colors.orangeAccent,
                                  title: "Investasi",
                                  amount: homeState.totalInvestments,
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
                        ref.read(homeProvider.notifier).refreshData();
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
                if (homeState.wallets.isEmpty)
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                      ref.read(homeProvider.notifier).refreshData();
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
                      itemCount: homeState.wallets.length,
                      itemBuilder: (context, index) {
                        final wallet = homeState.wallets[index];
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
                            borderRadius: BorderRadius.circular(20),
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
                            ref.read(homeProvider.notifier).refreshData();
                            _bumpRefreshCounter();
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
                            ref.read(homeProvider.notifier).refreshData();
                            _bumpRefreshCounter();
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
                            ref.read(homeProvider.notifier).refreshData();
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
                            ).then((_) => ref.read(homeProvider.notifier).refreshData());
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
                          ).then((_) => ref.read(homeProvider.notifier).refreshData()),
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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 30),
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
    final homeState = ref.watch(homeProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (homeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).refreshData(),
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
                          homeState.userName,
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
                        ref.read(homeProvider.notifier).getUserProfile();
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
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
                              currencyFormat.format(homeState.totalWalletBalance),
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
                                        icon: PhosphorIconsFill.arrowDown, color: AppColors.income, title: "Masuk", amount: homeState.monthlyIncome, currencyFormat: currencyFormat,
                                      ),
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.arrowUp, color: AppColors.expense, title: "Keluar", amount: homeState.monthlyExpense, currencyFormat: currencyFormat,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.piggyBank, color: Colors.tealAccent, title: "Tabungan", amount: homeState.totalSavings, currencyFormat: currencyFormat,
                                      ),
                                      _buildCardStatItem(
                                        icon: PhosphorIconsFill.chartLineUp, color: Colors.orangeAccent, title: "Investasi", amount: homeState.totalInvestments, currencyFormat: currencyFormat,
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
                                  ref.read(homeProvider.notifier).refreshData();
                                },
                                child: Text(
                                  "Kelola",
                                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (homeState.wallets.isEmpty)
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                                ref.read(homeProvider.notifier).refreshData();
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
                              itemCount: homeState.wallets.length > 4 ? 4 : homeState.wallets.length,
                              itemBuilder: (context, index) {
                                final wallet = homeState.wallets[index];
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
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringScreen())); ref.read(homeProvider.notifier).refreshData(); _bumpRefreshCounter(); },
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.piggyBank, label: "Tabungan", color: const Color(0xFF009688),
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const SavingsScreen())); ref.read(homeProvider.notifier).refreshData(); _bumpRefreshCounter(); },
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
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen())); ref.read(homeProvider.notifier).refreshData(); },
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
                        ).then((_) => ref.read(homeProvider.notifier).refreshData());
                      },
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.handHeart, label: "Zakat", color: Colors.green.shade700,
                      onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ZakatSedekahScreen(),
                            ),
                          ).then((_) => ref.read(homeProvider.notifier).refreshData()),
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
    final List<Widget> pages = [
      _buildMobileHomeContent(),
      TransactionsTabScreen(
        key: ValueKey('transactions_$_refreshCounter'),
        refreshCounter: _refreshCounter,
        initialIsExpense: _transactionsIsExpense,
        onActiveTabChanged: (v) => _transactionsIsExpense = v,
      ),
      StatsScreen(key: ValueKey('stats_$_refreshCounter')),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Center(
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBottomNav(
                  items: [
                    const AppBottomNavItem(
                      icon: PhosphorIconsRegular.house,
                      activeIcon: PhosphorIconsFill.house,
                    ),
                    AppBottomNavItem(
                      icon: PhosphorIconsRegular.receipt,
                      activeIcon: PhosphorIconsFill.receipt,
                      activeColor: AppColors.primary,
                    ),
                    const AppBottomNavItem(
                      icon: PhosphorIconsRegular.chartPieSlice,
                      activeIcon: PhosphorIconsFill.chartPieSlice,
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onChanged: (index) => setState(() => _selectedIndex = index),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () async {
                    bool isPengeluaran = _selectedIndex == 1 && _transactionsIsExpense;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            InputTransactionScreen(initialIsExpense: isPengeluaran),
                      ),
                    );
                    ref.read(homeProvider.notifier).refreshData();
                    _bumpRefreshCounter();
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
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
      TransactionsTabScreen(
        key: ValueKey('transactions_$_refreshCounter'),
        refreshCounter: _refreshCounter,
        initialIsExpense: _transactionsIsExpense,
        onActiveTabChanged: (v) => _transactionsIsExpense = v,
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
                icon: Icon(PhosphorIcons.receipt()),
                selectedIcon: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.fill), color: AppColors.primary),
                label: const Text('Transaksi'),
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
          bool isPengeluaran = _selectedIndex == 1 && _transactionsIsExpense;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InputTransactionScreen(initialIsExpense: isPengeluaran),
            ),
          );
          ref.read(homeProvider.notifier).refreshData();
          _bumpRefreshCounter();
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
