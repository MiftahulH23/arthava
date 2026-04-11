import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<TransactionModel>> _groupedTransactions = {};
  List<TransactionModel> _selectedTransactions = [];
  bool _isLoading = true;

  Map<String, String> _savingNames = {};

  // [NEW] Simpen data dompet biar bisa dipanggil warnanya
  Map<int, String> _walletNames = {};
  Map<int, Color> _walletColors = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchWallets(); // [NEW] Panggil data dompet
    _fetchTransactions();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // [NEW] Ambil nama & warna dompet buat badge
  Future<void> _fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId);
      if (mounted) {
        setState(() {
          for (var w in res as List) {
            _walletNames[w['id']] = w['name'].toString();
            final colorHex = w['color']?.toString() ?? '#1E3A8A';
            _walletColors[w['id']] = Color(
              int.parse(colorHex.replaceFirst('#', '0xFF')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error wallets: $e");
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Ambil nama tabungan buat kamus
      final savingsRes = await _supabase
          .from('savings')
          .select('id, name')
          .eq('user_id', userId);
      Map<String, String> tempSavings = {};
      for (var row in savingsRes as List) {
        tempSavings[row['id'].toString()] = row['name'].toString();
      }

      // 2. Ambil data transaksinya
      final res = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('date', ascending: false);

      Map<DateTime, List<TransactionModel>> tempGroups = {};

      for (var item in res) {
        final trx = TransactionModel.fromJson(item);
        final normalizedDate = _normalizeDate(trx.date);

        final catName = trx.category?.name.toLowerCase() ?? '';
        final note = trx.note ?? '';
        final isSystemCat =
            catName.contains('tabung') || catName.contains('cair');
        final isPureMutation = note.contains('[SAVING_ID:') && isSystemCat;

        if (!isPureMutation) {
          if (tempGroups[normalizedDate] == null) {
            tempGroups[normalizedDate] = [];
          }
          tempGroups[normalizedDate]!.add(trx);
        }
      }

      if (mounted) {
        setState(() {
          _savingNames = tempSavings;
          _groupedTransactions = tempGroups;
          _selectedTransactions = _getEventsForDay(_selectedDay!);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TransactionModel> _getEventsForDay(DateTime day) {
    return _groupedTransactions[_normalizeDate(day)] ?? [];
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('makan')) return PhosphorIconsFill.bowlFood;
    if (name.contains('minum') || name.contains('kopi'))
      return PhosphorIconsFill.coffee;
    if (name.contains('transport') || name.contains('bensin'))
      return PhosphorIconsFill.bus;
    if (name.contains('belanja')) return PhosphorIconsFill.shoppingBag;
    if (name.contains('hiburan')) return PhosphorIconsFill.gameController;
    if (name.contains('kesehatan')) return PhosphorIconsFill.firstAid;
    if (name.contains('tagihan') || name.contains('listrik'))
      return PhosphorIconsFill.lightning;
    if (name.contains('gaji')) return PhosphorIconsFill.money;
    if (name.contains('bonus')) return PhosphorIconsFill.gift;
    return PhosphorIconsFill.tag;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    double dailyIncome = 0;
    double dailyExpense = 0;
    for (var trx in _selectedTransactions) {
      if (trx.category?.isExpense ?? true) {
        dailyExpense += trx.amount;
      } else {
        dailyIncome += trx.amount;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Kalender Keuangan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // KALENDER MODERN
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TableCalendar<TransactionModel>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    daysOfWeekHeight: 30,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      markerSize: 6,
                      markerDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: const TextStyle(color: Colors.red),
                    ),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      leftChevronIcon: const Icon(
                        Icons.chevron_left,
                        color: AppColors.primary,
                      ),
                      rightChevronIcon: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                    ),
                    eventLoader: _getEventsForDay,
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _selectedTransactions = _getEventsForDay(selectedDay);
                        });
                      }
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return const SizedBox();
                        bool hasIncome = events.any(
                          (ev) => !(ev.category?.isExpense ?? true),
                        );
                        bool hasExpense = events.any(
                          (ev) => (ev.category?.isExpense ?? true),
                        );

                        return Positioned(
                          bottom: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasIncome)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.income,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasExpense)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.expense,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // RINGKASAN HARIAN
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          'EEEE, d MMM yyyy',
                          'id_ID',
                        ).format(_selectedDay!),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.income.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Masuk",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.income,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currencyFormat.format(dailyIncome),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.income,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Keluar",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.expense,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currencyFormat.format(dailyExpense),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.expense,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // LIST TRANSAKSI HARIAN DENGAN BADGE DOMPET
                Expanded(
                  child: _selectedTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIconsRegular.coffee,
                                size: 50,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Tidak ada transaksi hari ini",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _selectedTransactions.length,
                          itemBuilder: (context, index) {
                            final trx = _selectedTransactions[index];
                            final isExpense = trx.category?.isExpense ?? true;

                            // Logika Bersihin Saving ID
                            String displayNote = trx.note ?? '';
                            final match = RegExp(
                              r'\[SAVING_ID:(\d+)\]',
                            ).firstMatch(displayNote);
                            if (match != null) {
                              String sId = match.group(1)!;
                              String sName = _savingNames[sId] ?? 'Tabungan';
                              displayNote = displayNote
                                  .replaceAll(
                                    match.group(0)!,
                                    '(Sumber: $sName)',
                                  )
                                  .trim();
                            }
                            if (displayNote.isEmpty)
                              displayNote = "Tanpa catatan";

                            // [NEW] Persiapan Wallet Badge
                            final wId = trx.walletId;
                            final wName = _walletNames[wId] ?? 'Kas Utama';
                            final wColor = _walletColors[wId] ?? Colors.grey;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          (isExpense
                                                  ? AppColors.expense
                                                  : AppColors.income)
                                              .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(
                                        trx.category?.name ?? '',
                                      ),
                                      color: isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trx.category?.name ?? "Umum",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          displayNote,
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        // [NEW] Badge Dompet
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: wColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            wName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: wColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    (isExpense ? "- " : "+ ") +
                                        currencyFormat.format(trx.amount),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
