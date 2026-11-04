#!/usr/bin/env bash
# Publishes the Medusa packages Woodpecker changes in this fork to GitHub Packages, renamed into
# the @remo-digital scope, so woodpecker-commerce can consume them (pnpm overrides) until the
# changes are released upstream.
#
#   GITHUB_PACKAGES_TOKEN=$(gh auth token) scripts/woodpecker/publish-packages.sh 1
#   scripts/woodpecker/publish-packages.sh 1 --dry-run
#
# The argument N publishes <upstream version>-wood.N, e.g. 2.21.2-wood.1.
# The token needs the write:packages scope (gh auth refresh -s write:packages).
set -euo pipefail

REGISTRY="https://npm.pkg.github.com"
SCOPE="@remo-digital"
DIST_TAG="woodpecker"

# <package dir>:<published name>
PACKAGES=(
  "packages/core/types:medusa-types"
  "packages/modules/promotion:medusa-promotion"
  "packages/medusa:medusa-medusa"
  "packages/admin/dashboard:medusa-dashboard"
)

N="${1:-}"
DRY_RUN="${2:-}"

if [[ ! "$N" =~ ^[0-9]+$ ]]; then
  echo "usage: $0 <N> [--dry-run]   (publishes <version>-wood.<N>)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit first, so every published version maps to a commit." >&2
  exit 1
fi

if [[ "$DRY_RUN" != "--dry-run" && -z "${GITHUB_PACKAGES_TOKEN:-}" ]]; then
  echo "GITHUB_PACKAGES_TOKEN is not set (needs write:packages)." >&2
  exit 1
fi

COMMIT="$(git rev-parse --short HEAD)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

NPMRC="$WORK/.npmrc"
printf '%s:registry=%s\n//npm.pkg.github.com/:_authToken=%s\n' \
  "$SCOPE" "$REGISTRY" "${GITHUB_PACKAGES_TOKEN:-dry-run}" > "$NPMRC"

FILTERS=()
for entry in "${PACKAGES[@]}"; do
  FILTERS+=("--filter=$(node -p "require('./${entry%%:*}/package.json').name")")
done

echo "Building ${FILTERS[*]} (with their dependencies) at $COMMIT"
yarn turbo run build "${FILTERS[@]}"

for entry in "${PACKAGES[@]}"; do
  dir="${entry%%:*}"
  published="$SCOPE/${entry##*:}"
  upstream_version="$(node -p "require('./$dir/package.json').version")"
  version="$upstream_version-wood.$N"

  pack_dir="$WORK/${entry##*:}"
  mkdir -p "$pack_dir"
  (cd "$dir" && npm pack --silent --pack-destination "$pack_dir" > /dev/null)
  tar -xzf "$pack_dir"/*.tgz -C "$pack_dir"

  node - "$pack_dir/package/package.json" "$published" "$version" "$COMMIT" <<'EOF'
const fs = require("fs")
const [file, name, version, commit] = process.argv.slice(2)
const pkg = JSON.parse(fs.readFileSync(file, "utf8"))
pkg.name = name
pkg.version = version
pkg.publishConfig = { registry: "https://npm.pkg.github.com" }
pkg.repository = { type: "git", url: "https://github.com/Remo-Digital/medusa.git" }
pkg.gitHead = commit
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n")
EOF

  echo "Publishing $published@$version"
  npm publish "$pack_dir/package" \
    --userconfig "$NPMRC" \
    --registry "$REGISTRY" \
    --tag "$DIST_TAG" \
    --ignore-scripts \
    ${DRY_RUN:+--dry-run}
done

echo
echo "Done. pnpm-workspace.yaml overrides for woodpecker-commerce:"
for entry in "${PACKAGES[@]}"; do
  dir="${entry%%:*}"
  name="$(node -p "require('./$dir/package.json').name")"
  version="$(node -p "require('./$dir/package.json').version")-wood.$N"
  echo "  \"$name\": \"npm:$SCOPE/${entry##*:}@$version\""
done
