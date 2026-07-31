# Безопасная precision для specifier `n`

## Контекст

Specifier `n` использует `intl.NumberFormat` для локализованных цифр,
разделителей и группировки. `intl` 0.20.2 и текущая upstream-реализация
искажают значение при 19 и более дробных цифрах: например, прямое
форматирование `0.1` с 19 digits возвращает `1.844674407370955264`.

`double.toStringAsPrecision` поддерживает precision до 21, поэтому общая
граница `g`/`G` не подходит для `n`. Проверка должна учитывать безопасную
границу конкретной зависимости до вызова `NumberFormat`.

## Публичное поведение

- Для `double` со specifier `n` допустима literal precision от 1 до 18
  включительно.
- Precision 19 и выше приводит к `InvalidFormatException`.
- Исключение содержит полный placeholder в `fragment` и причину с верхней
  границей 18 в `reason`.
- Поведение `n` без precision, а также `g`/`G` с precision до 21 не меняется.
- Для integer со specifier `n` precision по-прежнему не поддерживается.

## Реализация

Проверка выполняется в `_intlNumberFormat` до построения и вызова
`NumberFormat`. Используется локальная граница 18; общий `NumberFormatter`
и ограничения `f`, `e`, `g` не изменяются.

Обновление `intl` не является исправлением: версия 0.20.3 не заявляет такой
fix и текущий upstream сохраняет тот же вычислительный путь.

## Тестирование

Regression-тест через публичный `format` проверяет:

- `.18n` сохраняет значение `0.1`;
- `.19n` выбрасывает `InvalidFormatException`;
- `fragment` равен `{:.19n}`;
- `reason` сообщает максимум 18.

После targeted RED→GREEN выполняются formatter check, analyzer, полный test
suite, analyzer примера, JIT/AOT benchmark и publish dry-run.

## Вне scope

- Собственная реализация locale-aware number formatting вместо `intl`.
- Изменение границ precision для `f`, `e`, `g` и `G`.
- Исправление upstream package внутри этого репозитория.
