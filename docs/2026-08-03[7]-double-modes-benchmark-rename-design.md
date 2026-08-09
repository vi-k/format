# Переименование benchmark режимов `double`

Статус: исполнен, вошло в 3.0.0.

## Цель

Убрать термин `float` из пользовательского benchmark, поскольку публичный тип
Dart и предмет сравнения — `double`. Одновременно разместить описание и
проверенный результат benchmark рядом с документацией
`DoubleFormatMode.compatible`, а не в разделе миграции.

## Переименование

До выпуска версии выполняется полный rename без устаревших alias:

- `example/bin/float_modes_benchmark.dart` →
  `example/bin/double_modes_benchmark.dart`;
- `example/lib/src/float_modes_benchmark.dart` →
  `example/lib/src/double_modes_benchmark.dart`;
- `runFloatModesBenchmark` → `runDoubleModesBenchmark`;
- `_FloatModeScenario` → `_DoubleModeScenario`;
- VS Code configuration `Benchmark: float modes` →
  `Benchmark: double modes`;
- актуальные unit-тесты, exports, команды и пользовательская документация
  переходят на `double`.

Исторические design/plan документы не переписываются: они фиксируют имена,
существовавшие на момент выполнения соответствующей работы.

## Документация результата

Команда запуска и описание benchmark размещаются непосредственно после
примера `DoubleFormatMode.compatible` в разделе профилей `double`.

README сообщает только подтверждённый результат для конечных значений:

> Для конечных `double` в протестированных сценариях
> `DoubleFormatMode.dartSdk` быстрее либо находится в пределах 5% от
> compatible-режима и считается равным.

Формулировка не распространяется на `NaN` и `Infinity`, потому что короткие
compatible-строки могут форматироваться быстрее. Раздел миграции больше не
содержит описание benchmark.

## Проверка

- Поиск в активных файлах не находит `float_modes`, `FloatModes` или
  `float modes`.
- `example` tests и analyzer проходят.
- Новый executable запускается, старый путь отсутствует.
- VS Code compound `Benchmark: all` ссылается на новое имя configuration.
