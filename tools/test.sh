#!/usr/bin/env bash
# Runs every suite in tests/ through the standalone Luau CLI.
#   LUAU=/path/to/luau tools/test.sh
set -uo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-}"
if [ -z "$LUAU" ]; then
	for candidate in "$HOME/.luaubin/luau" /home/user/.luaubin/luau "$(command -v luau || true)"; do
		if [ -x "$candidate" ]; then LUAU="$candidate"; break; fi
	done
fi
if [ -z "$LUAU" ]; then
	echo "luau not found -- set LUAU=/path/to/luau (https://github.com/luau-lang/luau/releases)"
	exit 1
fi
COMPILE="${LUAU}-compile"
fail=0

echo "syntax"
for file in src/*.luau tests/*.luau; do
	if ! out=$("$COMPILE" --null "$file" 2>&1); then
		echo "  FAIL  $file"
		echo "$out" | sed 's/^/        /'
		fail=1
	fi
done
[ $fail -eq 0 ] && echo "  ok    $(ls src/*.luau | wc -l) modules compile"

echo "suites"
for suite in tests/*.luau; do
	case "$(basename "$suite")" in stub.luau) continue ;; esac
	bundle=$(mktemp /tmp/ablocks-bundle-XXXXXX.luau)
	if ! python3 tools/bundle.py "$suite" > "$bundle"; then
		echo "  FAIL  $suite (bundling)"
		fail=1
		continue
	fi
	if ! "$LUAU" "$bundle"; then fail=1; fi
	rm -f "$bundle"
done

echo "packaging"
built=$(mktemp /tmp/ablocks-build-XXXXXX.rbxmx)
if python3 tools/build.py --out "$built" > /dev/null; then
	if cmp -s "$built" dist/ABlocks.rbxmx; then
		echo "  ok    dist/ABlocks.rbxmx matches src/"
	else
		echo "  FAIL  dist/ABlocks.rbxmx is stale -- run: python3 tools/build.py"
		fail=1
	fi
else
	echo "  FAIL  the model file did not build"
	fail=1
fi
rm -f "$built"

exit $fail
