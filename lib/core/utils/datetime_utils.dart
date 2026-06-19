const Duration jakartaOffset = Duration(hours: 7);

DateTime toJakarta(DateTime dt) => dt.toUtc().add(jakartaOffset);
