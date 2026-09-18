#!/usr/bin/env bash
# Build this fork's patched T3 Code (0.28 dark surfaces). Fonts and diff type
# are configured in-app now, not patched. Run with no arguments for a desktop
# .dmg.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
  cat <<'USAGE'
usage: ./build.sh [mode]

  (none)    build the desktop app -> release/T3-Code-<version>-<arch>.dmg
  --check   fmt, typecheck and web build, without packaging (fast)
  --dev     run the dev server with hot reload, for iterating on styling
  --help    show this message
USAGE
}

mode=dmg
case "${1:-}" in
"") ;;
--check) mode=check ;;
--dev) mode=dev ;;
-h | --help)
  usage
  exit 0
  ;;
*)
  echo "build.sh: unknown argument '$1'" >&2
  usage >&2
  exit 64
  ;;
esac

if [[ ! -d node_modules ]]; then
  echo "==> installing dependencies"
  pnpm install --frozen-lockfile
fi

# Upstream rewrites package versions at release time and never commits the bump,
# so the tree's package.json trails its own tag. Label the artifact from the
# nearest stable tag instead; otherwise the updater reads the build as outdated
# and offers to replace it with a stock release, discarding these patches.
version="$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*nightly*' HEAD 2>/dev/null || true)"
version="${version#v}"

if [[ $mode == dmg && -z $version ]]; then
  echo "build.sh: no stable tag found, falling back to the package.json version" >&2
fi

case $mode in
dev)
  exec pnpm dev
  ;;
check)
  pnpm exec vp fmt --check
  pnpm exec vp run --filter @t3tools/web typecheck
  pnpm exec vp run --filter @t3tools/web build
  ;;
dmg)
  if [[ -n $version ]]; then
    T3CODE_DESKTOP_VERSION="$version" pnpm dist:desktop:dmg
  else
    pnpm dist:desktop:dmg
  fi
  printf '\n==> artifact: %s\n' "$(ls -t release/*.dmg | head -1)"
  ;;
esac
