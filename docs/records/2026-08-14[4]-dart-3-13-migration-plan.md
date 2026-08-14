# Dart 3.13 Migration Implementation Plan

Статус: исполняется 2026-08-14 через `superpowers:executing-plans`. Tasks 1–5
завершены: миграционный commit/CI зелёные, проверенный AMD-эталон записан;
Task 6 — полный прогон, baseline-коммит и его push-CI — ещё открыт.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перевести внутренние wasm-host'ы и основной CI на Dart stable,
подтвердить миграцию полным прогоном на Dart 3.13.0 и записать новый
сопоставимый performance-эталон с AMD runner.

**Architecture:** Оба host'а напрямую используют объектный loader API Dart
3.13: `compile(bytes)`, `compiled.instantiate({})`,
`instance.invokeMain(...args)`. Реальные compile-тесты получают версию из
`Platform.version`, а CI сохраняет отдельную проверку минимального Dart 3.7.2
и использует `stable` для всех primary jobs. Миграция и пересъёмка эталона —
два последовательных атомарных коммита, потому что отчёты performance gate
могут быть собраны только из уже опубликованной ревизии.

**Tech Stack:** Dart stable 3.13.0, dart2js, dart2wasm, Node.js 24.8.0,
GitHub Actions, `package:test`, существующие benchmark suite и performance
gate.

## Global Constraints

- Документы пишутся по-русски, код и комментарии в коде — по-английски.
- Публичный API, язык форматных строк и минимальный Dart 3.7.2 не меняются.
- Оба внутренних wasm-host'а поддерживают только API Dart 3.13; compatibility
  shim для loader API 3.12 не добавляется.
- Матрица benchmark-сценариев не меняется. Литералы 3.12.2 и 3.12.3 в
  `benchmark/test/benchmark_gates_test.dart` остаются тестовыми фикстурами.
- Миграция — один коммит после полного локального прогона. Новый AMD-эталон —
  отдельный follow-up-коммит после CI-диспатча и ещё одного полного прогона.
- Промежуточных коммитов нет: перед каждым коммитом обязателен весь список из
  `docs/handoff.md`, включая Node, wasm, архив, генераторы, покрытие и три
  benchmark-матрицы.
- Миграция не заявляет ускорение, но локальные VM/JS/Wasm-матрицы обязательны.
  Эталон записывается только из восьми отчётов точной закоммиченной ревизии на
  AMD EPYC; Intel-прогон не подходит.
- Работа ведётся прямо в `main`, без PR. После каждого из двух коммитов — push
  и проверка GitHub Actions.
- `docs/backlog.md` не индексируется и не меняется. Пункт про медленный `c`
  вычёркивается только после отдельного завершённого исследования.
- Все локальные команды Dart для миграции запускаются SDK
  `/Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart`, а не
  закреплённым старым SDK.

---

### Task 1: Зафиксировать красную фазу на Dart 3.13

**Files:**
- Read: `benchmark/wasm_host.mjs`
- Read: `benchmark/suite/tool/run.dart:116-130`
- Test: `benchmark/test/benchmark_scenarios_test.dart`

**Interfaces:**
- Consumes: сгенерированный `benchmark.mjs` из Dart 3.13.
- Proves: оба старых host'а требуют отсутствующие named exports
  `instantiate` и `invoke`.

- [x] **Step 1: Проверить точный SDK и подготовить зависимости**

Run from the repository root:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart --version
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart pub get
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart pub get)
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/baselines/format16/fetch.dart
```

Expected: первая команда сообщает Dart SDK 3.13.0 stable; зависимости и
базовая линия материализуются без изменения отслеживаемых файлов.

- [x] **Step 2: Подтвердить отказ committed host'а**

Run:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test benchmark/test/benchmark_scenarios_test.dart --name 'compiled wasm runner records dart2wasm provenance'
```

Expected: FAIL до правки — Node сообщает, что loader module Dart 3.13 не
экспортирует `instantiate` (либо эквивалентный отказ старого
`instantiate`/`invoke` протокола). Сохранить точный текст в рабочей заметке
сессии.

- [x] **Step 3: Подтвердить отказ генерируемого host'а suite**

Run:

```sh
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/run.dart --runtime=wasm --bin=list_snapshot)
```

Expected: ненулевой exit code с тем же несовместимым импортом. Это отдельный
красный сторож для строки host'а в `benchmark/suite/tool/run.dart`.

- [x] **Step 4: Зафиксировать ожидаемую дельту форматтера**

Run:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart format -o none --set-exit-if-changed .
```

Expected: ненулевой exit code; по разведке Dart 3.13 требует форматирования
только `benchmark/test/benchmark_scenarios_test.dart`. Если список шире,
остановиться и проверить причину до изменения файлов.

### Task 2: Перевести host'ы, compile-тесты и CI на stable

**Files:**
- Modify: `benchmark/wasm_host.mjs:12-14`
- Modify: `benchmark/suite/tool/run.dart:116-130`
- Modify: `benchmark/test/benchmark_scenarios_test.dart:21,620-689,756-815`
- Modify: `.github/workflows/ci.yaml:41-68,154,181,216,263`

**Interfaces:**
- Consumes: `compile(Uint8Array) -> CompiledApp` из Dart 3.13 loader module.
- Produces: `CompiledApp.instantiate({}) -> InstantiatedApp` и
  `InstantiatedApp.invokeMain(...args)` в обоих host'ах.
- Produces: `_dartCompilerVersion`, равный первому токену
  `Platform.version`, для provenance реальных compile-тестов.

- [x] **Step 1: Перевести committed wasm-host**

Заменить старый импорт и вызов в `benchmark/wasm_host.mjs` на:

```js
const { compile } = await import(loaderUrl.href);
const compiled = await compile(await readFile(moduleUrl));
const instance = await compiled.instantiate({});
instance.invokeMain(...args);
```

Не менять разбор `modulePath`, вычисление `loaderUrl` и
`process.argv.slice(3)`.

- [x] **Step 2: Перевести host, генерируемый benchmark suite**

В строке, записываемой `benchmark/suite/tool/run.dart`, оставить импорт
`readFile`, а loader использовать так:

```js
import { readFile } from 'node:fs/promises';
import { compile } from './benchmark.mjs';

const bytes = await readFile(new URL('./benchmark.wasm', import.meta.url));
const compiled = await compile(bytes);
const instance = await compiled.instantiate({});
instance.invokeMain(...process.argv.slice(2));
```

Структуру временного каталога и имена `benchmark.wasm`, `benchmark.mjs`,
`host.mjs` не менять.

- [x] **Step 3: Убрать ложный литерал версии из реальных compile-тестов**

Сразу после `_testSourceRevision` в
`benchmark/test/benchmark_scenarios_test.dart` добавить:

```dart
final _dartCompilerVersion = Platform.version.split(' ').first;
```

В тестах `compiled JavaScript runner preserves typed error outcomes` и
`compiled wasm runner records dart2wasm provenance` заменить значение define
`format.benchmark.dartCompilerVersion=3.12.2` на
`format.benchmark.dartCompilerVersion=$_dartCompilerVersion` и ожидание
`dartCompilerVersion: '3.12.2'` на
`dartCompilerVersion: _dartCompilerVersion`.

Не менять фиктивные версии в `benchmark/test/benchmark_gates_test.dart`.

- [x] **Step 4: Вернуть primary CI на движущийся stable**

В `.github/workflows/ci.yaml`:

- сохранить запись матрицы `sdk: '3.7.2'` как минимальную;
- заменить primary-запись `sdk: '3.12.2'` на `sdk: stable`, сохранив
  `primary: true`;
- заменить на `stable` `dart-version` jobs `generated-artifacts`, `coverage`,
  `benchmark-suite` и `performance-gate`;
- убрать объяснение временного 3.12.2 pin и оставить короткий комментарий, что
  3.7.2 проверяет нижнюю границу, а stable запускает format/analyze и основной
  набор;
- не менять SHA actions, Node.js 24.8.0, события workflow и условия jobs.

- [x] **Step 5: Принять форматирование Dart 3.13**

Run:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart format .
rtk git diff --stat
```

Expected: кроме намеренных правок форматтер меняет только
`benchmark/test/benchmark_scenarios_test.dart`. Не принимать новые
необъяснённые файлы.

- [x] **Step 6: Подтвердить зелёные интеграционные сторожа**

Run:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test benchmark/test/benchmark_scenarios_test.dart --name 'compiled wasm runner records dart2wasm provenance'
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test benchmark/test/benchmark_scenarios_test.dart --name 'compiled JavaScript runner preserves typed error outcomes'
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/run.dart --runtime=wasm --bin=list_snapshot)
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart analyze --fatal-infos benchmark
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart analyze --fatal-infos .)
```

Expected: обе точечные проверки PASS, wasm suite завершает
`list_snapshot`, оба анализа не находят замечаний.

### Task 3: Обновить живую документацию и выполнить полный stable-прогон

**Files:**
- Modify: `docs/handoff.md`
- Modify: `docs/records/2026-08-14[3]-dart-3-13-migration-design.md`
- Modify: `docs/records/2026-08-14[4]-dart-3-13-migration-plan.md`

- [x] **Step 1: Обновить состояние документации перед проверками**

В `docs/handoff.md`:

- сохранить дату статуса 2026-08-14 и обновить содержание состояния;
- записать миграцию host'ов и CI на stable в сделанное;
- записать, что полный локальный прогон выполняется Dart 3.13.0;
- удалить миграцию из `## Что открыто`;
- первым открытым follow-up поставить AMD-эталон для stable, а исследование
  медленного `c` под JavaScript — следующим после эталона;
- сохранить исторические упоминания 3.12.2 и реестр вердиктов без
  переписывания.

В design сменить статус на «исполнен 2026-08-14» и указать SHA миграционного
коммита только после его создания. В этом плане отметить задачи 1–3
исполненными; общий статус до пересъёмки эталона оставить «исполнен частично».

- [x] **Step 2: Выполнить полный список проверок на Dart 3.13.0**

Run from the repository root, не сокращая список:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart format .
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart analyze --fatal-infos lib test example tool
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test -p node
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test -p node -c dart2wasm -x no-dart2wasm
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test benchmark/test tool/test
(cd packages/format_intl && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test)
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/verify_package_archive.dart
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/verify_generated_artifacts.dart
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test --coverage=.coverage
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run coverage:format_coverage --lcov --in=.coverage --out=coverage/lcov.info --report-on=lib --packages=.dart_tool/package_config.json
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/check_coverage.dart --lcov=coverage/lcov.info
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart pub get && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart test)
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/run.dart --runtime=vm)
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/run.dart --runtime=js)
(cd benchmark/suite && rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run tool/run.dart --runtime=wasm)
```

Expected: format clean; analyze clean; VM 604; Node 421 + 4 skipped; Wasm
403 + 1 skipped; auxiliary 45; `format_intl` 7; archive and generated
artifacts clean; coverage не ниже 94% (разведочный уровень 95.98%,
3131/3262); suite 15; все три матрицы PASS. Зафиксировать длительности
матриц в `docs/handoff.md`.

Если проверка падает, применить `superpowers:systematic-debugging`, устранить
коренную причину и повторить весь список с начала после последней правки.

- [x] **Step 3: Проверить границы diff и отсутствие случайной фиксации**

Run:

```sh
rtk git diff --check
rtk git diff -- . ':(exclude)docs/backlog.md'
rtk git diff -- docs/backlog.md
rtk rg -n "3\.12\.2|3\.12\.3|instantiate|invoke" .github benchmark docs/handoff.md 'docs/records/2026-08-14[3]-dart-3-13-migration-design.md'
rtk git status --short
```

Expected: `docs/backlog.md` без изменений; старый loader-протокол отсутствует
в двух host'ах; оставшиеся 3.12.2/3.12.3 относятся только к историческим
записям, старому эталону до follow-up и тестовым фикстурам.

### Task 4: Создать и опубликовать атомарный миграционный коммит

**Files:**
- Commit: все файлы Tasks 2–3 и этот план.
- Exclude: `docs/backlog.md`.

- [x] **Step 1: Проиндексировать только миграцию**

Run from the repository root:

```sh
rtk git add -A ':(exclude)docs/backlog.md'
rtk git diff --cached --check
rtk git diff --cached --name-status
rtk git diff --cached -- docs/backlog.md
```

Expected: последний diff пуст; staged-набор состоит только из host'ов, CI,
compile-тестов, stable-форматирования, handoff, design и плана.

- [x] **Step 2: Создать миграционный коммит**

Run:

```sh
rtk git commit -m 'chore: перевести инструменты на Dart stable'
rtk git status --short --branch
rtk git show --stat --oneline --decorate HEAD
```

Expected: коммит создан в `main`; рабочее дерево чистое; ветка впереди
`origin/main`. Записать полученный SHA в design и handoff можно только новым
follow-up-коммитом вместе с эталоном — уже созданный коммит не переписывать.

- [x] **Step 3: Push напрямую в main и проверить обычный CI**

Run:

```sh
rtk git push origin main
migration_sha="$(rtk git rev-parse HEAD)"
push_run_id="$(rtk gh run list --workflow=ci.yaml --branch=main --event=push --limit=10 --json databaseId,headSha --jq ".[] | select(.headSha == \"$migration_sha\") | .databaseId" | rtk head -n 1)"
rtk gh run view "$push_run_id" --json databaseId,headSha,status,conclusion,url,jobs
rtk gh run watch "$push_run_id" --exit-status
```

Expected: `checks (3.7.2)`, `checks (stable)`, `generated-artifacts`,
`coverage` и `benchmark-suite` зелёные; `performance-gate` на обычном push
пропущен условиями workflow. При CI-сбое использовать
`github:gh-fix-ci` и `superpowers:systematic-debugging`, не исправлять по
догадке.

### Task 5: Получить и проверить новый AMD-эталон stable

**Files:**
- Modify: `benchmark/results/gate-baseline.json`
- Read: `benchmark/results/README.md`
- Modify: `docs/handoff.md`
- Modify: `docs/records/2026-08-14[4]-dart-3-13-migration-plan.md`

**Interfaces:**
- Consumes: ровно восемь CI-отчётов `jit-1/2`, `aot-1/2`, `js-1/2`,
  `wasm-1/2` одной миграционной ревизии.
- Produces: baseline с Dart 3.13.0, Node.js 24.8.0 и AMD EPYC, после которого
  gate снова выдаёт сопоставимый вердикт.

- [x] **Step 1: Запустить performance workflow из миграционной ревизии**

Run на чистом дереве после push:

```sh
migration_sha="$(rtk git rev-parse HEAD)"
rtk gh workflow run ci.yaml --ref main
performance_run_id="$(rtk gh run list --workflow=ci.yaml --branch=main --event=workflow_dispatch --limit=10 --json databaseId,headSha --jq ".[] | select(.headSha == \"$migration_sha\") | .databaseId" | rtk head -n 1)"
rtk gh run view "$performance_run_id" --json databaseId,headSha,status,conclusion,url,jobs
rtk gh run watch "$performance_run_id" --exit-status
```

Expected: все обязательные jobs зелёные. Для `performance-gate` текущий старый
эталон может дать `comparable: false` из-за смены Dart 3.12.2 на 3.13.0; это
ожидаемо и не является завершением follow-up.

- [x] **Step 2: Скачать artifact в отдельный временный каталог**

Создать каталог и скачать artifact именно найденного запуска:

```sh
gate_dir="$(rtk mktemp -d /private/tmp/format-gate-stable.XXXXXX)"
rtk gh run download "$performance_run_id" --name performance-gate --dir "$gate_dir"
rtk find "$gate_dir" -maxdepth 1 -type f
```

Expected: `gate-report.json` и восемь runtime reports.

- [x] **Step 3: Проверить происхождение каждого отчёта до записи**

Run с переменными из предыдущих шагов:

```sh
reports="$gate_dir/jit-1.json,$gate_dir/jit-2.json,$gate_dir/aot-1.json,$gate_dir/aot-2.json,$gate_dir/js-1.json,$gate_dir/js-2.json,$gate_dir/wasm-1.json,$gate_dir/wasm-2.json"
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/gates.dart --describe="$gate_dir/gate-report.json"
rtk jq -r '[.runtime, .sourceRevision, .versions.cpu, .versions.dartVersion, .runtimeProvenance.dartCompilerVersion, .runtimeProvenance.nodeVersion] | @tsv' "$gate_dir/jit-1.json" "$gate_dir/jit-2.json" "$gate_dir/aot-1.json" "$gate_dir/aot-2.json" "$gate_dir/js-1.json" "$gate_dir/js-2.json" "$gate_dir/wasm-1.json" "$gate_dir/wasm-2.json"
```

Проверить вручную и записать в handoff:

- все восемь runtime reports имеют один `sourceRevision`, равный SHA
  миграционного коммита;
- у VM/AOT `versions.dartVersion` начинается с `3.13.0`, а у JS/Wasm
  `runtimeProvenance.dartCompilerVersion` равно `3.13.0`;
- CPU начинается с `AMD EPYC` (модели 7763 и 9V74 допустимы);
- JS/Wasm provenance сообщает Node.js `v24.8.0`;
- присутствуют ровно два отчёта каждого runtime.

Если runner Intel или provenance/revision расходятся, baseline не менять:
задиспетчить новый запуск и повторить шаги 1–3.

- [x] **Step 4: Записать baseline из точного списка восьми файлов**

Run с проверенной переменной `reports`:

```sh
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/gates.dart --reports="$reports" --record=2026-08-14 --output=benchmark/results/gate-baseline.json
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/gates.dart --reports="$reports" --baseline=benchmark/results/gate-baseline.json --allow-unverified-revision --output="$gate_dir/stable-gate-report.json"
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/gates.dart --describe="$gate_dir/stable-gate-report.json"
```

Expected: первая команда записывает baseline; вторая сообщает
`comparable: true`, а не только exit code 0. Флаг
`--allow-unverified-revision` допустим только здесь: первая команда уже
сверила отчёты с чистым migration HEAD, а после неё единственная причина
грязного tracked tree — только что записанный baseline. Проверить JSON:
revision равен
миграционному SHA, Dart 3.13.0, Node v24.8.0, CPU AMD EPYC, восемь наборов
измерений присутствуют.

- [x] **Step 5: Завершить документацию follow-up**

В `docs/handoff.md` записать run URL/ID, точную ревизию отчётов, CPU, Dart,
Node и сопоставимый итог. Убрать AMD-эталон из `## Что открыто`; первым
открытым делом сделать исследование `c` под JavaScript.

В design добавить SHA миграционного коммита и SHA пока готовящегося baseline
коммита не предугадывать. В этом плане отметить все выполненные флажки и
сменить статус на «исполнен 2026-08-14» после полного прогона следующего
шага.

### Task 6: Проверить, закоммитить и опубликовать stable baseline

**Files:**
- Commit: `benchmark/results/gate-baseline.json`, `docs/handoff.md`, design и
  этот план.
- Exclude: `docs/backlog.md`.

- [ ] **Step 1: Повторить полный список проверок перед вторым коммитом**

Повторить без сокращений все команды Task 3, Step 2 на Dart 3.13.0. Expected:
те же функциональные количества, coverage не ниже 94%, suite и три матрицы
зелёные. Дополнительно выполнить:

```sh
rtk git diff --check
rtk git diff -- docs/backlog.md
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/gates.dart --reports="$reports" --baseline=benchmark/results/gate-baseline.json --allow-unverified-revision --output="$gate_dir/stable-gate-report.json"
rtk /Users/user/fvm/versions/stable/bin/cache/dart-sdk/bin/dart run benchmark/gates.dart --describe="$gate_dir/stable-gate-report.json"
```

Expected: backlog diff пуст, gate `comparable: true`. После любой правки
повторить весь полный список с начала.

- [ ] **Step 2: Создать baseline-коммит**

Run from the repository root:

```sh
rtk git add benchmark/results/gate-baseline.json docs/handoff.md 'docs/records/2026-08-14[3]-dart-3-13-migration-design.md' 'docs/records/2026-08-14[4]-dart-3-13-migration-plan.md'
rtk git diff --cached --check
rtk git diff --cached --name-status
rtk git diff --cached -- docs/backlog.md
rtk git commit -m 'benchmark: переснять эталон на Dart stable'
rtk git status --short --branch
```

Expected: ровно четыре ожидаемых файла, backlog не staged, commit создан,
рабочее дерево чистое.

- [ ] **Step 3: Push baseline и проверить CI**

Run:

```sh
rtk git push origin main
baseline_sha="$(rtk git rev-parse HEAD)"
push_run_id="$(rtk gh run list --workflow=ci.yaml --branch=main --event=push --limit=10 --json databaseId,headSha --jq ".[] | select(.headSha == \"$baseline_sha\") | .databaseId" | rtk head -n 1)"
rtk gh run view "$push_run_id" --json databaseId,headSha,status,conclusion,url,jobs
rtk gh run watch "$push_run_id" --exit-status
rtk git status --short --branch
```

Expected: run относится к точному SHA baseline-коммита, все обычные jobs зелёные,
`main` чист и совпадает с `origin/main`. Новый baseline ссылается на
предшествующий миграционный SHA — ревизию, из которой CI действительно собрал
отчёты; это ожидаемый контракт.

Следующее отдельное дело после этого плана — исследование медленного `c` под
JavaScript по первому пункту `docs/backlog.md`. Для него заново применить
`superpowers:systematic-debugging` и локальную performance-методику; backlog
вычеркнуть только в одном коммите с доказанным результатом.
