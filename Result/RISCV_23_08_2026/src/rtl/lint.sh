#!/usr/bin/env bash
# Lint helper: lint <top-module> <file...>
# Bao gio cung nap rv32im_pkg.sv truoc. Bao cao warning tach theo file, va tach
# rieng UNUSEDPARAM cua package (chi co y nghia o full-design lint, Buoc 3).
set -u
TOP="$1"; shift
verilator --lint-only --sv -Wall --top-module "$TOP" \
  +incdir+src/rtl src/rtl/rv32im_pkg.sv "$@" 2>&1 \
| awk -v top="$TOP" '
  /Exiting due to/ { next }          # dong tong ket cua verilator, khong phai finding
  /^%(Warning|Error)/ {
    match($0, /%(Warning|Error)[-]?[A-Z_]*/); tag = substr($0, RSTART+1, RLENGTH-1)
    match($0, /src\/rtl\/[a-z0-9_]+\.sv/);    f   = substr($0, RSTART, RLENGTH)
    sub(/^src\/rtl\//, "", f)
    if (f == "rv32im_pkg.sv" && tag ~ /UNUSEDPARAM/) { pkgunused++; next }
    n[f "  " tag]++; total++
    if (total <= 25) print "  " $0
  }
  END {
    print "---------------------------------------------------------------"
    if (total == 0) printf("  LINT PASS: %s -- 0 warning, 0 error\n", top)
    else { printf("  LINT FAIL: %s -- %d finding(s)\n", top, total)
           for (k in n) printf("    %-46s x%d\n", k, n[k]) }
    printf("  (package UNUSEDPARAM deferred to full-design lint: %d)\n", pkgunused+0)
    exit (total == 0 ? 0 : 1)
  }'
