// Derived from coui17 basic/DatePicker.kt, Apache-2.0.
import 'package:flutter/widgets.dart';

import '../button/soft_button.dart';
import '../dialog/soft_dialog.dart';
import 'soft_number_picker.dart';

abstract final class SoftDatePickerDefaults {
  static const double yearWidth = 76, monthWidth = 96, dayWidth = 62;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Year/month/day wheels. Changing month or year clamps the day instead of
/// letting DateTime overflow into the next month. Bounds are inclusive dates.
class SoftDatePicker extends StatelessWidget {
  SoftDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    DateTime? firstDate,
    DateTime? lastDate,
    this.enabled = true,
    this.yearLabel,
    this.monthLabel,
    this.dayLabel,
    this.yearSemanticLabel = 'Year',
    this.monthSemanticLabel = 'Month',
    this.daySemanticLabel = 'Day',
    this.haptics = true,
  }) : firstDate = _dateOnly(firstDate ?? DateTime(1900)),
       lastDate = _dateOnly(lastDate ?? DateTime(2100, 12, 31)) {
    if (this.firstDate.isAfter(this.lastDate)) {
      throw ArgumentError('firstDate must not follow lastDate');
    }
  }

  final DateTime value, firstDate, lastDate;
  final ValueChanged<DateTime>? onChanged;
  final bool enabled, haptics;
  final String Function(int)? yearLabel, monthLabel, dayLabel;
  final String yearSemanticLabel, monthSemanticLabel, daySemanticLabel;

  DateTime _clamp(DateTime date) => date.isBefore(firstDate)
      ? firstDate
      : (date.isAfter(lastDate) ? lastDate : date);

  @override
  Widget build(BuildContext context) {
    final DateTime current = _clamp(_dateOnly(value));
    void update(int year, int month, int day) {
      final int lastDay = DateTime(year, month + 1, 0).day;
      final DateTime next = _clamp(
        DateTime(year, month, day.clamp(1, lastDay)),
      );
      if (next != current) onChanged?.call(next);
    }

    final int minMonth = current.year == firstDate.year ? firstDate.month : 1;
    final int maxMonth = current.year == lastDate.year ? lastDate.month : 12;
    final int minDay =
        current.year == firstDate.year && current.month == firstDate.month
        ? firstDate.day
        : 1;
    final int maxDay =
        current.year == lastDate.year && current.month == lastDate.month
        ? lastDate.day
        : DateTime(current.year, current.month + 1, 0).day;
    Widget wheel(
      double width,
      int selected,
      int min,
      int max,
      String semantics,
      String Function(int)? label,
      ValueChanged<int> changed,
    ) => SizedBox(
      width: width,
      child: SoftNumberPicker(
        value: selected,
        min: min,
        max: max,
        wrapAround: true,
        enabled: enabled,
        onChanged: onChanged == null ? null : changed,
        label: label,
        semanticLabel: semantics,
        haptics: haptics,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            wheel(
              76,
              current.year,
              firstDate.year,
              lastDate.year,
              yearSemanticLabel,
              yearLabel,
              (int year) => update(year, current.month, current.day),
            ),
            wheel(
              96,
              current.month,
              minMonth,
              maxMonth,
              monthSemanticLabel,
              monthLabel ??
                  (int month) => const <String>[
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec',
                  ][month - 1],
              (int month) => update(current.year, month, current.day),
            ),
            wheel(
              62,
              current.day,
              minDay,
              maxDay,
              daySemanticLabel,
              dayLabel ?? (int day) => '$day'.padLeft(2, '0'),
              (int day) => update(current.year, current.month, day),
            ),
          ],
        ),
      ),
    );
  }
}

/// A nullable initial date stays nullable until the user moves a wheel or
/// confirms. Cancelling never commits the displayed fallback date.
Future<DateTime?> showSoftDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  String Function(int)? yearLabel,
  String Function(int)? monthLabel,
  String Function(int)? dayLabel,
  String yearSemanticLabel = 'Year',
  String monthSemanticLabel = 'Month',
  String daySemanticLabel = 'Day',
}) {
  final DateTime first = firstDate ?? DateTime(1900);
  final DateTime last = lastDate ?? DateTime(2100, 12, 31);
  if (_dateOnly(first).isAfter(_dateOnly(last))) {
    throw ArgumentError('Invalid date range');
  }
  DateTime selected = _dateOnly(initialDate ?? DateTime.now());
  if (selected.isBefore(first)) selected = _dateOnly(first);
  if (selected.isAfter(last)) selected = _dateOnly(last);
  return showSoftDialog<DateTime>(
    context: context,
    title: title,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SoftDatePicker(
            value: selected,
            firstDate: first,
            lastDate: last,
            yearLabel: yearLabel,
            monthLabel: monthLabel,
            dayLabel: dayLabel,
            yearSemanticLabel: yearSemanticLabel,
            monthSemanticLabel: monthSemanticLabel,
            daySemanticLabel: daySemanticLabel,
            onChanged: (DateTime value) => setState(() => selected = value),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SoftTextButton(
                    text: cancelLabel,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftTextButton(
                    text: confirmLabel,
                    variant: SoftButtonVariant.primary,
                    onPressed: () => Navigator.of(dialogContext).pop(selected),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
