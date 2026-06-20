set windows-shell := ["C:\\Program Files\\Git\\bin\\sh.exe", "-cu"]

export PATH := if os_family() == "windows" { home_dir() + "/.local/bin;" + env_var("PATH") } else { env_var("PATH") }
C := CYAN + BOLD
G := GREEN + BOLD
R := RED + BOLD
N := NORMAL

_default:
    @just --list

# Install dependencies
init:
    @echo "{{ C }}Installing dependencies...{{ N }}"
    @node -v >/dev/null 2>&1 || (echo "{{ R }}Please install node.js and npm:{{ N + C }} https://nodejs.org/en/download{{ N }}" && exit 1)
    @npm -v >/dev/null 2>&1 || (echo "{{ R }}Please install node.js and npm:{{ N + C }} https://nodejs.org/en/download{{ N }}" && exit 1)
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

_generate-icon-url:
    #!/usr/bin/env python3
    import base64
    print("{{ C }}Generating icon url...{{ N }}")

    svg = open("src/metronome.svg", "rb").read()

    b64_svg = base64.b64encode(svg).decode("utf-8")
    svg_url = f"data:image/svg+xml;base64,{b64_svg}"

    open("build/icon.svg.url", "w", encoding="utf-8").write(svg_url)

_inline-manifest-icon: _generate-icon-url
    #!/usr/bin/env python3
    import base64
    print("{{ C }}Inlining webmanifest icon...{{ N }}")

    manifest = open("src/webmanifest.json", "r", encoding="utf-8").read()
    svg_url = open("build/icon.svg.url", "r", encoding="utf-8").read()

    manifest = manifest.replace("___BUILDSCRIPT_INLINES_ICON_HERE___", svg_url)

    open("build/webmanifest.json", "w", encoding="utf-8").write(manifest)

_generate-manifest-url: _inline-manifest-icon
    #!/usr/bin/env python3
    import base64
    print("{{ C }}Generating webmanifest url...{{ N }}")

    manifest = open("build/webmanifest.json", "rb").read()

    b64_manifest = base64.b64encode(manifest).decode("utf-8")
    manifest_url = f"data:application/manifest+json;base64,{b64_manifest}"

    open("build/webmanifest.json.url", "w", encoding="utf-8").write(manifest_url)

_bundle:
    #!/usr/bin/env python3
    import os
    print("{{ C }}Bundling...{{ N }}")

    js = open("build/index.js", "r", encoding="utf-8").read()
    css = open("build/style.css", "r", encoding="utf-8").read()
    src_html = open("src/index.html", "r", encoding="utf-8").read()
    version = open("VERSION", "r", encoding="utf-8").read()

    final_html = src_html.replace("/* ___BUILDSCRIPT_INJECTS_JS_HERE___  */", js)
    final_html = final_html.replace("/* ___BUILDSCRIPT_INJECTS_CSS_HERE___ */", css)
    final_html = final_html.replace("___BUILDSCRIPT_INJECTS_VERSION_HERE___", version)

    if os.path.exists("build/icon.svg.url"):
        icon_url = open("build/icon.svg.url", "r", encoding="utf-8").read()
        final_html = final_html.replace("___BUILDSCRIPT_INLINES_ICON_HERE___", icon_url)
    else:
        final_html = final_html.replace("""<link rel="icon" href="___BUILDSCRIPT_INLINES_ICON_HERE___">""", "")

    if os.path.exists("build/webmanifest.json.url"):
        manifest_url = open("build/webmanifest.json.url", "r", encoding="utf-8").read()
        final_html = final_html.replace("___BUILDSCRIPT_INJECTS_WEB_MANIFEST_HERE___", manifest_url)
    else:
        final_html = final_html.replace("""<link rel="manifest" href="___BUILDSCRIPT_INJECTS_WEB_MANIFEST_HERE___">""", "")

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

_google_search-console-verification:
    @cp src/google2c234ff157d97827.html dist/google2c234ff157d97827.html

# Build and bundle
build: clean _build-ts _inline-worker _copy-css _generate-manifest-url _bundle
    @echo "{{ G }}Done!{{ N + C }} App available at dist/index.html{{ N }}"

# Build, minify and bundle
build-release: clean _build-ts _minify-worker _inline-worker _minify-index _minify-css _generate-manifest-url _bundle _minify-html _google_search-console-verification
    @echo "{{ G }}Done!{{ N + C }} App available at dist/index.html{{ N }}"

# Build, minify, strip and bundle
build-ultra-small: clean _build-ts _minify-worker _inline-worker _minify-index _minify-css _bundle _minify-html
    @echo "{{ G }}Done!{{ N + C }} App available at dist/index.html{{ N }}"

# Open in Firefox
open:
    @firefox ./dist/index.html

# Clean build directory
clean:
    @rm -rf build dist
    @mkdir -p build dist
