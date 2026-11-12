/// Лабораторна робота 2. Об'єктно-орієнтована модель предметної області.
library;

import 'dart:io';

// ==========================================
// 1. Абстракції та Домішки (Mixins)
// ==========================================

/// Базовий інтерфейс для узагальненого сховища
abstract class Identifiable {
  String get id;
}

/// Домішка з обмеженням [on], яка додає спільну поведінку валідації.
/// Підмішується лише до класів, що реалізують [Identifiable].
mixin Validatable on Identifiable {
  bool get isValid;
  
  List<String> validate() {
    if (!isValid) return ['Сутність $id не пройшла внутрішню валідацію'];
    return [];
  }
}

// ==========================================
// 2. Ієрархія типів (Sealed Class) та Enum
// ==========================================

/// Ієрархія рівнів кандидата. Дозволяє вичерпні перевірки у switch.
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
// Для перевірки помилки компіляції (пункт 6) розкоментуй цей рядок:
// class Expert extends CandidateLevel { const Expert(); }

/// Перелічення з полями, конструктором та методом
enum WorkFormat {
  remote('Віддалено', true),
  office('Офіс', false),
  hybrid('Гібрид', true);
  const WorkFormat(this.displayName, this.isFlexible);

  final String displayName;
  final bool isFlexible;

  String getDescription() => '$displayName (Гнучкий графік: $isFlexible)';
}

// ==========================================
// 3. Класи-сутності
// ==========================================

/// Незмінний (immutable) клас-сутність.
class Vacancy extends Identifiable with Validatable {

  /// Генеративний константний конструктор (виконує роль первинного)
  const Vacancy({
    required this.id,
    required this.company,
    required this.position,
    required this.technologyStack,
    required this.level,
    required this.minSalary,
    required this.maxSalary,
    required this.publishedAt,
    this.workFormat = WorkFormat.remote,
  });

  /// Іменований конструктор для розбору рядка. 
  /// Якщо дані некоректні, ініціалізація викине виняток.
  Vacancy.fromCsv(String line)
      : id = _generateId(line),
        company = line.split(',')[0].trim(),
        position = line.split(',')[1].trim(),
        technologyStack = line.split(',')[2].trim().split('|'),
        level = CandidateLevel.fromString(line.split(',')[3].trim()),
        minSalary = _parseSalary(line.split(',')[4].trim()).$1,
        maxSalary = _parseSalary(line.split(',')[4].trim()).$2,
        publishedAt = _parseStrictIsoDate(line.split(',')[5].trim()),
        workFormat = WorkFormat.remote;

  /// Фабричний конструктор для кешування об'єктів за ID
  factory Vacancy.cached(Vacancy instance) {
    return _cache.putIfAbsent(instance.id, () => instance);
  }
  // Кеш для фабричного конструктора
  static final Map<String, Vacancy> _cache = {};

  @override
  final String id;
  final String company;
  final String position;
  final List<String> technologyStack;
  final CandidateLevel level;
  final int minSalary;
  final int maxSalary;
  final DateTime publishedAt;
  final WorkFormat workFormat;

  // Допоміжні статичні методи для парсингу в іменованому конструкторі
  static String _generateId(String line) {
    final parts = line.split(',');
    if (parts.length < 6) throw const FormatException('Недостатньо полів');
    return '${parts[0].trim()}_${parts[1].trim()}'.toLowerCase();
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

  @override
  bool get isValid => minSalary > 0 && maxSalary >= minSalary && publishedAt.isBefore(DateTime.now());

  /// Перевизначення для порівняння за значенням
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

/// Другий клас для демонстрації домішки (mixin)
class CompanyProfile extends Identifiable with Validatable {

  const CompanyProfile(this.id, this.name);
  @override
  final String id;
  final String name;

  @override
  bool get isValid => name.isNotEmpty;
}

// ==========================================
// 4. Узагальнене сховище (Generics)
// ==========================================

/// Сховище сутностей, які вміють повідомляти власний ідентифікатор.
class Repository<T extends Identifiable> {
  final Map<String, T> _items = {};

  void add(T item) => _items[item.id] = item;
  
  T? findById(String id) => _items[id];
  
  Iterable<T> where(bool Function(T) test) => _items.values.where(test);
  
  List<T> get all => _items.values.toList();
}

// ==========================================
// 5. Метод розширення (Extension)
// ==========================================

extension DateTimeFormatting on DateTime {
  /// Корисний метод для предметної області: повертає вік вакансії у днях
  int daysAgo() {
    final diff = DateTime.now().difference(this).inDays;
    return diff < 0 ? 0 : diff;
  }
}

// ==========================================
// 6. Дані та Головна функція
// ==========================================

const List<String> csvRows = <String>[
  'NovaTech,Flutter Developer,Dart|Flutter,Middle,\$1800-\$2600,2026-10-01',
  'CloudWay,Backend Developer,Dart|PostgreSQL,Senior,\$3200-\$4500,2026-09-28',
  'PixelForge,Mobile Developer,Dart|Flutter|Firebase,Junior,\$900-\$1400,2026-10-10',
  'BrokenCorp,Developer,Dart|Flutter,Middle,\$1500-\$2200', // Damaged
  'FutureRole,Platform Engineer,Dart|Docker,Senior,\$2500-\$3200,2099-01-01', // Future date
];

/// Використання запису (record) для повернення кількох значень
(int parsed, int failed) processCsv(List<String> rows, Repository<Vacancy> repo) {
  int success = 0;
  int fail = 0;

  for (final row in rows) {
    try {
      final vacancy = Vacancy.fromCsv(row);
      if (vacancy.isValid) {
        // Кешуємо та додаємо у репозиторій
        repo.add(Vacancy.cached(vacancy));
        success++;
      } else {
        fail++;
      }
    } catch (e) {
      fail++;
    }
  }
  return (success, fail);
}

void printSpecialOffers(Vacancy v) {
  // Деструктуризація запису та зіставлення зі зразком з охоронцем (when)
  final info = (v.level, v.minSalary);
  
  switch (info) {
    case (Senior(), final salary) when salary > 3000:
      stdout.writeln('🔥 Гаряча пропозиція для Senior: \$$salary+ у ${v.company}');
    case (Junior(), _):
      stdout.writeln('🌱 Вакансія для початківців: ${v.position} у ${v.company}');
    case _:
      break;
  }
}

double getSalaryMultiplier(CandidateLevel level) {
  // Вичерпний switch-вираз без default
  return switch (level) {
    Junior() => 1.0,
    Middle() => 1.5,
    Senior() => 2.5,
  };
}

void main() {
  final repo = Repository<Vacancy>();
  
  // Деструктуризація результату
  final (successCount, failCount) = processCsv(csvRows, repo);
  
  stdout.writeln('=== ЗВІТ З ПАРСИНГУ ===');
  stdout.writeln('Успішно додано: $successCount');
  stdout.writeln('Відхилено (помилки/невалідні): $failCount\n');

  stdout.writeln('=== АНАЛІЗ ВАКАНСІЙ ===');
  for (final vacancy in repo.all) {
    // Використання extension
    final age = vacancy.publishedAt.daysAgo();
    stdout.writeln('${vacancy.toString()} | Активна: $age дн. | ${vacancy.workFormat.getDescription()}');
    
    // Патерн-матчинг
    printSpecialOffers(vacancy);
  }

  // Експеримент із Set та hashCode (Пункт 4)
  final v1 = Vacancy(id: '1', company: 'A', position: 'Dev', technologyStack: [], level: Junior(), minSalary: 1000, maxSalary: 2000, publishedAt: DateTime.now());
  final v2 = Vacancy(id: '1', company: 'A', position: 'Dev', technologyStack: [], level: Junior(), minSalary: 1000, maxSalary: 2000, publishedAt: DateTime.now());
  
  final set = {v1, v2};
  stdout.writeln('\nРозмір множини Set з двома однаковими об\'єктами: ${set.length}');
}