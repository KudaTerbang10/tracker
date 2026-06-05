import 'package:intl/intl.dart';

const Duration jakartaOffset = Duration(hours: 7);

DateTime jakartaNow() => DateTime.now().toUtc().add(jakartaOffset);

DateTime toJakarta(DateTime dt) => dt.toUtc().add(jakartaOffset);

String formatDateTime(DateTime dt, String pattern) =>
    DateFormat(pattern, 'id_ID').format(toJakarta(dt));
