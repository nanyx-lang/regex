# nanyx.regex

Regular expressions for [Nanyx](https://github.com/nanyx-lang/nanyx) that take time in proportion to the text for every
pattern: a pattern that says where it is wrong and why, functions that find, test, replace and split, and the patterns
`#Matches` and `#MatchesRegex` for `match` arms.

## Install

In a package:

```bash
nanyx install nanyx.regex
```

That adds `(package = "nanyx.regex", version = "0.1")` to the manifest's `dependencies`, locks the version in
`nanyx.lock` and downloads it. A script names it in an `::install` line instead:

```nanyx
::install nanyx.regex 0.1.2
```

## Use

```nanyx
::install nanyx.regex 0.1.2

import nanyx.regex/regex

match Regex.parse('(\d+)-(\d+)')
  | #some(range) ->
    match "pages 10-20" \Regex.find(range)
      | #some(m) -> println("{m.text} from {m.start}: {m \group(1)} to {m \group(2)}")
      | #notFound -> println("no range")
  | #invalidPattern(e) -> println("bad pattern at {e.column}: {e.message}")

-- 10-20 from 6: #some(10) to #some(20)

def classify = { (line: string) ->
  match line
    | #Matches('^\s*$') -> "blank"
    | #Matches('^(\d+)-(\d+)$')(m) -> "range {m \group(1) \someOr("")} to {m \group(2) \someOr("")}"
    | _ -> "other"
}

println(classify("10-20"))

-- range 10 to 20
```

Import `nanyx.regex/regex`, and call its functions through the type they are attached to, `Regex.find`, or pipe a text
into them, `text \Regex.find(digits)`. It is pure, so it needs no context.

`Regex.parse` reads a pattern into a `Regex`, or gives `#invalidPattern(RegexError)`, with the column it goes wrong at
and why, so a pattern built at run time can be checked before it is used. `Regex.isMatch` says whether a regex matches
anywhere in a text, `Regex.find` finds the first match, `Regex.findAll` each in turn, as a sequence that finds the next
only when it is pulled, `Regex.replace` and `Regex.replaceWith` replace them, and `Regex.split` splits a text where they
are. `#Matches('pattern')` matches a string in a `match` arm against a literal pattern, crashing with what
`Regex.parse` says of it if it is wrong, and `#MatchesRegex(regex)` against a regex made at run time; either takes the
`Match` as its payload, or leaves it out.

Write a pattern as a raw, single-quoted string, `'\d+'`, so its backslashes need no escaping. The syntax is RE2's:
characters, and `\` before any that is syntax; `.`; classes such as `[a-z]`, `[^,;]` and `[[:alpha:]]`; the classes
`\d`, `\w` and `\s`, and `\D`, `\W` and `\S` for what they leave out; the escapes `\n`, `\t`, `\r`, `\f`, `\v`, `\a`,
`\x41` and `\x{1F600}`; the anchors `^`, `$`, `\A` and `\z`, and `\b` and `\B` for a word's edge; groups `( )`,
non-capturing `(?: )` and named `(?<name> )`; alternatives with `|`; and the quantifiers `*`, `+`, `?`, `{m}`, `{m,}`
and `{m,n}`, each greedy, or lazy with a `?` after it. The flags `i` (case-insensitive), `m` (`^` and `$` match at each
line's start and end) and `s` (`.` matches a line feed too) are turned on with `(?i)`, off with `(?-i)`, for the rest
of the group they're in, or for a group of their own with `(?i: )`.

Text is matched by Unicode code point, so `.` matches one character however many bytes it is, and a `Match`'s `start`
and `end` count code points. `\d`, `\w`, `\s` and `\b` are ASCII's, as in RE2, and `(?i)` matches both cases of the
ASCII, Latin-1, Greek and Cyrillic letters.

Limits, as in RE2, so that a pattern taken from input can't make matching slow, take much memory or run the program
out of stack: groups nest at most 1000 deep; repeats nested in each other can count to at most 1000 between them
(`(?:a{10}){100}`, but not `{101}`), with `*`, `+` and `?` counting 1 however they nest; and a pattern compiles to at
most 100000 instructions. Backreferences, lookaround and Unicode classes such as `\pL` aren't supported, and each is a
`RegexError` that says so.

The reference is the doc comments in `src/`, which an editor shows when you hover over a name. A guide with more
examples is the [regular expressions cookbook](https://nanyx.dev/docs/cookbook/regular-expressions).

## How it works

The engine is Nanyx code over the standard library, with no intrinsic, host import or runtime support of its own.
`src/regex.syntax.nyx` reads a pattern into a tree, applying its flags as it goes; it reads a group by going into it
and on, not by a call, so a pattern nested however deep is read in the same stack. `src/regex.vm.nyx` compiles the tree
into a Thompson NFA, in which `+` and `*` are loops over one copy of what they repeat, and runs it as a Pike VM, whose
threads are kept in priority order and marked in an `MArray` per code point, so matching is linear in the text for
every pattern. `src/regex.nyx` is the public module: `Regex`, `Match`, `RegexError` and the functions and patterns
attached to them.

Why it is built this way:

- **A package, not the standard library,** which stays what every program needs. It was shipped with the compiler up
  to 0.39, and is now an ordinary package from the [index](https://github.com/nanyx-lang/packages), released on its own.
- **Written in Nanyx, not provided by a host.** Matching is pure computation, so it needs no capability. Taking the
  host's engine (.NET's in the console host, JavaScript's in a browser), through a runtime import, would be fast and
  complete, but each host would match differently, and pure code would need a capability. The engine is also a real
  workload for `MArray`, functional but in place and sequences, written with the features users have.
- **Linear time, as RE2, Go and Rust have,** so that no pattern can hang a server (ReDoS). A backtracking engine would
  have backreferences and lookaround, but takes exponential time on some patterns.
- **No typed captures.** A pattern's named groups could become a record type, `(year: string, month: string)`, but that
  needs the compiler to evaluate the pattern while type checking, which Nanyx deliberately doesn't do.

Planned: a bad pattern written as a literal should be an error where it's written, not a crash when it runs. Nanyx
doesn't evaluate code at compile time, so the check is to be a linter rule that calls this package's own `Regex.parse`
on each literal passed to it, or to `#Matches`, and reports the `RegexError` at the column inside the literal
([nanyx#2033](https://github.com/nanyx-lang/nanyx/issues/2033)). It waits for linters written in Nanyx
([nanyx#107](https://github.com/nanyx-lang/nanyx/issues/107), [nanyx#1343](https://github.com/nanyx-lang/nanyx/issues/1343)).

## Develop

The tests are scripts in `tests/`, each with the output it should print in a `.expected` file beside it, and, for one
that should fail, the exit code it should give in an `.exitcode` file:

```bash
tests/run.sh                 # with nanyx on the PATH
NANYX=path/to/nanyx tests/run.sh
```

CI builds and tests the package with the compiler release its workflow names, 0.44.1. To release, set the manifest's
`version` (or run `nanyx bump`) in a pull request. When it merges, CI's `publish` job runs `nanyx publish`, which
creates the GitHub release `v<version>` with the `.nyxpkg`, and the [package index](https://github.com/nanyx-lang/packages)
records it. A merge whose version is already released publishes nothing.
