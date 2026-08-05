# Дизайн: горячие double-op'ы (вторая итерация IR)

Дата: 2026-08-05
Статус: одобрен пользователем (в чате)

## Цель

Снять оставшийся оверхед с double-пути обоих диалектов: сегодня после
генерации цифр (`_AsciiFloat`) каждый вызов гоняет regex по хвосту
экспоненты, режет body на integer/fraction и склеивает обратно
(`_displayFloatBody` — дорогая функция-тождество при отсутствии
grouping/locale), затем плодит конкатенации в `applyNumericWidth`.
Горячие op'ы пишут sign/body/суффикс/паддинг напрямую в `CharSink`.
Генерация цифр НЕ трогается: те же генераторы, та же семантика
округления, та же строка body от SDK-интринзика.

## Решения пользователя

- Охват: оба диалекта + double-ветка в `_BraceDynamicValueOp` (`{}`).
  Brace: `f/F/e/E/g/G/%` и `type == null` с числовыми опциями;
  printf: `f/F/e/E/g/G` со статикой и `*`-опциями. Grouping,
  `fractionalGrouping`, locale/`n`, `a/A` — fallback.
- Оба режима `doubleFormatMode` (dartSdk и compatible) горячие: режим
  читается из движка в рантайме, кэш программ по-прежнему зависит
  только от шаблона и `TextUnit`.
- Подход A: два op'а + общий писатель поверх существующих
  генераторов `_AsciiFloat`; собственный dtoa (подход B) отвергнут.
- Гейт — схема v1: устойчивое ускорение double-сценариев без
  регрессий где-либо (вкл. cold), VM — цель, JS — корректность.
  Нет GREEN — нет коммита.

## Ключевые факты (проверены в сессии)

- `_formatDartDouble` (режим dartSdk, дефолт) получает body от
  SDK-интринзиков (`toStringAsFixed`/`toStringAsExponential`/
  `toString`/`toStringAsPrecision`) — одна неустранимая аллокация.
  Compatible-режим — `_formatFixed`/`_formatScientific`/
  `_formatGeneral`/`_formatShortest` (Binary64), тоже отдают body.
- `_displayFloatBody` без locale/grouping сохраняет длину и
  содержимое body (identity), но выполняет regex
  `([eE])([+-])(\d+)$`, `indexOf('.')`, substrings и пересборку.
- Поэтому без grouping ветка `fitRegroupedZeroPadding` в
  `applyNumericWidth` вырождается: бинарный поиск сходится к
  обычному `=`-филлу — прямой zero-pad даёт бит-в-бит тот же вывод.
- printf-double безусловно использует `engine.numberLocale` (знак и
  `_displayFloatBody`); дефолт `const CNumberLocale()`
  канонизирован, поэтому рантайм-проверка
  `identical(frame.engine.numberLocale, const CNumberLocale())`
  отличает тождественную локализацию от настоящей.
- Знак: brace — `_asciiSign` (locale только при `n`); `z`-флаг
  (normalizeNegativeZero) гасит минус при `_AsciiFloat.roundedZero`.
  printf: zero-флаг гасится left-флагом и спец-значениями
  (`!formatted.special`).
- `{}` с double сегодня уходит в медленную ветку
  `_BraceDynamicValueOp` через `formatParsedValue` — при пустой
  спеке это body + опциональный минус, идеально ложится на
  single-string режим sink'а.

## Архитектура

### Общий писатель

`_writeAsciiFloatDirect(CharSink sink, String body, int signChar,
bool percentSuffix, int width, int fillChar, int align,
bool zeroEffective)` в `template_ir.dart`: контент = (знак ? 1 : 0)
+ body.length + (суффикс ? 1 : 0); формулы `>`/`=`/`<`/`^` — те же,
что `_writeLeading/_writeTrailing` у int-op'ов (ASCII-контент,
ширина инвариантна к `TextUnit`).

### `_BraceDoubleOp`

Классификация (внутри существующего `switch (spec.type)` +
отдельная ветка для `type == null` с числовыми опциями): условия
допуска — `grouping == null`, `fractionalGrouping == null`,
`customName/payload == null`, fill в один code unit. Запекаются:
type, precision, alternate, sign, zero, width, fillChar, align,
normalizeNegativeZero, percent.

Рантайм `write()`:
1. значение: `double` — как есть; `int`/`BigInt` — `toDouble()` с
   legacy-проверкой конечности (`_isIntegerValue` + `!isFinite` →
   Unsupported); прочее — делегирование в `formatParsedValue`,
   которое воспроизводит legacy целиком: для явных типов f/e/g это
   те же InvalidSpecifier/Unsupported, а для null-типа `String`
   легально форматируется как текст (спека `{:10.3}` полиморфна) —
   делегирование покрывает оба случая по построению;
2. percent → `value * 100` (как legacy);
3. генератор по `frame.engine.doubleFormatMode`: dartSdk →
   `_validateDartDoublePrecision` + `_formatDartDouble`; compatible
   → те же ветки, что `formatBraceDouble`; спец-значения →
   `_formatSpecialDouble` (учитывает `doubleSpecialValueSpelling`);
4. знак: `negative = !isNaN && isNegative`, `z`-флаг +
   `roundedZero` гасят; `_asciiSign`-семантика запечённого sign;
5. `_writeAsciiFloatDirect`.

`type == 'n'` в op не попадает (locale) — остаётся в fallback.

### `_PrintfDoubleOp`

Типы `f/F/e/E/g/G`; `a/A` — fallback. Поля width/precision — тройки
static/dynamic из v1 (`_resolveIrPrintfOption`). `write()`:
1. резолв опций (порядок width → precision → значение);
2. `identical(frame.engine.numberLocale, const CNumberLocale())` —
   иначе медленная ветка: сборка `_ResolvedPrintfConversion` и
   вызов `_formatPrintfValue`-хвоста с `writeString` результата
   (идентичные строки/ошибки при любой локали);
3. горячая ветка: `value is! double` → Unsupported (как legacy);
   генератор по режиму (`dartDecimal`-условие legacy); знак из
   флагов; zero-флаг: `zeroFlag && !left && !special`;
4. `_writeAsciiFloatDirect` (percent-суффикса в printf нет).

### `{}` с double

В `_BraceDynamicValueOp` перед медленной веткой: `value is double` →
пустая спека, генератор по режиму (dartSdk: `_formatDartDouble`
с type null/precision null → `toString`; compatible:
`_formatShortest`), спец-значения через `_formatSpecialDouble`;
минус при отрицательном (не-NaN) + `writeString(body)`.

### Кэш и согласованность

Программы зависят только от (шаблон, TextUnit). Режим, spelling и
локаль читаются из `frame.engine` в рантайме — как в fallback.
Ошибочные контексты строятся лениво по образцу v1 (specifier =
текст спеки, conversion опущен).

## Тесты (TDD)

- Compile-тесты: describe вида `double:<type>` с маркерами
  `:p<n>`/`:w<n>`/`:w*`/`:p*`; null-тип печатается как `-`
  (`'{:.2f}'` → `double:f:p2`, `'{:.3}'` → `double:-:p3`,
  `'%*.*f'` → `double:f:w*:p*`). Fallback-пины: `{:,.2f}`,
  `{:.2n}`, `{:é^10.2f}` (составной двухюнитный fill), `%a`.
- Дифф-матрица (`test/template_ir_diff_test.dart`, харнес v1 с
  паритетом контекстов): специи brace (`{:f}`, `{:.0f}`, `{:.2f}`,
  `{:10.2f}`, `{:<10.2f}`, `{:^10.2f}`, `{:=10.2f}`, `{:010.2f}`,
  `{:+.2f}`, `{: .2f}`, `{:z.1f}`, `{:#.0f}`, `{:e}`, `{:.3e}`,
  `{:E}`, `{:g}`, `{:.3g}`, `{:G}`, `{:.1%}`, `{:.3}`, `{:10.3}`)
  × значения (0.0, -0.0, 0.1, 2.5, 12345678901234.568, 1e21,
  1e-7, double.minPositive, double.maxFinite, double.nan,
  double.infinity, double.negativeInfinity, 42, BigInt, 'text',
  null) × оба режима (`Format()` и
  `Format(doubleFormatMode: DoubleFormatMode.compatible)`) × оба
  `TextUnit`; printf (`%f`, `%.0f`, `%.2f`, `%10.2f`, `%-10.2f`,
  `%010.2f`, `%+.2f`, `% .2f`, `%#.0f`, `%e`, `%.3e`, `%E`, `%g`,
  `%.3g`, `%G`, `%*.*f`) × те же значения × оба режима; плюс
  недефолтная локаль — любая `NumberLocale`, уже используемая в
  существующих тестах пакета, а при отсутствии удобной — минимальная
  инлайн-реализация в тест-файле; printf обязан дать паритет через
  медленную ветку op'а.
- Node-прогон дифф-тестов обязателен (SDK-строки на JS другие, но
  паритет с legacy — по построению; это и проверяем).
- A/B-бенчмарк: в hot добавляются `{:.2f}` (dartSdk), `{:.2f}`
  (compatible-движок), `%.2f`, `{:e}`, `{}` c 3.14159;
  `{:.2f}`-fallback-control заменяется на `{:,.2f}`.

## Бенчмарк и performance-гейт

Схема v1: RED — свежий прогон `example/bin/benchmark.dart` quick на
тихой машине перед стартом (double-сценарии матрицы:
`brace.double.*`, `printf.*f/e/g*`); GREEN — устойчивое ускорение
double-сценариев, без регрессий на остальных (порог — existing
equivalence threshold), cold не хуже, ровно один намеренный ERROR,
quick ≤ 60 с; A/B — ноль `RESULTS DIFFER`, ноль `LEGACY FASTER`.
JS — информационно.

## Вне охвата

- Собственная генерация цифр (dtoa) в sink.
- Grouping/fractionalGrouping/locale/`n` в горячих op'ах; `a/A`.
- Пул sink'ов; удаление legacy-процессоров (конфликтует с
  A/B-baseline).

## Проверка результата

- `dart test` (корень, example), node-прогон трёх IR-файлов,
  `dart analyze lib test example` — ноль замечаний.
- Compile-тесты пиннят describe и fallback-набор; дифф-матрица
  зелёная на обоих режимах/TextUnit/платформах.
- `dart run example/bin/template_ir_benchmark.dart` — double-hot
  сценарии `IR FASTER`, `{:,.2f}`-контроль не хуже EQUAL, ноль
  `RESULTS DIFFER`.
- Полная матрица quick: GREEN по критерию выше.
