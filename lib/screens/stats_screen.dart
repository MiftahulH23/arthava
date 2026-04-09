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

  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();
  // [NEW] Tambahan untuk filter Periode
  DateTimeRange? _selectedDateRange;

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
    // Default periode seminggu terakhir
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      DateTime startDate;
      DateTime endDate;

      // [UPDATE] Logika tanggal disamain kaya History Transaction
      if (_filterType == 'Harian') {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      } else if (_filterType == 'Tahunan') {
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
      } else if (_filterType == 'Periode' && _selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
      } else {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
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
        final catName = item['categories']['name']?.toString().toLowerCase() ?? '';
        final isPureMutation = note.contains('[SAVING_ID:') && (catName.contains('tabung') || catName.contains('cair'));

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
        ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

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

  // [UPDATE] Pemilih Tanggal disamain 100% sama History
  void _pickDate() async {
    if (_filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
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
            surfaceTintColor: Colors.transparent,
            title: Text("Pilih Tahun", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 300, height: 300,
              child: YearPicker(
                firstDate: DateTime(2020), lastDate: DateTime(2030), selectedDate: _selectedDate,
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
    } else if (_filterType == 'Periode') {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: _selectedDateRange,
        firstDate: DateTime(2020), lastDate: DateTime(2030),
        builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
      );
      if (picked != null) {
        setState(() => _selectedDateRange = picked);
        _fetchStats();
      }
    } else {
      final currentYear = DateTime.now().year;
      final years = List.generate(11, (i) => (currentYear - 5) + i);
      int tempYear = _selectedDate.year;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pilih Bulan", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempYear, dropdownColor: Colors.white, isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                          items: years.map((year) => DropdownMenuItem<int>(value: year, child: Text("$year", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))).toList(),
                          onChanged: (val) { if (val != null) setDialogState(() => tempYear = val); },
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 300, height: 300,
                  child: Column(
                    children: [
                      const Divider(), const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final int monthIndex = index + 1;
                            final bool isSelected = _selectedDate.month == monthIndex && _selectedDate.year == tempYear;
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedDate = DateTime(tempYear, monthIndex));
                                Navigator.pop(context);
                                _fetchStats();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                                ),
                                child: Text(
                                  DateFormat('MMM', 'id_ID').format(DateTime(2024, monthIndex)),
                                  style: GoogleFonts.poppins(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final activeColor = _isExpense ? AppColors.expense : AppColors.income;

    String dateLabel = '';
    if (_filterType == 'Harian') {
      dateLabel = DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Tahunan') {
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Periode') {
      dateLabel = _selectedDateRange != null 
        ? "${DateFormat('dd MMM', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.end)}"
        : "Pilih Periode";
    } else {
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
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
                Text("Laporan Keuangan", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // TOMBOL PEMASUKAN PENGELUARAN (TETAP SAMA)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
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
                              color: !_isExpense ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !_isExpense ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Pemasukan",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: !_isExpense ? AppColors.income : Colors.grey),
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
                              color: _isExpense ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _isExpense ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Pengeluaran",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isExpense ? AppColors.expense : Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // [NEW UX] TABS FILTER TIPE 4 KOTAK SEJAJAR
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: ['Harian', 'Bulanan', 'Tahunan', 'Periode'].map((type) {
                      final isSelected = _filterType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isSelected) {
                              setState(() => _filterType = type);
                              _fetchStats();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? activeColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 15),

                // [NEW UX] TOMBOL TANGGAL (MEMANJANG FULL WIDTH)
                GestureDetector(
                  onTap: _pickDate,
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
                        Icon(PhosphorIconsRegular.calendarBlank, size: 18, color: activeColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // BAGIAN BAWAH TETAP SAMA (PIE CHART DLL)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _categoryData.isEmpty
                ? Center(child: Text("Tidak ada data", style: GoogleFonts.poppins(color: Colors.grey)))
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
                                  sections: List.generate(_categoryData.length, (index) {
                                    final item = _categoryData[index];
                                    final percentage = (item['amount'] / _totalAmount) * 100;
                                    return PieChartSectionData(
                                      color: _chartColors[index % _chartColors.length],
                                      value: item['amount'],
                                      title: '${percentage.toStringAsFixed(0)}%',
                                      radius: 40,
                                      titleStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Total", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                                    Text(currencyFormat.format(_totalAmount), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // KOTAK TOTAL BAWAH
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _isExpense ? AppColors.expense.withOpacity(0.05) : AppColors.income.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: _isExpense ? AppColors.expense.withOpacity(0.2) : AppColors.income.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(_isExpense ? PhosphorIconsBold.trendDown : PhosphorIconsBold.trendUp, color: _isExpense ? AppColors.expense : AppColors.income),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Total ${_isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                                  style: GoogleFonts.poppins(color: Colors.grey.shade700),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                currencyFormat.format(_totalAmount),
                                style: GoogleFonts.poppins(color: _isExpense ? AppColors.expense : AppColors.income, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // DAFTAR KATEGORI
                        ...List.generate(_categoryData.length, (index) {
                          final item = _categoryData[index];
                          final percentage = (item['amount'] / _totalAmount) * 100;
                          final color = _chartColors[index % _chartColors.length];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(index == 0 ? PhosphorIconsFill.medal : (index == 1 ? PhosphorIconsFill.medal : PhosphorIconsFill.circle), size: index < 3 ? 24 : 12, color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade400 : color)),
                                      if (index < 3) Positioned(bottom: 4, child: Text("${index + 1}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))),
                                    ],
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(item['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 10),
                                    Text(currencyFormat.format(item['amount']), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                subtitle: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("${item['count']} Transaksi", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                    Text("${percentage.toStringAsFixed(1)}%", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15))),
                                    child: Column(
                                      children: (item['transactions'] as List).map((t) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(t['note'] ?? 'Tanpa catatan', style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                    const SizedBox(height: 2),
                                                    Text(DateFormat('dd MMM yyyy').format(DateTime.parse(t['date'])), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 15),
                                              Text(currencyFormat.format((t['amount'] as num).toDouble()), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
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