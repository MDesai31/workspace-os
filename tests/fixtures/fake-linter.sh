#!/usr/bin/env bash
# Test stub linter for tests/test-lint.sh. Invoked as: fake-linter.sh <file_path>
# A path containing "dirty" -> emit one diagnostic and exit 1 (as a real linter does on findings).
# Anything else -> exit 0 with no output (clean file -> silent).
case "$1" in
  *dirty*) printf '%s:1:1: E501 line too long\n' "$1"; exit 1 ;;
  *)       exit 0 ;;
esac
