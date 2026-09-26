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
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/home_summary.dart';
import 'package:catat_uang_app/screens/all_features/all_features_screen.dart';
import 'package:catat_uang_app/screens/all_features/app_feature.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_hero_card.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_progress.dart';
import 'package:catat_uang_app/widgets/app_summary_widget.dart';

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
                  style: GoogleFonts.poppins(color: AppColors.heroLabel, fontSize: 10),
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

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (!mounted) return;
    ref.read(homeProvider.notifier).getUserProfile();
  }

  Future<void> _openWallets() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalletScreen()),
    );
    if (!mounted) return;
    ref.read(homeProvider.notifier).refreshData();
  }

  /// Pengganti 12 callback grid lama. Refresh setelah kembali mengikuti
  /// AppFeature.refreshAfter (tabel Plan B3 Task 4).
  Future<void> _openFeature(AppFeature feature) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => feature.buildScreen()),
    );
    if (!mounted) return;
    switch (feature.refreshAfter) {
      case HomeRefreshAfter.none:
        break;
      case HomeRefreshAfter.homeData:
        ref.read(homeProvider.notifier).refreshData();
      case HomeRefreshAfter.homeDataAndTabs:
        ref.read(homeProvider.notifier).refreshData();
        _bumpRefreshCounter();
    }
  }

  Future<void> _openAllFeatures() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AllFeaturesScreen(onOpen: _openFeature)),
    );
  }

  Widget _buildMobileHomeContent() {
    final homeState = ref.watch(homeProvider);

    if (homeState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppPageScaffold(
      title: 'Beranda',
      embedded: true,
      titleWidget: _HomeHeader(userName: homeState.userName, onOpenSettings: _openSettings),
      onRefresh: () => ref.read(homeProvider.notifier).refreshData(),
      children: [
        _HomeHeroCard(state: homeState),
        _HomeWalletSection(
          wallets: homeState.wallets,
          includeMinBalance: homeState.includeMinBalance,
          onOpenWallets: _openWallets,
        ),
        _HomeSummaryGrid(summary: homeState.summary, onOpen: _openFeature),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const AppIconTile(
                icon: PhosphorIconsFill.squaresFour,
                color: AppColors.primary,
                filled: true,
              ),
              title: 'Semua Fitur',
              subtitle: 'Anggaran, target, tabungan, dan 9 lainnya',
              showChevron: true,
              onTap: _openAllFeatures,
            ),
          ],
        ),
      ],
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
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
                          ),
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
                                  style: GoogleFonts.poppins(color: AppColors.heroLabel, fontSize: 16),
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
                                final colorHex = wallet.color ?? '#1E3A8A';
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
                                              wallet.name,
                                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        currencyFormat.format(wallet.balance),
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
                      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const DebtScreen())); if (!mounted) return; ref.read(homeProvider.notifier).refreshData(); _bumpRefreshCounter(); },
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
                    if (!mounted) return;
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
          if (!mounted) return;
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName, required this.onOpenSettings});

  final String userName;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo, Bos!', style: AppTextStyles.subhead),
              Text(
                userName,
                style: AppTextStyles.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Pengaturan',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onOpenSettings,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text(
                initialsOf(userName),
                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final total = spendableTotal(state.wallets, includeMinBalance: state.includeMinBalance);
    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppHeroLabel('Total Saldo Keseluruhan'),
              Icon(PhosphorIconsFill.wallet, color: AppColors.heroLabel, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          AppHeroAmount(formatRupiah(total)),
          if (!state.includeMinBalance) ...[
            const SizedBox(height: 2),
            const AppHeroLabel('Sudah dikurangi saldo minimal'),
          ],
          const SizedBox(height: 16),
          Container(height: 0.5, color: AppColors.heroLabel.withOpacity(0.3)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.arrowDown,
                  color: AppColors.heroStatIncome,
                  label: 'Masuk',
                  amount: state.monthlyIncome,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.arrowUp,
                  color: AppColors.heroStatExpense,
                  label: 'Keluar',
                  amount: state.monthlyExpense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.piggyBank,
                  color: AppColors.heroStatSavings,
                  label: 'Tabungan',
                  amount: state.totalSavings,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: PhosphorIconsFill.chartLineUp,
                  color: AppColors.heroStatInvest,
                  label: 'Investasi',
                  amount: state.totalInvestments,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.color, required this.label, required this.amount});

  final IconData icon;
  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeroLabel(label),
              Text(
                formatRupiah(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.amountRow.copyWith(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeWalletSection extends StatelessWidget {
  const _HomeWalletSection({
    required this.wallets,
    required this.includeMinBalance,
    required this.onOpenWallets,
  });

  final List<WalletModel> wallets;
  final bool includeMinBalance;
  final VoidCallback onOpenWallets;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return AppGroupedSection(
        header: 'Dompet',
        headerAction: 'Kelola',
        onHeaderAction: onOpenWallets,
        children: [
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsRegular.plusCircle, color: AppColors.primary),
            title: 'Buat Dompet Pertama',
            titleColor: AppColors.primary,
            showChevron: true,
            onTap: onOpenWallets,
          ),
        ],
      );
    }

    final view = homeWallets(wallets);
    return AppGroupedSection(
      header: 'Dompet',
      headerAction: 'Kelola',
      onHeaderAction: onOpenWallets,
      children: [
        for (final w in view.shown)
          AppListRow(
            leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: w.displayColor, filled: true),
            title: w.name,
            subtitle: includeMinBalance || w.minBalance <= 0
                ? null
                : 'Bisa dipakai ${formatRupiah(spendableOf(w))}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (w.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(PhosphorIconsFill.star, size: 14, color: AppColors.tintAmber),
                  ),
                Text(formatRupiah(w.balance), style: AppTextStyles.amountRow),
              ],
            ),
            onTap: onOpenWallets,
          ),
        if (view.hiddenCount > 0)
          AppListRow(
            title: 'Lihat semua (${wallets.length} dompet)',
            titleColor: AppColors.primary,
            showChevron: true,
            onTap: onOpenWallets,
          ),
      ],
    );
  }
}

class _HomeSummaryGrid extends StatelessWidget {
  const _HomeSummaryGrid({required this.summary, required this.onOpen});

  final HomeSummary summary;
  final ValueChanged<AppFeature> onOpen;

  static Color _budgetColor(double ratio) {
    if (ratio > 1) return AppColors.expense;
    if (ratio > 0.8) return AppColors.tintOrange;
    return AppColors.primary;
  }

  Widget _emptyText(String text, {bool withAction = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: AppTextStyles.bodyStrong, maxLines: 2),
        if (withAction)
          Text(
            'Buat',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }

  Widget _budget() {
    final b = summary.budget;
    return AppSummaryWidget(
      icon: PhosphorIconsFill.chartDonut,
      label: 'Anggaran',
      color: AppColors.primary,
      onTap: () => onOpen(AppFeature.budget),
      children: b == null
          ? [_emptyText('Belum ada anggaran', withAction: true)]
          : [
              Text(formatRupiahCompact(b.totalSpent), style: AppTextStyles.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('dari ${formatRupiahCompact(b.totalBudget)} bulan ini', style: AppTextStyles.caption, maxLines: 2),
              const SizedBox(height: 4),
              AppProgressBar(value: b.ratio, color: _budgetColor(b.ratio), height: 6),
            ],
    );
  }

  Widget _target() {
    final t = summary.target;
    return AppSummaryWidget(
      icon: PhosphorIconsFill.target,
      label: 'Target',
      color: AppColors.tintGreen,
      onTap: () => onOpen(AppFeature.target),
      children: t == null
          ? [_emptyText('Belum ada target', withAction: true)]
          : [
              Text(t.name, style: AppTextStyles.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${formatRupiahCompact(t.savedAmount)} / ${formatRupiahCompact(t.targetAmount)}',
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              AppProgressBar(
                value: t.targetAmount <= 0 ? 0 : t.savedAmount / t.targetAmount,
                color: AppColors.income,
                height: 6,
              ),
            ],
    );
  }

  Widget _bill() {
    final r = summary.nextBill;
    return AppSummaryWidget(
      icon: PhosphorIconsFill.calendarPlus,
      label: 'Tagihan',
      color: AppColors.tintOrange,
      onTap: () => onOpen(AppFeature.recurring),
      children: r == null
          ? [_emptyText('Tidak ada tagihan')]
          : [
              Text(
                r.category?['name']?.toString() ?? 'Tagihan',
                style: AppTextStyles.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(DateFormat('d MMM yyyy', 'id_ID').format(r.nextRunDate), style: AppTextStyles.caption),
              Text('-${formatRupiahCompact(r.amount)}', style: AppTextStyles.amountRow.copyWith(color: AppColors.expense)),
            ],
    );
  }

  Widget _debt() {
    final d = summary.debt;
    final late = d == null ? 0 : d.overdueDays(DateTime.now());
    final String dueText;
    if (d == null) {
      dueText = '';
    } else if (late > 0) {
      dueText = 'Terlambat $late hari';
    } else if (d.dueDate != null) {
      dueText = 'Tempo: ${DateFormat('d MMM yyyy', 'id_ID').format(d.dueDate!)}';
    } else {
      dueText = 'Tanpa jatuh tempo';
    }
    return AppSummaryWidget(
      icon: PhosphorIconsFill.handCoins,
      label: 'Utang',
      color: AppColors.expense,
      onTap: () => onOpen(AppFeature.debt),
      children: d == null
          ? [_emptyText('Bebas utang')]
          : [
              Text(d.name, style: AppTextStyles.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                dueText,
                style: late > 0
                    ? AppTextStyles.caption.copyWith(color: AppColors.expense, fontWeight: FontWeight.w700)
                    : AppTextStyles.caption,
              ),
              Text(formatRupiahCompact(d.remainingAmount), style: AppTextStyles.amountRow),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('RINGKASAN', style: AppTextStyles.groupLabel),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _budget()),
              const SizedBox(width: 10),
              Expanded(child: _target()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _bill()),
              const SizedBox(width: 10),
              Expanded(child: _debt()),
            ],
          ),
        ),
      ],
    );
  }
}
