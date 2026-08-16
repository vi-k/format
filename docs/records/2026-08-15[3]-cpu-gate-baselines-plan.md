# План реализации: эталоны performance-gate по процессорам

> **Состояние на 2026-08-16:** Task 1 завершён в `7f6e21e`, Task 2 — в
> `47b6d34`, Task 3 — в `9847a11` и `b08d194`, Task 4 — в `8cc57c1`, Task 5
> завершена 2026-08-15; план исполнен.
> **Что это:** план реализации эталонов performance-gate по процессорам.
> **Связанные записи:** `2026-08-15[2]-cpu-gate-baselines-design.md`,
> `2026-08-15[4]-format-reference-and-4-0-0-report.md`.

> **Для агентных исполнителей:** ОБЯЗАТЕЛЬНЫЙ SUB-SKILL: используйте `superpowers:subagent-driven-development` (рекомендуется) либо `superpowers:executing-plans` и исполняйте задачи по одной. Шаги отслеживаются чекбоксами.

**Цель:** превратить единственный эталон performance-gate в набор проверенных
эталонов по точной модели CPU и дать GitHub Actions безопасный способ получить
новую запись на зафиксированной ревизии.

**Архитектура:** `GateBaseline` станет контейнером schema 2 с одной корневой
ревизией и картой `CPU -> GateReference`. Оценка выбирает точную запись до
сравнения Dart/Node; неизвестный CPU считает диагностические ratios по явно
заданной первичной записи, но не выносит вердикт. Controlled capture только
производит artifact из восьми reports; добавление в git выполняет отдельная
строго валидируемая команда.

**Технологии:** Dart stable, `package:test`, JSON, GitHub Actions workflow YAML
и GitHub CLI для ручного controlled capture.

## Глобальные ограничения

- Документы пишутся по-русски; код и комментарии в коде — по-английски.
- Минимальный SDK пакета остаётся `^3.7.2`; public API, зависимости, benchmark
  matrix и допуски не меняются.
- Ключ reference — точная строка `GateEnvironment.cpu`, а не семейство CPU.
- Все записи набора относятся к одному `sourceRevision`; Dart и Node
  сравниваются с выбранной CPU-записью.
- Unknown CPU остаётся `comparable: false`, `decisive: false` и с exit 0;
  никакой workflow не записывает baseline автоматически.
- `docs/backlog.md` не трогать и не stage'ить.
- Перед каждым коммитом выполнить полный список из `docs/handoff.md`; мержить
  напрямую в `main`, без PR.
- Изменение не заявляет ускорение: локальный performance A/B не нужен; реальная
  запись CPU создаётся только controlled capture на эталонной ревизии.

---

## Структура файлов

- `benchmark/gates.dart` — модель schema 2, выбор reference, запись первой и
  добавление последующей записи, CLI-режим `--add-reference`.
- `benchmark/test/benchmark_gates_test.dart` — TDD для JSON, выбора CPU,
  provenance и обоих режимов CLI.
- `benchmark/test/benchmark_gate_workflow_test.dart` — статический контракт
  controlled-capture YAML: inputs, checkout SHA, отсутствие evaluation и
  публикация восьми reports.
- `benchmark/results/gate-baseline.json` — миграция существующего EPYC 7763
  эталона в schema 2 в Task 1 и, после внешнего capture, только реальные
  дополнительные CPU-записи.
- `benchmark/results/README.md` — формат набора, команда добавления и meaning
  unknown CPU.
- `.github/workflows/ci.yaml` — opt-in controlled-capture workflow-dispatch.
- `docs/handoff.md` — состояние, выполненные коммиты, CPU, добавленные реальным
  capture, и оставшиеся модели без записи.

### Task 1: модель набора и выбор CPU-reference

**Файлы:**

- Modify: `benchmark/gates.dart:60-220,300-370,790-870`
- Modify: `benchmark/test/benchmark_gates_test.dart:67-118,281-360,640-760`
- Modify: `benchmark/results/gate-baseline.json`

**Интерфейсы:**

- Produces: `GateReference` с `String recordedAt`, `GateEnvironment environment`,
  `Map<String, Map<String, double>> phaseMeans` и
  `Map<String, Map<String, double>> scenarioRatios`.
- Produces: `GateBaseline` с `String sourceRevision`, `String primaryCpu` и
  `Map<String, GateReference> references`; `GateBaseline select(GateEnvironment)`
  возвращает точную запись или primary fallback.
- Produces: `GateSelection` с `GateReference reference`, `bool exactCpuMatch` и
  `List<String> differences`, используемый `evaluateGateReports`.
- Consumes: восемь валидных `BenchmarkReport` и текущий `GateEnvironment.of`.

- [x] **Шаг 1: написать красные model/selection-тесты.**

  В `benchmark_gates_test.dart` сначала определить два test-only helper:

  ```dart
  List<BenchmarkReport> _reportsForCpu(String cpu) => [
    for (final report in _completeReports())
      _copyReport(
        report,
        versions: {'dartVersion': 'test', 'os': 'test', 'cpu': cpu},
      ),
  ];

  GateBaseline _baselineWithSecondaryCpu(GateBaseline baseline, String cpu) {
    final json = baseline.toJson();
    final references = Map<String, Object?>.from(json['references']! as Map);
    final copied = Map<String, Object?>.from(references['test']! as Map);
    final environment = Map<String, Object?>.from(copied['environment']! as Map)
      ..['cpu'] = cpu;
    references[cpu] = {...copied, 'environment': environment};
    json['references'] = references;
    return GateBaseline.fromJson(json);
  }
  ```

  Затем добавить тесты с двумя синтетическими CPU:

  ```dart
  test('a matching CPU selects its own reference before Node and Dart checks', () {
    final amd = recordGateBaseline(_completeReports(), '2026-01-01');
    final intel = _baselineWithSecondaryCpu(amd, 'Intel Xeon test');
    final reports = _reportsForCpu('Intel Xeon test');

    final result = evaluateGateReports(reports, intel);

    expect(result.comparable, isTrue);
    expect(result.environmentDifferences, isEmpty);
  });

  test('an unknown CPU uses primary ratios but decides nothing', () {
    final baseline = recordGateBaseline(_completeReports(), '2026-01-01');
    final result = evaluateGateReports(
      _reportsForCpu('unrecorded CPU'),
      baseline,
    );

    expect(result.gates, hasLength(8));
    expect(result.comparable, isFalse);
    expect(result.decisive, isFalse);
    expect(result.environmentDifferences.single, contains('unrecorded CPU'));
  });
  ```

  Добавить round-trip assertion schema 2, а также malformed JSON cases для
  пустого `references`, отсутствующего `primaryCpu` и ключа, не равного
  `environment.cpu`. Добавить fixture-test, читающий committed
  `gate-baseline.json` и требующий schema 2, primary EPYC 7763 и совпадающий
  map key/environment CPU.

- [x] **Шаг 2: запустить тест и убедиться в RED.**

  Run: `rtk dart test benchmark/test/benchmark_gates_test.dart`

  Expected: FAIL, потому что schema 1 не содержит `references`, а helper и
  selection API отсутствуют.

- [x] **Шаг 3: реализовать минимальную schema 2 и selection.**

  Вынести payload прежнего `GateBaseline` в immutable `GateReference`; сохранить
  `phaseMean`, `scenarioRatio` и `recordedScenarios` на reference. Реализовать
  контейнер и строгий парсер:

  ```dart
  final class GateBaseline {
    final String sourceRevision;
    final String primaryCpu;
    final Map<String, GateReference> references;

    GateSelection select(GateEnvironment measured) {
      final reference = references[measured.cpu];
      if (reference != null) {
        return GateSelection.exact(reference);
      }
      return GateSelection.fallback(
        references[primaryCpu]!,
        measuredCpu: measured.cpu,
        primaryCpu: primaryCpu,
      );
    }
  }
  ```

  `fromJson` принимает только `schemaVersion == 2`, проверяет непустую карту,
  ключ primary и совпадение CPU каждого entry. `evaluateGateReports` получает
  environment до `_evaluateDialect`, выбирает `selection.reference` для всех
  threshold checks и строит `comparable` из `selection.exactCpuMatch` плюс
  Dart/Node differences выбранной entry. Fallback diagnostics обязаны назвать
  unknown CPU и `primaryCpu`; OS, как прежде, не влияет на verdict.

  В этом же commit переложить существующие `recordedAt`, `environment`,
  `phaseMeans` и `scenarioRatios` из единственного schema 1 object в
  `references['AMD EPYC 7763 64-Core Processor']`; сохранить их числа
  байт-в-байт, оставить source SHA в root, поставить `schemaVersion: 2` и
  `primaryCpu` в тот же exact key. Это происходит вместе с parser change,
  поэтому committed `benchmark/gates.dart` продолжает читать committed
  `gate-baseline.json` после Task 1.

- [x] **Шаг 4: запустить targeted GREEN и analyzer.**

  Run: `rtk dart test benchmark/test/benchmark_gates_test.dart`

  Expected: PASS, включая прежние environment cases и новые CPU-selection
  cases.

  Run: `rtk dart analyze --fatal-infos benchmark/gates.dart benchmark/test/benchmark_gates_test.dart`

  Expected: `No issues found!`

- [x] **Шаг 5: проверить diff, полный gate и закоммитить Task 1.**

  Run по одному: все команды раздела `## Как проверить всё` из
  `docs/handoff.md`, затем `rtk git diff --check`.

  ```sh
  rtk git add benchmark/gates.dart benchmark/results/gate-baseline.json benchmark/test/benchmark_gates_test.dart
  rtk git commit -m "feat: select CPU gate references"
  ```

### Task 2: безопасное добавление CPU-reference через CLI

**Файлы:**

- Modify: `benchmark/gates.dart:790-1060`
- Modify: `benchmark/test/benchmark_gates_test.dart:500-680,760-900`

**Интерфейсы:**

- Consumes: `GateBaseline baseline`, восемь `BenchmarkReport` и ISO date.
- Produces: `GateBaseline addGateBaselineReference(GateBaseline baseline,
  Iterable<BenchmarkReport> reports, String recordedAt)`.
- Produces: CLI `--add-reference=YYYY-MM-DD` вместе с обязательными
  `--reports=`, `--baseline=` и `--output=`.

- [x] **Шаг 1: написать красные API и end-to-end CLI-тесты.**

  Добавить API-test, который добавляет отчёты CPU `Intel Xeon test`, сохраняет
  AMD entry и проверяет обе записи:

  ```dart
  test('adding a CPU reference preserves the existing reference', () {
    final first = recordGateBaseline(_completeReports(), '2026-01-01');
    final added = addGateBaselineReference(
      first,
      _reportsForCpu('Intel Xeon test'),
      '2026-01-02',
    );

    expect(added.references.keys, unorderedEquals(['test', 'Intel Xeon test']));
    expect(added.references['test']!.recordedAt, '2026-01-01');
    expect(added.references['Intel Xeon test']!.recordedAt, '2026-01-02');
  });
  ```

  Здесь `_completeReports()` продолжает использовать CPU `test`. Отдельно
  потребовать `FormatException` от duplicate CPU и reports с другим
  `sourceRevision`. В temp-directory CLI-test создать baseline, восемь Intel
  reports, вызвать `benchmark/gates.dart --add-reference=2026-01-02` и проверить
  schema 2 output с двумя keys; повторный вызов с тем же CPU обязан завершиться
  `exitCode == 1` и не менять output.

- [x] **Шаг 2: запустить targeted test и зафиксировать RED.**

  Run: `rtk dart test benchmark/test/benchmark_gates_test.dart`

  Expected: FAIL, потому что `addGateBaselineReference` и
  `--add-reference` ещё не распознаны.

- [x] **Шаг 3: реализовать запись без частичного изменения файла.**

  Реализовать helper через уже существующие `_validateReport`, `_validatePair`,
  `_sourceRevisionFor` и общий private recorder `GateReference
  _recordGateReference(Iterable<BenchmarkReport> reports, String recordedAt)`.
  До построения нового `Map` требовать точный root SHA и отсутствие measured
  CPU в `baseline.references`; вернуть новый immutable container.

  В `main` различить три взаимоисключающих режима: evaluation, `--record` и
  `--add-reference`. `--record` создаёт schema 2 с единственным CPU;
  `--add-reference` требует существующий `--baseline` и non-null `--output`.
  Сначала прочитать и валидировать все входы, затем единственным
  `File(output).writeAsStringSync` записать JSON; это допускает совпадение
  baseline/output path, но не оставляет полузаписанный файл после validation
  error.

- [x] **Шаг 4: запустить targeted GREEN и command-line tests.**

  Run: `rtk dart test benchmark/test/benchmark_gates_test.dart`

  Expected: PASS, в том числе create/add/reject CLI cycle и отсутствие
  перезаписи output на отказе.

  Run: `rtk dart analyze --fatal-infos benchmark/gates.dart benchmark/test/benchmark_gates_test.dart`

  Expected: `No issues found!`

- [x] **Шаг 5: выполнить полный gate и закоммитить Task 2.**

  Run по одному: полный список `docs/handoff.md`, затем `rtk git diff --check`.

  ```sh
  rtk git add benchmark/gates.dart benchmark/test/benchmark_gates_test.dart
  rtk git commit -m "feat: add CPU gate references safely"
  ```

### Task 3: committed baseline, controlled capture и документация

**Файлы:**

- Create: `benchmark/test/benchmark_gate_workflow_test.dart`
- Modify: `benchmark/results/README.md:101-170`
- Modify: `.github/workflows/ci.yaml:1-20,240-340`

**Интерфейсы:**

- Consumes: schema 2 baseline из Task 1, `--add-reference` из Task 2 и root
  `sourceRevision` `9143e7407e162a1fdc6b11d57515143390a04c53`.
- Produces: opt-in `workflow_dispatch` inputs `capture_baseline` and
  `baseline_revision`, plus raw eight-report artifact without git write.

- [x] **Шаг 1: написать красный static workflow contract test.**

  Создать `benchmark/test/benchmark_gate_workflow_test.dart` с doc-comment на
  `library`. Прочитать repository-root `.github/workflows/ci.yaml` и проверить:

  ```dart
  test('controlled capture checks out its requested immutable revision', () {
    final workflow = File(workflowPath).readAsStringSync();

    expect(workflow, contains('capture_baseline:'));
    expect(workflow, contains('baseline_revision:'));
    expect(workflow, contains('ref: ${{ inputs.capture_baseline'));
    expect(workflow, contains('if: inputs.capture_baseline != true'));
    expect(workflow, contains('jit-*.json'));
    expect(workflow, contains('wasm-*.json'));
  });
  ```

- [x] **Шаг 2: запустить test и убедиться в RED.**

  Run: `rtk dart test benchmark/test/benchmark_gate_workflow_test.dart benchmark/test/benchmark_gates_test.dart`

  Expected: FAIL: workflow inputs отсутствуют.

- [x] **Шаг 3: добавить controlled capture и документацию.**

  В `workflow_dispatch.inputs` объявить `capture_baseline` как boolean с
  default `false` и `baseline_revision` как string. В performance-gate job
  выбрать checkout ref выражением, которое берёт `baseline_revision` только
  при capture, иначе `github.sha`. В capture-режиме пропустить Evaluate и
  Report steps; Measure и Upload всегда сохраняют ровно
  `jit-*.json`, `aot-*.json`, `js-*.json`, `wasm-*.json`. Workflow не получает
  write permission и не содержит `git commit`, `git push` или `--record`.

  В results README записать оба режима:

  ```sh
  gh workflow run CI --ref main \
    -f capture_baseline=true \
    -f baseline_revision=9143e7407e162a1fdc6b11d57515143390a04c53

  dart run benchmark/gates.dart --reports=jit-1.json,jit-2.json,aot-1.json,aot-2.json,js-1.json,js-2.json,wasm-1.json,wasm-2.json \
    --baseline=benchmark/results/gate-baseline.json \
    --add-reference=2026-08-15 \
    --output=benchmark/results/gate-baseline.json \
    --allow-unverified-revision
  ```

  Явно описать, что second command выполняется только после проверки artifact,
  а unknown CPU не является успешным сравнением.

- [x] **Шаг 4: запустить targeted GREEN, JSON и YAML checks.**

  Run: `rtk dart test benchmark/test/benchmark_gate_workflow_test.dart benchmark/test/benchmark_gates_test.dart`

  Expected: PASS.

  Run: `rtk dart analyze --fatal-infos benchmark/gates.dart benchmark/test`

  Expected: `No issues found!`

  До Task 4 не запускать command-line evaluation с вымышленными путями: для неё
  нужны восемь реальных reports из controlled-capture artifact. Проверку
  schema 2 и unknown CPU на этой стадии полностью выполняют targeted tests;
  artifact command и его expected `comparable: false` входят в Task 4.

- [x] **Шаг 5: выполнить полный gate, review и закоммитить Task 3.**

  Run по одному: полный список `docs/handoff.md`, затем `rtk git diff --check`.

  ```sh
  rtk git add .github/workflows/ci.yaml benchmark/results/README.md benchmark/test/benchmark_gate_workflow_test.dart
  rtk git commit -m "ci: capture CPU gate baselines"
  ```

### Task 4: собрать и добавить первый альтернативный CPU-эталон

**Файлы:**

- Modify: `benchmark/results/gate-baseline.json`

**Интерфейсы:**

- Consumes: pushed `main` с Task 3, workflow artifact восьми reports и
  `--add-reference` из Task 2.
- Produces: одна или больше новых entries с точной CPU-строкой, тем же root SHA
  `9143e7407e162a1fdc6b11d57515143390a04c53` и реальными measurement values.

- [x] **Шаг 1: подтвердить branch и отправить реализацию в `main`.**

  Run: `rtk git status --short`

  Expected: пустой вывод.

  Run: `rtk git branch --show-current`

  Expected: `main`.

  После зелёного полного gate Task 3 отправить только созданные commits в
  `origin/main`; PR не создавать.

- [x] **Шаг 2: dispatch controlled capture на эталонной ревизии.**

  Запустить workflow с ref `main`, не с historical SHA workflow:

  ```sh
  gh workflow run CI --ref main \
    -f capture_baseline=true \
    -f baseline_revision=9143e7407e162a1fdc6b11d57515143390a04c53
  ```

  Дождаться результата, скачать artifact `performance-gate` во временный
  каталог и извлечь из VM report точную `versions.cpu`. Если CPU уже есть в
  `references`, удалить только временный artifact и повторить dispatch. Сделать
  не более четырёх dispatches либо остановиться сразу после первого нового CPU;
  не придумывать новую запись при исчерпании четырёх попыток.

- [x] **Шаг 3: валидировать artifact до записи.**

  Проверить наличие ровно `jit-1/2.json`, `aot-1/2.json`, `js-1/2.json` и
  `wasm-1/2.json`. У всех восьми reports должны совпасть полный
  `sourceRevision` `9143e7407e162a1fdc6b11d57515143390a04c53`, CPU внутри
  одной машины, runs 1/2 и требуемые runtime/dialect. Запустить dry validation
  через add-command в temporary output; отказ или неверный SHA означает не
  менять committed baseline.

- [x] **Шаг 4: добавить проверенную запись и проверить выбор.**

  После успешной dry validation выполнить `--add-reference` с artifact paths,
  датой capture и `--output=benchmark/results/gate-baseline.json`. Убедиться,
  что новый CPU-key появился ровно один раз, EPYC 7763 сохранён byte-for-byte в
  своём nested entry, а primary CPU не изменился. Сохранить точный CPU, run URL
  и result для финального обновления `docs/handoff.md` в Task 5.

- [x] **Шаг 5: выполнить полный gate, закоммитить и проверить remote.**

  Run по одному: полный список `docs/handoff.md`, затем `rtk git diff --check`.

  ```sh
  rtk git add benchmark/results/gate-baseline.json
  rtk git commit -m "chore: record CPU gate reference"
  rtk git push origin main
  ```

  Проверить `rtk git status --short` и точный SHA `origin/main`. Если за четыре
  dispatches альтернативный CPU не появился, этот коммит не создавать:
  `docs/handoff.md` в Task 5 честно зафиксирует неполную operational coverage
  и внешнюю причину отсутствия additional baseline.

### Task 5: завершающая сверка и handoff

**Файлы:**

- Modify: `docs/handoff.md`

**Интерфейсы:**

- Consumes: commits Tasks 1–4 и результаты controlled capture.
- Produces: актуальный session handoff со статусом, фактами проверок и ясным
  списком открытых моделей CPU, если они остались.

- [x] **Шаг 1: обновить живой handoff.**

  В верхней строке `Статус:` поставить дату завершения и назвать schema 2,
  controlled capture и реальные CPU keys. В `Что сделано` внести commits,
  числа полного gate и ссылку на capture run. В `Что открыто` убрать решение
  владельца и оставить только отсутствие конкретных CPU references, если
  четырех dispatches не хватило.

- [x] **Шаг 2: финальная проверка.**

  Run: `rtk git diff --check`

  Expected: пустой вывод.

  Run: `rtk git status --short`

  Expected: только `docs/handoff.md` до её stage.

- [x] **Шаг 3: полный gate и финальный commit.**

  Run по одному: полный список `docs/handoff.md`.

  ```sh
  rtk git add docs/handoff.md
  rtk git commit -m "docs: record CPU gate baseline work"
  rtk git push origin main
  ```

  После push проверить пустой `rtk git status --short`, SHA `HEAD` равный
  `origin/main` и статус triggered CI. Публикация пакета не является частью
  этой работы, поэтому тег и GitHub Release не создаются.

## Самопроверка плана

- Цель schema 2, точный CPU-key, fallback и provenance покрыты Task 1.
- Безопасное ручное добавление reference и отсутствие частичной записи покрыты
  Task 2.
- JSON migration, opt-in workflow, artifact-only capture и документация
  покрыты Task 3.
- Реальное получение, проверка и commit альтернативного CPU вынесены в Task 4;
  лимит четырёх dispatches не подменяет данные выдуманной записью.
- Handoff, complete gates, direct-main integration и отсутствие release
  покрыты Task 5.
- Имена типов и CLI совпадают во всех задачах; в документе нет нерешённых
  маркеров или неоговорённых placeholders.
