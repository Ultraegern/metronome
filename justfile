set windows-shell := ["C:\\Program Files\\Git\\bin\\sh.exe", "-cu"]

C := CYAN + BOLD
G := GREEN + BOLD
N := NORMAL

_default:
    @just --list

_build-ts:
    @echo "{{ C }}Compiling TypeScript...{{ N }}"
    mkdir -p dist
    tsc

_minify:
    @echo "{{ C }}Minifying...{{ N }}"
    rm -f dist/index.js.map
    npx terser dist/index.js \
        --compress passes=2,toplevel=true \
        --mangle toplevel=true \
        -o dist/index.js

_bundle:
    @echo "{{ C }}Bundling...{{ N }}"
    python3 -c '\
    js = open("dist/index.js").read(); \
    src_html = open("src/index.html").read(); \
    final_html = src_html.replace("// ___BUILDSCRIPT_INJECTS_JS_HERE___", js); \
    open("dist/index.html", "w").write(final_html); \
    '

# Build and bundle
build: clean _build-ts _bundle
    @echo "{{ G }}Done! App available at dist/index.html{{ N }}"

# Build, minify and bundle
build-release: clean _build-ts _minify _bundle
    @echo "{{ G }}Done! App available at dist/index.html{{ N }}"

# Open in Firefox
open:
    firefox ./dist/index.html

# Clean build directory
clean:
    rm -rf dist/*
