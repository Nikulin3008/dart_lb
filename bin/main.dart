/// Console application for managing a registry of vacancies.
library;

/// A salary interval, a vacancy, and its parsing result use Records as required.
typedef SalaryRange = ({int minimum, int maximum});

typedef Vacancy = ({
  String company,
  String position,
  String technologyStack,
  String level,
  SalaryRange salaryRange,
  DateTime publishedAt,
});

typedef ParseResult = ({Vacancy? vacancy, String? error});

final RegExp salaryRangePattern = RegExp(r'^\$(?<min>\d+)-\$(?<max>\d+)$');

({SalaryRange? salaryRange, String? error}) _parseSalaryRange(String source) {
  final RegExpMatch? match = salaryRangePattern.firstMatch(source.trim());
  if (match == null) {
    return (
      salaryRange: null,
      error: 'Некоректний формат зарплатної вилки: $source',
    );
  }

  final int? minimum = int.tryParse(match.namedGroup('min')!);
  final int? maximum = int.tryParse(match.namedGroup('max')!);
  if (minimum == null || maximum == null) {
    return (
      salaryRange: null,
      error: 'Зарплата повинна містити цілі числа: $source',
    );
  }
  return (salaryRange: (minimum: minimum, maximum: maximum), error: null);
}

String formatSalaryRange(SalaryRange salaryRange) =>
    '\$${salaryRange.minimum}-\$${salaryRange.maximum}';

/// 1. Constant CSV input. Three rows are deliberately malformed.
const List<String> csvRows = <String>[
  'NovaTech,Flutter Developer,Dart|Flutter,Middle,\$1800-\$2600,2026-10-01',
  'CloudWay,Backend Developer,Dart|PostgreSQL,Senior,\$3200-\$4500,2026-09-28',
  'PixelForge,Mobile Developer,Dart|Flutter|Firebase,Junior,\$900-\$1400,2026-10-10',
  'DataPulse,Data Engineer,Python|SQL|Airflow,Middle,\$2100-\$3100,2026-09-21',
  'GreenByte,Full Stack Developer,Dart|Angular|Docker,Senior,\$3500-\$5000,2026-10-12',
  'SoftBridge,QA Engineer,Dart|Flutter|Appium,Middle,\$1600-\$2300,2026-10-08',
  'FinStack,API Developer,Dart|Shelf|Redis,Junior,\$1100-\$1700,2026-10-03',
  'CodePeak,Flutter Developer,Dart|Flutter|Bloc,Senior,\$3000-\$4200,2026-09-30',
  'BrightApps,Mobile Developer,Dart|Flutter|Riverpod,Middle,\$2000-\$2900,2026-10-15',
  'SecureNet,Backend Developer,Dart|MongoDB|Docker,Senior,\$3300-\$4700,2026-10-05',
  'WebNest,Junior Developer,Dart|HTML|CSS,Junior,\$800-\$1200,2026-09-25',
  'OrbitLabs,Flutter Developer,Dart|Flutter|REST,Middle,\$1900-\$2700,2026-10-18',
  // Damaged: only five fields.
  'BrokenCorp,Developer,Dart|Flutter,Middle,\$1500-\$2200',
  // Damaged: salary is not a salary range.
  'WrongSalary,Backend Developer,Dart|SQL,Senior,about 3000,2026-10-02',
  // Damaged: impossible date.
  'WrongDate,Mobile Developer,Dart|Flutter,Junior,\$1000-\$1500,2026-99-40',
  // Parses successfully, but validation must reject the future date and level.
  'FutureRole,Platform Engineer,Dart|Docker,Expert,\$2500-\$3200,2099-01-01',
];

/// 2. Parses one CSV row without allowing malformed input to stop the program.
ParseResult parseVacancy(String row) {
  final List<String> fields =
      row.split(',').map((String item) => item.trim()).toList();
  if (fields.length != 6) {
    return (
      vacancy: null,
      error: 'Очікується 6 полів, отримано ${fields.length}',
    );
  }

  if (fields.any((String field) => field.isEmpty)) {
    return (vacancy: null, error: 'Обов\'язкове поле не може бути порожнім');
  }

  final ({SalaryRange? salaryRange, String? error}) salaryResult =
      _parseSalaryRange(fields[4]);
  final SalaryRange? salaryRange = salaryResult.salaryRange;
  if (salaryRange == null) {
    return (vacancy: null, error: salaryResult.error);
  }

  final ({DateTime? date, String? error}) dateResult =
      _parseStrictIsoDate(fields[5]);
  final DateTime? publishedAt = dateResult.date;
  if (publishedAt == null) {
    return (vacancy: null, error: dateResult.error);
  }

  return (
    vacancy: (
      company: fields[0],
      position: fields[1],
      technologyStack: fields[2],
      level: fields[3],
      salaryRange: salaryRange,
      publishedAt: publishedAt,
    ),
    error: null,
  );
}

/// Rejects impossible calendar dates that DateTime would otherwise normalize.
({DateTime? date, String? error}) _parseStrictIsoDate(String source) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(source)) {
    return (date: null, error: 'Дата має формат YYYY-MM-DD: $source');
  }

  final int? year = int.tryParse(source.substring(0, 4));
  final int? month = int.tryParse(source.substring(5, 7));
  final int? day = int.tryParse(source.substring(8, 10));
  if (year == null || month == null || day == null) {
    return (date: null, error: 'Дата має формат YYYY-MM-DD: $source');
  }

  final DateTime parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return (date: null, error: 'Некоректна календарна дата: $source');
  }
  return (date: parsed, error: null);
}

/// 3. Returns every business-rule violation found in one vacancy.
List<String> validateVacancy(Vacancy vacancy, {DateTime? now}) {
  final List<String> violations = <String>[];
  const Set<String> allowedLevels = <String>{'Junior', 'Middle', 'Senior'};
  final DateTime currentDate = now ?? DateTime.now();

  if (!allowedLevels.contains(vacancy.level)) {
    violations.add('Непідтримуваний рівень: ${vacancy.level}');
  }
  if (vacancy.publishedAt.isAfter(currentDate)) {
    violations.add('Дата публікації не може бути в майбутньому');
  }
  if (vacancy.salaryRange.minimum <= 0 || vacancy.salaryRange.maximum <= 0) {
    violations.add('Межі зарплати мають бути додатними');
  }
  if (vacancy.salaryRange.minimum > vacancy.salaryRange.maximum) {
    violations.add('Мінімальна зарплата більша за максимальну');
  }
  return violations;
}

/// 6. Sorts a copy by publication date, then salary. `ascending` switches order.
List<Vacancy> sortVacancies(
  Iterable<Vacancy> vacancies, {
  required bool byPublicationDate,
  bool ascending = true,
}) {
  final List<Vacancy> sorted = List<Vacancy>.of(vacancies);
  sorted.sort((Vacancy left, Vacancy right) {
    final int comparison = byPublicationDate
        ? left.publishedAt.compareTo(right.publishedAt)
        : left.salaryRange.minimum.compareTo(right.salaryRange.minimum);
    return ascending ? comparison : -comparison;
  });
  return sorted;
}

/// 7. Produces a human-readable report using named parameters and StringBuffer.
String formatReport(
  Iterable<Vacancy> vacancies, {
  String title = 'Реєстр вакансій',
  bool maskSalary = true,
  DateTime? now,
}) {
  final StringBuffer buffer = StringBuffer('$title\n${'=' * title.length}\n');
  final DateTime currentDate = now ?? DateTime.now();

  for (final Vacancy vacancy in vacancies) {
    // 9. replaceAllMapped masks every salary digit in the public report.
    final String salary = maskSalary
        ? formatSalaryRange(vacancy.salaryRange).replaceAllMapped(
            RegExp(r'\d'),
            (Match _) => '*',
          )
        : formatSalaryRange(vacancy.salaryRange);
    // 10. Date arithmetic: the vacancy age comes from DateTime.difference.
    final Duration activeFor = currentDate.difference(vacancy.publishedAt);
    final int activeDays = activeFor.isNegative ? 0 : activeFor.inDays;
    buffer.writeln(
      '${vacancy.company}: ${vacancy.position} | ${vacancy.level} | '
      '${vacancy.technologyStack} | $salary | активна $activeDays дн.',
    );
  }
  return buffer.toString();
}

/// 8. The returned closure captures [successfulCount] from its lexical scope.
int Function({bool increment}) createSuccessCounter() {
  var successfulCount = 0;
  return ({bool increment = true}) {
    if (increment) {
      successfulCount++;
    }
    return successfulCount;
  };
}

/// Another closure factory: it captures the requested technology name.
bool Function(Vacancy) createStackPredicate(String technology) {
  final String normalizedTechnology = technology.toLowerCase();
  return (Vacancy vacancy) => vacancy.technologyStack
      .toLowerCase()
      .split('|')
      .contains(normalizedTechnology);
}

void main() {
  final int Function({bool increment}) successCounter = createSuccessCounter();
  final List<ParseResult> results = csvRows.map(parseVacancy).toList();
  final List<String> parseErrors = <String>[];
  final List<Vacancy> validVacancies = <Vacancy>[];

  for (final ParseResult result in results) {
    final Vacancy? vacancy = result.vacancy;
    if (vacancy == null) {
      parseErrors.add(result.error!);
      continue;
    }
    successCounter();
    final List<String> violations = validateVacancy(vacancy);
    if (violations.isEmpty) {
      validVacancies.add(vacancy);
    } else {
      parseErrors.add('${vacancy.company}: ${violations.join('; ')}');
    }
  }

  // 4a. Filtering pipeline with where.
  final List<Vacancy> middleVacancies = validVacancies
      .where((Vacancy vacancy) => vacancy.level == 'Middle')
      .toList();
  // 4b. Transformation pipeline with map.
  final List<String> companyAndPositions = validVacancies
      .map((Vacancy vacancy) => '${vacancy.company} — ${vacancy.position}')
      .toList();
  // 4c. Aggregation pipeline with fold: average minimum salary.
  final double averageMinimumSalary = validVacancies.isEmpty
      ? 0
      : validVacancies.fold<int>(
            0,
            (int sum, Vacancy vacancy) => sum + vacancy.salaryRange.minimum,
          ) /
          validVacancies.length;

  // 5. Group vacancies by level and calculate the aggregate for every group.
  final Map<String, List<Vacancy>> vacanciesByLevel = <String, List<Vacancy>>{};
  for (final Vacancy vacancy in validVacancies) {
    vacanciesByLevel.putIfAbsent(vacancy.level, () => <Vacancy>[]).add(vacancy);
  }
  final Map<String, double> averageMinimumSalaryByLevel = <String, double>{
    for (final MapEntry<String, List<Vacancy>> entry
        in vacanciesByLevel.entries)
      entry.key: entry.value.fold<int>(
            0,
            (int sum, Vacancy vacancy) => sum + vacancy.salaryRange.minimum,
          ) /
          entry.value.length,
  };

  final List<Vacancy> sortedByDate = sortVacancies(
    validVacancies,
    byPublicationDate: true,
    ascending: false,
  );
  final List<Vacancy> sortedBySalary = sortVacancies(
    validVacancies,
    byPublicationDate: false,
  );
  final int dartVacancyCount =
      validVacancies.where(createStackPredicate('Dart')).length;

  // avoid_print is intentionally disabled: this is a console application.
  // ignore: avoid_print
  print(formatReport(sortedByDate));
  // ignore: avoid_print
  print('Успішно розібрано: ${successCounter(increment: false)}');
  // ignore: avoid_print
  print('Коректних вакансій: ${validVacancies.length}');
  // ignore: avoid_print
  print('Middle вакансій: ${middleVacancies.length}');
  // ignore: avoid_print
  print('Dart вакансій: $dartVacancyCount');
  // ignore: avoid_print
  print(
    'Середня мінімальна зарплата: \$${averageMinimumSalary.toStringAsFixed(2)}',
  );
  // ignore: avoid_print
  print('Компанії та посади: ${companyAndPositions.join(', ')}');
  // ignore: avoid_print
  print('Групи: $averageMinimumSalaryByLevel');
  // ignore: avoid_print
  print('Найдешевша вакансія: ${sortedBySalary.first.company}');
  // ignore: avoid_print
  print('Помилки: ${parseErrors.join(' | ')}');
}
