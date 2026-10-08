#!/bin/bash
# Export the Godot project for the web and publish build/web to the gh-pages branch (no force-push).
set -e
cd "$(dirname "$0")"
(cd game && ../tools/godot --headless --export-release "Web" ../build/web/index.html)
REMOTE=$(git remote get-url origin)
TMP=$(mktemp -d)
if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
  git clone -q --depth 1 --branch gh-pages "$REMOTE" "$TMP"
  find "$TMP" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
else
  git init -q -b gh-pages "$TMP"; git -C "$TMP" remote add origin "$REMOTE"
fi
for f in build/web/index.*; do cp "$f" "$TMP/"; done
touch "$TMP/.nojekyll"
git -C "$TMP" add -A
git -C "$TMP" -c user.name="Loriens22" -c user.email="Loriens22@users.noreply.github.com" commit -qm "Web build $(date -u +%Y-%m-%dT%H:%MZ)" || echo "nothing to commit"
git -C "$TMP" push -q origin gh-pages
rm -rf "$TMP"
echo "deployed"
