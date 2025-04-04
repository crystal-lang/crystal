# Changelog

## [1.15.1] (2025-02-04)

[1.15.1]: https://github.com/crystal-lang/crystal/releases/1.15.1

### Bugfixes

#### stdlib

- *(networking)* Disable directory path redirect when `directory_listing=false` ([#15393], thanks @straight-shoota)
- *(runtime)* **[regression]** abstract `EventLoop::Polling#system_add` invalid signature ([#15380], backported from [#15358], thanks @straight-shoota)
- *(system)* **[regression]** Fix GC `sig_suspend`, `sig_resume` for `gc_none` ([#15382], backported from [#15349], thanks @ysbaddaden)

[#15393]: https://github.com/crystal-lang/crystal/pull/15393
[#15380]: https://github.com/crystal-lang/crystal/pull/15380
[#15358]: https://github.com/crystal-lang/crystal/pull/15358
[#15382]: https://github.com/crystal-lang/crystal/pull/15382
[#15349]: https://github.com/crystal-lang/crystal/pull/15349

### Documentation

#### stdlib

- *(system)* Fix code example in `Process::Status#exit_code` docs ([#15381], backported from [#15351], thanks @zw963)

[#15381]: https://github.com/crystal-lang/crystal/pull/15381
[#15351]: https://github.com/crystal-lang/crystal/pull/15351

### Infrastructure

- Changelog for 1.15.1 ([#15406], thanks @straight-shoota)
- Update distribution-scripts ([#15385], backported from [#15368], thanks @straight-shoota)
- Update distribution-scripts ([#15388], thanks @straight-shoota)
- Add backports to changelog generator ([#15402], thanks @straight-shoota)
- *(ci)* Add build shards to `mingw-w64` workflow ([#15344], thanks @straight-shoota)
- *(ci)* Update shards 0.19.1 ([#15384], backported from [#15366], thanks @straight-shoota)
- *(ci)* Add check for shards binary in `test_dist_linux_on_docker` ([#15394], thanks @straight-shoota)

[#15406]: https://github.com/crystal-lang/crystal/pull/15406
[#15385]: https://github.com/crystal-lang/crystal/pull/15385
[#15368]: https://github.com/crystal-lang/crystal/pull/15368
[#15388]: https://github.com/crystal-lang/crystal/pull/15388
[#15402]: https://github.com/crystal-lang/crystal/pull/15402
[#15344]: https://github.com/crystal-lang/crystal/pull/15344
[#15384]: https://github.com/crystal-lang/crystal/pull/15384
[#15366]: https://github.com/crystal-lang/crystal/pull/15366
[#15394]: https://github.com/crystal-lang/crystal/pull/15394

## [1.15.0] (2025-01-09)

[1.15.0]: https://github.com/crystal-lang/crystal/releases/1.15.0

### Breaking changes

#### lang

- Allow constants to start with non-ascii uppercase and titlecase ([#15148], thanks @nanobowers)

[#15148]: https://github.com/crystal-lang/crystal/pull/15148

### Features

#### lang

- *(macros)* Crystal `Not` operators do not need parens for stringification ([#15292], thanks @Blacksmoke16)
- *(macros)* Add `MacroIf#is_unless?` AST node method ([#15304], thanks @Blacksmoke16)

[#15292]: https://github.com/crystal-lang/crystal/pull/15292
[#15304]: https://github.com/crystal-lang/crystal/pull/15304

#### stdlib

- *(collection)* Add `Iterator(T).empty` ([#15039], thanks @spuun)
- *(collection)* Add `Enumerable#find_value` ([#14893], thanks @jgaskins)
- *(concurrency)* Implement the ARM64 Windows context switch ([#15155], thanks @HertzDevil)
- *(concurrency)* Add optional `name` parameter forward to `WaitGroup#spawn` ([#15189], thanks @spuun)
- *(crypto)* Enable bindings for functions in LibreSSL ([#15177], thanks @straight-shoota)
- *(log)* Add `Log` overloads for logging exceptions without giving a block ([#15257], thanks @lachlan)
- *(networking)* Better handle explicit chunked encoding responses ([#15092], thanks @Blacksmoke16)
- *(networking)* Support OpenSSL on MSYS2 ([#15111], thanks @HertzDevil)
- *(networking)* Add `Socket::Address.from` without `addrlen` ([#15060], thanks @mamantoha)
- *(networking)* Add stringification for `HTTP::Cookie` ([#15240], thanks @straight-shoota)
- *(networking)* Add stringification for `HTTP::Cookies` ([#15246], thanks @straight-shoota)
- *(networking)* Add `HTTP::Cookie#expire` ([#14819], thanks @a-alhusaini)
- *(numeric)* Implement `fast_float` for `String#to_f` ([#15195], thanks @HertzDevil)
- *(runtime)* Support call stacks for MinGW-w64 builds ([#15117], thanks @HertzDevil)
- *(runtime)* Support MSYS2's CLANGARM64 environment on ARM64 Windows ([#15159], thanks @HertzDevil)
- *(runtime)* Improve `Crystal::Tracing` ([#15297], thanks @ysbaddaden)
- *(runtime)* Add `Thread#internal_name=` ([#15298], thanks @ysbaddaden)
- *(runtime)* Add `Thread::LinkedList#each` to safely iterate lists ([#15300], thanks @ysbaddaden)
- *(system)* Add `Process::Status#exit_code?` ([#15247], thanks @straight-shoota)
- *(system)* Add `Process::Status#abnormal_exit?` ([#15266], thanks @straight-shoota)
- *(system)* Improve `Process::Status#to_s` for abnormal exits on Windows ([#15283], thanks @straight-shoota)
- *(system)* Add `Process::Status#exit_signal?` ([#15284], thanks @straight-shoota)
- *(system)* Change `Process::Status#to_s` to hex format on Windows ([#15285], thanks @straight-shoota)
- *(system)* Add `Process::Status#system_exit_status` ([#15296], thanks @straight-shoota)
- *(text)* Add `Regex::CompileOptions::MULTILINE_ONLY` ([#14870], thanks @ralsina)
- *(text)* Add type restrictions to Levenshtein ([#15168], thanks @beta-ziliani)
- *(text)* Add `unit_separator` to `Int#humanize` and `#humanize_bytes` ([#15176], thanks @CTC97)
- *(text)* Add `String#byte_index(Regex)` ([#15248], thanks @Zeljko-Predjeskovic)
- *(text)* Add `Colorize::Object#ansi_escape` ([#15113], thanks @devnote-dev)

[#15039]: https://github.com/crystal-lang/crystal/pull/15039
[#14893]: https://github.com/crystal-lang/crystal/pull/14893
[#15155]: https://github.com/crystal-lang/crystal/pull/15155
[#15189]: https://github.com/crystal-lang/crystal/pull/15189
[#15177]: https://github.com/crystal-lang/crystal/pull/15177
[#15257]: https://github.com/crystal-lang/crystal/pull/15257
[#15092]: https://github.com/crystal-lang/crystal/pull/15092
[#15111]: https://github.com/crystal-lang/crystal/pull/15111
[#15060]: https://github.com/crystal-lang/crystal/pull/15060
[#15240]: https://github.com/crystal-lang/crystal/pull/15240
[#15246]: https://github.com/crystal-lang/crystal/pull/15246
[#14819]: https://github.com/crystal-lang/crystal/pull/14819
[#15195]: https://github.com/crystal-lang/crystal/pull/15195
[#15117]: https://github.com/crystal-lang/crystal/pull/15117
[#15159]: https://github.com/crystal-lang/crystal/pull/15159
[#15297]: https://github.com/crystal-lang/crystal/pull/15297
[#15298]: https://github.com/crystal-lang/crystal/pull/15298
[#15300]: https://github.com/crystal-lang/crystal/pull/15300
[#15247]: https://github.com/crystal-lang/crystal/pull/15247
[#15266]: https://github.com/crystal-lang/crystal/pull/15266
[#15283]: https://github.com/crystal-lang/crystal/pull/15283
[#15284]: https://github.com/crystal-lang/crystal/pull/15284
[#15285]: https://github.com/crystal-lang/crystal/pull/15285
[#15296]: https://github.com/crystal-lang/crystal/pull/15296
[#14870]: https://github.com/crystal-lang/crystal/pull/14870
[#15168]: https://github.com/crystal-lang/crystal/pull/15168
[#15176]: https://github.com/crystal-lang/crystal/pull/15176
[#15248]: https://github.com/crystal-lang/crystal/pull/15248
[#15113]: https://github.com/crystal-lang/crystal/pull/15113

#### compiler

- Basic MinGW-w64 cross-compilation support ([#15070], [#15219], thanks @HertzDevil, @BlobCodes)
- *(cli)* Support building from a MinGW-w64-based compiler ([#15077], thanks @HertzDevil)
- *(codegen)* Add indirect branch tracking ([#15122], thanks @ysbaddaden)
- *(codegen)* Emit position dependent code for embedded targets ([#15174], thanks @RX14)
- *(interpreter)* Support "long format" DLL import libraries ([#15119], thanks @HertzDevil)
- *(interpreter)* Add `cc`'s search paths to Unix dynamic library loader ([#15127], thanks @HertzDevil)
- *(interpreter)* Basic MinGW-w64-based interpreter support ([#15140], thanks @HertzDevil)
- *(parser)* Add `ECR::Lexer::SyntaxException` with location info ([#15222], thanks @nobodywasishere)

[#15070]: https://github.com/crystal-lang/crystal/pull/15070
[#15219]: https://github.com/crystal-lang/crystal/pull/15219
[#15077]: https://github.com/crystal-lang/crystal/pull/15077
[#15122]: https://github.com/crystal-lang/crystal/pull/15122
[#15174]: https://github.com/crystal-lang/crystal/pull/15174
[#15119]: https://github.com/crystal-lang/crystal/pull/15119
[#15127]: https://github.com/crystal-lang/crystal/pull/15127
[#15140]: https://github.com/crystal-lang/crystal/pull/15140
[#15222]: https://github.com/crystal-lang/crystal/pull/15222

#### tools

- *(formatter)* Enable pending formatter features ([#14718], thanks @Blacksmoke16)
- *(unreachable)* Implement `codecov` format for `unreachable` tool ([#15059], thanks @Blacksmoke16)

[#14718]: https://github.com/crystal-lang/crystal/pull/14718
[#15059]: https://github.com/crystal-lang/crystal/pull/15059

### Bugfixes

#### lang

- *(macros)* Add location information to more MacroIf related nodes ([#15100], thanks @Blacksmoke16)

[#15100]: https://github.com/crystal-lang/crystal/pull/15100

#### stdlib

- LibC bindings and std specs on NetBSD 10 ([#15115], thanks @ysbaddaden)
- *(files)* Treat `WinError::ERROR_DIRECTORY` as an error for non-existent files ([#15114], thanks @HertzDevil)
- *(files)* Replace handle atomically in `IO::FileDescriptor#close` on Windows ([#15165], thanks @HertzDevil)
- *(llvm)* Fix `find-llvm-config` to ignore `LLVM_CONFIG`'s escape sequences ([#15076], thanks @HertzDevil)
- *(log)* **[regression]** Fix `Log` to emit with `exception` even if block outputs `nil` ([#15253], thanks @lachlan)
- *(macros)* Avoid identifier naming collision in `getter`, `setter`, and `property` macros ([#15239], thanks @jgaskins)
- *(networking)* **[regression]** Fix `UNIXSocket#receive` ([#15107], thanks @straight-shoota)
- *(numeric)* Fix `Complex#/` edge cases ([#15086], thanks @HertzDevil)
- *(numeric)* Fix `Number#humanize` printing of `(-)Infinity` and `NaN` ([#15090], thanks @lachlan)
- *(runtime)* Fix Deadlock with parallel stop-world/fork calls in MT ([#15096], thanks @ysbaddaden)
- *(runtime)* **[regression]** Protect constant initializers with mutex on Windows ([#15134], thanks @HertzDevil)
- *(runtime)* use `uninitialized LibC::SigsetT` ([#15144], thanks @straight-shoota)
- *(runtime)* Fix static linking when using MinGW-w64 ([#15167], thanks @HertzDevil)
- *(runtime)* register GC callbacks inside `GC.init` ([#15278], thanks @ysbaddaden)
- *(runtime)* Cleanup nodes in `Thread::LinkedList(T)#delete` ([#15295], thanks @ysbaddaden)
- *(runtime)* Make `Crystal::EventLoop#remove(io)` a class method ([#15282], thanks @ysbaddaden)
- *(system)* Raise on abnormal exit in `Procss::Status#exit_code` ([#15241], thanks @straight-shoota)
- *(system)* Fix `Process::Status` for unknown signals ([#15280], thanks @straight-shoota)
- *(system)* Fix error handling for `LibC.clock_gettime(CLOCK_MONOTONIC)` calls ([#15309], thanks @compumike)
- *(text)* Fix libiconv build on Windows ([#15095], thanks @HertzDevil)
- *(text)* Change `sprintf "%c"` to support only `Char` and `Int::Primitive` ([#15142], thanks @nanobowers)
- *(time)* Fix proper error handling for early end in `HTTP_DATE` parser ([#15232], thanks @straight-shoota)

[#15115]: https://github.com/crystal-lang/crystal/pull/15115
[#15114]: https://github.com/crystal-lang/crystal/pull/15114
[#15165]: https://github.com/crystal-lang/crystal/pull/15165
[#15076]: https://github.com/crystal-lang/crystal/pull/15076
[#15253]: https://github.com/crystal-lang/crystal/pull/15253
[#15239]: https://github.com/crystal-lang/crystal/pull/15239
[#15107]: https://github.com/crystal-lang/crystal/pull/15107
[#15086]: https://github.com/crystal-lang/crystal/pull/15086
[#15090]: https://github.com/crystal-lang/crystal/pull/15090
[#15096]: https://github.com/crystal-lang/crystal/pull/15096
[#15134]: https://github.com/crystal-lang/crystal/pull/15134
[#15144]: https://github.com/crystal-lang/crystal/pull/15144
[#15167]: https://github.com/crystal-lang/crystal/pull/15167
[#15278]: https://github.com/crystal-lang/crystal/pull/15278
[#15295]: https://github.com/crystal-lang/crystal/pull/15295
[#15282]: https://github.com/crystal-lang/crystal/pull/15282
[#15241]: https://github.com/crystal-lang/crystal/pull/15241
[#15280]: https://github.com/crystal-lang/crystal/pull/15280
[#15309]: https://github.com/crystal-lang/crystal/pull/15309
[#15095]: https://github.com/crystal-lang/crystal/pull/15095
[#15142]: https://github.com/crystal-lang/crystal/pull/15142
[#15232]: https://github.com/crystal-lang/crystal/pull/15232

#### compiler

- OpenBSD: fix integration and broken specs ([#15118], thanks @ysbaddaden)
- *(interpreter)* setup signal handlers in interpreted code ([#14766], [#15178], thanks @ysbaddaden, @straight-shoota)
- *(parser)* Fix `SyntaxHighlighter` delimiter state ([#15104], thanks @straight-shoota)
- *(parser)* Disallow weird assignments ([#14815], thanks @FnControlOption)

[#15118]: https://github.com/crystal-lang/crystal/pull/15118
[#14766]: https://github.com/crystal-lang/crystal/pull/14766
[#15178]: https://github.com/crystal-lang/crystal/pull/15178
[#15104]: https://github.com/crystal-lang/crystal/pull/15104
[#14815]: https://github.com/crystal-lang/crystal/pull/14815

#### tools

- Improve man and shell completion for tools ([#15082], thanks @Blacksmoke16)
- *(docs-generator)* Fix first doc comment inside macro yield ([#15050], thanks @RX14)
- *(implementations)* Fix `tool implementations` to handle gracefully a def with missing location ([#15273], thanks @straight-shoota)

[#15082]: https://github.com/crystal-lang/crystal/pull/15082
[#15050]: https://github.com/crystal-lang/crystal/pull/15050
[#15273]: https://github.com/crystal-lang/crystal/pull/15273

### Chores

#### stdlib

- Fix various typos ([#15080], thanks @kojix2)
- *(runtime)* Make `Enum` an abstract struct ([#15274], thanks @straight-shoota)
- *(system)* **[deprecation]** Deprecate `Process::Status#exit_status` ([#8647], thanks @jwoertink)
- *(system)* Redefine `Process::Status#normal_exit?` on Windows ([#15255], [#15267], thanks @straight-shoota)
- *(system)* **[breaking]** Redefine `Process::Status#signal_exit?` ([#15289], thanks @straight-shoota)

[#15080]: https://github.com/crystal-lang/crystal/pull/15080
[#15274]: https://github.com/crystal-lang/crystal/pull/15274
[#8647]: https://github.com/crystal-lang/crystal/pull/8647
[#15255]: https://github.com/crystal-lang/crystal/pull/15255
[#15267]: https://github.com/crystal-lang/crystal/pull/15267
[#15289]: https://github.com/crystal-lang/crystal/pull/15289

#### compiler

- *(codegen)* Link i128 constants internally if possible ([#15217], thanks @BlobCodes)
- *(parser)* Add location to `RegexLiteral` ([#15235], thanks @straight-shoota)

[#15217]: https://github.com/crystal-lang/crystal/pull/15217
[#15235]: https://github.com/crystal-lang/crystal/pull/15235

### Performance

#### stdlib

- *(collection)* Optimize `Slice#<=>` and `#==` with reference check ([#15234], thanks @straight-shoota)
- *(concurrency)* Do not over-commit fiber stacks on Windows ([#15037], thanks @HertzDevil)
- *(text)* Pre-compute `String` size after `#chomp()` if possible ([#15153], thanks @HertzDevil)
- *(text)* Optimize `String#rchop?()` ([#15175], thanks @HertzDevil)
- *(text)* Optimize `String#==` taking character size into account ([#15233], thanks @straight-shoota)

[#15234]: https://github.com/crystal-lang/crystal/pull/15234
[#15037]: https://github.com/crystal-lang/crystal/pull/15037
[#15153]: https://github.com/crystal-lang/crystal/pull/15153
[#15175]: https://github.com/crystal-lang/crystal/pull/15175
[#15233]: https://github.com/crystal-lang/crystal/pull/15233

#### compiler

- *(semantic)* Inline `ASTNode` bindings dependencies and observers ([#15098], thanks @ggiraldez)

[#15098]: https://github.com/crystal-lang/crystal/pull/15098

### Refactor

#### stdlib

- Use Win32 heap functions with `-Dgc_none` ([#15173], thanks @HertzDevil)
- *(collection)* Refactor `Enumerable#map` to delegate to `#map_with_index` ([#15210], thanks @straight-shoota)
- *(concurrency)* Drop `Crystal::FiberChannel` ([#15245], thanks @ysbaddaden)
- *(runtime)* Refactor uses of `LibC.dladdr` inside `Exception::CallStack` ([#15108], thanks @HertzDevil)
- *(runtime)* Introduce `Crystal::EventLoop` namespace ([#15226], thanks @ysbaddaden)
- *(runtime)* Change `libevent` event loop to wait forever when blocking ([#15243], thanks @ysbaddaden)
- *(runtime)* Refactor the IOCP event loop (timers, ...) ([#15238], thanks @ysbaddaden)
- *(runtime)* Explicit exit from main ([#15299], thanks @ysbaddaden)
- *(serialization)* Use per-thread libxml2 global state on all platforms ([#15121], thanks @HertzDevil)
- *(system)* Assume `getrandom` on Linux ([#15040], thanks @ysbaddaden)
- *(system)* Refactor Lifetime Event Loop ([#14996], [#15205], [#15206], [#15215], [#15301], thanks @ysbaddaden)
- *(system)* Refactor use of `Process::Status#exit_code` to `#exit_code?` ([#15254], thanks @straight-shoota)
- *(system)* Refactor simplify `Process::Status#exit_reason` on Unix ([#15288], thanks @straight-shoota)

[#15173]: https://github.com/crystal-lang/crystal/pull/15173
[#15210]: https://github.com/crystal-lang/crystal/pull/15210
[#15245]: https://github.com/crystal-lang/crystal/pull/15245
[#15108]: https://github.com/crystal-lang/crystal/pull/15108
[#15226]: https://github.com/crystal-lang/crystal/pull/15226
[#15243]: https://github.com/crystal-lang/crystal/pull/15243
[#15238]: https://github.com/crystal-lang/crystal/pull/15238
[#15299]: https://github.com/crystal-lang/crystal/pull/15299
[#15121]: https://github.com/crystal-lang/crystal/pull/15121
[#15040]: https://github.com/crystal-lang/crystal/pull/15040
[#14996]: https://github.com/crystal-lang/crystal/pull/14996
[#15205]: https://github.com/crystal-lang/crystal/pull/15205
[#15206]: https://github.com/crystal-lang/crystal/pull/15206
[#15215]: https://github.com/crystal-lang/crystal/pull/15215
[#15301]: https://github.com/crystal-lang/crystal/pull/15301
[#15254]: https://github.com/crystal-lang/crystal/pull/15254
[#15288]: https://github.com/crystal-lang/crystal/pull/15288

#### compiler

- *(semantic)* Replace uses of `AliasType#types?` by `Type#lookup_name` ([#15068], thanks @straight-shoota)

[#15068]: https://github.com/crystal-lang/crystal/pull/15068

### Documentation

#### stdlib

- Add docs for lib bindings with supported library versions ([#14900], [#15198], thanks @straight-shoota)
- *(concurrency)* Make `Fiber.timeout` and `.cancel_timeout` nodoc ([#15184], thanks @straight-shoota)
- *(concurrency)* Update example code for `::spawn` with `WaitGroup` ([#15191], thanks @BigBoyBarney)
- *(numeric)* Clarify behavior of `strict` for `String`-to-number conversions ([#15199], thanks @HertzDevil)
- *(runtime)* Make `Box` constructor and `object` getter nodoc ([#15136], thanks @straight-shoota)
- *(runtime)* Fix `EventLoop` docs for `Socket` `read`, `write` ([#15194], thanks @straight-shoota)
- *(system)* Add example for `Dir.glob` ([#15171], thanks @BigBoyBarney)
- *(system)* Adjust definition of `ExitReason::Aborted` ([#15256], thanks @straight-shoota)
- *(text)* Improve docs for `String#rindex!` ([#15132], thanks @BigBoyBarney)
- *(text)* Add note about locale-dependent system error messages ([#15196], thanks @HertzDevil)

[#14900]: https://github.com/crystal-lang/crystal/pull/14900
[#15198]: https://github.com/crystal-lang/crystal/pull/15198
[#15184]: https://github.com/crystal-lang/crystal/pull/15184
[#15191]: https://github.com/crystal-lang/crystal/pull/15191
[#15199]: https://github.com/crystal-lang/crystal/pull/15199
[#15136]: https://github.com/crystal-lang/crystal/pull/15136
[#15194]: https://github.com/crystal-lang/crystal/pull/15194
[#15171]: https://github.com/crystal-lang/crystal/pull/15171
[#15256]: https://github.com/crystal-lang/crystal/pull/15256
[#15132]: https://github.com/crystal-lang/crystal/pull/15132
[#15196]: https://github.com/crystal-lang/crystal/pull/15196

### Specs

#### stdlib

- Fix failing specs on FreeBSD ([#15093], thanks @ysbaddaden)
- Disable specs that break on MinGW-w64 ([#15116], thanks @HertzDevil)
- *(networking)* DragonFlyBSD: std specs fixes + pending ([#15152], thanks @ysbaddaden)
- *(networking)* Close some dangling sockets in specs ([#15163], thanks @HertzDevil)
- *(networking)* Update specs to run with IPv6 support disabled ([#15046], thanks @Blacksmoke16)
- *(networking)* Add specs for invalid special characters in `Cookie` ([#15244], thanks @straight-shoota)
- *(system)* Improve `System::User` specs on Windows ([#15156], thanks @HertzDevil)
- *(system)* Make `cmd.exe` drop `%PROCESSOR_ARCHITECTURE%` in `Process` specs ([#15158], thanks @HertzDevil)
- *(system)* Add specs for signal exit ([#15229], thanks @straight-shoota)

[#15093]: https://github.com/crystal-lang/crystal/pull/15093
[#15116]: https://github.com/crystal-lang/crystal/pull/15116
[#15152]: https://github.com/crystal-lang/crystal/pull/15152
[#15163]: https://github.com/crystal-lang/crystal/pull/15163
[#15046]: https://github.com/crystal-lang/crystal/pull/15046
[#15244]: https://github.com/crystal-lang/crystal/pull/15244
[#15156]: https://github.com/crystal-lang/crystal/pull/15156
[#15158]: https://github.com/crystal-lang/crystal/pull/15158
[#15229]: https://github.com/crystal-lang/crystal/pull/15229

#### compiler

- *(cli)* Remove the entire compiler code base from `external_command_spec` ([#15208], thanks @straight-shoota)
- *(interpreter)* **[regression]** Fix `Crystal::Loader.default_search_paths` spec for macOS ([#15135], thanks @HertzDevil)

[#15208]: https://github.com/crystal-lang/crystal/pull/15208
[#15135]: https://github.com/crystal-lang/crystal/pull/15135

#### tools

- Use empty prelude for compiler tools specs ([#15272], thanks @straight-shoota)
- *(docs-generator)* Allow skipping compiler tool specs that require Git ([#15125], thanks @HertzDevil)

[#15272]: https://github.com/crystal-lang/crystal/pull/15272
[#15125]: https://github.com/crystal-lang/crystal/pull/15125

### Infrastructure

- Changelog for 1.15.0 ([#15277], thanks @straight-shoota)
- Update previous Crystal release 1.14.0 ([#15071], thanks @straight-shoota)
- Fix remove trailing whitespace from CRYSTAL definition ([#15131], thanks @straight-shoota)
- Make utilities posix compatible ([#15139], thanks @nanobowers)
- Update `shell.nix` to `nixpkgs-24.05` and LLVM 18 ([#14651], thanks @straight-shoota)
- Makefile: Allow custom extensions for exports and spec flags ([#15099], thanks @straight-shoota)
- Merge changelog entries for fixups with main PR ([#15207], thanks @straight-shoota)
- Update link to good first issues ([#15250], thanks @BigBoyBarney)
- Update distribution-scripts ([#15291], thanks @straight-shoota)
- Bump NOTICE copyright year ([#15318], thanks @straight-shoota)
- Merge `release/1.14`@1.14.1 ([#15329], thanks @straight-shoota)
- Update distribution-scripts ([#15332], thanks @straight-shoota)
- Make `bin/crystal` work on MSYS2 ([#15094], thanks @HertzDevil)
- Make `Makefile` work on MSYS2 ([#15102], thanks @HertzDevil)
- Support `.exe` file extension in `Makefile` on MSYS2 ([#15123], thanks @HertzDevil)
- Support dereferencing symlinks in `make install` ([#15138], thanks @HertzDevil)
- *(ci)* Extract `deploy_api_docs` job into its own Workflow ([#15022], thanks @straight-shoota)
- *(ci)* Remove pin for ancient nix version ([#15150], thanks @straight-shoota)
- *(ci)* Migrate renovate config ([#15151], thanks @renovate)
- *(ci)* Update GH Actions ([#15052], thanks @renovate)
- *(ci)* Update msys2/setup-msys2 action to v2.26.0 ([#15265], thanks @renovate)
- *(ci)* Update shards 0.19.0 ([#15290], thanks @straight-shoota)
- *(ci)* **[security]** Restrict GitHub token permissions of CI workflows ([#15087], thanks @HertzDevil)
- *(ci)* Do not link against `DbgHelp` for MinGW-w64 CI build ([#15160], thanks @HertzDevil)
- *(ci)* Use MSYS2's upstream LLVM version on MinGW-w64 CI ([#15197], thanks @HertzDevil)
- *(ci)* Add CI workflow for cross-compiling Crystal on MSYS2 ([#15110], thanks @HertzDevil)
- *(ci)* Add MinGW-w64 CI workflow for stdlib and compiler specs ([#15124], thanks @HertzDevil)
- *(ci)* Make MinGW-w64 build artifact a full installation ([#15204], thanks @HertzDevil)
- *(ci)* Use official Apt respositories for LLVM CI ([#15103], thanks @HertzDevil)
- *(ci)* Drop LLVM Apt installer script on WebAssembly CI ([#15109], thanks @HertzDevil)
- *(ci)* Run interpreter specs on Windows CI ([#15141], thanks @HertzDevil)

[#15277]: https://github.com/crystal-lang/crystal/pull/15277
[#15071]: https://github.com/crystal-lang/crystal/pull/15071
[#15131]: https://github.com/crystal-lang/crystal/pull/15131
[#15139]: https://github.com/crystal-lang/crystal/pull/15139
[#14651]: https://github.com/crystal-lang/crystal/pull/14651
[#15099]: https://github.com/crystal-lang/crystal/pull/15099
[#15207]: https://github.com/crystal-lang/crystal/pull/15207
[#15250]: https://github.com/crystal-lang/crystal/pull/15250
[#15291]: https://github.com/crystal-lang/crystal/pull/15291
[#15318]: https://github.com/crystal-lang/crystal/pull/15318
[#15329]: https://github.com/crystal-lang/crystal/pull/15329
[#15332]: https://github.com/crystal-lang/crystal/pull/15332
[#15094]: https://github.com/crystal-lang/crystal/pull/15094
[#15102]: https://github.com/crystal-lang/crystal/pull/15102
[#15123]: https://github.com/crystal-lang/crystal/pull/15123
[#15138]: https://github.com/crystal-lang/crystal/pull/15138
[#15022]: https://github.com/crystal-lang/crystal/pull/15022
[#15150]: https://github.com/crystal-lang/crystal/pull/15150
[#15151]: https://github.com/crystal-lang/crystal/pull/15151
[#15052]: https://github.com/crystal-lang/crystal/pull/15052
[#15265]: https://github.com/crystal-lang/crystal/pull/15265
[#15290]: https://github.com/crystal-lang/crystal/pull/15290
[#15087]: https://github.com/crystal-lang/crystal/pull/15087
[#15160]: https://github.com/crystal-lang/crystal/pull/15160
[#15197]: https://github.com/crystal-lang/crystal/pull/15197
[#15110]: https://github.com/crystal-lang/crystal/pull/15110
[#15124]: https://github.com/crystal-lang/crystal/pull/15124
[#15204]: https://github.com/crystal-lang/crystal/pull/15204
[#15103]: https://github.com/crystal-lang/crystal/pull/15103
[#15109]: https://github.com/crystal-lang/crystal/pull/15109
[#15141]: https://github.com/crystal-lang/crystal/pull/15141

## Previous Releases

For information on prior releases, refer to their changelogs:

* [1.0 to 1.15](https://github.com/crystal-lang/crystal/blob/release/1.15/CHANGELOG.md)
* [before 1.0](https://github.com/crystal-lang/crystal/blob/release/0.36/CHANGELOG.md)
