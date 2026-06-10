import sys
import re

with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Rename _buildHomeContent to _buildMobileHomeContent
content = content.replace('Widget _buildHomeContent() {', 'Widget _buildMobileHomeContent() {')

# 2. Add _buildWebFeatureButton
web_feature_button_code = """
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildCardStatItem(
                                    icon: PhosphorIconsFill.arrowDown, color: AppColors.income, title: "Masuk", amount: _monthlyIncome, currencyFormat: currencyFormat,
                                  ),
                                  _buildCardStatItem(
                                    icon: PhosphorIconsFill.arrowUp, color: AppColors.expense, title: "Keluar", amount: _monthlyExpense, currencyFormat: currencyFormat,
                                  ),
                                  _buildCardStatItem(
                                    icon: PhosphorIconsFill.piggyBank, color: Colors.tealAccent, title: "Tabungan", amount: _totalSavings, currencyFormat: currencyFormat,
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
                      icon: PhosphorIconsFill.chartLineUp, label: "Investasi", color: Colors.cyan,
                      onTap: () => _showComingSoon(context, "Investasi"),
                    ),
                    _buildWebFeatureButton(
                      icon: PhosphorIconsFill.handHeart, label: "Zakat", color: Colors.green.shade700,
                      onTap: () => _showComingSoon(context, "Zakat & Sedekah"),
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
"""

content = content.replace('  @override\n  Widget build(BuildContext context) {', web_feature_button_code + '\n  @override\n  Widget build(BuildContext context) {')

# 3. Update build method
build_method_replacement = """
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
                  _selectedIndex == 0 ? PhosphorIcons.house(PhosphorIconsStyle.fill) : PhosphorIcons.house(),
                  color: _selectedIndex == 0 ? activeColor : inactiveColor,
                ),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              IconButton(
                icon: Icon(
                  _selectedIndex == 1 ? PhosphorIcons.wallet(PhosphorIconsStyle.fill) : PhosphorIcons.wallet(),
                  color: _selectedIndex == 1 ? AppColors.income : inactiveColor,
                ),
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: Icon(
                  _selectedIndex == 2 ? PhosphorIcons.receipt(PhosphorIconsStyle.fill) : PhosphorIcons.receipt(),
                  color: _selectedIndex == 2 ? AppColors.expense : inactiveColor,
                ),
                onPressed: () => setState(() => _selectedIndex = 2),
              ),
              IconButton(
                icon: Icon(
                  _selectedIndex == 3 ? PhosphorIcons.chartPieSlice(PhosphorIconsStyle.fill) : PhosphorIcons.chartPieSlice(),
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
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text("Tambah", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 20),
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
            child: pages[_selectedIndex],
          ),
        ],
      ),
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
"""

old_build_regex = re.compile(r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n\}', re.DOTALL)
content = old_build_regex.sub(build_method_replacement + '\n}', content)

with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
