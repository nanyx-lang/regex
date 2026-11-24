#!/usr/bin/env bash
# Runs each test script in this directory with `nanyx run` and compares what it prints with its `.expected` file.
# Give the compiler to use as NANYX (default: `nanyx` on the PATH).
#
# A script in the package's own directory would be one of its files, so the tests run from a temporary directory
# that holds a copy of the package, `nanyx.regex`, beside them: each names it with `::dependency nanyx.regex ./nanyx.regex`.
#
# A script should exit with 0, or with the code in its `.exitcode` file if it has one. A script that should crash prints
# where the crash came from after the message, by the lines of the package's sources, so only the first lines of its
# output, as many as its `.expected` file has, are compared.
set -u
nanyx="${NANYX:-nanyx}"
tests="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/nanyx.regex"
cp -r "$tests/../nanyx.regex.nyxp" "$tests/../src" "$work/nanyx.regex/"
cp "$tests"/*.nyx "$work/"
cd "$work"
failed=0
for test in *.nyx; do
  expected="$tests/${test%.nyx}.expected"
  exitcode=0
  if [ -f "$tests/${test%.nyx}.exitcode" ]; then
    exitcode="$(cat "$tests/${test%.nyx}.exitcode")"
  fi
  actual="$("$nanyx" run "$test" 2>&1)"
  code=$?
  if [ "$exitcode" != 0 ]; then
    actual="$(printf '%s\n' "$actual" | head -n "$(wc -l < "$expected")")"
  fi
  if [ "$code" == "$exitcode" ] && [ "$actual" == "$(cat "$expected")" ]; then
    echo "pass  $test"
  else
    echo "FAIL  $test (exit code $code, expected $exitcode)"
    diff "$expected" <(printf '%s\n' "$actual") | sed 's/^/      /'
    failed=$((failed + 1))
  fi
done
echo
if [ "$failed" -gt 0 ]; then
  echo "$failed of $(ls *.nyx | wc -l) tests failed"
  exit 1
fi
echo "All $(ls *.nyx | wc -l) tests passed"
