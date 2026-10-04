const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

String two(int v) => v.toString().padLeft(2, '0');

String hhmm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Время в списке чатов: сегодня — часы, на этой неделе — день, иначе дата.
String chatTime(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  now ??= DateTime.now();
  if (sameDay(t, now)) return hhmm(t);
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
  if (diff < 7) return _weekdays[t.weekday - 1];
  return '${two(t.day)}.${two(t.month)}${t.year == now.year ? '' : '.${t.year % 100}'}';
}

/// Разделитель дат в переписке: «Сегодня», «Вчера», «19 августа».
String dayLabel(DateTime t, {DateTime? now}) {
  now ??= DateTime.now();
  if (sameDay(t, now)) return 'Сегодня';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) return 'Вчера';
  final base = '${t.day} ${_months[t.month - 1]}';
  return t.year == now.year ? base : '$base ${t.year}';
}

/// «5 участников», «1 участник», «2 участника».
String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n $one';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n $few';
  return '$n $many';
}

String lastSeen(DateTime? t) {
  if (t == null) return 'был(а) давно';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 3) return 'в сети';
  if (d.inHours < 1) return 'был(а) ${plural(d.inMinutes, 'минуту', 'минуты', 'минут')} назад';
  if (sameDay(t, DateTime.now())) return 'был(а) в ${hhmm(t)}';
  return 'был(а) ${dayLabel(t).toLowerCase()} в ${hhmm(t)}';
}
