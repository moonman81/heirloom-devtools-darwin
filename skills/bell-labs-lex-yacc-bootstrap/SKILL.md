---
name: bell-labs-lex-yacc-bootstrap
description: "Bootstrap discipline for Heirloom devtools where yacc has to compile itself and lex has to compile itself. On first build, use the host system's yacc/lex (bison/flex on modern systems); after devtools installs, subsequent Heirloom builds should point YACC and LEX at the Heirloom-installed versions to keep the toolchain internally consistent and avoid subtle grammar-token divergence between bison and Ritter's yacc."
gate: 3
version: "1.0.0"
author: moonman81
tags: [heirloom, devtools, yacc, lex, bison, flex, bootstrap, self-hosting]
depends_on: []
allowed-tools:
  - Read
  - Write
  - Bash
when_to_use: "Invoke when porting heirloom-devtools, when scoping the toolchain-consistency question 'should downstream Heirloom builds use system bison or Heirloom yacc?', or when debugging a yacc-consumer failure that only reproduces under one lex/yacc pair. Triggers: 'yacc self-hosting', 'lex bootstrap', 'bison vs yacc', 'flex vs lex', 'YACC=/opt/heirloom/ccs/bin/yacc', 'grammar token divergence'."
---

# Bell Labs lex / yacc bootstrap discipline

## The two-phase bootstrap

Heirloom devtools ships yacc, lex, m4, make, and sccs — including
the yacc and lex sources. Building them requires yacc and lex.

**Phase 1 (bootstrap)** — use whatever the host provides:
- macOS Xcode CLT: `/Library/Developer/CommandLineTools/usr/bin/yacc`
  is bison ~2.3; `lex` is flex.
- These work well enough to build devtools' own yacc / lex.

**Phase 2 (self-hosting)** — after devtools installs, downstream
Heirloom consumers (toolchest, doctools, pkgtools) should point
`YACC` and `LEX` at the Heirloom-installed versions:

```make
YACC = /opt/heirloom/ccs/bin/yacc
LEX  = /opt/heirloom/ccs/bin/lex
```

This is what the toolchest / doctools / pkgtools `mk.config`
overrides do (see the port patches).

## Why self-hosting matters

Bison and Heirloom yacc are ~90% compatible but not identical. Real
divergences that bit downstream Heirloom code:

- **`scriptvfy.l`** (pkgtools libinst) uses Bell Labs lex internals
  `yytchar`, `yysptr`, `yysbuf`, `U(...)`. Flex does not emit these
  names. Building `scriptvfy.l` with flex produces a scanner that
  fails to compile against the hand-written `#define input()`
  override.
- **`m4y.y` + `m4y_xpg4.y`** (devtools m4): both `.y` files build
  concurrently in parallel-make and race on the fixed output name
  `y.tab.c`. bison in `-y` compat mode has the same problem; the
  fix is `make -j1` for m4 or a `-b` prefix.

## The parallel-y.tab.c race

Both yacc and bison emit their output as `y.tab.c` by default. Any
Makefile that runs yacc for two `.y` files concurrently races. Fix:

- Add `.NOTPARALLEL:` to the `.y`-consuming subdir's `Makefile.mk`,
  or
- Run the yacc rules with an explicit output file (`bison -o
  <target>.c` or Ritter yacc `-b <prefix>`), or
- Serialise the offending target only: `make -j1 m4`.

## When to use system bison anyway

- CI / build servers where installing Heirloom devtools first is
  impractical.
- Cross-compiling to a target that doesn't have Heirloom.
- Debugging a specific compatibility question.

Set:

```make
YACC = yacc
LEX  = lex
```

… and accept that scanner files like `scriptvfy.l` will not build.
For a Darwin-native pkgtools port, this is why we set
`LEX=/opt/heirloom/ccs/bin/lex` in `pkgtools/mk.config`.

## Reference

- Steve Johnson, "Yacc: Yet Another Compiler-Compiler" (Bell Labs
  Technical Memo, 1975).
- Mike Lesk, "Lex — A Lexical Analyser Generator" (Bell Labs Technical
  Memo, 1975).
- Upstream `man/yacc.1`, `man/lex.1` in heirloom-devtools-darwin.
