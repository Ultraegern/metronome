set windows-shell := ["C:\\Program Files\\Git\\bin\\sh.exe", "-cu"]

C := CYAN + BOLD
G := GREEN + BOLD
N := NORMAL

_default:
    @just --list

# Install dependencies
init:
    @echo "{{ C }}Installing dependencies...{{ N }}"
    @npm install
    @echo "{{ G }}Done!{{ N }}"

_build-ts:
    @echo "{{ C }}Compiling TypeScript...{{ N }}"
    mkdir -p dist
    ./node_modules/.bin/tsc

_minify-worker:
    @echo "{{ C }}Minifying...{{ N }}"
    ./node_modules/.bin/terser dist/worker.js \
        --compress passes=2,toplevel=true \
        --mangle toplevel=true \
        --no-map \
        -o dist/worker.js

_inline-worker:
    #!/usr/bin/env python3
    print("{{ C }}Inlining worker thread...{{ N }}")

    main_js = open("dist/main.js", "r", encoding="utf-8").read()
    worker_js = open("dist/worker.js", "r", encoding="utf-8").read()

    worker_js = worker_js.replace("`", "\\`").replace("${", "\\${")

    final_js = main_js.replace("___BUILDSCRIPT_INLINES_WORKER_JS_HERE___", worker_js)

    open("dist/index.js", "w").write(final_js)

_minify-index:
    @echo "{{ C }}Minifying...{{ N }}"
    ./node_modules/.bin/terser dist/index.js \
        --compress passes=2,toplevel=true \
        --mangle toplevel=true \
        --no-map \
        -o dist/index.js

_bundle:
    #!/usr/bin/env python3
    print("{{ C }}Bundling...{{ N }}")

    js = open("dist/index.js").read()
    src_html = open("src/index.html").read()

    final_html = src_html.replace("// ___BUILDSCRIPT_INJECTS_JS_HERE___", js)

    open("dist/index.html", "w").write(final_html)

# Build and bundle
build: clean _build-ts _inline-worker _bundle
    @echo "{{ G }}Done! App available at dist/index.html{{ N }}"

# Build, minify and bundle
build-release: clean _build-ts _minify-worker _inline-worker _minify-index _bundle
    @echo "{{ G }}Done! App available at dist/index.html{{ N }}"

# Open in Firefox
open:
    firefox ./dist/index.html

# Clean build directory
clean:
    rm -rf dist/*
