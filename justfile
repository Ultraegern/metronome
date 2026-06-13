set windows-shell := ["C:\\Program Files\\Git\\bin\\sh.exe", "-cu"]

export PATH := if os_family() == "windows" { home_dir() + "/.local/bin;" + env_var("PATH") } else { env_var("PATH") }
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
    @npx tsc

_minify-worker:
    @echo "{{ C }}Minifying JS...{{ N }}"
    @npx terser build/worker.js \
        --compress passes=2,toplevel=true,ecma=2022 \
        --mangle toplevel=true \
        --ecma 2022 \
        --no-map \
        -o build/worker.js

_inline-worker:
    #!/usr/bin/env python3
    print("{{ C }}Inlining worker thread...{{ N }}")

    main_js = open("build/main.js", "r", encoding="utf-8").read()
    worker_js = open("build/worker.js", "r", encoding="utf-8").read()

    worker_js = worker_js.replace("`", "\\`").replace("${", "\\${")

    final_js = main_js.replace("___BUILDSCRIPT_INLINES_WORKER_JS_HERE___", worker_js)

    open("build/index.js", "w", encoding="utf-8").write(final_js)

_minify-index:
    @echo "{{ C }}Minifying JS...{{ N }}"
    @npx terser build/index.js \
        --compress passes=2,toplevel=true,ecma=2022 \
        --mangle toplevel=true \
        --ecma 2022 \
        --no-map \
        -o build/index.js

_minify-css:
    @echo "{{ C }}Minifying CSS...{{ N }}"
    @npx lightningcss \
        --targets "since 2022" \
        --minify \
        src/style.css \
        -o build/style.css

_copy-css:
    @cp src/style.css build/style.css

_bundle:
    #!/usr/bin/env python3
    print("{{ C }}Bundling...{{ N }}")

    js = open("build/index.js", "r", encoding="utf-8").read()
    css = open("build/style.css", "r", encoding="utf-8").read()
    src_html = open("src/index.html", "r", encoding="utf-8").read()

    final_html = src_html.replace("/* ___BUILDSCRIPT_INJECTS_JS_HERE___  */", js)
    final_html = final_html.replace("/* ___BUILDSCRIPT_INJECTS_CSS_HERE___ */", css)

    open("dist/index.html", "w", encoding="utf-8").write(final_html)

_minify-html:
    @echo "{{ C }}Minifying HTML...{{ N }}"
    @npx html-minifier-terser \
        --collapse-whitespace \
        --remove-comments \
        --remove-redundant-attributes \
        --use-short-doctype \
        dist/index.html \
        -o dist/index.html

# Build and bundle
build: clean _build-ts _inline-worker _copy-css _bundle
    @echo "{{ G }}Done!{{ N + C }} App available at dist/index.html{{ N }}"

# Build, minify and bundle
build-release: clean _build-ts _minify-worker _inline-worker _minify-index _minify-css _bundle _minify-html
    @echo "{{ G }}Done!{{ N + C }} App available at dist/index.html{{ N }}"

# Open in Firefox
open:
    @firefox ./dist/index.html

# Clean build directory
clean:
    @rm -rf build dist
    @mkdir -p build dist
