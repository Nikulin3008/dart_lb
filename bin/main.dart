/// Console application for managing a registry of vacancies.
library;

import 'dart:io';

abstract class Identifiable {
  String get id;
}

mixin Validatable on Identifiable {
  bool get isValid;
  
  List<String> validate() {
    if (!isValid) return ['Сутність $id не пройшла внутрішню валідацію'];
    return [];
  }
}

sealed class CandidateLevel {
  const CandidateLevel();

  factory CandidateLevel.fromString(String level) {
    return switch (level.trim().toLowerCase()) {
      'junior' => const Junior(),
      'middle' => const Middle(),
      'senior' => const Senior(),
      _ => throw FormatException('Невідомий рівень: $level'),
    };
  }
}

class Junior extends CandidateLevel { const Junior(); }
class Middle extends CandidateLevel { const Middle(); }
class Senior extends CandidateLevel { const Senior(); }

enum WorkFormat {
  remote('Віддалено', true),
  office('Офіс', false),
  hybrid('Гібрид', true);

  final String displayName;
  final bool isFlexible;
  const WorkFormat(this.displayName, this.isFlexible);

  String getDescription() => '$displayName (Гнучкий графік: $isFlexible)';
}

/// A salary interval, a vacancy, and its parsing result use Records as required.
class Vacancy extends Identifiable with Validatable {
  final String id;
  final String company;
  final String position;
  final List<String> technologyStack;
  final int minSalary;
  final int maxSalary;
  final DateTime publishedAt;
  final CandidateLevel level;
  final WorkFormat workFormat;

  const Vacancy({
    required this.id,
    required this.company,
    required this.position,
    required this.technologyStack,
    required this.minSalary,
    required this.maxSalary,
    required this.publishedAt,
    required this.level,
    required this.workFormat,
  });

@override
  bool get isValid => minSalary > 0 && maxSalary >= minSalary && publishedAt.isBefore(DateTime.now());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vacancy &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          company == other.company &&
          position == other.position &&
          minSalary == other.minSalary;

  @override
  int get hashCode => Object.hash(id, company, position, minSalary);

  @override
  String toString() => 'Vacancy($company, $position, \$$minSalary-\$$maxSalary)';
}

class CompanyProfile extends Identifiable with Validatable {
  @override
  final String id;
  final String name;

  const CompanyProfile(this.id, this.name);

  @override
  bool get isValid => name.isNotEmpty;
}

class Repository<T extends Identifiable> {
  final Map<String, T> _items = {};

  void add(T item) => _items[item.id] = item;
  T? findById(String id) => _items[id];
  Iterable<T> where(bool Function(T) test) => _items.values.where(test);
  List<T> get all => _items.values.toList();
}

static final Map<String, Vacancy> _cache = {};

  Vacancy.fromCsv(String line)
      : id = '${line.split(',')[0].trim()}_${line.split(',')[1].trim()}'.toLowerCase(),
        company = line.split(',')[0].trim(),
        position = line.split(',')[1].trim(),
        technologyStack = line.split(',')[2].trim().split('|'),
        minSalary = _parseSalary(line.split(',')[4].trim()).$1,
        maxSalary = _parseSalary(line.split(',')[4].trim()).$2,
        publishedAt = _parseStrictIsoDate(line.split(',')[5].trim());
        level = CandidateLevel.fromString(line.split(',')[3].trim()),
        workFormat = WorkFormat.remote,

  factory Vacancy.cached(Vacancy instance) {
    return _cache.putIfAbsent(instance.id, () => instance);
  }

  static (int, int) _parseSalary(String source) {
    final match = RegExp(r'^\$(\d+)-\$(\d+)$').firstMatch(source);
    if (match == null) throw FormatException('Некоректна зарплата: $source');
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static DateTime _parseStrictIsoDate(String source) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(source)) {
      throw FormatException('Формат має бути YYYY-MM-DD: $source');
    }
    final parsed = DateTime.parse(source);
    if (source != parsed.toIso8601String().substring(0, 10)) {
      throw const FormatException('Неіснуюча календарна дата');
    }
    return parsed;
  }

final RegExp salaryRangePattern = RegExp(r'^\$(?<min>\d+)-\$(?<max>\d+)$');



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
  final List<String> validationErrors = <String>[];
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
      validationErrors.add('${vacancy.company}: ${violations.join('; ')}');
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

  stdout.writeln(formatReport(sortedByDate));
  stdout.writeln('Успішно розібрано: ${successCounter(increment: false)}');
  stdout.writeln('Коректних вакансій: ${validVacancies.length}');
  stdout.writeln('Middle вакансій: ${middleVacancies.length}');
  stdout.writeln('Dart вакансій: $dartVacancyCount');
  stdout.writeln(
    'Середня мінімальна зарплата: \$${averageMinimumSalary.toStringAsFixed(2)}',
  );
  stdout.writeln('Компанії та посади: ${companyAndPositions.join(', ')}');
  stdout.writeln('Групи: $averageMinimumSalaryByLevel');
  if (sortedBySalary.isNotEmpty) {
    stdout.writeln('Найдешевша вакансія: ${sortedBySalary.first.company}');
  } else {
    stdout.writeln('Найдешевша вакансія: немає коректних вакансій');
  }
  stdout.writeln('Помилки парсингу: ${parseErrors.join(' | ')}');
  stdout.writeln('Помилки валідації: ${validationErrors.join(' | ')}');
}