#!/usr/bin/env bash
# FILE: tool/test-fast.sh
#
# ============================================================================
# WHAT THIS FILE DOES
# ============================================================================
# Runs `flutter test --exclude-tags=slow` so the dev-loop only executes
# unit / repository / service tests. Widget tests (every `testWidgets(...)`
# callsite in `test/`) carry the `slow` tag and are skipped here. Pass
# any extra `flutter test` args through unchanged — for example
# `tool/test-fast.sh test/group_stats_test.dart` runs a single file under
# the same fast policy.
#
# ============================================================================
# WHY IT EXISTS IN THE ARCHITECTURE
# ============================================================================
# `flutter test` with no flag walks the entire `test/` tree, including
# the slower widget pumps that need a real Flutter binding spun up per
# test. Excluding the `slow` tag drops a multi-minute run to a few
# seconds, which is the difference between running tests on every save
# and not running them at all. The companion `dart_test.yaml` registers
# the `slow` tag and sets the per-tag 60-second timeout that widget
# tests rely on. To run JUST the widget tests, call
# `flutter test --tags=slow`.
#
# ============================================================================
# WHY THIS IS HARDER THAN IT LOOKS
# ============================================================================
# - `set -e` makes the script exit on the first failing command. The
#   test runner's exit code propagates correctly.
# - `"$@"` forwards every argument the user passed, so file selectors
#   and extra flags (`--name=foo`, `-r expanded`) keep working.
# - Tagging is opt-in per `testWidgets(...)` callsite. If a NEW widget
#   test forgets the `tags: 'slow'` argument, it will land in the fast
#   bucket and balloon the loop. Audit fresh widget tests after
#   landing them.
#
# ============================================================================
# WHO CONSUMES THIS FILE
# ============================================================================
# - Engineers running the fast dev-loop locally
#   (`tool/test-fast.sh` from the repo root).
# - Optionally a pre-commit hook or CI fast-path can call this in place
#   of `flutter test` for quicker feedback.
#
# ============================================================================
# SIDE EFFECTS
# ============================================================================
# - Spawns `flutter test`. No filesystem writes outside of any cache
#   the Flutter tool maintains.

# Fast test loop: skip slow widget tests for the dev iteration loop.
set -e
flutter test --exclude-tags=slow "$@"
