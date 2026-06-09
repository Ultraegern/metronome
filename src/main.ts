const workerCode = `___BUILDSCRIPT_INLINES_WORKER_JS_HERE___`;
const blob = new Blob([workerCode], { type: 'application/javascript' });
const workerUrl = URL.createObjectURL(blob);
const worker = new Worker(workerUrl);
URL.revokeObjectURL(workerUrl);

let foo = "Hi from the main thread";
console.log(foo);
