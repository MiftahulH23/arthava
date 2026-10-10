import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/models/transaction_model.dart';
import 'package:arthava/providers/calendar_provider.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_chip.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
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

  static final DateTime _firstDay = DateTime.utc(2020, 1, 1);
  static final DateTime _lastDay = DateTime.utc(2030, 12, 31);

  void _goToMonth(int delta) {
    final target = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
    final lastOfTarget = DateTime(target.year, target.month + 1, 0);
    if (lastOfTarget.isBefore(_firstDay) || target.isAfter(_lastDay)) return;
    setState(() => _focusedDay = target);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final selectedTransactions = state.eventsForDay(_selectedDay!);

    double dailyIncome = 0;
    double dailyExpense = 0;
    for (var trx in selectedTransactions) {
      if (trx.category?.isExpense ?? true) {
        dailyExpense += trx.amount;
      } else {
        dailyIncome += trx.amount;
      }
    }

    return AppPageScaffold(
      title: 'Kalender Keuangan',
      backLabel: 'Beranda',
      children: state.isLoading
          ? const [
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ]
          : [
              AppSurfaceCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
                            style: AppTextStyles.headline,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bulan sebelumnya',
                          icon: const Icon(PhosphorIconsBold.caretLeft, color: AppColors.primary, size: 20),
                          onPressed: () => _goToMonth(-1),
                        ),
                        IconButton(
                          tooltip: 'Bulan berikutnya',
                          icon: const Icon(PhosphorIconsBold.caretRight, color: AppColors.primary, size: 20),
                          onPressed: () => _goToMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildCalendar(state),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_selectedDay!),
                  style: AppTextStyles.headline,
                ),
              ),
              Row(
                children: [
                  Expanded(child: _DailyTotalTile(label: 'Masuk', amount: dailyIncome, color: AppColors.income)),
                  const SizedBox(width: 10),
                  Expanded(child: _DailyTotalTile(label: 'Keluar', amount: dailyExpense, color: AppColors.expense)),
                ],
              ),
              if (selectedTransactions.isEmpty)
                const AppEmptyState(icon: PhosphorIconsRegular.coffee, title: 'Tidak ada transaksi hari ini')
              else
                AppGroupedSection(
                  children: [for (final trx in selectedTransactions) _buildTransactionRow(state, trx)],
                ),
            ],
    );
  }

  Widget _buildCalendar(CalendarState state) {
    final dayStyle = AppTextStyles.body.copyWith(fontSize: 15);
    return TableCalendar<TransactionModel>(
      locale: 'id_ID',
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      headerVisible: false,
      daysOfWeekHeight: 24,
      rowHeight: 44,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        weekendStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: dayStyle,
        weekendTextStyle: dayStyle.copyWith(color: AppColors.expense),
        outsideTextStyle: dayStyle.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
        todayDecoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
        todayTextStyle: dayStyle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        selectedTextStyle: dayStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      eventLoader: state.eventsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        }
      },
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return const SizedBox();
          final bool hasIncome = events.any((ev) => !(ev.category?.isExpense ?? true));
          final bool hasExpense = events.any((ev) => (ev.category?.isExpense ?? true));
          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIncome) const _MarkerDot(color: AppColors.income),
                if (hasExpense) const _MarkerDot(color: AppColors.expense),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionRow(CalendarState state, TransactionModel trx) {
    final isExpense = trx.category?.isExpense ?? true;

    // Logika Bersihin Saving ID (sama persis dengan versi lama)
    String displayNote = trx.note ?? '';
    final match = RegExp(r'\[SAVING_ID:(\d+)\]').firstMatch(displayNote);
    if (match != null) {
      String sId = match.group(1)!;
      String sName = state.savingNames[sId] ?? 'Tabungan';
      displayNote = displayNote.replaceAll(match.group(0)!, '(Sumber: $sName)').trim();
    }
    if (displayNote.isEmpty) displayNote = "Tanpa catatan";

    final wId = trx.walletId;
    final wName = state.walletNames[wId] ?? 'Kas Utama';
    final wColor = state.walletColors[wId] ?? AppColors.tintGray;
    final color = isExpense ? AppColors.expense : AppColors.income;

    return AppListRow(
      leading: AppIconTile(icon: _getCategoryIcon(trx.category?.name ?? ''), color: color, round: true),
      title: trx.category?.name ?? "Umum",
      // Wrap: chip dompet turun ke baris berikut bila tidak muat di samping catatan.
      subtitleWidget: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(displayNote, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          AppChip(label: wName, color: wColor, icon: PhosphorIconsFill.wallet),
        ],
      ),
      trailing: Text(
        (isExpense ? "- " : "+ ") + formatRupiah(trx.amount),
        style: AppTextStyles.amountRow.copyWith(color: color),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DailyTotalTile extends StatelessWidget {
  const _DailyTotalTile({required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      color: color.withValues(alpha: 0.10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(formatRupiah(amount), style: AppTextStyles.amountRow.copyWith(color: color)),
        ],
      ),
    );
  }
}
