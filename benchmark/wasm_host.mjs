// Starts a dart2wasm build of `runner.dart` under node.
//
// dart2wasm emits a module plus a loader, and neither runs on its own: the
// bytes have to be read, the module instantiated against the loader, and
// `main` invoked. Committed rather than generated because the performance
// gate's job runs it, and a measurement harness that writes part of itself at
// run time is one more thing that can differ between a laptop and CI.
//
// Arguments after this script reach `main` unchanged, so the runner's own
// options work exactly as they do for the dart2js build:
//
//   node benchmark/wasm_host.mjs benchmark.wasm --runtime=wasm --run=1
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const [modulePath, ...args] = process.argv.slice(2);
if (modulePath === undefined) {
  console.error('Usage: node wasm_host.mjs <module.wasm> [runner arguments]');
  process.exit(64);
}

// The loader sits beside the module and is named after it: `-o x.wasm` writes
// `x.wasm` and `x.mjs`.
const moduleUrl = pathToFileURL(modulePath);
const loaderUrl = new URL(moduleUrl.href.replace(/\.wasm$/, '.mjs'));

const { compile } = await import(loaderUrl.href);
const compiled = await compile(await readFile(moduleUrl));
const instance = await compiled.instantiate({});
instance.invokeMain(...args);
