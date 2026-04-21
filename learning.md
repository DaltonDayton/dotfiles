# Learning Go through `quill`

Notes as we build out the `quill` dotfiles manager. Each section corresponds to one plan task, tagged with the commit hash so you can `git show <hash>` to see the exact diff being discussed.

---

## Task 0 — Scaffold (`758c2fa`, `cb0e74f`)

Repo layout after this task:

```
.dotfiles/
├── .gitignore
├── CLAUDE.md
├── README.md
├── bin/quill                    # built binary (gitignored)
├── cmd/quill/main.go
├── docs/superpowers/{specs,plans}/...
└── go.mod
```

- **`package main` in `cmd/quill/main.go`** makes it an executable (rather than a library). The function `main()` in this package is the entry point.
- **Module path `github.com/DaltonDayton/dotfiles` in `go.mod`** is how the project refers to itself internally. Once we add internal packages, imports will look like `"github.com/DaltonDayton/dotfiles/internal/manifest"` — the path mirrors the folder structure under the module root.
- **`cmd/<name>/main.go`** is a Go community convention for binaries. If we later add a second binary (e.g., `cmd/quilld/main.go` for a daemon), both live under `cmd/`.

Nothing to review in the test suite yet — Task 1 is where the TDD rhythm kicks in.

---

## Task 1 — Manifest parser (`e849ec5`)

Four tests green, first real Go package.

- **Struct tags (`toml:"name"`)**: every field in `schema.go` has a back-ticked tag like `` `toml:"depends_on"` ``. These are metadata strings attached to fields that libraries read via reflection. `BurntSushi/toml` uses them to know which TOML key maps to which Go field. Go's stdlib `encoding/json` works the same way (`json:"..."`) — once you know the pattern, every serialization library in the ecosystem follows it.
- **Pointer returns (`*Module`, `*Host`)**: `ParseModule` returns `*Module` rather than `Module` (value). Two reasons in Go: (1) callers can compare against `nil` for "no module loaded yet"; (2) no struct copy on every call. Rule of thumb: if a function loads/allocates a complex struct, return a pointer.
- **Error wrapping (`fmt.Errorf("%w", err)`)**: The `%w` verb (distinct from `%v`) wraps an error so callers can later unwrap it with `errors.Is` / `errors.As`. Idiomatic way to add context to a lower-level error without destroying the ability to match on its type.
- **`t.TempDir()`**: Gives you a throwaway directory that Go deletes after the test. No cleanup code, no flaky leftover files across runs. Always prefer this to `os.MkdirTemp` + `defer remove` in tests.
- **The "fail first" step**: You saw the test fail with "undefined: ParseModule" before the implementation existed. That's the TDD discipline — the test proves it can detect the absence of the code, so we know a passing test later is meaningful and not a false positive.

---

## Task 2 — Host detection & profile loader (`ba8a01c`)

First task where one of our packages imports another.

- **Cross-package import (`"github.com/DaltonDayton/dotfiles/internal/manifest"`)**: `host.go` imports `manifest` to reuse `ParseHost` and the `*Host` return type. This is the payoff for the module path in `go.mod` — an import path mirrors the filesystem: `internal/manifest` on disk ↔ `github.com/DaltonDayton/dotfiles/internal/manifest` in imports.
- **The `internal/` convention**: Go treats any package under a directory literally named `internal` as private to its parent. `internal/manifest` is only importable by code inside `github.com/DaltonDayton/dotfiles/...`. If someone else ever depends on this module as a library, they can't pull in `internal/manifest` — it's a compile error. Useful when you want to split code into packages without committing to a public API.
- **Two functions, one package**: `Detect()` and `Load()` live together because they're different phases of the same workflow (figure out who we are → load the matching profile). Tests only cover `Load` because `Detect()` is a thin wrapper over `os.Hostname()` — testing it would really just be testing the stdlib.

---

## Task 3 — Template renderer (`613fae9`)

Phase 1 (foundations) complete.

- **`text/template` (stdlib)**: Go ships with two templating packages — `text/template` for plain text and `html/template` for HTML (auto-escapes). Same API, different defaults. We want plain text (hyprland configs, `.gitconfig`, etc.), so `text/template`.
- **`template.New("render")`**: The string `"render"` is the template's name. It's used in error messages and when a template references another by name (via `{{ template "other" }}`). Since we're compiling a one-off string with no sub-templates, the name is basically just a label.
- **Option chaining (`Option("missingkey=error")`)**: Go's `text/template` has three modes for missing map keys — default (inserts `<no value>`), zero (inserts the zero value), or error (fails). Default is the silent-insert mode, which is a footgun for config files. We opt into `error` so a typo like `{{ .Vars.montor }}` fails the Apply with a clear message instead of writing a half-broken config.
- **`bytes.Buffer` as a writer**: `tmpl.Execute` takes any `io.Writer` — a file, a network connection, an in-memory buffer, etc. `bytes.Buffer` is the in-memory option and doubles as both a writer (`Write([]byte)`) and a string producer (`.String()`). Standard Go idiom for "build up output then return it as a string."
- **`// why:` comment convention**: I left a short `// why:` on `missingkey=error` since the reason isn't obvious from reading the code. Per your `CLAUDE.md`, *what* comments are skipped — the name `Render` and the `text/template` call already say what. *Why* comments earn their keep when removing them would leave a reader guessing.

---

## Task 4 — Action interface & directories executor (`1e30fb9`)

The `Action` interface is now the contract every remaining executor will follow.

- **Interfaces**. In `action.go`:

  ```go
  type Action interface {
      Describe() string
      Check() (bool, error)
      Apply() error
  }
  ```

  Go interfaces are **structural, not nominal** — you don't write `type Directory struct { ... } implements Action`. Any type that has all three methods with the right signatures automatically satisfies `Action`. The compiler figures it out. This is different from Java/C# where you declare what you implement.

  What that gives us: the runner (Task 12+) will take a `[]Action` and iterate — it doesn't need to know or care that the concrete types are `*Directory`, `*Symlink`, `*Packages`, etc. It just calls `.Check()` then `.Apply()`. Adding a new action type later requires zero runner changes.

- **The compile-time interface check**. In the test file:

  ```go
  var _ Action = (*Directory)(nil)
  ```

  This is a Go idiom worth memorizing. Breakdown:
  - `(*Directory)(nil)` — a typed nil pointer to `Directory`
  - `var _ Action = ...` — declare an anonymous variable of type `Action` and assign the nil pointer to it
  - `_` is the "blank identifier" — discard the value

  At runtime this does nothing. But at compile time, Go checks that `*Directory` satisfies `Action`. If you later remove `Check()` or change a method signature, the build fails with a clear error at this line instead of somewhere confusing downstream. You'll see this pattern all over the Go ecosystem.

- **Pointer receivers (`func (d *Directory) Check()`)**: Methods are declared with a receiver — the `(d *Directory)` part before the method name. The `*` means pointer receiver — the method operates on a pointer to a `Directory`, not a copy. Two reasons to prefer pointer receivers: (1) methods can mutate the receiver; (2) no struct copy on each call. Rule of thumb: if a type has *any* pointer receiver methods, use pointer receivers for all of them.

- **`os.FileMode` and octal literals (`0o755`)**: Go's type system treats file modes as their own type (`os.FileMode`, an alias for `uint32`). `0o755` is a Go 1.13+ octal literal (the older `0755` style still works, but `0o` is clearer). `strconv.ParseUint(s, 8, 32)` parses a string in base 8 into a uint that fits in 32 bits.

- **What `Status` is doing in `action.go`**: We defined `type Status string` and three constants (`StatusApplied`, `StatusSkipped`, `StatusFailed`). The runner (Task 12) will use these to report outcomes. Declaring a named string type (instead of using raw `string`) gives us type safety — you can't accidentally pass a status-shaped string where another string is expected. Common Go pattern.

---

## Task 5 — Symlinks executor (`dc530b2`)

Added overwrite and skip policy tests beyond the plan's 3 — all three conflict policies now have a test each.

- **`errors.Is(err, os.ErrNotExist)`**: This is the modern way to check "is this error this kind of thing?" Before Go 1.13, people compared errors with `==` (e.g., `if err == os.ErrNotExist`), which broke whenever someone wrapped the error for context. `errors.Is` walks the wrapped chain (the `%w` verb from Task 1) and returns `true` if any layer matches. Always use `errors.Is` for sentinel errors like `os.ErrNotExist`, `io.EOF`, `context.Canceled`, etc.
- **`os.Lstat` vs `os.Stat`**: Subtle but important. `Stat` follows symlinks — if you `Stat` a symlink, you get info about the *target*. `Lstat` does not follow — it tells you about the link itself. For symlink work, you almost always want `Lstat`; otherwise a symlink to a missing file would look like "the destination doesn't exist at all."
- **Mode bitmask check (`info.Mode()&os.ModeSymlink != 0`)**: `os.FileMode` packs several booleans (directory, symlink, setuid, etc.) into one value using bit flags. `os.ModeSymlink` is a single bit. `mode & ModeSymlink` masks out everything else — nonzero means "this bit is set." The `& != 0` idiom comes up constantly in Go when dealing with flags.
- **switch-with-no-tag as chained conditionals**: In `Apply()`:

  ```go
  switch {
  case errors.Is(err, os.ErrNotExist):
      // ...
  case err != nil:
      return err
  case info.Mode()&os.ModeSymlink != 0:
      // ...
  default:
      // ...
  }
  ```

  A `switch` with no value after the keyword is equivalent to `if/else if/else`, but reads better with more than two branches. Very common Go pattern — reach for it instead of deep `if` ladders.

- **Design choice worth calling out**: wrong-target symlinks get fixed regardless of `ConflictPolicy`. Logic: if it's already a symlink, we put it there (or something like us did), so healing drift is safe. The conflict policy only applies to regular files, which are the user's own content. I made that explicit in the doc comment so future-you doesn't wonder why `ConflictSkip` still replaces a broken link.

---

## Task 6 — Files executor (`15cd14b`)

Short task — only a few things worth noting.

- **Reused `parseMode` from `directories.go`**: Both `Directory` and `File` take an octal mode string. Rather than duplicate the parser, `File` just calls the one that already lives in the same package. This is the value of keeping related action types in one package — unexported helpers (`parseMode` starts with lowercase) are visible across files but hidden from outside callers.
- **Subtle bug the `Chmod` after `WriteFile` catches**: `os.WriteFile` only applies the mode argument when it *creates* the file. If the file already existed (as in `TestFile_rewritesWhenModeDiffers`), Go keeps the original permissions. `os.Chmod` forces the declared mode unconditionally. Added a `// why:` comment — this is the kind of thing that bites you six months later if you forget.
- **Design tradeoff — no `content_from`**: The schema in `manifest/schema.go` has a `ContentFrom` field (read content from another file), but the executor only reads `Content` as a string. Task 13 (in the runner) is where `ContentFrom` gets resolved — it reads the referenced file, then hands the executor a plain `File{Content: <bytes>}`. Keeping the executor free of filesystem lookups for its input makes it easier to test: the test just passes a string. Separating "gather inputs" from "apply" is a pattern worth internalizing.

---

## Task 7 — Commands executor (`96780a8`)

- **Field vs method name collision**: the struct field is `CheckCmd`, not `Check`, because the `Action` interface requires a `Check()` method. Go lets a struct have a field and method with the same name on different types, but it's confusing and error-prone, so the convention is to rename one.
- **`*exec.ExitError` type assertion**: `cmd.Run()` returns an error for two very different reasons: the process ran and exited non-zero (normal "not applied" signal), or the process couldn't run at all (`sh` missing, etc. — a real failure). `err.(*exec.ExitError)` tells the two apart so we only propagate real failures.
- **`CombinedOutput()` in `Apply`**: captures stdout+stderr so when a command fails, the error message includes what the shell actually said, not just "exit status 1".

---

## Task 8 — Services executor (`ebc1bd1`)

- **Package-level `var` for test injection**: `var systemctl = func(...) {...}` gives us a function value that tests can swap out via `t.Cleanup` to restore. This is the idiomatic Go equivalent of dependency injection when you don't want to thread an interface through every caller. Same pattern shows up again in the next task with `pkgDrivers`.
- **`t.Cleanup`**: registers a function to run when the test (and its subtests) finish. Cleaner than `defer` because it composes with test helpers — `withFake` sets up *and* registers teardown, and the caller doesn't need to remember to defer anything.
- **`t.Helper()`**: marks a function as a test helper so failures are reported at the *caller's* line number, not inside the helper. Small but nice for readability.
- **`append` returning a new slice**: `append(s.scopeArgs(), "enable", s.Name)` builds a fresh args slice per call. Go slices are cheap; prefer copying over mutating shared state.

---

## Task 9 — Packages executor (`ab9e505`)

First task where we introduce a **named Go interface** alongside the package-level-var pattern from Task 8.

- **Interface as extension point**: `PackageDriver` is a two-method interface (`IsInstalled`, `Install`). Every concrete driver (`pacmanDriver`, `paruDriver`, …) is a tiny struct with two methods. New managers (apt, brew, nix) are a matter of adding a file, not refactoring the core. The `Packages` action knows only the interface, not any specific driver.
- **Value receivers on driver methods (`func (pacmanDriver) IsInstalled(...)`)**: The drivers carry no state, so a value receiver is fine. Rule of thumb: pointer receiver if the method mutates the receiver *or* the struct is large; value receiver if it's stateless and cheap to copy. Here the struct is empty — zero cost either way.
- **Driver reuse (`paruDriver.IsInstalled` → `pacmanDriver{}.IsInstalled`)**: paru reads the pacman database, so we literally call the pacman driver's check. Composition beats inheritance — `pacmanDriver{}` is a fresh zero-value struct, and since the method has a value receiver, that's perfectly cheap.
- **`sudo -n` policy call-out**: `-n` means non-interactive — sudo errors out instead of prompting for a password. That's intentional: we document that `quill apply` expects `sudo -v` to have been run, rather than adding a TTY prompt to a tool that's mostly non-interactive. This is the first piece of real *policy* baked into the codebase, so it got a `// why:` comment.

---

## Task 10 — Module loader (`cd57f80`)

First package-level type that *embeds* another.

- **Struct embedding (`type Module struct { *manifest.Module; Dir string }`)**: Writing a type name without a field name inside a struct is called embedding. All the embedded type's fields and methods become accessible directly on the outer type — `m.Name` works even though `Name` is actually a field of the embedded `*manifest.Module`. This is Go's composition-over-inheritance answer. Two notes:
  - We embed `*manifest.Module` (pointer) rather than the value. That's usually the right default — it avoids copies and lets the outer and inner types share the same allocation.
  - `type Module struct` in `internal/module` and `type Module struct` in `internal/manifest` coexist because they're in different packages. Callers disambiguate with `module.Module` vs `manifest.Module`.
- **`os.ReadDir` vs `filepath.Walk`**: `ReadDir` returns only the immediate children of a directory. `Walk` recurses the whole tree. Modules live exactly one level deep (`modules/<name>/module.toml`), so `ReadDir` is the right choice — faster and simpler.
- **Graceful skip for non-module dirs**: `if _, err := os.Stat(manifestPath); err != nil { continue }`. Rather than erroring on a directory that doesn't have a `module.toml`, we just skip it. This means we can have `modules/README.md`, scratch directories, `.git`, etc. without blowing up.

---

## Task 11 — Selection state (`a188175`)

First JSON marshaling.

- **`encoding/json` with struct tags**: Same pattern as `toml:"..."` tags from Task 1, but with `json:"modules"`. One pattern, many encoders.
- **`json.MarshalIndent(data, "", "  ")`**: like `json.Marshal` but with indentation. The two string args are (prefix, indent). Prefer this for files humans might read.
- **Missing-file is not an error**: `LoadSelection` returns `nil, nil` if the file doesn't exist. That's appropriate for optional UI state — first-run should not error. For required files, you'd propagate the error instead.
- **`DefaultPath()` returns a path, doesn't create it**: common Go pattern — file-path functions compute paths; `SaveSelection` is what creates the parent directory. Keep "know where it goes" and "put it there" in separate functions.

---

## Task 12 — Runner dependency resolution + host filter (`4e3d4cb`)

Classic DFS-based topological sort, first use of a closure.

- **Closures over loop state**: `visit` is declared with `var visit func(name string) error` first, then assigned. That's because `visit` calls itself recursively — if we tried `visit := func(name string) error { visit(dep); ... }`, the inner `visit` would be unbound (Go's `:=` doesn't let the RHS see its own LHS). The two-step declare-then-assign is the idiomatic workaround.
- **Two maps for cycle detection**: `visited` is the "fully processed" set; `onStack` is the "in-progress" set. If we try to visit something already `onStack`, that's a cycle. If it's already `visited`, we're fine to skip. This three-color DFS pattern shows up everywhere: compilers, linkers, CI graph engines.
- **`for ... range selected`** drives the outer loop — dependency resolution is per root, then per-root DFS. Roots can overlap; `visited` keeps us from double-processing.

---

## Task 13 — Runner BuildActions (`c0a5d61`)

Translation layer: manifest (data) → actions (behavior).

- **Separation of concerns**: the manifest package only knows *shapes*; the action package only knows *how to run one thing*; the runner bridges them. `BuildActions` reads filesystem for `.tmpl` rendering and `ContentFrom` resolution, then hands plain values to action structs. Each action is testable with strings, not files.
- **`strings.HasSuffix(s.Src, ".tmpl")`** drives the template branch. We render the template to a sibling file (strip the `.tmpl` suffix) before symlinking — this keeps the symlink target a stable on-disk path instead of a tmp file, which matters for `readlink` debugging.
- **`~/` expansion**: `expandHome` handles the `~/` prefix Go's stdlib won't do for you. Subtle gotcha — `os.UserHomeDir()` is the canonical "home dir" call; don't read `$HOME` directly because Go normalizes platform differences.
- **Type assertions in tests (`acts[0].(*action.Symlink)`)**: the action slice is `[]action.Action`, and we want to check the concrete type of element 0. `v.(T)` is the type assertion syntax — it panics if the assertion fails unless you use the two-value form `v, ok := x.(T)` where `ok` is `false` instead of panicking.

---

## Task 14 — Runner ApplyActions + events (`54f62b0`)

First channel-based API. Concurrency primitives done right.

- **Chan directions (`chan<- Event`)**: parameter type is a *send-only* channel. This is a compile-time guarantee — callees that receive `chan<- Event` can only send on it, never receive. The runner sends events; the consumer (install command) owns the bidirectional channel and passes a send-only view in. Two's company: `<-chan Event` is the receive-only equivalent.
- **Non-blocking send with `select + default`**:

  ```go
  select {
  case ch <- e:
  default:
  }
  ```

  If the channel buffer is full, the `default` branch fires and we drop the event. This is the idiomatic "best effort; don't block" pattern. We accept that a saturated TUI might miss a progress line; that's better than stalling the whole apply loop behind a slow UI.
- **`Status` constants pay off**: the `StatusApplied` / `StatusSkipped` / `StatusFailed` enum we defined back in Task 4 finally gets used here. Each action produces a `Result{Status: ...}`, and the TUI / CLI consumer can switch on `Status` instead of parsing strings.
- **Check-then-Apply is the idempotency contract**: notice `ApplyActions` calls `Check()` first and only calls `Apply()` if `Check` returns false. This is *the* contract every executor implements. Action authors don't need to re-check inside `Apply` — the runner guarantees the `Check == false` precondition.

---

## Task 15 — Runner RunInstallSh escape hatch (`23ec77c`)

The "eject" button for things declarative TOML can't express.

- **Present-file check as absence-of-error**: `if _, err := os.Stat(script); err != nil { return nil }` — any stat error (including "file not found") means "no install.sh, skip silently." This is intentionally permissive: an install.sh is optional per-module, and we'd rather quietly skip modules without one than introduce a separate "does it have an install.sh?" flag.
- **Shell dispatch via `exec.Command("sh", script)`**: we explicitly invoke `sh` rather than trusting the shebang — saves us from chmod +x bugs and makes the behavior deterministic across hosts. The script still runs with its own `#!/bin/sh` line, but `sh path/to/install.sh` overrides.
- **`cmd.Dir = m.Dir` sets CWD**: `os.Exec`-level calls default to the parent's working dir. Setting `cmd.Dir` lets the script use relative paths like `./helper.sh` without worrying about where `quill` was invoked from.
- **Self-idempotency contract**: the declarative actions let the runner gate `Apply` on `Check`. `install.sh` doesn't have that luxury — the script itself must be safe to re-run. That's documented in `CLAUDE.md` and called out in the action's doc comment.

---

## Task 16 — Cobra CLI skeleton (`52a3d7c`)

First external CLI dep. Cobra is the de-facto standard for Go CLIs (kubectl, gh, hugo).

- **Command-builder pattern**: each subcommand lives in its own file (`list.go`, `status.go`) and returns `*cobra.Command` from a `newXxxCmd()` constructor. `main.go` calls `root.AddCommand(newListCmd(), newStatusCmd(), ...)`. Keeps each subcommand self-contained and trivially testable.
- **Persistent flags (`root.PersistentFlags().StringVar(...)`)** are inherited by subcommands. `--repo` works on `quill list --repo /path` and every other subcommand. Local (non-persistent) flags would only attach to the specific subcommand.
- **`RunE` vs `Run`**: `RunE` returns an `error`, which cobra prints and exits 1 on. `Run` is the older error-swallowing variant. Always use `RunE` in real code — proper exit codes matter for scripting.
- **Shared context via a package-level helper** (`cmd/quill/context.go`'s `loadCtx`): rather than threading `RepoRoot`, `Modules`, `Host` through every command's closure, each command calls `loadCtx()` at the top of its `RunE`. Centralizes the "figure out where the repo lives and load modules/host" logic — lookup stays flexible (env var, flag, binary-relative) without duplication.
- **Stubs for unimplemented commands** compile but error at runtime with a clear message pointing at the task number. Lets the rest of the CLI structure come together before every subcommand is implemented. The stubs get deleted as each real command lands.

---

## Task 17 — Lipgloss styles and banner (`44d575b`)

Three Charm libraries added together: `lipgloss` (styling), `bubbletea` (interactive TUI), `huh` (forms).

- **Style values as package-level vars**: each style (`Title`, `Subtle`, `Success`, …) is built once at import time and reused. Lipgloss's `Style` is a value type — you chain builder methods (`Bold(true).Foreground(...)`) and store the result. It's goroutine-safe for reads, which is what you want for a shared palette.
- **`.Render(s)`** is how you apply a style. `Title.Render("quill")` returns a string with ANSI escape codes. Pure strings in, pure strings out — no side effects, which is why you can compose them freely in `Banner`.
- **Package doc comments**: `internal/tui/styles.go` has `// Package tui contains ...` above the `package tui` line. Go tooling picks up package docs from any file in the package, but by convention they go on the most central-feeling file. Go's docs toolchain (`go doc`, pkg.go.dev) surfaces these directly.

---

## Task 18 — Huh module selector (`5f8f090`)

Huh's form API is declarative but with some surprises. Grouped multi-selects bind to a single shared slice pointer, so defaults require careful handling.

- **Test the pure helper, not the form**: `huh.Form.Run()` takes over the terminal, which is a nightmare to unit-test. Extracting `GroupByTag` as a pure data-transform gives us something testable; the form construction code is thin enough to eyeball-verify.
- **`[]huh.Option[string]`** is a generic type — Huh's options are parameterized by the value they return. We use `string` here (module names), but for a typed selector you'd see `huh.Option[int]` etc. Generics showed up in Go 1.18 and libraries have gradually adopted them for exactly this kind of API.
- **Shared `&chosen` across fields**: every `MultiSelect` in the form uses `Value(&chosen)`. That means every selection across all tag groups ends up in the same slice. `unique(chosen)` dedupes at the end. This matches Huh's data model, which expects a single binding per value.
- **Pre-seeding defaults via the bound slice**: before building fields, we prepend the preselected names to `chosen`. When Huh renders, any option whose value is already in the slice starts checked. Not intuitive, but the correct incantation.
- **Slice re-slicing for dedupe (`out := xs[:0]`)**: `unique` reuses the input slice's backing array. Safe here because we've already iterated past each element before overwriting. Saves an allocation — idiomatic Go when the function owns the input.

---

## Task 19 — Bubble Tea progress view + install command (`1bc9c43`)

First use of The Elm Architecture in Go — Bubble Tea's `Model` / `Init` / `Update` / `View` pattern.

- **Model-Update-View**: your TUI state is one struct (`Model`). `Init()` returns a command to do first (here: wait for the first event). `Update(msg)` handles an incoming message and returns a new model + optional next command. `View()` renders the model as a string. No mutation outside `Update`. One-way data flow.
- **Typed message envelope (`type eventMsg runner.Event`)**: Bubble Tea passes messages as `interface{}` (well, `tea.Msg`), and dispatches based on type. Wrapping `runner.Event` in our own named type `eventMsg` lets us match on it cleanly in the `switch msg := msg.(type)` block without conflicting with any other package that might also emit `tea.Msg` values.
- **Commands as `func() tea.Msg`**: `waitEvent(m.events)` returns a closure that blocks on a channel read and returns the next message. Bubble Tea's runtime spawns this in a goroutine, so the TUI loop stays responsive. Every Update that wants to keep listening returns `waitEvent(m.events)` again — recursive-ish, but cheap.
- **Concurrent goroutine feeds events**: in `install.go`, a `go func() { ... close(events) }()` runs the apply loop in the background and closes the channel when done. The `waitEvent` reader detects the close via `<-chan` returning `ok=false` and emits `doneMsg{}`, which triggers `tea.Quit`. Classic producer-consumer-with-cleanup pattern.

---

## Task 20 — Non-interactive `apply` (`148d060`)

Same event stream as `install`, but no TUI — just stdout.

- **Same runner.ApplyActions, different consumer**: the runner doesn't know or care whether its events go to a Bubble Tea model or a `for e := range events` loop. Designing the runner to emit events rather than call a UI layer directly pays off exactly here — two commands, one orchestrator.
- **Exit code via returned error**: `return fmt.Errorf("%d actions failed", failed)` — cobra prints this to stderr and exits 1. CI-friendly. Don't `os.Exit(1)` from inside a `RunE`; return an error and let cobra handle the exit.
- **`for e := range events` over a channel**: this is the canonical Go pattern for consuming a producer-closed channel. When the producer calls `close(events)`, the loop exits automatically. No sentinel values, no extra state.

---

## Task 21 — `path` command (`3bc97da`)

Mostly an excuse for a clean "pure helper + thin command" split.

- **Pure helper is the tested unit**: `ensurePathLine(rcPath)` is a pure function — takes a path, touches only that file, returns a bool. That's what the unit tests exercise (missing file, present line, commented-out line). The cobra command itself is thin glue and not worth testing in isolation.
- **`bufio.Scanner` over `bytes.Reader`**: simpler than hand-splitting a byte slice on newlines. For files measured in KB, not MB, this is the right tool.
- **`os.IsNotExist` (older form)** vs `errors.Is(err, fs.ErrNotExist)` (newer): both work for `os.ReadFile`. The newer form is preferred in new code — it handles wrapped errors too.
- **`os.Remove` before `os.Symlink`**: `Symlink` errors if the target already exists. The idempotent pattern is "remove then create." We use `_ = os.Remove(link)` because "doesn't exist" is fine; this would be a bug if we cared about distinguishing permission-denied from not-found, but for a user-local path we don't.

---

## Task 22 — bootstrap.sh (`73decfb`)

Thirty-line bash, no Go. Called out because the `set -euo pipefail` + `exec` tail are worth internalizing.

- **`set -euo pipefail`**: `-e` = exit on first error, `-u` = error on unset variable, `-o pipefail` = propagate errors through pipes. Should be the first thing in every non-trivial bash script. It's why the script stays readable — we don't check `$?` after every command because we know failure terminates us.
- **`${VAR:-default}` parameter expansion**: `${DOTFILES_REPO_URL:-https://...}` means "use `$DOTFILES_REPO_URL` if set, otherwise the default." That's how we let the user override via env vars without writing flag-parsing logic.
- **`exec ./bin/quill install`** at the end: replaces the shell process with the Go binary instead of forking. When the user pipes `curl ... | bash`, the `exec` means the interactive installer inherits the terminal directly — no zombie bash parent, no signal-handling weirdness.

---

## Task 23 — First real git module + host profile (`96b0620`, `6d82e74`)

The first actual *end-user* data. Also a small landmine.

- **Render-on-disk side effect caught**: `BuildActions` renders `.tmpl` files to a sibling file (stripping the `.tmpl` suffix). That means running `quill status` has a filesystem side effect — it writes a rendered file next to the template. That rendered file got committed by accident; `6d82e74` added a `.gitignore` pattern to keep only `.tmpl` (and `.gitkeep`) files in `modules/*/files/`. Lesson: "pure analysis" commands can have side effects in this codebase — we accept that because it keeps the symlink target stable.
- **Templated gitconfig** uses `{{ .Vars.git_email }}` — the `Vars` map from the host profile. Any string in `hosts/<name>.toml`'s `[vars]` table becomes available to templates. This is the hook you'll use for per-host differences like monitor configs, usernames, etc.
- **Smoke-tested via `list` + `status`**: `quill list` prints `git  Git + global gitconfig`; `quill status` prints `git  PENDING (1/2)` (git installed, `.gitconfig` not yet applied). Actual apply is deferred until you greenlight — your existing `~/.gitconfig` points at a pre-startover path, and applying would repoint it.

---

## End of auto-generated plan (Phases 1–6 complete)

Remaining manual smoke test: run `./bin/quill apply git` (once you're ready to have it repoint `~/.gitconfig`), then re-run to confirm idempotency. `./bin/quill install` for the interactive flow. `./bin/quill path` to symlink into `~/.local/bin`.

Phase 7 in the plan is open-ended polish — add follow-up modules and extra action types as needs arise.
