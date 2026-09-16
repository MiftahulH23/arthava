import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/providers/stats_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:catat_uang_app/widgets/app_tab_selector.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final List<Color> _chartColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  int _touchedIndex = -1;

  StatsNotifier get _notifier => ref.read(statsProvider.notifier);

  void _pickDate(StatsState state) async {
    if (state.filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: state.selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        _notifier.setSelectedDate(picked);
      }
    } else if (state.filterType == 'Tahunan') {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(
              "Pilih Tahun",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectedDate: state.selectedDate,
                onChanged: (DateTime val) {
                  Navigator.pop(context);
                  _notifier.setSelectedDate(val);
                },
              ),
            ),
          );
        },
      );
    } else if (state.filterType == 'Periode') {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: state.selectedDateRange,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        _notifier.setSelectedDateRange(picked);
      }
    } else {
      final currentYear = DateTime.now().year;
      final years = List.generate(11, (i) => (currentYear - 5) + i);
      int tempYear = state.selectedDate.year;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pilih Bulan",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempYear,
                          dropdownColor: Colors.white,
                          isDense: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.primary,
                          ),
                          items: years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    "$year",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => tempYear = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 300,
                  height: 300,
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final int monthIndex = index + 1;
                            final bool isSelected =
                                state.selectedDate.month == monthIndex &&
                                state.selectedDate.year == tempYear;
                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _notifier.setSelectedDate(
                                  DateTime(tempYear, monthIndex),
                                );
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  DateFormat(
                                    'MMM',
                                    'id_ID',
                                  ).format(DateTime(2024, monthIndex)),
                                  style: GoogleFonts.poppins(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _showFilterSheet() {
    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final state = ref.read(statsProvider);
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Transaksi",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _notifier.resetFilters();
                          setSheetState(() {});
                        },
                        child: Text(
                          "Reset",
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Kategori",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: state.categories.map((c) {
                              final id = c['id'] as int;
                              final isSelected =
                                  state.selectedCategoryIds.contains(id);
                              final color = state.isExpense
                                  ? AppColors.expense
                                  : AppColors.income;
                              return FilterChip(
                                label: Text(c['name']),
                                selected: isSelected,
                                onSelected: (val) {
                                  _notifier.toggleCategoryFilter(id, val);
                                  setSheetState(() {});
                                },
                                selectedColor: color.withOpacity(0.2),
                                checkmarkColor: color,
                                labelStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isSelected ? color : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                backgroundColor: Colors.grey.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected
                                        ? color
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Dompet",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: state.walletNames.entries.map((e) {
                              final id = e.key;
                              final isSelected =
                                  state.selectedWalletIds.contains(id);
                              final color = state.isExpense
                                  ? AppColors.expense
                                  : AppColors.income;
                              return FilterChip(
                                label: Text(e.value),
                                selected: isSelected,
                                onSelected: (val) {
                                  _notifier.toggleWalletFilter(id, val);
                                  setSheetState(() {});
                                },
                                selectedColor: color.withOpacity(0.2),
                                checkmarkColor: color,
                                labelStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isSelected ? color : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                backgroundColor: Colors.grey.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected
                                        ? color
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isExpense
                            ? AppColors.expense
                            : AppColors.income,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _notifier.applyFilters();
                      },
                      child: Text(
                        "Terapkan Filter",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final activeColor = state.isExpense ? AppColors.expense : AppColors.income;

    String dateLabel = '';
    if (state.filterType == 'Harian')
      dateLabel = DateFormat('dd MMM yyyy', 'id_ID').format(state.selectedDate);
    else if (state.filterType == 'Tahunan')
      dateLabel = DateFormat('yyyy', 'id_ID').format(state.selectedDate);
    else if (state.filterType == 'Periode')
      dateLabel = state.selectedDateRange != null
          ? "${DateFormat('dd MMM', 'id_ID').format(state.selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(state.selectedDateRange!.end)}"
          : "Pilih Periode";
    else
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(state.selectedDate);

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Laporan Keuangan",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _notifier.setIsExpense(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !state.isExpense
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !state.isExpense
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
                              "Pemasukan",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: !state.isExpense
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _notifier.setIsExpense(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: state.isExpense
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: state.isExpense
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
                              "Pengeluaran",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: state.isExpense
                                    ? AppColors.expense
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                AppTabSelector(
                  labels: const ['Harian', 'Bulanan', 'Tahunan', 'Periode'],
                  initialIndex: ['Harian', 'Bulanan', 'Tahunan', 'Periode']
                      .indexOf(state.filterType),
                  activeColor: activeColor,
                  onChanged: (index) {
                    final type = ['Harian', 'Bulanan', 'Tahunan', 'Periode'][index];
                    _notifier.setFilterType(type);
                  },
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickDate(state),
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.calendarBlank,
                                size: 18,
                                color: activeColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIconsRegular.funnel,
                                size: 16,
                                color: (state.selectedCategoryIds.isNotEmpty ||
                                        state.selectedWalletIds.isNotEmpty)
                                    ? activeColor
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Filter",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (state.selectedCategoryIds.isNotEmpty ||
                                          state.selectedWalletIds.isNotEmpty)
                                      ? activeColor
                                      : Colors.black87,
                                ),
                              ),
                              if (state.selectedCategoryIds.isNotEmpty ||
                                  state.selectedWalletIds.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${state.selectedCategoryIds.length + state.selectedWalletIds.length}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.categoryData.isEmpty
                ? Center(
                    child: Text(
                      "Tidak ada data",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: Stack(
                            children: [
                              PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (event is FlTapUpEvent) {
                                          if (pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection == null ||
                                              pieTouchResponse.touchedSection!.touchedSectionIndex == -1) {
                                            _touchedIndex = -1;
                                          } else {
                                            final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                            if (_touchedIndex == newIndex) {
                                              _touchedIndex = -1; // toggle off if tapped again
                                            } else {
                                              _touchedIndex = newIndex;
                                            }
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                  sections: () {
                                    List<PieChartSectionData> sections = [];
                                    double otherAmount = 0;
                                    int currentIndex = 0;
                                    for (int i = 0; i < state.categoryData.length; i++) {
                                      final item = state.categoryData[i];
                                      final percentage = (item['amount'] / state.totalAmount) * 100;

                                      if (i < 5 && percentage >= 2) {
                                        final isTouched = currentIndex == _touchedIndex;
                                        sections.add(PieChartSectionData(
                                          color: _chartColors[i % _chartColors.length],
                                          value: item['amount'],
                                          title: isTouched ? '${item['name']}\n${percentage.toStringAsFixed(1)}%' : '${percentage.toStringAsFixed(0)}%',
                                          radius: isTouched ? 65 : 50,
                                          titleStyle: GoogleFonts.poppins(
                                            fontSize: isTouched ? 12 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: isTouched ? [const Shadow(color: Colors.black45, blurRadius: 2)] : null,
                                          ),
                                        ));
                                        currentIndex++;
                                      } else {
                                        otherAmount += (item['amount'] as num).toDouble();
                                      }
                                    }

                                    if (otherAmount > 0) {
                                      final otherPercentage = (otherAmount / state.totalAmount) * 100;
                                      final isTouched = currentIndex == _touchedIndex;
                                      final remainingCount = state.categoryData.length - currentIndex;
                                      final labelText = "Gabungan\n($remainingCount)";
                                      sections.add(PieChartSectionData(
                                        color: Colors.grey.shade400,
                                        value: otherAmount,
                                        title: isTouched ? '$labelText\n${otherPercentage.toStringAsFixed(1)}%' : '${otherPercentage.toStringAsFixed(0)}%\n$labelText',
                                        radius: isTouched ? 65 : 50,
                                        titleStyle: GoogleFonts.poppins(
                                          fontSize: isTouched ? 11 : 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: isTouched ? [const Shadow(color: Colors.black45, blurRadius: 2)] : null,
                                        ),
                                      ));
                                    }
                                    return sections;
                                  }(),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Total",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      currencyFormat.format(state.totalAmount),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: state.isExpense
                                ? AppColors.expense.withOpacity(0.05)
                                : AppColors.income.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: state.isExpense
                                  ? AppColors.expense.withOpacity(0.2)
                                  : AppColors.income.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    state.isExpense
                                        ? PhosphorIconsBold.trendDown
                                        : PhosphorIconsBold.trendUp,
                                    color: state.isExpense
                                        ? AppColors.expense
                                        : AppColors.income,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Total ${state.isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    currencyFormat.format(state.totalAmount),
                                    style: GoogleFonts.poppins(
                                      color: state.isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (state.totalAmount > 0) ...[
                                const SizedBox(height: 15),
                                Divider(color: Colors.grey.shade300, height: 1),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Rata-rata harian",
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      currencyFormat.format(state.dailyAverage),
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (state.highestTransaction != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Terbesar (${state.highestTransaction!['note']})",
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        currencyFormat.format(state.highestTransaction!['amount']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: state.isExpense ? AppColors.expense : AppColors.income
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        ...List.generate(state.categoryData.length, (index) {
                          final item = state.categoryData[index];
                          final percentage =
                              (item['amount'] / state.totalAmount) * 100;
                          final color =
                              _chartColors[index % _chartColors.length];

                          Color rankColor;
                          Widget rankIcon;

                          if (index == 0) {
                            rankColor = Colors.amber;
                            rankIcon = const Icon(
                              PhosphorIconsFill.medal,
                              color: Colors.amber,
                              size: 24,
                            );
                          } else if (index == 1) {
                            rankColor = Colors.grey.shade400;
                            rankIcon = Icon(
                              PhosphorIconsFill.medal,
                              color: Colors.grey.shade400,
                              size: 24,
                            );
                          } else if (index == 2) {
                            rankColor = Colors.brown.shade300;
                            rankIcon = Icon(
                              PhosphorIconsFill.medal,
                              color: Colors.brown.shade300,
                              size: 24,
                            );
                          } else {
                            rankColor = color;
                            rankIcon = Text(
                              "#${index + 1}",
                              style: GoogleFonts.poppins(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: rankIcon,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      currencyFormat.format(item['amount']),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "${item['count']} Transaksi",
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            "${percentage.toStringAsFixed(1)}%",
                                            style: GoogleFonts.poppins(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: (percentage / 100).clamp(0.0, 1.0),
                                          backgroundColor: color.withOpacity(0.15),
                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(15),
                                      ),
                                    ),
                                    child: Column(
                                      children: (item['transactions'] as List).map((
                                        t,
                                      ) {
                                        final wId = t['wallet_id'];
                                        final wName =
                                            state.walletNames[wId] ?? 'Kas Utama';
                                        final wColor =
                                            state.walletColors[wId] ?? Colors.grey;

                                        // [FIX] Kita hajar string `[SAVING_ID:]` pakai mesin cuci regex!
                                        final rawNote =
                                            t['note']?.toString() ?? '';
                                        final cleanNote = rawNote
                                            .replaceAll(
                                              RegExp(r'\[SAVING_ID:\d+\]'),
                                              '',
                                            )
                                            .trim();

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cleanNote.isNotEmpty
                                                          ? cleanNote
                                                          : 'Tanpa catatan',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 13,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            DateTime.parse(
                                                              t['date'],
                                                            ),
                                                          ),
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize: 11,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: wColor
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            wName,
                                                            style:
                                                                GoogleFonts.poppins(
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: wColor,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              Text(
                                                currencyFormat.format(
                                                  (t['amount'] as num)
                                                      .toDouble(),
                                                ),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
