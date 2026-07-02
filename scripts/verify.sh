#!/bin/sh
# verify.sh — post-install smoke test for heirloom-devtools
set -eu
PREFIX="${1:-/opt/heirloom}"
CCSBIN="$PREFIX/ccs/bin"

if tty >/dev/null 2>&1; then
	C_OK='\033[32m'; C_FAIL='\033[31m'; C_RESET='\033[0m'
else
	C_OK=''; C_FAIL=''; C_RESET=''
fi
ok()   { printf '  %b✓%b %s\n' "$C_OK" "$C_RESET" "$*"; }
fail() { printf '  %b✗ %s%b\n' "$C_FAIL" "$*" "$C_RESET"; exit 1; }

for tool in yacc lex m4 make sccs admin get prs; do
	[ -x "$CCSBIN/$tool" ] || fail "$CCSBIN/$tool not executable"
	ok "$tool installed"
done

# yacc + lex functional smoke
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/g.y" <<'EOF'
%token INT
%%
expr : INT ;
EOF
(cd "$TMP" && "$CCSBIN/yacc" g.y) && [ -f "$TMP/y.tab.c" ] || fail 'yacc did not produce y.tab.c'
ok 'yacc functional smoke'

cat > "$TMP/l.l" <<'EOF'
%%
[ \t] { }
%%
int yywrap(){return 1;}
EOF
(cd "$TMP" && "$CCSBIN/lex" l.l) && [ -f "$TMP/lex.yy.c" ] || fail 'lex did not produce lex.yy.c'
ok 'lex functional smoke'

# m4 smoke
out=$(echo 'define(FOO, bar)FOO' | "$CCSBIN/m4")
[ "$out" = 'bar' ] || fail "m4 macro expansion: got '$out'"
ok 'm4 macro expansion'

# make smoke
cat > "$TMP/Makefile" <<'EOF'
all:
	@echo make-ok
EOF
out=$(cd "$TMP" && "$CCSBIN/make")
[ "$out" = 'make-ok' ] || fail "make: got '$out'"
ok 'make functional'

printf '%bverify: devtools OK%b\n' "$C_OK" "$C_RESET"
