/// `dd MMM yyyy, h:mm a` as shown in the design preview
/// (e.g. `19 Nov 2026, 8:30 PM`). Values are rendered in device-local time;
/// storage keeps UTC ISO-8601 (see docs/spec/data-model.md).
String formatEntryDate(DateTime value) {
  const List<String> months = <String>[
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
  ];
  final String day = value.day.toString().padLeft(2, '0');
  final int hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final String minute = value.minute.toString().padLeft(2, '0');
  final String marker = value.hour < 12 ? 'AM' : 'PM';
  return '$day ${months[value.month - 1]} ${value.year}, '
      '$hour12:$minute $marker';
}
