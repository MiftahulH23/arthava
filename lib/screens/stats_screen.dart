import 'package:catat_uang_app/core/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isExpense = true;

  // [KEMBALIKAN FITUR FILTER]
  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();

  double _totalAmount = 0;
  List<Map<String, dynamic>> _categoryData = [];

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

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      DateTime startDate;
      DateTime endDate;

      if (_filterType == 'Harian') {
        startDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
          59,
        );
      } else if (_filterType == 'Tahunan') {
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
      } else {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
          23,
          59,
          59,
        );
      }

      final response = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .eq('categories.is_expense', _isExpense)
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(endDate));

      double total = 0;
      Map<String, Map<String, dynamic>> grouped = {};

      for (var item in response as List) {
        if (item['categories'] == null) continue;

        final note = item['note']?.toString() ?? '';
        final catName =
            item['categories']['name']?.toString().toLowerCase() ?? '';
        final isPureMutation =
            note.contains('[SAVING_ID:') &&
            (catName.contains('tabung') || catName.contains('cair'));

        if (isPureMutation) continue;

        final amount = (item['amount'] as num).toDouble();
        final catId = item['category_id'].toString();
        final cName = item['categories']['name'];

        total += amount;

        if (grouped.containsKey(catId)) {
          grouped[catId]!['amount'] += amount;
          grouped[catId]!['count'] += 1;
          grouped[catId]!['transactions'].add(item);
        } else {
          grouped[catId] = {
            'name': cName,
            'amount': amount,
            'count': 1,
            'transactions': [item],
          };
        }
      }

      final sortedList = grouped.values.toList()
        ..sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
        );

      if (mounted) {
        setState(() {
          _totalAmount = total;
          _categoryData = sortedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickDate() async {
    if (_filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _fetchStats();
      }
    } else if (_filterType == 'Tahunan') {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text("Pilih Tahun"),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectedDate: _selectedDate,
                onChanged: (DateTime val) {
                  setState(() => _selectedDate = val);
                  Navigator.pop(context);
                  _fetchStats();
                },
              ),
            ),
          );
        },
      );
    } else {
      DateTime tempDate = _selectedDate;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: 300,
            child: Column(
              children: [
                Text(
                  "Pilih Bulan",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: YearPicker(
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    selectedDate: tempDate,
                    onChanged: (DateTime dateTime) {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              return InkWell(
                                onTap: () {
                                  setState(
                                    () => _selectedDate = DateTime(
                                      dateTime.year,
                                      index + 1,
                                    ),
                                  );
                                  Navigator.pop(context);
                                  _fetchStats();
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'MMM',
                                    ).format(DateTime(2024, index + 1)),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    String dateLabel = '';
    if (_filterType == 'Harian') {
      dateLabel = DateFormat('dd MMM yy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Tahunan') {
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);
    } else {
      dateLabel = DateFormat('MMM yyyy', 'id_ID').format(_selectedDate);
    }

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
                          onTap: () {
                            setState(() => _isExpense = false);
                            _fetchStats();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isExpense
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !_isExpense
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
                                color: !_isExpense
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isExpense = true);
                            _fetchStats();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isExpense
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _isExpense
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
                                color: _isExpense
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _filterType,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                  ),
                                  items: ['Harian', 'Bulanan', 'Tahunan']
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _filterType = v;
                                        _selectedDate = DateTime.now();
                                      });
                                      _fetchStats();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.calendarBlank,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: Colors.grey,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _categoryData.isEmpty
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
                          height: 200,
                          child: Stack(
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                  sections: List.generate(
                                    _categoryData.length,
                                    (index) {
                                      final item = _categoryData[index];
                                      final percentage =
                                          (item['amount'] / _totalAmount) * 100;
                                      return PieChartSectionData(
                                        color:
                                            _chartColors[index %
                                                _chartColors.length],
                                        value: item['amount'],
                                        title:
                                            '${percentage.toStringAsFixed(0)}%',
                                        radius: 40,
                                        titleStyle: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
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
                                      currencyFormat.format(_totalAmount),
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
                            color: _isExpense
                                ? AppColors.expense.withOpacity(0.05)
                                : AppColors.income.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _isExpense
                                  ? AppColors.expense.withOpacity(0.2)
                                  : AppColors.income.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isExpense
                                    ? PhosphorIconsBold.trendDown
                                    : PhosphorIconsBold.trendUp,
                                color: _isExpense
                                    ? AppColors.expense
                                    : AppColors.income,
                              ),
                              const SizedBox(width: 10),
                              // [FIX OVERFLOW TOTAL]
                              Expanded(
                                child: Text(
                                  "Total ${_isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                currencyFormat.format(_totalAmount),
                                style: GoogleFonts.poppins(
                                  color: _isExpense
                                      ? AppColors.expense
                                      : AppColors.income,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(_categoryData.length, (index) {
                          final item = _categoryData[index];
                          final percentage =
                              (item['amount'] / _totalAmount) * 100;
                          final color =
                              _chartColors[index % _chartColors.length];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        index == 0
                                            ? PhosphorIconsFill.medal
                                            : (index == 1
                                                  ? PhosphorIconsFill.medal
                                                  : PhosphorIconsFill.circle),
                                        size: index < 3 ? 24 : 12,
                                        color: index == 0
                                            ? Colors.amber
                                            : (index == 1
                                                  ? Colors.grey.shade400
                                                  : color),
                                      ),
                                      if (index < 3)
                                        Positioned(
                                          bottom: 4,
                                          child: Text(
                                            "${index + 1}",
                                            style: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Row(
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
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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
                                      children: (item['transactions'] as List).map(
                                        (t) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        t['note'] ??
                                                            'Tanpa catatan',
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
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
                                        },
                                      ).toList(),
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
