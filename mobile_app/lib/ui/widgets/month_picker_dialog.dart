import 'package:flutter/material.dart';

const List<String> _monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

Future<DateTime?> showMonthPicker(
  BuildContext context,
  DateTime initialDate,
) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => MonthPickerDialog(initialDate: initialDate),
  );
}

class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _year;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Ay Seç'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const Key('month-picker-prev-year'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _year--),
                ),
                Text('$_year', style: textTheme.titleMedium),
                IconButton(
                  key: const Key('month-picker-next-year'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected = month == _selectedMonth;
                return _MonthCell(
                  label: _monthNames[index],
                  selected: selected,
                  selectedColor: colors.primary,
                  onTap: () => setState(() => _selectedMonth = month),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('month-picker-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const Key('month-picker-select'),
          onPressed: () => Navigator.of(context).pop(
            DateTime(_year, _selectedMonth),
          ),
          child: const Text('Seç'),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? selectedColor : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.bold : null,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
