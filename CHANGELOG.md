# Changelog

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

## [1.14.1] (2025-01-08)

[1.14.1]: https://github.com/crystal-lang/crystal/releases/1.14.1

### Bugfixes

#### tools

- *(formatter)* Handle trailing comma with multiple parameters on the same line ([#15097], thanks @Blacksmoke16)

[#15097]: https://github.com/crystal-lang/crystal/pull/15097

### Infrastructure

- Changelog for 1.14.1 ([#15323], thanks @straight-shoota)
- *(ci)* Update XCode 15.3.0 in circleci ([#15327], thanks @straight-shoota)

[#15323]: https://github.com/crystal-lang/crystal/pull/15323
[#15327]: https://github.com/crystal-lang/crystal/pull/15327

## [1.14.0] (2024-10-09)

[1.14.0]: https://github.com/crystal-lang/crystal/releases/1.14.0

### Features

#### lang

- Allow `^` in constant numeric expressions ([#14951], thanks @HertzDevil)

[#14951]: https://github.com/crystal-lang/crystal/pull/14951

#### stdlib

- Add support for Windows on aarch64 ([#14911], thanks @HertzDevil)
- *(collection)* **[breaking]** Add support for negative start index in `Slice#[start, count]` ([#14778], thanks @ysbaddaden)
- *(collection)* Add `Slice#same?` ([#14728], thanks @straight-shoota)
- *(concurrency)* Add `WaitGroup.wait` and `WaitGroup#spawn` ([#14837], thanks @jgaskins)
- *(concurrency)* Open non-blocking regular files as overlapped on Windows ([#14921], thanks @HertzDevil)
- *(concurrency)* Support non-blocking `File#read` and `#write` on Windows ([#14940], thanks @HertzDevil)
- *(concurrency)* Support non-blocking `File#read_at` on Windows ([#14958], thanks @HertzDevil)
- *(concurrency)* Support non-blocking `Process.run` standard streams on Windows ([#14941], thanks @HertzDevil)
- *(concurrency)* Support `IO::FileDescriptor#flock_*` on non-blocking files on Windows ([#14943], thanks @HertzDevil)
- *(concurrency)* Emulate non-blocking `STDIN` console on Windows ([#14947], thanks @HertzDevil)
- *(concurrency)* Async DNS resolution on Windows ([#14979], thanks @HertzDevil)
- *(crypto)* Update `LibCrypto` bindings for LibreSSL 3.5+ ([#14872], thanks @straight-shoota)
- *(llvm)* Expose LLVM instruction builder for `neg` and `fneg` ([#14774], thanks @JarnaChao09)
- *(llvm)* **[experimental]** Add minimal LLVM OrcV2 bindings ([#14887], thanks @HertzDevil)
- *(llvm)* Add `LLVM::Builder#finalize` ([#14892], thanks @JarnaChao09)
- *(llvm)* Support LLVM 19.1 ([#14842], thanks @HertzDevil)
- *(macros)* Add `Crystal::Macros::TypeNode#has_inner_pointers?` ([#14847], thanks @HertzDevil)
- *(macros)* Add `HashLiteral#has_key?` and `NamedTupleLiteral#has_key?` ([#14890], thanks @kamil-gwozdz)
- *(numeric)* Implement floating-point manipulation functions for `BigFloat` ([#11007], thanks @HertzDevil)
- *(runtime)* Stop & start the world (undocumented API) ([#14729], thanks @ysbaddaden)
- *(runtime)* Add `Pointer::Appender#to_slice` ([#14874], thanks @straight-shoota)
- *(serialization)* Add `URI.from_json_object_key?` and `URI#to_json_object_key` ([#14834], thanks @nobodywasishere)
- *(serialization)* Add `URI::Params::Serializable` ([#14684], thanks @Blacksmoke16)
- *(system)* Enable full backtrace for exception in process spawn ([#14796], thanks @straight-shoota)
- *(system)* Implement `System::User` on Windows ([#14933], thanks @HertzDevil)
- *(system)* Implement `System::Group` on Windows ([#14945], thanks @HertzDevil)
- *(system)* Add methods to `Crystal::EventLoop` ([#14977], thanks @ysbaddaden)
- *(text)* Add `underscore_to_space` option to `String#titleize` ([#14822], thanks @Blacksmoke16)
- *(text)* Support Unicode 16.0.0 ([#14997], thanks @HertzDevil)

[#14911]: https://github.com/crystal-lang/crystal/pull/14911
[#14778]: https://github.com/crystal-lang/crystal/pull/14778
[#14728]: https://github.com/crystal-lang/crystal/pull/14728
[#14837]: https://github.com/crystal-lang/crystal/pull/14837
[#14921]: https://github.com/crystal-lang/crystal/pull/14921
[#14940]: https://github.com/crystal-lang/crystal/pull/14940
[#14958]: https://github.com/crystal-lang/crystal/pull/14958
[#14941]: https://github.com/crystal-lang/crystal/pull/14941
[#14943]: https://github.com/crystal-lang/crystal/pull/14943
[#14947]: https://github.com/crystal-lang/crystal/pull/14947
[#14979]: https://github.com/crystal-lang/crystal/pull/14979
[#14872]: https://github.com/crystal-lang/crystal/pull/14872
[#14774]: https://github.com/crystal-lang/crystal/pull/14774
[#14887]: https://github.com/crystal-lang/crystal/pull/14887
[#14892]: https://github.com/crystal-lang/crystal/pull/14892
[#14842]: https://github.com/crystal-lang/crystal/pull/14842
[#14847]: https://github.com/crystal-lang/crystal/pull/14847
[#14890]: https://github.com/crystal-lang/crystal/pull/14890
[#11007]: https://github.com/crystal-lang/crystal/pull/11007
[#14729]: https://github.com/crystal-lang/crystal/pull/14729
[#14874]: https://github.com/crystal-lang/crystal/pull/14874
[#14834]: https://github.com/crystal-lang/crystal/pull/14834
[#14684]: https://github.com/crystal-lang/crystal/pull/14684
[#14796]: https://github.com/crystal-lang/crystal/pull/14796
[#14933]: https://github.com/crystal-lang/crystal/pull/14933
[#14945]: https://github.com/crystal-lang/crystal/pull/14945
[#14977]: https://github.com/crystal-lang/crystal/pull/14977
[#14822]: https://github.com/crystal-lang/crystal/pull/14822
[#14997]: https://github.com/crystal-lang/crystal/pull/14997

#### compiler

- *(cli)* Adds initial support for external commands ([#14953], thanks @bcardiff)
- *(interpreter)* Add `Crystal::Repl::Value#runtime_type` ([#14156], thanks @bcardiff)
- *(interpreter)* Implement `Reference.pre_initialize` in the interpreter ([#14968], thanks @HertzDevil)
- *(interpreter)* Enable the interpreter on Windows ([#14964], thanks @HertzDevil)

[#14953]: https://github.com/crystal-lang/crystal/pull/14953
[#14156]: https://github.com/crystal-lang/crystal/pull/14156
[#14968]: https://github.com/crystal-lang/crystal/pull/14968
[#14964]: https://github.com/crystal-lang/crystal/pull/14964

### Bugfixes

#### lang

- Fix `Slice.literal` for multiple calls with identical signature ([#15009], thanks @HertzDevil)
- *(macros)* Add location info to some `MacroIf` nodes ([#14885], thanks @Blacksmoke16)

[#15009]: https://github.com/crystal-lang/crystal/pull/15009
[#14885]: https://github.com/crystal-lang/crystal/pull/14885

#### stdlib

- *(collection)* Fix `Range#size` return type to `Int32` ([#14588], thanks @straight-shoota)
- *(concurrency)* Update `DeallocationStack` for Windows context switch ([#15032], thanks @HertzDevil)
- *(concurrency)* Fix race condition in `pthread_create` handle initialization ([#15043], thanks @HertzDevil)
- *(files)* **[regression]** Fix `File#truncate` and `#lock` for Win32 append-mode files ([#14706], thanks @HertzDevil)
- *(files)* **[breaking]** Avoid flush in finalizers for `Socket` and `IO::FileDescriptor` ([#14882], thanks @straight-shoota)
- *(files)* Make `IO::Buffered#buffer_size=` idempotent ([#14855], thanks @jgaskins)
- *(macros)* Implement `#sort_by` inside macros using `Enumerable#sort_by` ([#14895], thanks @HertzDevil)
- *(macros)* Fix internal error when calling `#is_a?` on `External` nodes ([#14918], thanks @HertzDevil)
- *(networking)* Use correct timeout for `Socket#connect` on Windows ([#14961], thanks @HertzDevil)
- *(numeric)* Fix handle empty string in `String#to_f(whitespace: false)` ([#14902], thanks @Blacksmoke16)
- *(numeric)* Fix exponent wrapping in `Math.frexp(BigFloat)` for very large values ([#14971], thanks @HertzDevil)
- *(numeric)* Fix exponent overflow in `BigFloat#to_s` for very large values ([#14982], thanks @HertzDevil)
- *(numeric)* Add missing `@[Link(dll:)]` annotation to MPIR ([#15003], thanks @HertzDevil)
- *(runtime)* Add missing return type of `LibC.VirtualQuery` ([#15036], thanks @HertzDevil)
- *(runtime)* Fix main stack top detection on musl-libc ([#15047], thanks @HertzDevil)
- *(serialization)* **[breaking]** Remove `XML::Error.errors` ([#14936], thanks @straight-shoota)
- *(specs)* **[regression]** Fix `Expectations::Be` for module type ([#14926], thanks @straight-shoota)
- *(system)* Fix return type restriction for `ENV.fetch` ([#14919], thanks @straight-shoota)
- *(system)* `#file_descriptor_close` should set `@closed` (UNIX) ([#14973], thanks @ysbaddaden)
- *(system)* reinit event loop first after fork (UNIX) ([#14975], thanks @ysbaddaden)
- *(text)* Fix avoid linking `libpcre` when unused ([#14891], thanks @kojix2)
- *(text)* Add type restriction to `String#byte_index` `offset` parameter ([#14981], thanks @straight-shoota)

[#14588]: https://github.com/crystal-lang/crystal/pull/14588
[#15032]: https://github.com/crystal-lang/crystal/pull/15032
[#15043]: https://github.com/crystal-lang/crystal/pull/15043
[#14706]: https://github.com/crystal-lang/crystal/pull/14706
[#14882]: https://github.com/crystal-lang/crystal/pull/14882
[#14855]: https://github.com/crystal-lang/crystal/pull/14855
[#14895]: https://github.com/crystal-lang/crystal/pull/14895
[#14918]: https://github.com/crystal-lang/crystal/pull/14918
[#14961]: https://github.com/crystal-lang/crystal/pull/14961
[#14902]: https://github.com/crystal-lang/crystal/pull/14902
[#14971]: https://github.com/crystal-lang/crystal/pull/14971
[#14982]: https://github.com/crystal-lang/crystal/pull/14982
[#15003]: https://github.com/crystal-lang/crystal/pull/15003
[#15036]: https://github.com/crystal-lang/crystal/pull/15036
[#15047]: https://github.com/crystal-lang/crystal/pull/15047
[#14936]: https://github.com/crystal-lang/crystal/pull/14936
[#14926]: https://github.com/crystal-lang/crystal/pull/14926
[#14919]: https://github.com/crystal-lang/crystal/pull/14919
[#14973]: https://github.com/crystal-lang/crystal/pull/14973
[#14975]: https://github.com/crystal-lang/crystal/pull/14975
[#14891]: https://github.com/crystal-lang/crystal/pull/14891
[#14981]: https://github.com/crystal-lang/crystal/pull/14981

#### compiler

- *(cli)* Add error handling for linker flag sub commands ([#14932], thanks @straight-shoota)
- *(codegen)* Allow returning `Proc`s from top-level funs ([#14917], thanks @HertzDevil)
- *(codegen)* Fix CRT static-dynamic linking conflict in specs with C sources ([#14970], thanks @HertzDevil)
- *(interpreter)* Fix Linux `getrandom` failure in interpreted code ([#15035], thanks @HertzDevil)
- *(interpreter)* Fix undefined behavior in interpreter mixed union upcast ([#15042], thanks @HertzDevil)
- *(semantic)* Fix `TopLevelVisitor` adding existing `ClassDef` type to current scope ([#15067], thanks @straight-shoota)

[#14932]: https://github.com/crystal-lang/crystal/pull/14932
[#14917]: https://github.com/crystal-lang/crystal/pull/14917
[#14970]: https://github.com/crystal-lang/crystal/pull/14970
[#15035]: https://github.com/crystal-lang/crystal/pull/15035
[#15042]: https://github.com/crystal-lang/crystal/pull/15042
[#15067]: https://github.com/crystal-lang/crystal/pull/15067

#### tools

- *(dependencies)* Fix `crystal tool dependencies` format flat ([#14927], thanks @straight-shoota)
- *(dependencies)* Fix `crystal tool dependencies` filters for Windows paths ([#14928], thanks @straight-shoota)
- *(docs-generator)* Fix doc comment above annotation with macro expansion ([#14849], thanks @Blacksmoke16)
- *(unreachable)* Fix `crystal tool unreachable` & co visiting circular hierarchies ([#15065], thanks @straight-shoota)

[#14927]: https://github.com/crystal-lang/crystal/pull/14927
[#14928]: https://github.com/crystal-lang/crystal/pull/14928
[#14849]: https://github.com/crystal-lang/crystal/pull/14849
[#15065]: https://github.com/crystal-lang/crystal/pull/15065

### Chores

#### stdlib

- **[deprecation]** Use `Time::Span` in `Benchmark.ips` ([#14805], thanks @HertzDevil)
- **[deprecation]** Deprecate `::sleep(Number)` ([#14962], thanks @HertzDevil)
- *(runtime)* **[deprecation]** Deprecate `Pointer.new(Int)` ([#14875], thanks @straight-shoota)

[#14805]: https://github.com/crystal-lang/crystal/pull/14805
[#14962]: https://github.com/crystal-lang/crystal/pull/14962
[#14875]: https://github.com/crystal-lang/crystal/pull/14875

#### compiler

- *(interpreter)* Remove TODO in `Crystal::Loader` on Windows ([#14988], thanks @HertzDevil)
- *(interpreter:repl)* Update REPLy version ([#14950], thanks @HertzDevil)

[#14988]: https://github.com/crystal-lang/crystal/pull/14988
[#14950]: https://github.com/crystal-lang/crystal/pull/14950

### Performance

#### stdlib

- *(collection)* Always use unstable sort for simple types ([#14825], thanks @HertzDevil)
- *(collection)* Optimize `Hash#transform_{keys,values}` ([#14502], thanks @jgaskins)
- *(numeric)* Optimize arithmetic between `BigFloat` and integers ([#14944], thanks @HertzDevil)
- *(runtime)* **[regression]** Cache `Exception::CallStack.empty` to avoid repeat `Array` allocation ([#15025], thanks @straight-shoota)

[#14825]: https://github.com/crystal-lang/crystal/pull/14825
[#14502]: https://github.com/crystal-lang/crystal/pull/14502
[#14944]: https://github.com/crystal-lang/crystal/pull/14944
[#15025]: https://github.com/crystal-lang/crystal/pull/15025

#### compiler

- Avoid unwinding the stack on hot path in method call lookups ([#15002], thanks @ggiraldez)
- *(codegen)* Reduce calls to `Crystal::Type#remove_indirection` in module dispatch ([#14992], thanks @HertzDevil)
- *(codegen)* Compiler: enable parallel codegen with MT ([#14748], thanks @ysbaddaden)

[#15002]: https://github.com/crystal-lang/crystal/pull/15002
[#14992]: https://github.com/crystal-lang/crystal/pull/14992
[#14748]: https://github.com/crystal-lang/crystal/pull/14748

### Refactor

#### stdlib

- *(concurrency)* Extract `select` from `src/channel.cr` ([#14912], thanks @straight-shoota)
- *(concurrency)* Make `Crystal::IOCP::OverlappedOperation` abstract ([#14987], thanks @HertzDevil)
- *(files)* Move `#evented_read`, `#evented_write` into `Crystal::LibEvent::EventLoop` ([#14883], thanks @straight-shoota)
- *(networking)* Simplify `Socket::Addrinfo.getaddrinfo(&)` ([#14956], thanks @HertzDevil)
- *(networking)* Add `Crystal::System::Addrinfo` ([#14957], thanks @HertzDevil)
- *(runtime)* Add `Exception::CallStack.empty` ([#15017], thanks @straight-shoota)
- *(system)* Refactor cancellation of `IOCP::OverlappedOperation` ([#14754], thanks @straight-shoota)
- *(system)* Include `Crystal::System::Group` instead of extending it ([#14930], thanks @HertzDevil)
- *(system)* Include `Crystal::System::User` instead of extending it ([#14929], thanks @HertzDevil)
- *(system)* Fix: `Crystal::SpinLock` doesn't need to be allocated on the HEAP ([#14972], thanks @ysbaddaden)
- *(system)* Don't involve evloop after fork in `System::Process.spawn` (UNIX) ([#14974], thanks @ysbaddaden)
- *(system)* Refactor `EventLoop` interface for sleeps & select timeouts ([#14980], thanks @ysbaddaden)

[#14912]: https://github.com/crystal-lang/crystal/pull/14912
[#14987]: https://github.com/crystal-lang/crystal/pull/14987
[#14883]: https://github.com/crystal-lang/crystal/pull/14883
[#14956]: https://github.com/crystal-lang/crystal/pull/14956
[#14957]: https://github.com/crystal-lang/crystal/pull/14957
[#15017]: https://github.com/crystal-lang/crystal/pull/15017
[#14754]: https://github.com/crystal-lang/crystal/pull/14754
[#14930]: https://github.com/crystal-lang/crystal/pull/14930
[#14929]: https://github.com/crystal-lang/crystal/pull/14929
[#14972]: https://github.com/crystal-lang/crystal/pull/14972
[#14974]: https://github.com/crystal-lang/crystal/pull/14974
[#14980]: https://github.com/crystal-lang/crystal/pull/14980

#### compiler

- *(codegen)* Compiler: refactor codegen ([#14760], thanks @ysbaddaden)
- *(interpreter)* Refactor interpreter stack code to avoid duplicate macro expansion ([#14876], thanks @straight-shoota)

[#14760]: https://github.com/crystal-lang/crystal/pull/14760
[#14876]: https://github.com/crystal-lang/crystal/pull/14876

### Documentation

#### stdlib

- *(collection)* **[breaking]** Hide `Hash::Entry` from public API docs ([#14881], thanks @Blacksmoke16)
- *(collection)* Fix typos in docs for `Set` and `Hash` ([#14889], thanks @philipp-classen)
- *(llvm)* Add `@[Experimental]` to `LLVM::DIBuilder` ([#14854], thanks @HertzDevil)
- *(networking)* Add documentation about synchronous DNS resolution ([#15027], thanks @straight-shoota)
- *(networking)* Add `uri/json` to `docs_main` ([#15069], thanks @straight-shoota)
- *(runtime)* Add docs about `Pointer`'s alignment requirement ([#14853], thanks @HertzDevil)
- *(runtime)* Reword `Pointer#memcmp`'s documentation ([#14818], thanks @HertzDevil)
- *(runtime)* Add documentation for `NoReturn` and `Void` ([#14817], thanks @nobodywasishere)

[#14881]: https://github.com/crystal-lang/crystal/pull/14881
[#14889]: https://github.com/crystal-lang/crystal/pull/14889
[#14854]: https://github.com/crystal-lang/crystal/pull/14854
[#15027]: https://github.com/crystal-lang/crystal/pull/15027
[#15069]: https://github.com/crystal-lang/crystal/pull/15069
[#14853]: https://github.com/crystal-lang/crystal/pull/14853
[#14818]: https://github.com/crystal-lang/crystal/pull/14818
[#14817]: https://github.com/crystal-lang/crystal/pull/14817

### Specs

#### stdlib

- Remove some uses of deprecated overloads in standard library specs ([#14963], thanks @HertzDevil)
- *(collection)* Disable `Tuple#to_static_array` spec on AArch64 ([#14844], thanks @HertzDevil)
- *(serialization)* Add JSON parsing UTF-8 spec ([#14823], thanks @Blacksmoke16)
- *(text)* Add specs for `String#index`, `#rindex` search for `Char::REPLACEMENT` ([#14946], thanks @straight-shoota)

[#14963]: https://github.com/crystal-lang/crystal/pull/14963
[#14844]: https://github.com/crystal-lang/crystal/pull/14844
[#14823]: https://github.com/crystal-lang/crystal/pull/14823
[#14946]: https://github.com/crystal-lang/crystal/pull/14946

#### compiler

- *(codegen)* Support return types in codegen specs ([#14888], thanks @HertzDevil)
- *(codegen)* Fix codegen spec for `ProcPointer` of virtual type ([#14903], thanks @HertzDevil)
- *(codegen)* Support LLVM OrcV2 codegen specs ([#14886], thanks @HertzDevil)
- *(codegen)* Don't spawn subprocess if codegen spec uses flags but not the prelude ([#14904], thanks @HertzDevil)

[#14888]: https://github.com/crystal-lang/crystal/pull/14888
[#14903]: https://github.com/crystal-lang/crystal/pull/14903
[#14886]: https://github.com/crystal-lang/crystal/pull/14886
[#14904]: https://github.com/crystal-lang/crystal/pull/14904

### Infrastructure

- Changelog for 1.14.0 ([#14969], thanks @straight-shoota)
- Update previous Crystal release 1.13.1 ([#14810], thanks @straight-shoota)
- Refactor GitHub changelog generator print special infra ([#14795], thanks @straight-shoota)
- Update distribution-scripts ([#14877], thanks @straight-shoota)
- Update version in `shard.yml` ([#14909], thanks @straight-shoota)
- Merge `release/1.13`@1.13.2 ([#14924], thanks @straight-shoota)
- Update previous Crystal release 1.13.2 ([#14925], thanks @straight-shoota)
- Merge `release/1.13`@1.13.3 ([#15012], thanks @straight-shoota)
- Update previous Crystal release 1.13.3 ([#15016], thanks @straight-shoota)
- **[regression]** Fix `SOURCE_DATE_EPOCH` in `Makefile.win` ([#14922], thanks @HertzDevil)
- *(ci)* Update actions/checkout action to v4 - autoclosed ([#14896], thanks @renovate)
- *(ci)* Update LLVM 18 for `wasm32-test` ([#14821], thanks @straight-shoota)
- *(ci)* Pin package repos for OpenSSL packages ([#14831], thanks @straight-shoota)
- *(ci)* Upgrade XCode 15.4.0 ([#14794], thanks @straight-shoota)
- *(ci)* Update GH Actions ([#14535], thanks @renovate)
- *(ci)* Add test for OpenSSL 3.3 ([#14873], thanks @straight-shoota)
- *(ci)* Update GitHub runner to `macos-14` ([#14833], thanks @straight-shoota)
- *(ci)* Refactor SSL workflow with job matrix ([#14899], thanks @straight-shoota)
- *(ci)* Drop the non-release Windows compiler artifact ([#15000], thanks @HertzDevil)
- *(ci)* Fix compiler artifact name in WindowsCI ([#15021], thanks @straight-shoota)
- *(ci)* Restrict CI runners from runs-on to 8GB ([#15030], thanks @straight-shoota)
- *(ci)* Increase memory for stdlib CI runners from runs-on to 16GB ([#15044], thanks @straight-shoota)
- *(ci)* Use Cygwin to build libiconv on Windows CI ([#14999], thanks @HertzDevil)
- *(ci)* Use our own `libffi` repository on Windows CI ([#14998], thanks @HertzDevil)

[#14969]: https://github.com/crystal-lang/crystal/pull/14969
[#14810]: https://github.com/crystal-lang/crystal/pull/14810
[#14795]: https://github.com/crystal-lang/crystal/pull/14795
[#14877]: https://github.com/crystal-lang/crystal/pull/14877
[#14909]: https://github.com/crystal-lang/crystal/pull/14909
[#14924]: https://github.com/crystal-lang/crystal/pull/14924
[#14925]: https://github.com/crystal-lang/crystal/pull/14925
[#15012]: https://github.com/crystal-lang/crystal/pull/15012
[#15016]: https://github.com/crystal-lang/crystal/pull/15016
[#14922]: https://github.com/crystal-lang/crystal/pull/14922
[#14896]: https://github.com/crystal-lang/crystal/pull/14896
[#14821]: https://github.com/crystal-lang/crystal/pull/14821
[#14831]: https://github.com/crystal-lang/crystal/pull/14831
[#14794]: https://github.com/crystal-lang/crystal/pull/14794
[#14535]: https://github.com/crystal-lang/crystal/pull/14535
[#14873]: https://github.com/crystal-lang/crystal/pull/14873
[#14833]: https://github.com/crystal-lang/crystal/pull/14833
[#14899]: https://github.com/crystal-lang/crystal/pull/14899
[#15000]: https://github.com/crystal-lang/crystal/pull/15000
[#15021]: https://github.com/crystal-lang/crystal/pull/15021
[#15030]: https://github.com/crystal-lang/crystal/pull/15030
[#15044]: https://github.com/crystal-lang/crystal/pull/15044
[#14999]: https://github.com/crystal-lang/crystal/pull/14999
[#14998]: https://github.com/crystal-lang/crystal/pull/14998

## [1.13.3] (2024-09-18)

[1.13.3]: https://github.com/crystal-lang/crystal/releases/1.13.3

### Bugfixes

#### stdlib

- **[regression]** Fix use global paths in macro bodies ([#14965], thanks @straight-shoota)
- *(system)* **[regression]** Fix `Process.exec` stream redirection on Windows ([#14986], thanks @HertzDevil)
- *(text)* **[regression]** Fix `String#index` and `#rindex` for `Char::REPLACEMENT` ([#14937], thanks @HertzDevil)

[#14965]: https://github.com/crystal-lang/crystal/pull/14965
[#14986]: https://github.com/crystal-lang/crystal/pull/14986
[#14937]: https://github.com/crystal-lang/crystal/pull/14937

### Infrastructure

- Changelog for 1.13.3 ([#14991], thanks @straight-shoota)
- *(ci)* Enable runners from `runs-on.com` for Aarch64 CI ([#15007], thanks @straight-shoota)

[#14991]: https://github.com/crystal-lang/crystal/pull/14991
[#15007]: https://github.com/crystal-lang/crystal/pull/15007

## [1.13.2] (2024-08-20)

[1.13.2]: https://github.com/crystal-lang/crystal/releases/1.13.2

### Bugfixes

#### stdlib

- *(collection)* Fix explicitly clear deleted `Hash::Entry` ([#14862], thanks @HertzDevil)

[#14862]: https://github.com/crystal-lang/crystal/pull/14862

#### compiler

- *(codegen)* Fix `ReferenceStorage(T)` atomic if `T` has no inner pointers ([#14845], thanks @HertzDevil)
- *(codegen)* Fix misaligned store in `Bool` to union upcasts ([#14906], thanks @HertzDevil)
- *(interpreter)* Fix misaligned stack access in the interpreter ([#14843], thanks @HertzDevil)

[#14845]: https://github.com/crystal-lang/crystal/pull/14845
[#14906]: https://github.com/crystal-lang/crystal/pull/14906
[#14843]: https://github.com/crystal-lang/crystal/pull/14843

### Infrastructure

- Changelog for 1.13.2 ([#14914], thanks @straight-shoota)

[#14914]: https://github.com/crystal-lang/crystal/pull/14914

## [1.13.1] (2024-07-12)

[1.13.1]: https://github.com/crystal-lang/crystal/releases/1.13.1

### Bugfixes

#### stdlib

- *(serialization)* **[regression]** Revert "Optimize JSON parsing a bit" ([#14804], thanks @straight-shoota)

[#14804]: https://github.com/crystal-lang/crystal/pull/14804

### Infrastructure

- Changelog for 1.13.1 ([#14806], thanks @straight-shoota)

[#14806]: https://github.com/crystal-lang/crystal/pull/14806

## [1.13.0] (2024-07-09)

[1.13.0]: https://github.com/crystal-lang/crystal/releases/1.13.0

### Features

#### lang

- Allow rescuing exceptions that include a module ([#14553], thanks @Blacksmoke16)
- *(macros)* Allow assignment to `_` inside macro expressions ([#14452], thanks @HertzDevil)

[#14553]: https://github.com/crystal-lang/crystal/pull/14553
[#14452]: https://github.com/crystal-lang/crystal/pull/14452

#### stdlib

- *(collection)* Add `Array#insert_all` ([#14486], thanks @summer-alice)
- *(collection)* Improve compile time error for `#sort(&block : T, T -> U)` ([#14693], thanks @beta-ziliani)
- *(concurrency)* Add `WaitGroup` synchronization primitive ([#14167], thanks @ysbaddaden)
- *(concurrency)* Allow `Atomic`s of pointer types ([#14401], thanks @HertzDevil)
- *(concurrency)* Add `Thread.new` yields itself ([#14543], thanks @ysbaddaden)
- *(concurrency)* Add support for `Atomic(Bool)` ([#14532], thanks @ysbaddaden)
- *(concurrency)* Add `Thread.sleep(Time::Span)` ([#14715], thanks @ysbaddaden)
- *(files)* Implement `IO#tty?` in Win32 ([#14421], thanks @HertzDevil)
- *(files)* Implement `File.readable?` and `.writable?` in Win32 ([#14420], thanks @HertzDevil)
- *(files)* Make `File.readable?` and `.writable?` follow symlinks on Windows ([#14514], thanks @HertzDevil)
- *(llvm)* Add some missing `LLVM::Context` bindings ([#14612], thanks @ysbaddaden)
- *(llvm)* Do not strip the macOS target triple ([#14466], thanks @hovsater)
- *(log)* Support `UInt32` and `UInt64` in Log Context ([#14459], thanks @toddsundsted)
- *(macros)* Add AST node methods for macro-related nodes ([#14492], thanks @HertzDevil)
- *(macros)* Support short blocks in `#[]` operator call's macro interpolation ([#14523], thanks @HertzDevil)
- *(macros)* Add macro methods for `Select` ([#14600], thanks @HertzDevil)
- *(macros)* Add `TypeNode#private?`, `#public?` and `#visibility` ([#11696], thanks @Hadeweka)
- *(macros)* Add `StringLiteral#to_utf16` ([#14676], thanks @ysbaddaden)
- *(networking)* Relax type restriction of handlers in `HTTP::Server.new` to `Indexable(HTTP::Handler)` ([#14413], thanks @hugopl)
- *(networking)* **[security]** OpenSSL: don't change default cipher suites ([#14655], thanks @ysbaddaden)
- *(networking)* Allow parsing cookies with space in the value ([#14455], thanks @anton7c3)
- *(runtime)* Add `EventLoop::Socket` module ([#14643], thanks @straight-shoota)
- *(runtime)* Add `EventLoop::FileDescriptor` module ([#14639], thanks @straight-shoota)
- *(runtime)* Add `Crystal::Tracing` for runtime tracing ([#14659], thanks @ysbaddaden)
- *(system)* **[security]** **[breaking]** Disable implicit execution of batch files on Windows ([#14557], thanks @straight-shoota)
- *(system)* Add `EventLoop#run(blocking)` and `EventLoop#interrupt` ([#14568], thanks @ysbaddaden)
- *(system)* Add `Crystal::System::Time.ticks` ([#14620], thanks @ysbaddaden)
- *(system)* Add `Crystal::System::Thread.current_thread?`, `#scheduler?` ([#14660], thanks @ysbaddaden)
- *(system)* Protect fork/exec on targets that don't support atomic CLOEXEC ([#14674], thanks @ysbaddaden)
- *(system)* Add `Crystal::System.panic` ([#14733], thanks @ysbaddaden)
- *(text)* Add `Regex::MatchOptions` overload for `String#index!` ([#14462], thanks @HertzDevil)
- *(text)* Add `StringPool#get?` ([#14508], thanks @HertzDevil)
- *(text)* Add `pkg_config` names for `pcre2` and `pcre` ([#14584], thanks @straight-shoota)
- *(text)* Add UUID v7 ([#14732], thanks @jgaskins)
- *(time)* Add `Time::Error` ([#14743], thanks @Blacksmoke16)

[#14486]: https://github.com/crystal-lang/crystal/pull/14486
[#14693]: https://github.com/crystal-lang/crystal/pull/14693
[#14167]: https://github.com/crystal-lang/crystal/pull/14167
[#14401]: https://github.com/crystal-lang/crystal/pull/14401
[#14543]: https://github.com/crystal-lang/crystal/pull/14543
[#14532]: https://github.com/crystal-lang/crystal/pull/14532
[#14715]: https://github.com/crystal-lang/crystal/pull/14715
[#14421]: https://github.com/crystal-lang/crystal/pull/14421
[#14420]: https://github.com/crystal-lang/crystal/pull/14420
[#14514]: https://github.com/crystal-lang/crystal/pull/14514
[#14612]: https://github.com/crystal-lang/crystal/pull/14612
[#14466]: https://github.com/crystal-lang/crystal/pull/14466
[#14459]: https://github.com/crystal-lang/crystal/pull/14459
[#14492]: https://github.com/crystal-lang/crystal/pull/14492
[#14523]: https://github.com/crystal-lang/crystal/pull/14523
[#14600]: https://github.com/crystal-lang/crystal/pull/14600
[#11696]: https://github.com/crystal-lang/crystal/pull/11696
[#14676]: https://github.com/crystal-lang/crystal/pull/14676
[#14413]: https://github.com/crystal-lang/crystal/pull/14413
[#14655]: https://github.com/crystal-lang/crystal/pull/14655
[#14455]: https://github.com/crystal-lang/crystal/pull/14455
[#14643]: https://github.com/crystal-lang/crystal/pull/14643
[#14639]: https://github.com/crystal-lang/crystal/pull/14639
[#14659]: https://github.com/crystal-lang/crystal/pull/14659
[#14557]: https://github.com/crystal-lang/crystal/pull/14557
[#14568]: https://github.com/crystal-lang/crystal/pull/14568
[#14620]: https://github.com/crystal-lang/crystal/pull/14620
[#14660]: https://github.com/crystal-lang/crystal/pull/14660
[#14674]: https://github.com/crystal-lang/crystal/pull/14674
[#14733]: https://github.com/crystal-lang/crystal/pull/14733
[#14462]: https://github.com/crystal-lang/crystal/pull/14462
[#14508]: https://github.com/crystal-lang/crystal/pull/14508
[#14584]: https://github.com/crystal-lang/crystal/pull/14584
[#14732]: https://github.com/crystal-lang/crystal/pull/14732
[#14743]: https://github.com/crystal-lang/crystal/pull/14743

#### compiler

- *(codegen)* Add compiler flags `-Os` and `-Oz` to optimize binary size ([#14463], thanks @ysbaddaden)
- *(codegen)* Add compiler support for AVR architecture (Arduino) ([#14393], thanks @ysbaddaden)

[#14463]: https://github.com/crystal-lang/crystal/pull/14463
[#14393]: https://github.com/crystal-lang/crystal/pull/14393

#### tools

- *(formatter)* Allow new formatter styles for trailing comma and whitespace around proc literal ([#14726], thanks @Blacksmoke16)

[#14726]: https://github.com/crystal-lang/crystal/pull/14726

### Bugfixes

#### lang

- *(macros)* Fix parsing of non-trailing `if` bodies inside macro expressions ([#14505], thanks @HertzDevil)
- *(macros)* Drop parentheses around `->` inside certain comma-separated lists ([#14506], thanks @HertzDevil)
- *(macros)* Fix indentation of `Select` nodes' macro interpolation ([#14510], thanks @HertzDevil)
- *(macros)* Fix indentation of parenthesized `Expressions#to_s` ([#14511], thanks @HertzDevil)

[#14505]: https://github.com/crystal-lang/crystal/pull/14505
[#14506]: https://github.com/crystal-lang/crystal/pull/14506
[#14510]: https://github.com/crystal-lang/crystal/pull/14510
[#14511]: https://github.com/crystal-lang/crystal/pull/14511

#### stdlib

- *(collection)* **[regression]** Ensure `Enumerable#to_a` and `Enumerable#tally` properly retain return type of `T` ([#14447], thanks @Blacksmoke16)
- *(collection)* **[breaking]** Never raise `IndexError` in `#[]?(Range)` ([#14444], thanks @HertzDevil)
- *(collection)* **[breaking]** Fix `Set#to_a(&)` ([#14519], thanks @meatball133)
- *(collection)* Fix `Hash#rehash` to reset `@first` ([#14606], thanks @straight-shoota)
- *(collection)* Fix macro interpolation in `NamedTuple#from` ([#14790], thanks @HertzDevil)
- *(collection)* **[regression]** Fix regression with `NamedTuple.new` when using key with a hyphen ([#14785], thanks @Blacksmoke16)
- *(files)* Allow `#fsync` and `#flock_*` on `IO::FileDescriptor` ([#14432], thanks @HertzDevil)
- *(files)* Make `IO::FileDescriptor#tty?` return false for NUL on Windows ([#14509], thanks @HertzDevil)
- *(files)* Fix blockless `IO::FileDescriptor` echo and raw mode methods ([#14529], thanks @HertzDevil)
- *(files)* Remove target path's forward slashes in `File.symlink` on Windows ([#14522], thanks @HertzDevil)
- *(files)* Fix `IO#same_content?` accepting prefix on second stream ([#14664], thanks @straight-shoota)
- *(files)* Fix overflow in `File#read_at` for large offsets on Windows ([#14708], thanks @HertzDevil)
- *(files)* Fix `IO::FileDescriptor.new` for closed fd ([#14697], thanks @straight-shoota)
- *(files)* Fix `IO::Delimited` reading into limited slice with peek ([#14772], thanks @straight-shoota)
- *(files)* Fix `Compress::Gzip` extra field ([#14550], thanks @kojix2)
- *(log)* delete source from builder cache when finalize ([#14475], thanks @ysbaddaden)
- *(networking)* Fix `Socket#close` error handling on Windows ([#14517], thanks @HertzDevil)
- *(networking)* Set UTF-8 charset on directory listing in `HTTP::StaticFileHandler` ([#14546], thanks @alexkutsan)
- *(networking)* Don't pass socket file descriptors to subprocesses on Unix (`SOCK_CLOEXEC`) ([#14632], thanks @carlhoerberg)
- *(networking)* **[security]** OpenSSL: don't set default ECDH curve ([#14656], thanks @ysbaddaden)
- *(networking)* **[security]** OpenSSL: deprecate Mozilla's TLS Server recommendation ([#14657], thanks @ysbaddaden)
- *(networking)* use `SOCK_CLOEXEC` with `FD_CLOEXEC` fallback ([#14672], thanks @ysbaddaden)
- *(networking)* **[regression]** Fix regression on `Socket#connect` timeout type restriction ([#14755], thanks @straight-shoota)
- *(networking)* Drop default timeout for `Socket#connect` on Windows ([#14756], thanks @straight-shoota)
- *(networking)* don't hardcode alpn protocol byte size (OpenSSL) ([#14769], thanks @ysbaddaden)
- *(numeric)* Fix `BigRational#format` ([#14525], thanks @meatball133)
- *(numeric)* **[regression]** Restore leading zero in exponent for `printf("%e")` and `printf("%g")` ([#14695], thanks @straight-shoota)
- *(runtime)* Fix enable docs for builtin constants ([#14571], thanks @straight-shoota)
- *(runtime)* Fix `GC.malloc` for `gc_none` to clear memory ([#14746], thanks @straight-shoota)
- *(serialization)* Fix JSON discriminator for Bool `false` value ([#14779], thanks @dammer)
- *(specs)* Fix relative file paths in spec output ([#14725], thanks @straight-shoota)
- *(system)* Fix using `System.retry_with_buffer` with stack buffer ([#14615], thanks @straight-shoota)
- *(system)* Harmonize close on exec for `Socket` & `FileDescriptor` on Windows ([#14634], thanks @ysbaddaden)
- *(system)* Use `dup3` and `pipe2` to set `O_CLOEXEC` when available ([#14673], thanks @ysbaddaden)
- *(system)* Fix calls to `retry_with_buffer` when big buffer is necessary ([#14622], thanks @BlobCodes)
- *(system)* Fix `Process.run` with closed IO ([#14698], thanks @straight-shoota)
- *(system)* Prefer `strerror_r` over `strerror` for thread-safe errno ([#14764], thanks @ysbaddaden)
- *(text)* Make `String#sub` raise `IndexError` if index is equal to size ([#14458], thanks @HertzDevil)
- *(text)* Fix `libpcre2` version detection not working for `-RC{N}` versions ([#14478], thanks @Frityet)
- *(text)* Fix `Regex#inspect` with non-literal-compatible options ([#14575], thanks @straight-shoota)
- *(text)* Fix ECR escape sequences containing `-` ([#14739], thanks @HertzDevil)

[#14447]: https://github.com/crystal-lang/crystal/pull/14447
[#14444]: https://github.com/crystal-lang/crystal/pull/14444
[#14519]: https://github.com/crystal-lang/crystal/pull/14519
[#14606]: https://github.com/crystal-lang/crystal/pull/14606
[#14790]: https://github.com/crystal-lang/crystal/pull/14790
[#14785]: https://github.com/crystal-lang/crystal/pull/14785
[#14432]: https://github.com/crystal-lang/crystal/pull/14432
[#14509]: https://github.com/crystal-lang/crystal/pull/14509
[#14529]: https://github.com/crystal-lang/crystal/pull/14529
[#14522]: https://github.com/crystal-lang/crystal/pull/14522
[#14664]: https://github.com/crystal-lang/crystal/pull/14664
[#14708]: https://github.com/crystal-lang/crystal/pull/14708
[#14697]: https://github.com/crystal-lang/crystal/pull/14697
[#14772]: https://github.com/crystal-lang/crystal/pull/14772
[#14550]: https://github.com/crystal-lang/crystal/pull/14550
[#14475]: https://github.com/crystal-lang/crystal/pull/14475
[#14517]: https://github.com/crystal-lang/crystal/pull/14517
[#14546]: https://github.com/crystal-lang/crystal/pull/14546
[#14632]: https://github.com/crystal-lang/crystal/pull/14632
[#14656]: https://github.com/crystal-lang/crystal/pull/14656
[#14657]: https://github.com/crystal-lang/crystal/pull/14657
[#14672]: https://github.com/crystal-lang/crystal/pull/14672
[#14755]: https://github.com/crystal-lang/crystal/pull/14755
[#14756]: https://github.com/crystal-lang/crystal/pull/14756
[#14769]: https://github.com/crystal-lang/crystal/pull/14769
[#14525]: https://github.com/crystal-lang/crystal/pull/14525
[#14695]: https://github.com/crystal-lang/crystal/pull/14695
[#14571]: https://github.com/crystal-lang/crystal/pull/14571
[#14746]: https://github.com/crystal-lang/crystal/pull/14746
[#14779]: https://github.com/crystal-lang/crystal/pull/14779
[#14725]: https://github.com/crystal-lang/crystal/pull/14725
[#14615]: https://github.com/crystal-lang/crystal/pull/14615
[#14634]: https://github.com/crystal-lang/crystal/pull/14634
[#14673]: https://github.com/crystal-lang/crystal/pull/14673
[#14622]: https://github.com/crystal-lang/crystal/pull/14622
[#14698]: https://github.com/crystal-lang/crystal/pull/14698
[#14764]: https://github.com/crystal-lang/crystal/pull/14764
[#14458]: https://github.com/crystal-lang/crystal/pull/14458
[#14478]: https://github.com/crystal-lang/crystal/pull/14478
[#14575]: https://github.com/crystal-lang/crystal/pull/14575
[#14739]: https://github.com/crystal-lang/crystal/pull/14739

#### compiler

- *(codegen)* Fix create new `target_machine` for every program ([#14694], thanks @straight-shoota)
- *(codegen)* Make `ReferenceStorage(T)` non-atomic if `T` is non-atomic ([#14730], thanks @HertzDevil)
- *(codegen)* Detect and error on failed codegen process ([#14762], thanks @ysbaddaden)
- *(codegen)* Fix stats and progress issues in codegen ([#14763], thanks @ysbaddaden)
- *(debugger)* Fix LLDB `crystal_formatters.py` for Python 3 ([#14665], thanks @zw963)
- *(parser)* Disallow assignments to calls with parentheses ([#14527], thanks @HertzDevil)
- *(parser)* Fix parser validate UTF-8 on first input byte  ([#14750], thanks @straight-shoota)
- *(semantic)* Fix type def reopening type from parent namespace ([#11208], thanks @straight-shoota)
- *(semantic)* Fix `Crystal::Path#to_macro_id` for global path ([#14490], thanks @straight-shoota)
- *(semantic)* Fix `Class#===` on metaclass ([#11162], thanks @makenowjust)

[#14694]: https://github.com/crystal-lang/crystal/pull/14694
[#14730]: https://github.com/crystal-lang/crystal/pull/14730
[#14762]: https://github.com/crystal-lang/crystal/pull/14762
[#14763]: https://github.com/crystal-lang/crystal/pull/14763
[#14665]: https://github.com/crystal-lang/crystal/pull/14665
[#14527]: https://github.com/crystal-lang/crystal/pull/14527
[#14750]: https://github.com/crystal-lang/crystal/pull/14750
[#11208]: https://github.com/crystal-lang/crystal/pull/11208
[#14490]: https://github.com/crystal-lang/crystal/pull/14490
[#11162]: https://github.com/crystal-lang/crystal/pull/11162

#### tools

- *(docs-generator)* Fix generate docs for builtins `HOST_TRIPLE` and `TARGET_TRIPLE` ([#14570], thanks @straight-shoota)
- *(docs-generator)* Decode URI component for search functionality in docs ([#14645], thanks @nobodywasishere)
- *(formatter)* Fix formatting for short block inside `#[]` operator call ([#14526], thanks @HertzDevil)
- *(formatter)* Fix formatter to skip trailing comma for single-line parameters ([#14713], thanks @Blacksmoke16)

[#14570]: https://github.com/crystal-lang/crystal/pull/14570
[#14645]: https://github.com/crystal-lang/crystal/pull/14645
[#14526]: https://github.com/crystal-lang/crystal/pull/14526
[#14713]: https://github.com/crystal-lang/crystal/pull/14713

### Chores

#### stdlib

- *(collection)* Drop obsolete workaround in `Range#reverse_each` ([#14709], thanks @yxhuvud)
- *(concurrency)* Add `WaitGroup` to `docs_main.cr` ([#14624], thanks @straight-shoota)
- *(files)* **[deprecation]** Move `File.readable?`, `.writable?`, `.executable?` to `File::Info` ([#14484], thanks @straight-shoota)
- *(networking)* Drop `Crystal::System::Socket#system_send` ([#14637], thanks @straight-shoota)
- *(networking)* Add type restriction `host : String` in `TCPSocket` and `Addrinfo` ([#14703], thanks @straight-shoota)
- *(runtime)* Fix abstract def parameter name in `LibEvent::EventLoop#send_to` ([#14658], thanks @straight-shoota)
- *(runtime)* **[breaking]** Drop unused methods in `IO::Evented` ([#14666], thanks @straight-shoota)
- *(runtime)* Drop `IO::Overlapped` ([#14704], thanks @straight-shoota)

[#14709]: https://github.com/crystal-lang/crystal/pull/14709
[#14624]: https://github.com/crystal-lang/crystal/pull/14624
[#14484]: https://github.com/crystal-lang/crystal/pull/14484
[#14637]: https://github.com/crystal-lang/crystal/pull/14637
[#14703]: https://github.com/crystal-lang/crystal/pull/14703
[#14658]: https://github.com/crystal-lang/crystal/pull/14658
[#14666]: https://github.com/crystal-lang/crystal/pull/14666
[#14704]: https://github.com/crystal-lang/crystal/pull/14704

#### compiler

- *(codegen)* **[breaking]** Remove `CRYSTAL_LIBRARY_RPATH` and delay-load helper ([#14598], thanks @HertzDevil)

[#14598]: https://github.com/crystal-lang/crystal/pull/14598

### Performance

#### stdlib

- *(collection)* Optimize `Hash` for repeated removals and insertions ([#14539], thanks @HertzDevil)
- *(runtime)* Remove unnecessary explicit memory barriers on ARM ([#14567], thanks @ysbaddaden)
- *(serialization)* Optimize JSON parsing a bit ([#14366], thanks @asterite)
- *(text)* Use wrapping arithmetic for `Int::Primitive#unsafe_chr` ([#14443], thanks @HertzDevil)
- *(text)* Optimize `String#index(Char)` and `#rindex(Char)` for invalid UTF-8 ([#14461], thanks @HertzDevil)
- *(text)* Optimize `String#to_utf16` ([#14671], thanks @straight-shoota)

[#14539]: https://github.com/crystal-lang/crystal/pull/14539
[#14567]: https://github.com/crystal-lang/crystal/pull/14567
[#14366]: https://github.com/crystal-lang/crystal/pull/14366
[#14443]: https://github.com/crystal-lang/crystal/pull/14443
[#14461]: https://github.com/crystal-lang/crystal/pull/14461
[#14671]: https://github.com/crystal-lang/crystal/pull/14671

### Refactor

#### stdlib

- Remove unnecessary calls to `#unsafe_as(UInt64)` etc. ([#14686], thanks @straight-shoota)
- *(crypto)* Replace calls to `StaticArray(UInt8, 1)#unsafe_as(UInt8)` ([#14685], thanks @straight-shoota)
- *(files)* Remove calls to `LibC._setmode` ([#14419], thanks @HertzDevil)
- *(files)* Use file handles directly instead of C file descriptors on Win32 ([#14501], thanks @HertzDevil)
- *(files)* Refactor win32 `System::FileDescriptor#unbuffered_{read,write}` ([#14607], thanks @straight-shoota)
- *(files)* Extract `#system_read` and `#system_write` for `FileDescriptor` and `Socket` ([#14626], thanks @straight-shoota)
- *(files)* Drop unused slice parameters of `#evented_*` methods ([#14627], thanks @straight-shoota)
- *(networking)* Refactor use `IO#read_byte` instead of `#read_char` in `HTTP::ChunkedContent` ([#14548], thanks @straight-shoota)
- *(runtime)* `Thread` owns its current fiber (instead of `Crystal::Scheduler`) ([#14554], thanks @ysbaddaden)
- *(runtime)* Use `Fiber#enqueue` ([#14561], thanks @ysbaddaden)
- *(runtime)* Add `Crystal::EventLoop.current` ([#14559], thanks @ysbaddaden)
- *(runtime)* Add `Fiber.suspend` ([#14560], thanks @ysbaddaden)
- *(runtime)* Remove `OverlappedOperation#synchronous` ([#14663], thanks @straight-shoota)
- *(runtime)* Rename `Crystal::Iocp` to `Crystal::IOCP` ([#14662], thanks @straight-shoota)
- *(runtime)* Unify `EventLoop.create` ([#14661], thanks @straight-shoota)
- *(serialization)* Replace `type` declarations for void pointers with `alias` in `libxml2` ([#14494], thanks @straight-shoota)
- *(serialization)* Refactor `JSON::Any#size` to use two branches instead of three ([#14533], thanks @meatball133)
- *(specs)* Move `Spec` context state into `Spec::CLI` ([#14259], thanks @HertzDevil)
- *(system)* Update `WinError#to_errno` ([#14515], thanks @HertzDevil)
- *(system)* Rename `Crystal::System.print_error(fmt, *args, &)` to `printf` ([#14617], thanks @ysbaddaden)
- *(system)* Refactor `Crystal::System.retry_with_buffer` calling `#to_slice` ([#14614], thanks @straight-shoota)
- *(system)* Extract system implementation of `UNIXSocket.pair` as `Crystal::System::Socket.socketpair` ([#14675], thanks @ysbaddaden)
- *(system)* Remove calls to `Pointer.new(Int)` ([#14683], thanks @straight-shoota)
- *(system)* Cleanup for `IOCP::OverlappedOperation` ([#14723], thanks @straight-shoota)
- *(system)* Refactor `IOCP::OverlappedOperation` internalize `handle` and `wait_for_completion` ([#14724], thanks @straight-shoota)

[#14686]: https://github.com/crystal-lang/crystal/pull/14686
[#14685]: https://github.com/crystal-lang/crystal/pull/14685
[#14419]: https://github.com/crystal-lang/crystal/pull/14419
[#14501]: https://github.com/crystal-lang/crystal/pull/14501
[#14607]: https://github.com/crystal-lang/crystal/pull/14607
[#14626]: https://github.com/crystal-lang/crystal/pull/14626
[#14627]: https://github.com/crystal-lang/crystal/pull/14627
[#14548]: https://github.com/crystal-lang/crystal/pull/14548
[#14554]: https://github.com/crystal-lang/crystal/pull/14554
[#14561]: https://github.com/crystal-lang/crystal/pull/14561
[#14559]: https://github.com/crystal-lang/crystal/pull/14559
[#14560]: https://github.com/crystal-lang/crystal/pull/14560
[#14663]: https://github.com/crystal-lang/crystal/pull/14663
[#14662]: https://github.com/crystal-lang/crystal/pull/14662
[#14661]: https://github.com/crystal-lang/crystal/pull/14661
[#14494]: https://github.com/crystal-lang/crystal/pull/14494
[#14533]: https://github.com/crystal-lang/crystal/pull/14533
[#14259]: https://github.com/crystal-lang/crystal/pull/14259
[#14515]: https://github.com/crystal-lang/crystal/pull/14515
[#14617]: https://github.com/crystal-lang/crystal/pull/14617
[#14614]: https://github.com/crystal-lang/crystal/pull/14614
[#14675]: https://github.com/crystal-lang/crystal/pull/14675
[#14683]: https://github.com/crystal-lang/crystal/pull/14683
[#14723]: https://github.com/crystal-lang/crystal/pull/14723
[#14724]: https://github.com/crystal-lang/crystal/pull/14724

#### compiler

- *(codegen)* Add `Program#size_t` and `Target#size_bit_width` ([#14442], thanks @ysbaddaden)
- *(parser)* Replace `Crystal::Select::When` with `Crystal::When` ([#14497], thanks @HertzDevil)

[#14442]: https://github.com/crystal-lang/crystal/pull/14442
[#14497]: https://github.com/crystal-lang/crystal/pull/14497

### Documentation

#### stdlib

- *(collection)* Fix doc for `Set#proper_superset_of?` ([#14516], thanks @meatball133)
- *(collection)* Fix result formatting in code example for `Indexable#[]?` ([#14721], thanks @meatball133)
- *(concurrency)* Fix example for `WeakRef` by removing `ref.value` call ([#10846], thanks @hugopl)
- *(networking)* Improve API docs for `Socket#send` ([#14638], thanks @straight-shoota)
- *(networking)* Add documentation for `HTTP::WebSocket#stream` ([#14537], thanks @meatball133)
- *(numeric)* Add documentation for complex methods inside Number ([#14538], thanks @meatball133)
- *(runtime)* Add documentation for standard streams blocking behaviour ([#14577], thanks @straight-shoota)
- *(serialization)* Fix docs for `CSV::Builder#row(&)` ([#14736], thanks @philipp-classen)
- *(system)* **[breaking]** Undocument `IO::Evented` ([#14749], thanks @straight-shoota)
- *(system)* Fix code example for `Process.on_terminate` ([#14798], thanks @philipp-classen)
- *(text)* Fix docs for `Char#ascii_number?` stating wrong minium base ([#14521], thanks @meatball133)
- *(text)* Enhance documentation for regex options `NO_UTF_CHECK` ([#14542], thanks @straight-shoota)

[#14516]: https://github.com/crystal-lang/crystal/pull/14516
[#14721]: https://github.com/crystal-lang/crystal/pull/14721
[#10846]: https://github.com/crystal-lang/crystal/pull/10846
[#14638]: https://github.com/crystal-lang/crystal/pull/14638
[#14537]: https://github.com/crystal-lang/crystal/pull/14537
[#14538]: https://github.com/crystal-lang/crystal/pull/14538
[#14577]: https://github.com/crystal-lang/crystal/pull/14577
[#14736]: https://github.com/crystal-lang/crystal/pull/14736
[#14749]: https://github.com/crystal-lang/crystal/pull/14749
[#14798]: https://github.com/crystal-lang/crystal/pull/14798
[#14521]: https://github.com/crystal-lang/crystal/pull/14521
[#14542]: https://github.com/crystal-lang/crystal/pull/14542

### Specs

#### stdlib

- Remove incorrect uses of `describe` ([#14757], thanks @HertzDevil)
- *(files)* Add spec for `Compress::Gzip::Writer` with `extra` ([#14788], thanks @straight-shoota)
- *(runtime)* Add specs for `Pointer::Appender` ([#14719], thanks @straight-shoota)
- *(text)* Add test helper for `normalize/regex_spec` ([#14545], thanks @straight-shoota)

[#14757]: https://github.com/crystal-lang/crystal/pull/14757
[#14788]: https://github.com/crystal-lang/crystal/pull/14788
[#14719]: https://github.com/crystal-lang/crystal/pull/14719
[#14545]: https://github.com/crystal-lang/crystal/pull/14545

### Infrastructure

- Changelog for 1.13.0 ([#14712], thanks @straight-shoota)
- Update previous Crystal release 1.12.1 ([#14480], thanks @straight-shoota)
- Highlight regression bugfixes in changelog ([#14474], thanks @straight-shoota)
- Write release version to `src/VERSION` in `update-changelog` and `release-update` ([#14547], thanks @straight-shoota)
- Fix `shell.nix` use `llvmPackages.bintools` with wrapper for rpath config ([#14583], thanks @straight-shoota)
- Add `src/SOURCE_DATE_EPOCH` to release tree ([#14574], thanks @straight-shoota)
- Update distribution-scripts ([#14562], thanks @straight-shoota)
- Update distribution-scripts ([#14594], thanks @straight-shoota)
- Use `boehmgc` package from nixpkgs in `shell.nix` ([#14591], thanks @straight-shoota)
- Simplify LLVM dependency in `shell.nix` ([#14590], thanks @straight-shoota)
- Fix nixpkgs `pkg-config` name in `shell.nix` ([#14593], thanks @straight-shoota)
- Update previous Crystal release 1.12.2 ([#14647], thanks @straight-shoota)
- Update distribution-scripts ([#14648], thanks @straight-shoota)
- Update distribution-scripts ([#14714], thanks @straight-shoota)
- Update distribution-scripts ([#14776], thanks @straight-shoota)
- Fix changelog generator increase topic priority for `infrastructure` ([#14781], thanks @straight-shoota)
- Remove `SetShouldExit` in Powershell wrapper ([#13769], thanks @straight-shoota)
- *(ci)* Run `primitives_spec` with the interpreter on CI ([#14438], thanks @HertzDevil)
- *(ci)* Add LLVM 18 to LLVM CI ([#14565], thanks @HertzDevil)
- *(ci)* Update to Ruby 3 in macOS circleCI runner ([#14777], thanks @straight-shoota)
- *(ci)* Distribute `shards.pdb` on Windows ([#14415], thanks @HertzDevil)
- *(ci)* Drop Windows CI workaround for 1.12.0-dev ([#14483], thanks @HertzDevil)

[#14712]: https://github.com/crystal-lang/crystal/pull/14712
[#14480]: https://github.com/crystal-lang/crystal/pull/14480
[#14474]: https://github.com/crystal-lang/crystal/pull/14474
[#14547]: https://github.com/crystal-lang/crystal/pull/14547
[#14583]: https://github.com/crystal-lang/crystal/pull/14583
[#14574]: https://github.com/crystal-lang/crystal/pull/14574
[#14562]: https://github.com/crystal-lang/crystal/pull/14562
[#14594]: https://github.com/crystal-lang/crystal/pull/14594
[#14591]: https://github.com/crystal-lang/crystal/pull/14591
[#14590]: https://github.com/crystal-lang/crystal/pull/14590
[#14593]: https://github.com/crystal-lang/crystal/pull/14593
[#14647]: https://github.com/crystal-lang/crystal/pull/14647
[#14648]: https://github.com/crystal-lang/crystal/pull/14648
[#14714]: https://github.com/crystal-lang/crystal/pull/14714
[#14776]: https://github.com/crystal-lang/crystal/pull/14776
[#14781]: https://github.com/crystal-lang/crystal/pull/14781
[#13769]: https://github.com/crystal-lang/crystal/pull/13769
[#14438]: https://github.com/crystal-lang/crystal/pull/14438
[#14565]: https://github.com/crystal-lang/crystal/pull/14565
[#14777]: https://github.com/crystal-lang/crystal/pull/14777
[#14415]: https://github.com/crystal-lang/crystal/pull/14415
[#14483]: https://github.com/crystal-lang/crystal/pull/14483

## [1.12.2] (2024-05-31)

_Patch release with a bug fix necessary for support of latest libgc_

[1.12.2]: https://github.com/crystal-lang/crystal/releases/1.12.2

### Bugfixes

#### stdlib

- *(runtime)* Don't allocate in `Fiber.unsafe_each` and `Thread.unsafe_each` ([#14635], thanks @ysbaddaden)

[#14635]: https://github.com/crystal-lang/crystal/pull/14635

### Infrastructure

- Changelog for 1.12.2 ([#14640], thanks @straight-shoota)

[#14640]: https://github.com/crystal-lang/crystal/pull/14640

## [1.12.1] (2024-04-11)

[1.12.1]: https://github.com/crystal-lang/crystal/releases/1.12.1

### Bugfixes

#### tools

- *(formatter)* **[regression]** Fix formatter with whitespace before closing parenthesis ([#14471], thanks @straight-shoota)

[#14471]: https://github.com/crystal-lang/crystal/pull/14471

### Infrastructure

- Changelog for 1.12.1 ([#14472], thanks @straight-shoota)

[#14472]: https://github.com/crystal-lang/crystal/pull/14472

## [1.12.0] (2024-04-09)

[1.12.0]: https://github.com/crystal-lang/crystal/releases/1.12.0

### Features

#### lang

- Allow multiple parameters and blocks for operators ending in `=` ([#14159], thanks @HertzDevil)

[#14159]: https://github.com/crystal-lang/crystal/pull/14159

#### stdlib

- *(concurrency)* MT: reduce interleaved backtraces in spawn unhandled exceptions ([#14220], thanks @ysbaddaden)
- *(concurrency)* Fix: opening/reading from fifo/chardev files are blocking the thread ([#14255], thanks @ysbaddaden)
- *(concurrency)* Fix: Atomics and Locks (ARM, AArch64, X86) ([#14293], thanks @ysbaddaden)
- *(files)* Add `IO::FileDescriptor::Handle` ([#14390], thanks @straight-shoota)
- *(macros)* Add macro methods for lib-related nodes ([#14218], thanks @HertzDevil)
- *(macros)* Add macro methods for `Primitive` ([#14263], thanks @HertzDevil)
- *(macros)* Add macro methods for `TypeOf` ([#14262], thanks @HertzDevil)
- *(macros)* Add macro methods for `Alias` ([#14261], thanks @HertzDevil)
- *(macros)* Add macro methods for `Asm` and `AsmOperand` ([#14268], thanks @HertzDevil)
- *(macros)* Relax `delegate`'s setter detection ([#14282], thanks @HertzDevil)
- *(numeric)* Add `BigRational#%`, `#tdiv`, `#remainder` ([#14306], thanks @HertzDevil)
- *(runtime)* **[experimental]** Add `ReferenceStorage` for manual allocation of references ([#14270], thanks @HertzDevil)
- *(runtime)* Add MSVC invalid parameter handler ([#14313], thanks @HertzDevil)
- *(system)* Add `Signal#trap_handler?` ([#14126], thanks @stakach)
- *(system)* Thread: set name ([#14257], thanks @ysbaddaden)
- *(system)* Add `Process.on_terminate` ([#13694], thanks @stakach)
- *(time)* Add support for `Etc/UTC` time zone identifier without tzdb ([#14185], thanks @femto)

[#14220]: https://github.com/crystal-lang/crystal/pull/14220
[#14255]: https://github.com/crystal-lang/crystal/pull/14255
[#14293]: https://github.com/crystal-lang/crystal/pull/14293
[#14390]: https://github.com/crystal-lang/crystal/pull/14390
[#14218]: https://github.com/crystal-lang/crystal/pull/14218
[#14263]: https://github.com/crystal-lang/crystal/pull/14263
[#14262]: https://github.com/crystal-lang/crystal/pull/14262
[#14261]: https://github.com/crystal-lang/crystal/pull/14261
[#14268]: https://github.com/crystal-lang/crystal/pull/14268
[#14282]: https://github.com/crystal-lang/crystal/pull/14282
[#14306]: https://github.com/crystal-lang/crystal/pull/14306
[#14270]: https://github.com/crystal-lang/crystal/pull/14270
[#14313]: https://github.com/crystal-lang/crystal/pull/14313
[#14126]: https://github.com/crystal-lang/crystal/pull/14126
[#14257]: https://github.com/crystal-lang/crystal/pull/14257
[#13694]: https://github.com/crystal-lang/crystal/pull/13694
[#14185]: https://github.com/crystal-lang/crystal/pull/14185

#### compiler

- Add `CRYSTAL_CONFIG_CC` compiler config ([#14318], thanks @straight-shoota)
- *(cli)* Respect `NO_COLOR` in the compiler ([#14260], thanks @HertzDevil)
- *(cli)* Respect `--static` on Windows ([#14292], thanks @HertzDevil)
- *(cli)* Allow `--single-module` and `--threads` for `eval` and `spec` ([#14341], thanks @HertzDevil)
- *(codegen)* Add `--frame-pointers` to control preservation of frame pointers ([#13860], thanks @refi64)
- *(codegen)* x86-64 Solaris / illumos support ([#14343], thanks @HertzDevil)
- *(interpreter)* Support `@[Link]`'s DLL search order in the interpreter on Windows ([#14146], thanks @HertzDevil)
- *(interpreter)* Automatically detect MSVC tools on Windows interpreter ([#14391], thanks @HertzDevil)
- *(parser)* Allow calling `#[]=` with a block using method syntax ([#14161], thanks @HertzDevil)
- *(semantic)* Change short_reference for top-level macros to `::foo` ([#14203], thanks @femto)

[#14318]: https://github.com/crystal-lang/crystal/pull/14318
[#14260]: https://github.com/crystal-lang/crystal/pull/14260
[#14292]: https://github.com/crystal-lang/crystal/pull/14292
[#14341]: https://github.com/crystal-lang/crystal/pull/14341
[#13860]: https://github.com/crystal-lang/crystal/pull/13860
[#14343]: https://github.com/crystal-lang/crystal/pull/14343
[#14146]: https://github.com/crystal-lang/crystal/pull/14146
[#14391]: https://github.com/crystal-lang/crystal/pull/14391
[#14161]: https://github.com/crystal-lang/crystal/pull/14161
[#14203]: https://github.com/crystal-lang/crystal/pull/14203

#### tools

- Add `crystal tool flags` ([#14234], thanks @straight-shoota)
- *(formatter)* Add more whitespace around `ProcLiteral`s ([#14209], thanks @HertzDevil)

[#14234]: https://github.com/crystal-lang/crystal/pull/14234
[#14209]: https://github.com/crystal-lang/crystal/pull/14209

### Bugfixes

#### lang

- *(macros)* Remove extra newline in top-level `FunDef`'s string representation ([#14212], thanks @HertzDevil)
- *(macros)* Remove `T*` and `T[N]` macro interpolation behavior inside libs ([#14215], thanks @HertzDevil)

[#14212]: https://github.com/crystal-lang/crystal/pull/14212
[#14215]: https://github.com/crystal-lang/crystal/pull/14215

#### stdlib

- *(collection)* Fix `Hash#update` when default block also adds given key ([#14417], thanks @HertzDevil)
- *(collection)* Fix `Hash#put_if_absent` putting duplicate keys ([#14427], thanks @HertzDevil)
- *(concurrency)* Reserve stack space on non-main threads for crash recovery on Windows ([#14187], thanks @HertzDevil)
- *(concurrency)* Add memory barrier to `Mutex#unlock` on aarch64 ([#14272], thanks @jgaskins)
- *(concurrency)* init schedulers before we spawn fibers ([#14339], thanks @ysbaddaden)
- *(files)* Make `FileUtils.mv` work across filesystems on Windows ([#14320], thanks @HertzDevil)
- *(llvm)* Use correct string size for `LLVM::Type#inline_asm` ([#14265], thanks @HertzDevil)
- *(llvm)* Fix System V ABI for packed structs with misaligned fields ([#14324], thanks @HertzDevil)
- *(networking)* OpenSSL 3.x reports unexpected EOF as SSL error ([#14219], thanks @ysbaddaden)
- *(numeric)* Make equality between `Complex` and other numbers exact ([#14309], thanks @HertzDevil)
- *(numeric)* Fix `#hash` for the `Big*` number types ([#14308], thanks @HertzDevil)
- *(runtime)* Do not allocate memory in the segmentation fault signal handler ([#14327], thanks @HertzDevil)
- *(runtime)* Fix crash stack trace decoding on macOS ([#14335], thanks @HertzDevil)
- *(runtime)* `Crystal::RWLock` should be a struct ([#14345], thanks @ysbaddaden)
- *(runtime)* Fix `min_by?` in IOCP event loop `#run_once` ([#14394], thanks @straight-shoota)
- *(serialization)* `XML::Reader`: Disallow attributes containing null bytes ([#14193], thanks @HertzDevil)
- *(serialization)* Always call `LibXML.xmlInitParser` when requiring XML libraries ([#14191], thanks @HertzDevil)
- *(system)* Fix macro `Crystal::LIBRARY_PATH.split` when cross-compiling ([#14330], thanks @HertzDevil)
- *(system)* Add `SA_RESTART` flag to sigaction syscall ([#14351], thanks @ysbaddaden)
- *(text)* Add `Nil` return type restriction to `String::Formatter#consume_substitution` ([#14430], thanks @straight-shoota)

[#14417]: https://github.com/crystal-lang/crystal/pull/14417
[#14427]: https://github.com/crystal-lang/crystal/pull/14427
[#14187]: https://github.com/crystal-lang/crystal/pull/14187
[#14272]: https://github.com/crystal-lang/crystal/pull/14272
[#14339]: https://github.com/crystal-lang/crystal/pull/14339
[#14320]: https://github.com/crystal-lang/crystal/pull/14320
[#14265]: https://github.com/crystal-lang/crystal/pull/14265
[#14324]: https://github.com/crystal-lang/crystal/pull/14324
[#14219]: https://github.com/crystal-lang/crystal/pull/14219
[#14309]: https://github.com/crystal-lang/crystal/pull/14309
[#14308]: https://github.com/crystal-lang/crystal/pull/14308
[#14327]: https://github.com/crystal-lang/crystal/pull/14327
[#14335]: https://github.com/crystal-lang/crystal/pull/14335
[#14345]: https://github.com/crystal-lang/crystal/pull/14345
[#14394]: https://github.com/crystal-lang/crystal/pull/14394
[#14193]: https://github.com/crystal-lang/crystal/pull/14193
[#14191]: https://github.com/crystal-lang/crystal/pull/14191
[#14330]: https://github.com/crystal-lang/crystal/pull/14330
[#14351]: https://github.com/crystal-lang/crystal/pull/14351
[#14430]: https://github.com/crystal-lang/crystal/pull/14430

#### compiler

- *(cli)* `build --no-codegen` output file name error ([#14239], thanks @apainintheneck)
- *(codegen)* Do not handle inline assembly with `"intel"` flag as AT&T syntax ([#14264], thanks @HertzDevil)
- *(codegen)* **[breaking]** Respect alignments above `alignof(Void*)` inside union values ([#14279], thanks @HertzDevil)
- *(codegen)* Fix stack corruption in union-to-union casts ([#14289], thanks @HertzDevil)
- *(codegen)* Don't copy DLL to output directory if file already exists ([#14315], thanks @HertzDevil)
- *(codegen)* Fix `Proc#call` that takes and returns large extern structs by value ([#14323], thanks @HertzDevil)
- *(codegen)* Never discard ivar initializer inside `.allocate` and `.pre_initialize` ([#14337], thanks @HertzDevil)
- *(codegen)* Use separate names for constant and class variable internals ([#14445], thanks @HertzDevil)
- *(interpreter)* fix fiber's resumable property ([#14252], thanks @ysbaddaden)
- *(interpreter)* Ensure all constants only have one initializer in the interpreter ([#14381], thanks @HertzDevil)
- *(interpreter)* Handle NaN comparisons in the interpreter ([#14441], thanks @HertzDevil)
- *(interpreter)* Check `UInt16#to_u8` for overflow in the interpreter ([#14436], thanks @HertzDevil)
- *(interpreter)* Fix interpreter internal overflow for `UInt128#to_f32` and `#to_f32!` ([#14437], thanks @HertzDevil)
- *(parser)* Fix name locations of `FunDef` and `External` nodes ([#14267], thanks @HertzDevil)
- *(parser)* Fix end locations of `Alias` nodes ([#14271], thanks @HertzDevil)

[#14239]: https://github.com/crystal-lang/crystal/pull/14239
[#14264]: https://github.com/crystal-lang/crystal/pull/14264
[#14279]: https://github.com/crystal-lang/crystal/pull/14279
[#14289]: https://github.com/crystal-lang/crystal/pull/14289
[#14315]: https://github.com/crystal-lang/crystal/pull/14315
[#14323]: https://github.com/crystal-lang/crystal/pull/14323
[#14337]: https://github.com/crystal-lang/crystal/pull/14337
[#14445]: https://github.com/crystal-lang/crystal/pull/14445
[#14252]: https://github.com/crystal-lang/crystal/pull/14252
[#14381]: https://github.com/crystal-lang/crystal/pull/14381
[#14441]: https://github.com/crystal-lang/crystal/pull/14441
[#14436]: https://github.com/crystal-lang/crystal/pull/14436
[#14437]: https://github.com/crystal-lang/crystal/pull/14437
[#14267]: https://github.com/crystal-lang/crystal/pull/14267
[#14271]: https://github.com/crystal-lang/crystal/pull/14271

#### tools

- *(formatter)* Fix format for `asm` with comments ([#14278], thanks @straight-shoota)
- *(formatter)* Fix formatter for white space in `a.[b]` syntax ([#14346], thanks @straight-shoota)
- *(formatter)* Fix formatter on call without parentheses followed by doc comment ([#14354], thanks @straight-shoota)
- *(formatter)* Do not remove the whitespace in `foo ()` when formatting ([#14439], thanks @HertzDevil)

[#14278]: https://github.com/crystal-lang/crystal/pull/14278
[#14346]: https://github.com/crystal-lang/crystal/pull/14346
[#14354]: https://github.com/crystal-lang/crystal/pull/14354
[#14439]: https://github.com/crystal-lang/crystal/pull/14439

### Chores

#### stdlib

- *(concurrency)* **[deprecation]** Drop flag `openbsd6.2` ([#14233], thanks @straight-shoota)
- *(files)* **[deprecation]** Deprecate timeout setters with `Number` arguments ([#14372], thanks @straight-shoota)

[#14233]: https://github.com/crystal-lang/crystal/pull/14233
[#14372]: https://github.com/crystal-lang/crystal/pull/14372

#### compiler

- *(codegen)* Drop pinning Dwarf version 2 for android ([#14243], thanks @straight-shoota)

[#14243]: https://github.com/crystal-lang/crystal/pull/14243

### Performance

#### stdlib

- *(collection)* Optimize hash lookup in `Enumerable#group_by` ([#14235], thanks @straight-shoota)
- *(concurrency)* Use per-scheduler stack pools (let's recycle) ([#14100], thanks @ysbaddaden)

[#14235]: https://github.com/crystal-lang/crystal/pull/14235
[#14100]: https://github.com/crystal-lang/crystal/pull/14100

#### compiler

- *(codegen)* on demand distribution to forked processes ([#14273], thanks @ysbaddaden)
- *(interpreter)* Use `Fiber::StackPool` in the interpreter ([#14395], thanks @HertzDevil)

[#14273]: https://github.com/crystal-lang/crystal/pull/14273
[#14395]: https://github.com/crystal-lang/crystal/pull/14395

### Refactor

#### stdlib

- *(files)* Replace some Microsoft C runtime funs with Win32 equivalents ([#14316], thanks @HertzDevil)
- *(files)* Move timeout properties to `Socket` and `IO::FileDescriptor` ([#14367], thanks @straight-shoota)
- *(files)* Add type restrictions to `#unbuffered_*` implementations ([#14382], thanks @straight-shoota)
- *(networking)* Refactor `HTTP::Client` timeout ivars to `Time::Span` ([#14371], thanks @straight-shoota)
- *(networking)* Refactor `Socket#system_receive` to return `Address` ([#14384], thanks @straight-shoota)
- *(networking)* Refactor `#system_connect` without yield ([#14383], thanks @straight-shoota)
- *(numeric)* Add `Crystal::Hasher.reduce_num` and `#number` ([#14304], thanks @HertzDevil)
- *(runtime)* Refactor and add comments to IOCP `#run_once` ([#14380], thanks @straight-shoota)
- *(specs)* **[deprecation]** Move most of spec runner's state into `Spec::CLI` ([#14170], thanks @HertzDevil)
- *(specs)* Add `Spec::Formatter#should_print_summary?` ([#14397], thanks @HertzDevil)

[#14316]: https://github.com/crystal-lang/crystal/pull/14316
[#14367]: https://github.com/crystal-lang/crystal/pull/14367
[#14382]: https://github.com/crystal-lang/crystal/pull/14382
[#14371]: https://github.com/crystal-lang/crystal/pull/14371
[#14384]: https://github.com/crystal-lang/crystal/pull/14384
[#14383]: https://github.com/crystal-lang/crystal/pull/14383
[#14304]: https://github.com/crystal-lang/crystal/pull/14304
[#14380]: https://github.com/crystal-lang/crystal/pull/14380
[#14170]: https://github.com/crystal-lang/crystal/pull/14170
[#14397]: https://github.com/crystal-lang/crystal/pull/14397

#### compiler

- Ensure `Crystal::Visitor#visit` returns `Bool` ([#14266], thanks @HertzDevil)
- *(parser)* Add `Token::Kind#unary_operator?` ([#14342], thanks @straight-shoota)
- *(parser)* Add `Lexer#wants_def_or_macro_name` ([#14352], thanks @straight-shoota)

[#14266]: https://github.com/crystal-lang/crystal/pull/14266
[#14342]: https://github.com/crystal-lang/crystal/pull/14342
[#14352]: https://github.com/crystal-lang/crystal/pull/14352

### Documentation

#### stdlib

- *(collection)* Fix docs `:inherit:` pragma for `Indexable#first` ([#14296], thanks @lachlan)
- *(collection)* Fix `Hash.new(initial_capacity, &block)` doc to use relevant example ([#14429], thanks @lachlan)
- *(crypto)* Improve OpenSSL module documentation ([#14410], thanks @summer-alice)
- *(numeric)* Enhance docs for `Int#downto` ([#14176], thanks @jkthorne)
- *(runtime)* Document builtin constants ([#14276], thanks @straight-shoota)
- *(runtime)* Fix `Pointer#+(offset: Int64)` doc parameter name typo ([#14428], thanks @lachlan)
- *(runtime)* Improve documentation for `at_exit` handler conditions ([#14426], thanks @straight-shoota)
- *(system)* Fix typo in Signal docs ([#14400], thanks @joshrickard)
- *(text)* Fix `Colorize.enabled?`'s documentation ([#14258], thanks @HertzDevil)

[#14296]: https://github.com/crystal-lang/crystal/pull/14296
[#14429]: https://github.com/crystal-lang/crystal/pull/14429
[#14410]: https://github.com/crystal-lang/crystal/pull/14410
[#14176]: https://github.com/crystal-lang/crystal/pull/14176
[#14276]: https://github.com/crystal-lang/crystal/pull/14276
[#14428]: https://github.com/crystal-lang/crystal/pull/14428
[#14426]: https://github.com/crystal-lang/crystal/pull/14426
[#14400]: https://github.com/crystal-lang/crystal/pull/14400
[#14258]: https://github.com/crystal-lang/crystal/pull/14258

### Specs

#### stdlib

- Fix spelling in `spec/std/uri/params_spec.cr` ([#14302], thanks @jbampton)
- *(files)* Refactor expectations with `SpecChannelStatus` to be explicit ([#14378], thanks @straight-shoota)
- *(files)* Move some `IO::FileDescriptor` specs to the correct file ([#14431], thanks @HertzDevil)
- *(system)* Always preserve the environment for specs that modify `ENV` ([#14211], thanks @HertzDevil)
- *(system)* Ensure Windows time zone specs request `SeTimeZonePrivilege` properly ([#14297], thanks @HertzDevil)
- *(text)* Add single source of UTF-8 test sequences for specs ([#14433], thanks @HertzDevil)
- *(time)* Fix requires for `time/time_spec.cr` and `time/format_spec.cr` ([#14385], thanks @HertzDevil)

[#14302]: https://github.com/crystal-lang/crystal/pull/14302
[#14378]: https://github.com/crystal-lang/crystal/pull/14378
[#14431]: https://github.com/crystal-lang/crystal/pull/14431
[#14211]: https://github.com/crystal-lang/crystal/pull/14211
[#14297]: https://github.com/crystal-lang/crystal/pull/14297
[#14433]: https://github.com/crystal-lang/crystal/pull/14433
[#14385]: https://github.com/crystal-lang/crystal/pull/14385

#### compiler

- Remove the prelude from some compiler specs ([#14336], thanks @HertzDevil)
- *(interpreter)* Fix: don't run thread specs with the interpreter ([#14287], thanks @ysbaddaden)
- *(interpreter)* Add `pending_interpreted` ([#14386], thanks @HertzDevil)
- *(interpreter)* Remove `spec/interpreter_std_spec.cr` ([#14399], thanks @HertzDevil)
- *(semantic)* Enable `@[Primitive(:va_arg)]` semantic spec on Windows ([#14338], thanks @HertzDevil)

[#14336]: https://github.com/crystal-lang/crystal/pull/14336
[#14287]: https://github.com/crystal-lang/crystal/pull/14287
[#14386]: https://github.com/crystal-lang/crystal/pull/14386
[#14399]: https://github.com/crystal-lang/crystal/pull/14399
[#14338]: https://github.com/crystal-lang/crystal/pull/14338

### Infrastructure

- Changelog for 1.12.0 ([#14232], thanks @straight-shoota)
- Remove filtering of already mentioned PRs ([#14229], thanks @straight-shoota)
- Mention RFC process in contribution instructions ([#14291], thanks @straight-shoota)
- Drop Nikola sponsor mention from Readme ([#14290], thanks @straight-shoota)
- Enhance changelog script to pull milestone info from GitHub ([#14230], thanks @straight-shoota)
- Add `shard.yml` ([#14365], thanks @straight-shoota)
- Update vendored dependencies ([#14373], thanks @straight-shoota)
- Fix `Milestone` JSON bindings in `github-changelog` helper ([#14404], thanks @straight-shoota)
- Make repository configurable for reusable `github-changelog` ([#14407], thanks @straight-shoota)
- Use link refs for PR links in changelog ([#14406], thanks @straight-shoota)
- Implement pagination for GitHub API in `github-changelog` helper ([#14412], thanks @straight-shoota)
- Add `scripts/update-changelog.sh` ([#14231], thanks @straight-shoota)
- Update distribution-scripts ([#14457], thanks @straight-shoota)
- Change some line endings from CRLF to LF ([#14299], thanks @HertzDevil)
- Update copyright year in NOTICE.md ([#14329], thanks @HertzDevil)
- Install system dependencies in the Windows GUI installer ([#14328], thanks @HertzDevil)
- Skip building `llvm_ext.cc` on LLVM 18 or above ([#14357], thanks @HertzDevil)
- *(ci)* Update previous Crystal release 1.11.0 ([#14189], thanks @straight-shoota)
- *(ci)* Update previous Crystal release 1.11.1 ([#14224], thanks @straight-shoota)
- *(ci)* Update previous Crystal release - 1.11.2 ([#14251], thanks @straight-shoota)
- *(ci)* Update GH Actions ([#14246], thanks @renovate)
- *(ci)* Upgrade `resource_class` for `test_preview_mt` ([#14274], thanks @straight-shoota)
- *(ci)* Upgrade from old machine images approaching EOL ([#14275], thanks @straight-shoota)
- *(ci)* Update Windows library versions ([#14355], thanks @HertzDevil)
- *(ci)* Update cachix/install-nix-action action to v26 ([#14375], thanks @renovate)
- *(ci)* Update shards 0.18.0 ([#14411], thanks @straight-shoota)
- *(ci)* Support LLVM 18.1 ([#14277], thanks @HertzDevil)
- *(ci)* Use `Makefile.win` for Shards on Windows CI ([#14414], thanks @HertzDevil)

[#14232]: https://github.com/crystal-lang/crystal/pull/14232
[#14229]: https://github.com/crystal-lang/crystal/pull/14229
[#14291]: https://github.com/crystal-lang/crystal/pull/14291
[#14290]: https://github.com/crystal-lang/crystal/pull/14290
[#14230]: https://github.com/crystal-lang/crystal/pull/14230
[#14365]: https://github.com/crystal-lang/crystal/pull/14365
[#14373]: https://github.com/crystal-lang/crystal/pull/14373
[#14404]: https://github.com/crystal-lang/crystal/pull/14404
[#14407]: https://github.com/crystal-lang/crystal/pull/14407
[#14406]: https://github.com/crystal-lang/crystal/pull/14406
[#14412]: https://github.com/crystal-lang/crystal/pull/14412
[#14231]: https://github.com/crystal-lang/crystal/pull/14231
[#14457]: https://github.com/crystal-lang/crystal/pull/14457
[#14299]: https://github.com/crystal-lang/crystal/pull/14299
[#14329]: https://github.com/crystal-lang/crystal/pull/14329
[#14328]: https://github.com/crystal-lang/crystal/pull/14328
[#14357]: https://github.com/crystal-lang/crystal/pull/14357
[#14189]: https://github.com/crystal-lang/crystal/pull/14189
[#14224]: https://github.com/crystal-lang/crystal/pull/14224
[#14251]: https://github.com/crystal-lang/crystal/pull/14251
[#14246]: https://github.com/crystal-lang/crystal/pull/14246
[#14274]: https://github.com/crystal-lang/crystal/pull/14274
[#14275]: https://github.com/crystal-lang/crystal/pull/14275
[#14355]: https://github.com/crystal-lang/crystal/pull/14355
[#14375]: https://github.com/crystal-lang/crystal/pull/14375
[#14411]: https://github.com/crystal-lang/crystal/pull/14411
[#14277]: https://github.com/crystal-lang/crystal/pull/14277
[#14414]: https://github.com/crystal-lang/crystal/pull/14414

## [1.11.2] (2024-01-18)

[1.11.2]: https://github.com/crystal-lang/crystal/releases/1.11.2

### Bugfixes

#### stdlib

- *(files)* Fix missing `cause` parameter from `IO::Error#initialize` ([#14242](https://github.com/crystal-lang/crystal/pull/14242), thanks @straight-shoota)
- *(runtime)* Always use `%p` for pointers in `Crystal::System.print_error` ([#14186](https://github.com/crystal-lang/crystal/pull/14186), thanks @HertzDevil)
- *(runtime)* Fixup for always use `%p` for pointers in `Crystal::System.print_error` ([#14221](https://github.com/crystal-lang/crystal/pull/14221), thanks @HertzDevil)

### Infrastructure

- Changelog for 1.11.2 ([#14249](https://github.com/crystal-lang/crystal/pull/14249), thanks @straight-shoota)

## [1.11.1] (2024-01-11)

[1.11.1]: https://github.com/crystal-lang/crystal/releases/1.11.1

### Bugfixes

#### stdlib

- *(crypto)* Revert "Fix OpenSSL error handling for EOF (support for OpenSSL 3.2) (#14169)" ([#14217](https://github.com/crystal-lang/crystal/pull/14217), thanks @straight-shoota)

#### compiler

- *(interpreter)* Remove pkg-config name for libgc as workaround for interpreter loader ([#14198](https://github.com/crystal-lang/crystal/pull/14198), thanks @straight-shoota)
- *(semantic)* Revert "Add `ReferenceStorage` for manual allocation of references (#14106)" ([#14207](https://github.com/crystal-lang/crystal/pull/14207), thanks @straight-shoota)

### Infrastructure

- Changelog for 1.11.1 ([#14208](https://github.com/crystal-lang/crystal/pull/14208), thanks @straight-shoota)
- Bump VERSION to 1.11.1-dev ([#14197](https://github.com/crystal-lang/crystal/pull/14197), thanks @straight-shoota)

## [1.11.0] (2024-01-08)

[1.11.0]: https://github.com/crystal-lang/crystal/releases/1.11.0

### Features

#### lang

- **[breaking]** Support `alignof` and `instance_alignof` ([#14087](https://github.com/crystal-lang/crystal/pull/14087), thanks @HertzDevil)
- *(annotations)* Support `dll` parameter in `@[Link]` ([#14131](https://github.com/crystal-lang/crystal/pull/14131), thanks @HertzDevil)
- *(macros)* Expose macro `Call` context via new `@caller` macro ivar ([#14048](https://github.com/crystal-lang/crystal/pull/14048), thanks @Blacksmoke16)

#### stdlib

- *(collection)* Add `Enumerable#present?` ([#13866](https://github.com/crystal-lang/crystal/pull/13866), thanks @straight-shoota)
- *(collection)* Add `Enumerable#each_step` and `Iterable#each_step` ([#13610](https://github.com/crystal-lang/crystal/pull/13610), thanks @baseballlover723)
- *(collection)* Add `Enumerable(T)#to_set(& : T -> U) : Set(U) forall U` ([#12654](https://github.com/crystal-lang/crystal/pull/12654), thanks @caspiano)
- *(collection)* Add `Enumerable(T)#to_a(& : T -> U) forall U` ([#12653](https://github.com/crystal-lang/crystal/pull/12653), thanks @caspiano)
- *(files)* Add `IO::Error#target` ([#13865](https://github.com/crystal-lang/crystal/pull/13865), thanks @straight-shoota)
- *(llvm)* Add `LLVM::OperandBundleDef#dispose` ([#14095](https://github.com/crystal-lang/crystal/pull/14095), thanks @HertzDevil)
- *(llvm)* Windows: Use local configuration for LLVM when linking dynamically ([#14101](https://github.com/crystal-lang/crystal/pull/14101), thanks @HertzDevil)
- *(macros)* Add `CharLiteral#ord` ([#13910](https://github.com/crystal-lang/crystal/pull/13910), thanks @refi64)
- *(macros)* Add macro methods for `MacroIf` and `MacroFor` nodes ([#13902](https://github.com/crystal-lang/crystal/pull/13902), thanks @sbsoftware)
- *(macros)* Expose doc comments on `ASTNode` when generating docs ([#14050](https://github.com/crystal-lang/crystal/pull/14050), thanks @Blacksmoke16)
- *(macros)* Add macro methods for `ModuleDef` ([#14063](https://github.com/crystal-lang/crystal/pull/14063), thanks @HertzDevil)
- *(macros)* Add macro methods for `Include` and `Extend` ([#14064](https://github.com/crystal-lang/crystal/pull/14064), thanks @HertzDevil)
- *(macros)* Add macro methods for `ClassDef`, `EnumDef`, `AnnotationDef` ([#14072](https://github.com/crystal-lang/crystal/pull/14072), thanks @HertzDevil)
- *(numeric)* Implement `BigRational`'s rounding modes ([#13871](https://github.com/crystal-lang/crystal/pull/13871), thanks @HertzDevil)
- *(numeric)* Support full exponent range in `BigFloat#**(BigInt)` ([#13881](https://github.com/crystal-lang/crystal/pull/13881), thanks @HertzDevil)
- *(numeric)* Add `Math.fma` ([#13934](https://github.com/crystal-lang/crystal/pull/13934), thanks @HertzDevil)
- *(numeric)* Add `Number#integer?` ([#13936](https://github.com/crystal-lang/crystal/pull/13936), thanks @HertzDevil)
- *(numeric)* Publish `Int::Primitive#abs_unsigned` and `#neg_signed` ([#13938](https://github.com/crystal-lang/crystal/pull/13938), thanks @HertzDevil)
- *(numeric)* Add `Int::Primitive#to_signed`, `#to_signed!`, `#to_unsigned`, `#to_unsigned!` ([#13960](https://github.com/crystal-lang/crystal/pull/13960), thanks @HertzDevil)
- *(numeric)* Support `BigFloat#**` for all `Int::Primitive` arguments ([#13971](https://github.com/crystal-lang/crystal/pull/13971), thanks @HertzDevil)
- *(numeric)* Add `Float32::MIN_SUBNORMAL` and `Float64::MIN_SUBNORMAL` ([#13961](https://github.com/crystal-lang/crystal/pull/13961), thanks @HertzDevil)
- *(numeric)* Add `Float::Primitive.parse_hexfloat`, `.parse_hexfloat?`, `#to_hexfloat` ([#14027](https://github.com/crystal-lang/crystal/pull/14027), thanks @HertzDevil)
- *(numeric)* Implement `sprintf "%f"` in Crystal using Ryu Printf ([#14067](https://github.com/crystal-lang/crystal/pull/14067), thanks @HertzDevil)
- *(numeric)* Implement `sprintf "%e"` in Crystal ([#14084](https://github.com/crystal-lang/crystal/pull/14084), thanks @HertzDevil)
- *(numeric)* Implement `sprintf "%a"` in Crystal ([#14102](https://github.com/crystal-lang/crystal/pull/14102), thanks @HertzDevil)
- *(numeric)* Implement `sprintf "%g"` in Crystal ([#14123](https://github.com/crystal-lang/crystal/pull/14123), thanks @HertzDevil)
- *(runtime)* Add `Crystal::HOST_TRIPLE` and `TARGET_TRIPLE` ([#13823](https://github.com/crystal-lang/crystal/pull/13823), thanks @HertzDevil)
- *(runtime)* **[experimental]** Add `Reference.pre_initialize` and `.unsafe_construct` ([#14108](https://github.com/crystal-lang/crystal/pull/14108), thanks @HertzDevil)
- *(runtime)* **[experimental]** Add `ReferenceStorage` for manual allocation of references ([#14106](https://github.com/crystal-lang/crystal/pull/14106), thanks @HertzDevil)
- *(serialization)* Fix `StaticArray#to_json` ([#14104](https://github.com/crystal-lang/crystal/pull/14104), thanks @Vendicated)
- *(specs)* Add `crystal spec --dry-run` ([#13804](https://github.com/crystal-lang/crystal/pull/13804), thanks @nobodywasishere)
- *(specs)* Add `crystal spec --list-tags` ([#13616](https://github.com/crystal-lang/crystal/pull/13616), thanks @baseballlover723)
- *(system)* Respect Windows `Path` directory separators in `File.match?` ([#13912](https://github.com/crystal-lang/crystal/pull/13912), thanks @HertzDevil)
- *(text)* Support Unicode 15.1.0 ([#13812](https://github.com/crystal-lang/crystal/pull/13812), thanks @HertzDevil)
- *(text)* Add `UUID.v1`, `.v2`, `.v3`, `.v4`, `.v5` ([#13693](https://github.com/crystal-lang/crystal/pull/13693), thanks @threez)
- *(text)* Add `String` and `Char` patterns to `StringScanner` ([#13806](https://github.com/crystal-lang/crystal/pull/13806), thanks @funny-falcon)
- *(text)* Add `EOL`constant (End-Of-Line) ([#11303](https://github.com/crystal-lang/crystal/pull/11303), thanks @postmodern)
- *(text)* Add `Char::Reader#current_char?`, `#next_char?`, `#previous_char?` ([#14012](https://github.com/crystal-lang/crystal/pull/14012), thanks @HertzDevil)
- *(text)* Add `String#matches_full?` ([#13968](https://github.com/crystal-lang/crystal/pull/13968), thanks @straight-shoota)
- *(text)* Change `Regex::MatchData#to_s` to return matched substring ([#14115](https://github.com/crystal-lang/crystal/pull/14115), thanks @Vendicated)

#### compiler

- *(codegen)* Add incremental optimization levels ([#13464](https://github.com/crystal-lang/crystal/pull/13464), thanks @kostya)
- *(debugger)* Support debug information for 64-bit or unsigned enums ([#14081](https://github.com/crystal-lang/crystal/pull/14081), thanks @HertzDevil)
- *(interpreter)* Support `instance_sizeof(T)` in the interpreter ([#14031](https://github.com/crystal-lang/crystal/pull/14031), thanks @HertzDevil)
- *(interpreter)* Support `-dynamic.lib` in Windows interpreter ([#14143](https://github.com/crystal-lang/crystal/pull/14143), thanks @HertzDevil)
- *(interpreter)* Support absolute paths in `CRYSTAL_INTERPRETER_LOADER_INFO` ([#14147](https://github.com/crystal-lang/crystal/pull/14147), thanks @HertzDevil)
- *(interpreter)* Add `Crystal::Repl#parse_and_interpret` ([#14138](https://github.com/crystal-lang/crystal/pull/14138), thanks @bcardiff)
- *(semantic)* Change short_reference for top-level methods to `::foo` ([#14071](https://github.com/crystal-lang/crystal/pull/14071), thanks @keshavbiswa)

#### tools

- *(docs-generator)* Expose inherited macros in generated API docs ([#13810](https://github.com/crystal-lang/crystal/pull/13810), thanks @Blacksmoke16)
- *(docs-generator)* Order macros below class methods in generated docs ([#14024](https://github.com/crystal-lang/crystal/pull/14024), thanks @Blacksmoke16)
- *(formatter)* Do not remove trailing comma from multi-line macro/def parameters (not yet enabled) ([#14075](https://github.com/crystal-lang/crystal/pull/14075), thanks @Blacksmoke16)
- *(unreachable)* Add `--check` flag to `crystal tool unreachable` ([#13930](https://github.com/crystal-lang/crystal/pull/13930), thanks @straight-shoota)
- *(unreachable)* Add annotations to output of `crystal tool unreachable` ([#13927](https://github.com/crystal-lang/crystal/pull/13927), thanks @straight-shoota)
- *(unreachable)* Print relative paths in `crystal tool unreachable` ([#13929](https://github.com/crystal-lang/crystal/pull/13929), thanks @straight-shoota)
- *(unreachable)* Add CSV output format to `crystal tool unreachable` ([#13926](https://github.com/crystal-lang/crystal/pull/13926), thanks @straight-shoota)
- *(unreachable)* Add `--tallies` option to `crystal tool unreachable` ([#13969](https://github.com/crystal-lang/crystal/pull/13969), thanks @straight-shoota)

### Bugfixes

#### stdlib

- Fix `Box(T?)` crashing on `nil` ([#13893](https://github.com/crystal-lang/crystal/pull/13893), thanks @HertzDevil)
- Fix typos in src ([#14053](https://github.com/crystal-lang/crystal/pull/14053), thanks @kojix2)
- *(collection)* Fix `Indexable#each_repeated_combination(n)` when `n > size` ([#14092](https://github.com/crystal-lang/crystal/pull/14092), thanks @HertzDevil)
- *(concurrency)* Make `Process#wait` asynchronous on Windows ([#13908](https://github.com/crystal-lang/crystal/pull/13908), thanks @HertzDevil)
- *(concurrency)* Fix math overflow after spawning `Int32::MAX + 1` fibers ([#14096](https://github.com/crystal-lang/crystal/pull/14096), thanks @ysbaddaden)
- *(concurrency)* Fix `can't resume a running fiber` ([#14128](https://github.com/crystal-lang/crystal/pull/14128), thanks @ysbaddaden)
- *(crypto)* Fix OpenSSL error handling for EOF (support for OpenSSL 3.2) ([#14169](https://github.com/crystal-lang/crystal/pull/14169), thanks @straight-shoota)
- *(files)* Fix `Globber.constant_entry?` matching patterns ([#13955](https://github.com/crystal-lang/crystal/pull/13955), thanks @GeopJr)
- *(files)* Fix `String::Buffer` and `IO::Memory` capacity to grow beyond 1GB ([#13989](https://github.com/crystal-lang/crystal/pull/13989), thanks @straight-shoota)
- *(llvm)* Fix a typo ([#13914](https://github.com/crystal-lang/crystal/pull/13914), thanks @kojix2)
- *(numeric)* Make `String#to_f(whitespace: false)` work with infinity and NaN ([#13875](https://github.com/crystal-lang/crystal/pull/13875), thanks @HertzDevil)
- *(numeric)* Use `LibGMP::SI` and `UI` for size checks, not `Long` and `ULong` ([#13874](https://github.com/crystal-lang/crystal/pull/13874), thanks @HertzDevil)
- *(numeric)* Fix integral part extraction in `Number#format` ([#14061](https://github.com/crystal-lang/crystal/pull/14061), thanks @HertzDevil)
- *(numeric)* Fix out-of-bounds access in `Int128::MIN.to_s(base: 2)` ([#14119](https://github.com/crystal-lang/crystal/pull/14119), thanks @HertzDevil)
- *(numeric)* Avoid double rounding in `Float#format` for nonnegative `decimal_place` ([#14129](https://github.com/crystal-lang/crystal/pull/14129), thanks @HertzDevil)
- *(runtime)* Avoid `@[ThreadLocal]` on Android ([#14025](https://github.com/crystal-lang/crystal/pull/14025), thanks @HertzDevil)
- *(runtime)* Never use string interpolation in `Crystal::System.print_error` ([#14114](https://github.com/crystal-lang/crystal/pull/14114), thanks @HertzDevil)
- *(runtime)* Fix segfault with next boehm gc (after v8.2.4) ([#14130](https://github.com/crystal-lang/crystal/pull/14130), thanks @ysbaddaden)
- *(specs)* Skip spec execution on error exit ([#13986](https://github.com/crystal-lang/crystal/pull/13986), thanks @straight-shoota)
- *(system)* Fix `FileUtils.ln_sf` to override special file types ([#13896](https://github.com/crystal-lang/crystal/pull/13896), thanks @straight-shoota)
- *(system)* Fix `Process.exists?` throwing errors on EPERM ([#13911](https://github.com/crystal-lang/crystal/pull/13911), thanks @refi64)
- *(system)* Fix portable shell command arguments in `Process#prepare_args` ([#13942](https://github.com/crystal-lang/crystal/pull/13942), thanks @GeopJr)
- *(system)* Windows: Do not close process handle in `Process#close` ([#13997](https://github.com/crystal-lang/crystal/pull/13997), thanks @HertzDevil)
- *(system)* Windows: clear `Crystal::System::Process#@completion_key` after use ([#14068](https://github.com/crystal-lang/crystal/pull/14068), thanks @HertzDevil)
- *(system)* Fix UTF-8 console input on Windows ([#13758](https://github.com/crystal-lang/crystal/pull/13758), thanks @erdian718)
- *(text)* Fix invalid UTF-8 handling in `Char::Reader#previous_char` ([#14013](https://github.com/crystal-lang/crystal/pull/14013), thanks @HertzDevil)
- *(text)* Fix `options` parameter for `String#split`, `#scan` ([#14183](https://github.com/crystal-lang/crystal/pull/14183), thanks @straight-shoota)
- *(time)* Fix time span overflow on `Int#milliseconds` and `Int#microseconds` ([#14105](https://github.com/crystal-lang/crystal/pull/14105), thanks @bcardiff)

#### compiler

- *(cli)* Remove unnecessary file check for CLI arguments ([#13853](https://github.com/crystal-lang/crystal/pull/13853), thanks @straight-shoota)
- *(cli)* Check for invalid integers in compiler's CLI ([#13959](https://github.com/crystal-lang/crystal/pull/13959), thanks @HertzDevil)
- *(cli)* Fix compiler error message for invalid source file ([#14157](https://github.com/crystal-lang/crystal/pull/14157), thanks @straight-shoota)
- *(codegen)* Fix a typo in compiler source ([#14054](https://github.com/crystal-lang/crystal/pull/14054), thanks @kojix2)
- *(codegen)* Fix codegen error when discarding `is_a?` or `responds_to?`'s result ([#14148](https://github.com/crystal-lang/crystal/pull/14148), thanks @HertzDevil)
- *(interpreter)* Fix element alignment of `Tuple` and `NamedTuple` casts ([#14040](https://github.com/crystal-lang/crystal/pull/14040), thanks @HertzDevil)
- *(interpreter)* `Crystal::Loader`: Skip second linker member on Windows if absent ([#14111](https://github.com/crystal-lang/crystal/pull/14111), thanks @HertzDevil)
- *(parser)* Support `%r` and `%x` when not followed by delimiter start ([#13933](https://github.com/crystal-lang/crystal/pull/13933), thanks @HertzDevil)
- *(parser)* Fix location of global `Path` nodes in certain constructs ([#13932](https://github.com/crystal-lang/crystal/pull/13932), thanks @HertzDevil)
- *(parser)* Fix `ToSVisitor` for expanded string interpolation in backticks ([#13943](https://github.com/crystal-lang/crystal/pull/13943), thanks @straight-shoota)
- *(parser)* Fix location for "invalid trailing comma in call" errors ([#13964](https://github.com/crystal-lang/crystal/pull/13964), thanks @HertzDevil)
- *(semantic)* Fix check for file type ([#13760](https://github.com/crystal-lang/crystal/pull/13760), thanks @straight-shoota)
- *(semantic)* Fix private type definitions with namespaced `Path`s ([#13931](https://github.com/crystal-lang/crystal/pull/13931), thanks @HertzDevil)
- *(semantic)* Fix missing param count in compilation error message ([#13985](https://github.com/crystal-lang/crystal/pull/13985), thanks @koffeinfrei)
- *(semantic)* Fix `ReadInstanceVar` on typedefs ([#14044](https://github.com/crystal-lang/crystal/pull/14044), thanks @HertzDevil)
- *(semantic)* Fix global `Path` lookup inside macro when def has free variables ([#14073](https://github.com/crystal-lang/crystal/pull/14073), thanks @HertzDevil)
- *(semantic)* Add location information to implicit flag enum members ([#14127](https://github.com/crystal-lang/crystal/pull/14127), thanks @Blacksmoke16)

#### tools

- *(docs-generator)* Fix `crystal docs` check `File.exists?` for `shard.yml` ([#13937](https://github.com/crystal-lang/crystal/pull/13937), thanks @straight-shoota)
- *(docs-generator)* Fix version sorting in API docs ([#13994](https://github.com/crystal-lang/crystal/pull/13994), thanks @m-o-e)
- *(docs-generator)* Strip whitespace in doc comment before determining summary line ([#14049](https://github.com/crystal-lang/crystal/pull/14049), thanks @Blacksmoke16)
- *(docs-generator)* Skip `Crystal::Macros` unless generating docs ([#13970](https://github.com/crystal-lang/crystal/pull/13970), thanks @straight-shoota)
- *(init)* Fix tool init error message when target exists but not a dir ([#13869](https://github.com/crystal-lang/crystal/pull/13869), thanks @straight-shoota)
- *(unreachable)* Fix infinite recursion of expanded nodes in `UnreachableVisitor` ([#13922](https://github.com/crystal-lang/crystal/pull/13922), thanks @straight-shoota)

### Chores

#### lang

- *(macros)* **[deprecation]** Deprecate the splat operators in macro expressions ([#13939](https://github.com/crystal-lang/crystal/pull/13939), thanks @HertzDevil)

#### stdlib

- *(llvm)* **[deprecation]** Deprecate `LLVM.start_multithreaded` and `.stop_multithreaded` ([#13949](https://github.com/crystal-lang/crystal/pull/13949), thanks @HertzDevil)

### Performance

#### stdlib

- *(concurrency)* Skip indirections in `Crystal::Scheduler` ([#14098](https://github.com/crystal-lang/crystal/pull/14098), thanks @ysbaddaden)
- *(numeric)* Optimize `BigInt#&`, `#|`, `#^` with `Int::Primitive` arguments ([#14006](https://github.com/crystal-lang/crystal/pull/14006), thanks @HertzDevil)
- *(numeric)* Optimize `BigInt#bit` ([#13980](https://github.com/crystal-lang/crystal/pull/13980), thanks @HertzDevil)
- *(numeric)* Use `#trailing_zeros_count` in `Int#gcd` ([#14069](https://github.com/crystal-lang/crystal/pull/14069), thanks @HertzDevil)
- *(serialization)* Optimize `JSON::Builder#string` with byte-based algorithm ([#13915](https://github.com/crystal-lang/crystal/pull/13915), thanks @straight-shoota)
- *(serialization)* Improve performance of `JSON::Builder#string` with direct stringification ([#13950](https://github.com/crystal-lang/crystal/pull/13950), thanks @straight-shoota)
- *(text)* Refactor `HTML.unescape` in native Crystal ([#13844](https://github.com/crystal-lang/crystal/pull/13844), thanks @straight-shoota)
- *(text)* Refactor some uses of the blockless `String#split` ([#14001](https://github.com/crystal-lang/crystal/pull/14001), thanks @HertzDevil)

### Refactor

#### stdlib

- *(concurrency)* Add `Crystal::System::Thread` ([#13814](https://github.com/crystal-lang/crystal/pull/13814), thanks @HertzDevil)
- *(concurrency)* Move `Thread#set_current_thread` to `Fiber` ([#14099](https://github.com/crystal-lang/crystal/pull/14099), thanks @ysbaddaden)
- *(files)* Use `IO.copy` in `IO#gets_to_end` ([#13990](https://github.com/crystal-lang/crystal/pull/13990), thanks @straight-shoota)
- *(files)* Do not use `pointerof(Path)` in the standard library ([#14144](https://github.com/crystal-lang/crystal/pull/14144), thanks @HertzDevil)
- *(llvm)* **[deprecation]** Remove `LLVMExtSetCurrentDebugLocation` from `llvm_ext.cc` for LLVM 9+ ([#13965](https://github.com/crystal-lang/crystal/pull/13965), thanks @HertzDevil)
- *(llvm)* Replace some deprecated LLVM bindings ([#13953](https://github.com/crystal-lang/crystal/pull/13953), thanks @HertzDevil)
- *(llvm)* Split `LibLLVM` by C headers ([#13948](https://github.com/crystal-lang/crystal/pull/13948), thanks @HertzDevil)
- *(llvm)* Support `LLVMSetTargetMachineGlobalISel` from LLVM 18 ([#14079](https://github.com/crystal-lang/crystal/pull/14079), thanks @HertzDevil)
- *(llvm)* Support the operand bundle API from LLVM 18 ([#14082](https://github.com/crystal-lang/crystal/pull/14082), thanks @HertzDevil)
- *(numeric)* Simplify `String::Formatter` when Ryu Printf is available ([#14132](https://github.com/crystal-lang/crystal/pull/14132), thanks @HertzDevil)
- *(runtime)* Implement most of `Crystal::System.print_error` in native Crystal ([#14116](https://github.com/crystal-lang/crystal/pull/14116), thanks @HertzDevil)
- *(text)* Drop `Char::Reader#@end` ([#13920](https://github.com/crystal-lang/crystal/pull/13920), thanks @straight-shoota)
- *(text)* Generate `src/html/entities.cr` automatically ([#13998](https://github.com/crystal-lang/crystal/pull/13998), thanks @HertzDevil)
- *(time)* Refactor leap year to use `divisible_by?` ([#13982](https://github.com/crystal-lang/crystal/pull/13982), thanks @meatball133)

#### compiler

- Remove relative path to vendored shards `markd` and `reply` ([#13992](https://github.com/crystal-lang/crystal/pull/13992), thanks @nobodywasishere)
- *(cli)* Generalize allowed values for compiler CLI `--format` option ([#13940](https://github.com/crystal-lang/crystal/pull/13940), thanks @straight-shoota)
- *(parser)* Use `Char#to_i?` in lexer ([#13841](https://github.com/crystal-lang/crystal/pull/13841), thanks @straight-shoota)

#### tools

- *(unreachable)* Refactor `UnreachablePresenter` ([#13941](https://github.com/crystal-lang/crystal/pull/13941), thanks @straight-shoota)

### Documentation

#### lang

- *(macros)* Add reference to book how merging macro expansion and call docs ([#14139](https://github.com/crystal-lang/crystal/pull/14139), thanks @Blacksmoke16)

#### stdlib

- *(collection)* Fix documentation of `Hash#put_if_absent` ([#13898](https://github.com/crystal-lang/crystal/pull/13898), thanks @ilmanzo)
- *(collection)* Improve docs on initial/default values passed to `Array.new` and `Hash.new` ([#13962](https://github.com/crystal-lang/crystal/pull/13962), thanks @straight-shoota)
- *(collection)* Improve docs for `Iterator` step-by-step iteration ([#13967](https://github.com/crystal-lang/crystal/pull/13967), thanks @straight-shoota)
- *(macros)* Document `Crystal::Macros::MagicConstant` ([#14070](https://github.com/crystal-lang/crystal/pull/14070), thanks @HertzDevil)
- *(serialization)* Add docs and explicit type restriction for indent parameter of `JSON.build` ([#14140](https://github.com/crystal-lang/crystal/pull/14140), thanks @syeopite)
- *(text)* Add note about `Char::Reader`'s value semantics ([#14008](https://github.com/crystal-lang/crystal/pull/14008), thanks @HertzDevil)
- *(text)* Fix documentation for `String#index!` ([#14038](https://github.com/crystal-lang/crystal/pull/14038), thanks @gettalong)

#### compiler

- *(cli)* Add optimization levels to manpage ([#14162](https://github.com/crystal-lang/crystal/pull/14162), thanks @straight-shoota)
- *(cli)* Add `unreachable` options to manpage ([#14164](https://github.com/crystal-lang/crystal/pull/14164), thanks @straight-shoota)
- *(cli)* Fix formatting in manpage ([#14163](https://github.com/crystal-lang/crystal/pull/14163), thanks @straight-shoota)

### Specs

#### stdlib

- Add `pending_wasm32` ([#14086](https://github.com/crystal-lang/crystal/pull/14086), thanks @HertzDevil)
- *(concurrency)* Workaround regular timeouts in `HTTP::Server` specs with MT ([#14097](https://github.com/crystal-lang/crystal/pull/14097), thanks @ysbaddaden)
- *(files)* Fix `File::AccessDeniedError` expectations in `File` specs ([#14029](https://github.com/crystal-lang/crystal/pull/14029), thanks @HertzDevil)
- *(text)* Refactor specs for `HTML.unescape` ([#13842](https://github.com/crystal-lang/crystal/pull/13842), thanks @straight-shoota)
- *(text)* Fix spec for `String#encode` and `String.new` on DragonFlyBSD ([#13944](https://github.com/crystal-lang/crystal/pull/13944), thanks @GeopJr)

#### compiler

- *(codegen)* Remove `LLVMExtCreateMCJITCompilerForModule` from `llvm_ext.cc` ([#13966](https://github.com/crystal-lang/crystal/pull/13966), thanks @HertzDevil)
- *(interpreter)* Disable `mkfifo` spec for interpreter ([#14051](https://github.com/crystal-lang/crystal/pull/14051), thanks @HertzDevil)
- *(interpreter)* Fix interpreter specs on Windows ([#14145](https://github.com/crystal-lang/crystal/pull/14145), thanks @HertzDevil)

#### tools

- *(docs-generator)* Use `top_level_semantic` in doc spec instead of `semantic` ([#9352](https://github.com/crystal-lang/crystal/pull/9352), thanks @makenowjust)

### Infrastructure

- Changelog for 1.11.0 ([#14158](https://github.com/crystal-lang/crystal/pull/14158), thanks @straight-shoota)
- Update previous Crystal release - 1.10.0 ([#13878](https://github.com/crystal-lang/crystal/pull/13878), thanks @straight-shoota)
- Allow to specify git fork of distribution-scripts in CI ([#13976](https://github.com/crystal-lang/crystal/pull/13976), thanks @miry)
- Extract `generate_data` to separate Makefile ([#14015](https://github.com/crystal-lang/crystal/pull/14015), thanks @straight-shoota)
- Windows: Run specs in random order by default ([#14041](https://github.com/crystal-lang/crystal/pull/14041), thanks @HertzDevil)
- Update shards 0.17.4 ([#14133](https://github.com/crystal-lang/crystal/pull/14133), thanks @straight-shoota)
- Update distribution-scripts ([#14136](https://github.com/crystal-lang/crystal/pull/14136), thanks @straight-shoota)
- Update GH Actions to v4 ([#14120](https://github.com/crystal-lang/crystal/pull/14120), thanks @renovate)
- Embed logo image into repository and upgrade to SVG ([#14137](https://github.com/crystal-lang/crystal/pull/14137), thanks @straight-shoota)
- Improvements for `github-changelog` script ([#14160](https://github.com/crystal-lang/crystal/pull/14160), thanks @straight-shoota)
- Add `scripts/generate_llvm_version_info.cr` ([#14112](https://github.com/crystal-lang/crystal/pull/14112), thanks @HertzDevil)
- Fix `make clean` to remove zipped manpages ([#14135](https://github.com/crystal-lang/crystal/pull/14135), thanks @straight-shoota)
- Make `scripts/*.cr` all executable ([#13999](https://github.com/crystal-lang/crystal/pull/13999), thanks @HertzDevil)
- Reformat changelog release headings ([#13663](https://github.com/crystal-lang/crystal/pull/13663), thanks @straight-shoota)
- Merge `samples/.gitignore` into `.gitignore` ([#14134](https://github.com/crystal-lang/crystal/pull/14134), thanks @straight-shoota)
- *(ci)* Update GH Actions ([#13801](https://github.com/crystal-lang/crystal/pull/13801), thanks @renovate)
- *(ci)* Update LLVM patch version to LLVM 17.0.6 ([#14080](https://github.com/crystal-lang/crystal/pull/14080), thanks @straight-shoota)
- *(ci)* Configure Renovate Bot to add label `topic:infrastructure/ci` on PRs ([#14166](https://github.com/crystal-lang/crystal/pull/14166), thanks @straight-shoota)
- *(ci)* Update GH Actions ([#14165](https://github.com/crystal-lang/crystal/pull/14165), thanks @renovate)
- *(ci)* Distribute LLVM DLLs on Windows CI ([#14110](https://github.com/crystal-lang/crystal/pull/14110), thanks @HertzDevil)
- *(ci)* Use `CMAKE_MSVC_RUNTIME_LIBRARY` flag in win.yml ([#13900](https://github.com/crystal-lang/crystal/pull/13900), thanks @HertzDevil)

## [1.10.1] (2023-10-13)

[1.10.1]: https://github.com/crystal-lang/crystal/releases/1.10.1

### Bugfixes

#### stdlib

- `IO#gets` should have same result regardless of `#peek` availability ([#13882](https://github.com/crystal-lang/crystal/pull/13882), thanks @compumike)
- Support Android API levels 24 - 27 ([#13884](https://github.com/crystal-lang/crystal/pull/13884), thanks @HertzDevil)

### Infrastructure

- *(ci)* Fix `win.yml` ([#13876](https://github.com/crystal-lang/crystal/pull/13876), thanks @straight-shoota)

## [1.10.0] (2023-10-09)

[1.10.0]: https://github.com/crystal-lang/crystal/releases/1.10.0

### Features

#### lang

- Add unlimited block unpacking ([#11597](https://github.com/crystal-lang/crystal/pull/11597), thanks @asterite)

#### stdlib

- Add more `Colorize::Mode` flags ([#13745](https://github.com/crystal-lang/crystal/pull/13745), thanks @HertzDevil)
- *(collection)* Add `Hash#put_if_absent` ([#13590](https://github.com/crystal-lang/crystal/pull/13590), thanks @HertzDevil)
- *(collection)* Add `Set#rehash` ([#13630](https://github.com/crystal-lang/crystal/pull/13630), thanks @HertzDevil)
- *(collection)* Add yield `key` in `Hash#transform_values` and `value` in `#transform_keys` ([#13608](https://github.com/crystal-lang/crystal/pull/13608), thanks @baseballlover723)
- *(crypto)* Upgrade SSL defaults to Mozilla guidelines version 5.7 ([#13685](https://github.com/crystal-lang/crystal/pull/13685), thanks @straight-shoota)
- *(crypto)* **[security]** Allow OpenSSL clients to choose cipher ([#13695](https://github.com/crystal-lang/crystal/pull/13695), thanks @carlhoerberg)
- *(files)* Add `File#rename` ([#13640](https://github.com/crystal-lang/crystal/pull/13640), thanks @carlhoerberg)
- *(llvm)* Support LLVM 17 ([#13782](https://github.com/crystal-lang/crystal/pull/13782), thanks @HertzDevil)
- *(networking)* Add overloads for `URI::Params.encode` with `IO` parameter ([#13798](https://github.com/crystal-lang/crystal/pull/13798), thanks @jwoertink)
- *(numeric)* Add `Complex#to_i128`, `Complex#to_u128` ([#13838](https://github.com/crystal-lang/crystal/pull/13838), thanks @HertzDevil)
- *(runtime)* Add additional fields to `GC:ProfStats` ([#13734](https://github.com/crystal-lang/crystal/pull/13734), thanks @carlhoerberg)
- *(serialization)* Support YAML deserialization of 128-bit integers ([#13834](https://github.com/crystal-lang/crystal/pull/13834), thanks @HertzDevil)
- *(serialization)* Support 128-bit integers in `JSON::PullParser#read?` ([#13837](https://github.com/crystal-lang/crystal/pull/13837), thanks @HertzDevil)
- *(specs)* **[breaking]** Change spec runner to exit with failure for `focus: true` ([#13653](https://github.com/crystal-lang/crystal/pull/13653), thanks @straight-shoota)
- *(text)* Add `String#byte_index(Char)` ([#13819](https://github.com/crystal-lang/crystal/pull/13819), thanks @funny-falcon)
- *(time)* Support Android's system timezone database ([#13666](https://github.com/crystal-lang/crystal/pull/13666), thanks @HertzDevil)

#### compiler

- Experimental: Add `Slice.literal` for numeric slice constants ([#13716](https://github.com/crystal-lang/crystal/pull/13716), thanks @HertzDevil)

#### tools

- Add `tool unreachable` ([#13783](https://github.com/crystal-lang/crystal/pull/13783), thanks @straight-shoota)
- *(dependencies)* Add `crystal tool dependencies` ([#13631](https://github.com/crystal-lang/crystal/pull/13631), thanks @straight-shoota)
- *(docs-generator)* Add CSS for tables ([#13822](https://github.com/crystal-lang/crystal/pull/13822), thanks @nobodywasishere)
- *(hierarchy)* Support generic types in `crystal tool hierarchy` ([#13715](https://github.com/crystal-lang/crystal/pull/13715), thanks @HertzDevil)
- *(playground)* Update octicons to v19.5.0 ([#13738](https://github.com/crystal-lang/crystal/pull/13738), thanks @GeopJr)

### Bugfixes

#### lang

- *(macros)* Fix missing normalization of macro expressions (and others) ([#13709](https://github.com/crystal-lang/crystal/pull/13709), thanks @asterite)
- *(macros)* Fix block parameter unpacking inside macros ([#13813](https://github.com/crystal-lang/crystal/pull/13813), thanks @HertzDevil)

#### stdlib

- *(collection)* **[breaking]** Mark the return type of methods such as `Slice#copy_to` as `Nil` ([#13774](https://github.com/crystal-lang/crystal/pull/13774), thanks @erdian718)
- *(files)* Change `IO::Buffered#peek`'s return type to `Bytes` ([#13863](https://github.com/crystal-lang/crystal/pull/13863), thanks @HertzDevil)
- *(llvm)* Chop git suffix from `LibLLVM::VERSION` ([#13699](https://github.com/crystal-lang/crystal/pull/13699), thanks @HOMODELUNA)
- *(macros)* Do not add trailing `+` in `TypeNode#id` for virtual types ([#13708](https://github.com/crystal-lang/crystal/pull/13708), thanks @HertzDevil)
- *(numeric)* Fix `BigDecimal#round` for large digit counts in base 10 ([#13811](https://github.com/crystal-lang/crystal/pull/13811), thanks @HertzDevil)
- *(serialization)* Set encoding in `XML.parse_html` explicitly to UTF-8 ([#13705](https://github.com/crystal-lang/crystal/pull/13705), thanks @straight-shoota)
- *(serialization)* Fix error message when parsing unknown JSON enum value ([#13728](https://github.com/crystal-lang/crystal/pull/13728), thanks @willhbr)
- *(serialization)* Fix YAML scalar type validation error message ([#13771](https://github.com/crystal-lang/crystal/pull/13771), thanks @MistressRemilia)
- *(serialization)* Fix incorrect overflow in `UInt64.from_yaml` ([#13829](https://github.com/crystal-lang/crystal/pull/13829), thanks @HertzDevil)
- *(system)* Fix `Process.new` with nilable chdir parameter on Windows ([#13768](https://github.com/crystal-lang/crystal/pull/13768), thanks @straight-shoota)
- *(system)* Fix typo in unistd.cr ([#13850](https://github.com/crystal-lang/crystal/pull/13850), thanks @kojix2)
- *(text)* Fix `Char::Reader#each` bounds check after block ([#13817](https://github.com/crystal-lang/crystal/pull/13817), thanks @straight-shoota)
- *(text)* Minor fixup for `HTML.decode_codepoint` ([#13843](https://github.com/crystal-lang/crystal/pull/13843), thanks @straight-shoota)

#### compiler

- **[breaking]** Remove double `.cr.cr` extension in `require` path lookup ([#13749](https://github.com/crystal-lang/crystal/pull/13749), thanks @straight-shoota)
- *(parser)* Fix end location for `FunDef` ([#13789](https://github.com/crystal-lang/crystal/pull/13789), thanks @straight-shoota)
- *(semantic)* Fix lookup scope for `@[Primitive]` def's return type ([#13658](https://github.com/crystal-lang/crystal/pull/13658), thanks @HertzDevil)
- *(semantic)* Fix typo in call_error.cr ([#13764](https://github.com/crystal-lang/crystal/pull/13764), thanks @kojix2)

#### tools

- *(docs-generator)* Fix octicon-link icon color on dark mode ([#13670](https://github.com/crystal-lang/crystal/pull/13670), thanks @GeopJr)
- *(docs-generator)* Allow word breaks between module names in docs ([#13827](https://github.com/crystal-lang/crystal/pull/13827), thanks @nobodywasishere)
- *(docs-generator)* Fix docs dark mode dropdown background on blink ([#13840](https://github.com/crystal-lang/crystal/pull/13840), thanks @GeopJr)
- *(init)* Fix shard crystal version in `crystal init` ([#13730](https://github.com/crystal-lang/crystal/pull/13730), thanks @xendk)
- *(hierarchy)*: Fix byte sizes for `Proc`s inside extern structs ([#13711](https://github.com/crystal-lang/crystal/pull/13711), thanks @HertzDevil)

### Performance

#### stdlib

- Optimize `IO::Delimited` ([#11242](https://github.com/crystal-lang/crystal/pull/11242), thanks @asterite)
- *(crypto)* Use `IO::DEFAULT_BUFFER_SIZE` in `Digest#update` ([#13635](https://github.com/crystal-lang/crystal/pull/13635), thanks @carlhoerberg)
- *(crypto)* Fix memory leak in `OpenSSL::SSL::Socket#peer_certificate` ([#13785](https://github.com/crystal-lang/crystal/pull/13785), thanks @compumike)
- *(files)* Optimize `IO#read_string(0)` ([#13732](https://github.com/crystal-lang/crystal/pull/13732), thanks @jgaskins)
- *(files)* Avoid double file buffering ([#13780](https://github.com/crystal-lang/crystal/pull/13780), thanks @carlhoerberg)
- *(llvm)* Refactor `LLVM.default_target_triple` to avoid regex ([#13659](https://github.com/crystal-lang/crystal/pull/13659), thanks @straight-shoota)
- *(numeric)* Pre-allocate Dragonbox cache array ([#13649](https://github.com/crystal-lang/crystal/pull/13649), thanks @HertzDevil)
- *(runtime)* Avoid realloc callstack array when unwinding ([#13781](https://github.com/crystal-lang/crystal/pull/13781), thanks @carlhoerberg)
- *(time)* Optimize the constructors of `Time::Span` ([#13807](https://github.com/crystal-lang/crystal/pull/13807), thanks @erdian718)

### Refactor

#### stdlib

- Do not use nilable `Pointer`s ([#13710](https://github.com/crystal-lang/crystal/pull/13710), thanks @HertzDevil)
- *(collection)* Use `Set(T)` instead of `Hash(T, Bool)` ([#13611](https://github.com/crystal-lang/crystal/pull/13611), thanks @HertzDevil)
- *(concurrency)* Use `Fiber.inactive` inside `Fiber#run`'s `ensure` block ([#13701](https://github.com/crystal-lang/crystal/pull/13701), thanks @HertzDevil)
- *(crypto)* Use `JSON::Serializable` in `scripts/generate_ssl_server_defaults.cr` ([#13667](https://github.com/crystal-lang/crystal/pull/13667), thanks @HertzDevil)
- *(crypto)* Refactor narrow OpenSSL requires for digest implementations ([#13818](https://github.com/crystal-lang/crystal/pull/13818), thanks @straight-shoota)
- *(networking)* **[deprecation]** Add types to `HTTP::StaticFileHandler` ([#13778](https://github.com/crystal-lang/crystal/pull/13778), thanks @jkthorne)

#### compiler

- Restrict some boolean properties to `Bool` in the compiler ([#13614](https://github.com/crystal-lang/crystal/pull/13614), thanks @HertzDevil)

### Documentation

#### stdlib

- *(crypto)* Fix docs for `Digest::SHA512` ([#13796](https://github.com/crystal-lang/crystal/pull/13796), thanks @jgaskins)
- *(files)* Document `Dir#mkdir`, `Dir#exists?` ([#13795](https://github.com/crystal-lang/crystal/pull/13795), thanks @jkthorne)
- *(networking)* Add documentation for `HTTP::Headers#add` ([#13762](https://github.com/crystal-lang/crystal/pull/13762), thanks @jkthorne)
- *(text)* Fix typo in regex.cr ([#13751](https://github.com/crystal-lang/crystal/pull/13751), thanks @beta-ziliani)

### Specs

#### stdlib

- *(numeric)* Update specs for `Int::Primitive.from_json` ([#13835](https://github.com/crystal-lang/crystal/pull/13835), thanks @HertzDevil)
- *(numeric)* Remove overflowing `Float#to_u!` interpreter primitive specs ([#13737](https://github.com/crystal-lang/crystal/pull/13737), thanks @HertzDevil)
- *(time)* Clear `Time::Location` cache before `.load_android` specs ([#13718](https://github.com/crystal-lang/crystal/pull/13718), thanks @HertzDevil)

### Infrastructure

- Update previous Crystal release - 1.9.2 ([#13650](https://github.com/crystal-lang/crystal/pull/13650), thanks @straight-shoota)
- Update distribution-scripts ([#13776](https://github.com/crystal-lang/crystal/pull/13776), thanks @straight-shoota)
- make: Add `generate_data` target for running generator scripts ([#13700](https://github.com/crystal-lang/crystal/pull/13700), thanks @straight-shoota)
- Add shell completions for `clear_cache` ([#13636](https://github.com/crystal-lang/crystal/pull/13636), thanks @straight-shoota)
- New changelog format ([#13662](https://github.com/crystal-lang/crystal/pull/13662), thanks @straight-shoota)
- Detect developer mode in Windows installer ([#13681](https://github.com/crystal-lang/crystal/pull/13681), thanks @HertzDevil)
- Update PGP key link ([#13754](https://github.com/crystal-lang/crystal/pull/13754), thanks @syeopite)
- Fix log format in update-distribution-scripts.sh ([#13777](https://github.com/crystal-lang/crystal/pull/13777), thanks @straight-shoota)
- *(ci)* Trigger windows release jobs on tag ([#13683](https://github.com/crystal-lang/crystal/pull/13683), thanks @straight-shoota)
- *(ci)* Update GH Actions ([#13748](https://github.com/crystal-lang/crystal/pull/13748), thanks @renovate)
- *(ci)* Refactor `crystal_bootstrap_version` ([#13845](https://github.com/crystal-lang/crystal/pull/13845), thanks @straight-shoota)

## [1.9.2] - 2023-07-19

[1.9.2]: https://github.com/crystal-lang/crystal/releases/1.9.2

### Bugfixes

#### stdlib

- *(runtime)* Revert "Add default interrupt handlers" ([#13673](https://github.com/crystal-lang/crystal/pull/13673), thanks @straight-shoota)

## [1.9.1] - 2023-07-17

[1.9.1]: https://github.com/crystal-lang/crystal/releases/1.9.1

### Bugfixes

#### stdlib

- *(serialization)* Fix `Serializable` with converter parsing `null` value ([#13656](https://github.com/crystal-lang/crystal/pull/13656), thanks @straight-shoota)

#### compiler

- *(codegen)* Fix generated cc command for cross compile ([#13661](https://github.com/crystal-lang/crystal/pull/13661), thanks @fnordfish)

## [1.9.0] - 2023-07-11

[1.9.0]: https://github.com/crystal-lang/crystal/releases/1.9.0
### Breaking changes

#### stdlib

- *(numeric)* Handle NaNs when comparing `Big*` numbers against `Float` ([#13293](https://github.com/crystal-lang/crystal/pull/13293), [#13294](https://github.com/crystal-lang/crystal/pull/13294), [#13350](https://github.com/crystal-lang/crystal/pull/13350), [#13554](https://github.com/crystal-lang/crystal/pull/13554), thanks @HertzDevil)
- *(llvm)* Remove most `LLVM::DIBuilder` functions from `llvm_ext.cc` ([#13448](https://github.com/crystal-lang/crystal/pull/13448), thanks @HertzDevil)

### Features

#### lang

- *(macros)* Add `warning` macro ([#13262](https://github.com/crystal-lang/crystal/pull/13262), thanks @Blacksmoke16)
- *(macros)* Add `print` macro ([#13336](https://github.com/crystal-lang/crystal/pull/13336), thanks @jkthorne)

#### stdlib

- *(collection)* Add `Enumerable#in_slices_of` ([#13108](https://github.com/crystal-lang/crystal/pull/13108), thanks @pricelessrabbit)
- *(collection)* Add support for dash separator to `Enum.parse` ([#13508](https://github.com/crystal-lang/crystal/pull/13508), thanks @straight-shoota)
- *(collection)* Add `Enum#to_i128` and `#to_u128` ([#13576](https://github.com/crystal-lang/crystal/pull/13576), thanks @meatball133)
- *(collection)* Add `Enumerable#partition` overload with type filter ([#13572](https://github.com/crystal-lang/crystal/pull/13572), thanks @baseballlover723)
- *(concurrency)* Support asynchronous `IO.pipe` on Windows ([#13362](https://github.com/crystal-lang/crystal/pull/13362), thanks @HertzDevil)
- *(files)* **[deprecation]** Add `File::MatchOptions` to control `Dir.glob`'s behavior ([#13550](https://github.com/crystal-lang/crystal/pull/13550), thanks @HertzDevil)
- *(networking)* Implement `Socket#reuse_port` on Windows ([#13326](https://github.com/crystal-lang/crystal/pull/13326), thanks @stakach)
- *(networking)* Add multicast support to `UDPSocket` on Windows ([#13325](https://github.com/crystal-lang/crystal/pull/13325), thanks @stakach)
- *(networking)* HTTP Server should allow custom concurrency models ([#13428](https://github.com/crystal-lang/crystal/pull/13428), thanks @stakach)
- *(networking)* Add `Socket::IPaddress.v4`, `.v6`, `.v4_mapped_v6` ([#13422](https://github.com/crystal-lang/crystal/pull/13422), thanks @HertzDevil)
- *(networking)* Add `URI::Params#merge`, `#merge!` and `URI#update_query_params` ([#13415](https://github.com/crystal-lang/crystal/pull/13415), thanks @skinnyjames)
- *(networking)* Support Unix sockets on Windows ([#13493](https://github.com/crystal-lang/crystal/pull/13493), thanks @HertzDevil)
- *(networking)* Add `HTTP::Request#form_params` ([#13418](https://github.com/crystal-lang/crystal/pull/13418), thanks @threez)
- *(numeric)* Add `BigDecimal#%` ([#13255](https://github.com/crystal-lang/crystal/pull/13255), thanks @MattAlp)
- *(numeric)* Improve conversions from `BigInt` to `Int::Primitive` ([#13562](https://github.com/crystal-lang/crystal/pull/13562), thanks @HertzDevil)
- *(runtime)* Print error if unable to delay-load DLL on Windows ([#13475](https://github.com/crystal-lang/crystal/pull/13475), thanks @HertzDevil)
- *(runtime)* Add default interrupt handlers ([#13568](https://github.com/crystal-lang/crystal/pull/13568), thanks @straight-shoota) ⚠️ This was reverted in 1.9.2
- *(serialization)* Add `ignore_serialize` for `YAML::Serializable` ([#13556](https://github.com/crystal-lang/crystal/pull/13556), thanks @meatball133)
- *(specs)* Add a testcase line number to the output of JUnitFormatter ([#13468](https://github.com/crystal-lang/crystal/pull/13468), thanks @nobodywasishere)
- *(specs)* Publish the `assert_prints` spec helper ([#13599](https://github.com/crystal-lang/crystal/pull/13599), thanks @HertzDevil)
- *(system)* Implement `Process.exec` on Windows ([#13374](https://github.com/crystal-lang/crystal/pull/13374), thanks @HertzDevil)
- *(system)* Add `File::BadExecutableError` ([#13491](https://github.com/crystal-lang/crystal/pull/13491), thanks @HertzDevil)
- *(text)* Add inspection of Regex options support ([#13354](https://github.com/crystal-lang/crystal/pull/13354), thanks @straight-shoota)
- *(text)* Add `Regex.literal` ([#13339](https://github.com/crystal-lang/crystal/pull/13339), thanks @straight-shoota)
- *(text)* Implement `#match!` for Regex ([#13285](https://github.com/crystal-lang/crystal/pull/13285), thanks @devnote-dev)
- *(text)* Add parameters for `Regex::MatchOptions` to matching methods ([#13353](https://github.com/crystal-lang/crystal/pull/13353), thanks @straight-shoota)
- *(text)* Add `Char#titlecase` for correct mixed-case transformations ([#13539](https://github.com/crystal-lang/crystal/pull/13539), thanks @HertzDevil)
- *(time)* Add `start_day` parameter to `Time#at_beginning_of_week` ([#13446](https://github.com/crystal-lang/crystal/pull/13446), thanks @DanielGilchrist)
- *(time)* Map IANA time zone identifiers to Windows time zones ([#13517](https://github.com/crystal-lang/crystal/pull/13517), thanks @HertzDevil)
- *(time)* Add `Time.unix_ns` and `#to_unix_ns` ([#13359](https://github.com/crystal-lang/crystal/pull/13359), thanks @garymardell)

#### compiler

- Add message about non-release mode to `crystal --version` ([#13254](https://github.com/crystal-lang/crystal/pull/13254), thanks @will)
- Respect `%CC%` on Windows ([#13376](https://github.com/crystal-lang/crystal/pull/13376), thanks @HertzDevil)
- Support DLL delay-loading on Windows ([#13436](https://github.com/crystal-lang/crystal/pull/13436), thanks @HertzDevil)
- Support `-static` and `-dynamic` `.lib` suffixes on Windows ([#13473](https://github.com/crystal-lang/crystal/pull/13473), [#13645](https://github.com/crystal-lang/crystal/pull/13645), thanks @HertzDevil)
- Make compiler aware of output extension when building programs ([#13370](https://github.com/crystal-lang/crystal/pull/13370), thanks @HertzDevil)
- Support `CRYSTAL_LIBRARY_RPATH` for adding dynamic library lookup paths ([#13499](https://github.com/crystal-lang/crystal/pull/13499), thanks @HertzDevil)
- Add compiler command `crystal clear_cache` ([#13553](https://github.com/crystal-lang/crystal/pull/13553), thanks @baseballlover723)
- *(codegen)* Support LLVM 16 ([#13181](https://github.com/crystal-lang/crystal/pull/13181), thanks @HertzDevil)
- *(semantic)* Correctly ignore nested deprecation warnings ([#13513](https://github.com/crystal-lang/crystal/pull/13513), thanks @straight-shoota)

#### tools

- *(docs-generator)* Add dark mode to docs ([#13512](https://github.com/crystal-lang/crystal/pull/13512), thanks @GeopJr)
- *(docs-generator)* Add mobile support to docs ([#13515](https://github.com/crystal-lang/crystal/pull/13515), thanks @GeopJr)
- *(formatter)* **[security]** Formatter: escape bi-directional control characters within strings ([#13067](https://github.com/crystal-lang/crystal/pull/13067), thanks @HertzDevil)

### Bugfixes

#### stdlib

- *(collection)* Fix `Array#flatten` to discard `Iterator::Stop` ([#13388](https://github.com/crystal-lang/crystal/pull/13388), thanks @straight-shoota)
- *(collection)* Fix return type of `Iterator#chunk` and `Enumerable#chunks` without `Drop` ([#13506](https://github.com/crystal-lang/crystal/pull/13506), thanks @straight-shoota)
- *(collection)* Fix `Iterator#with_index(offset)` with non-`Int32` `offset` ([#13612](https://github.com/crystal-lang/crystal/pull/13612), thanks @HertzDevil)
- *(concurrency)* Fix `preview_mt` infinite loop on Windows ([#13419](https://github.com/crystal-lang/crystal/pull/13419), thanks @HertzDevil)
- *(concurrency)* Fix `Atomic#max` and `#min` for signed enums ([#13524](https://github.com/crystal-lang/crystal/pull/13524), thanks @HertzDevil)
- *(concurrency)* Fix timeout events getting lost on Windows ([#13525](https://github.com/crystal-lang/crystal/pull/13525), thanks @HertzDevil)
- *(concurrency)* Support `Atomic(T)#compare_and_set` when `T` is a reference union ([#13565](https://github.com/crystal-lang/crystal/pull/13565), thanks @HertzDevil)
- *(files)* Fix `Dir#info` on Windows ([#13395](https://github.com/crystal-lang/crystal/pull/13395), thanks @HertzDevil)
- *(files)* Windows: open standard streams in binary mode ([#13397](https://github.com/crystal-lang/crystal/pull/13397), thanks @HertzDevil)
- *(files)* Fix `File.info(File::NULL)` on Windows ([#13421](https://github.com/crystal-lang/crystal/pull/13421), thanks @HertzDevil)
- *(files)* Allow `File.delete` to remove read-only files on Windows ([#13462](https://github.com/crystal-lang/crystal/pull/13462), thanks @HertzDevil)
- *(files)* Make `fcntl` defined on all platforms ([#13495](https://github.com/crystal-lang/crystal/pull/13495), thanks @HertzDevil)
- *(files)* Allow `Dir.delete` to remove read-only directories on Windows ([#13626](https://github.com/crystal-lang/crystal/pull/13626), thanks @HertzDevil)
- *(files)* Use current directory's root for `Dir.glob("/...")` on Windows ([#13628](https://github.com/crystal-lang/crystal/pull/13628), thanks @HertzDevil)
- *(llvm)* Fix `LLVM.default_target_triple` to normalize aarch64 darwin target ([#13597](https://github.com/crystal-lang/crystal/pull/13597), thanks @straight-shoota)
- *(log)* Fix `Log::Builder` append `BroadcastBackend` to itself ([#13405](https://github.com/crystal-lang/crystal/pull/13405), thanks @straight-shoota)
- *(macros)* Fix error message for calling `record` macro with kwargs ([#13367](https://github.com/crystal-lang/crystal/pull/13367), thanks @a-alhusaini)
- *(networking)* Remove double URL escape in `HTTP::Server::Response.redirect` ([#13321](https://github.com/crystal-lang/crystal/pull/13321), thanks @threez)
- *(networking)* Fix WebSocket capitalization in docs ([#13331](https://github.com/crystal-lang/crystal/pull/13331), thanks @joshrickard)
- *(networking)* Fix `TCPSocket#tcp_keepalive_idle` on Windows ([#13364](https://github.com/crystal-lang/crystal/pull/13364), thanks @HertzDevil)
- *(networking)* Fix client-side `TCPSocket#remote_address` on Windows ([#13363](https://github.com/crystal-lang/crystal/pull/13363), thanks @HertzDevil)
- *(networking)* Parse IP addresses in Crystal instead of using `LibC.inet_pton` ([#13463](https://github.com/crystal-lang/crystal/pull/13463), thanks @HertzDevil)
- *(networking)* Windows: do not set `SO_EXCLUSIVEADDRUSE` if `SO_REUSEADDR` already present ([#13477](https://github.com/crystal-lang/crystal/pull/13477), thanks @HertzDevil)
- *(networking)* Implement `Socket::IPAddress#to_s` with Crystal instead of `LibC.inet_ntop` ([#13483](https://github.com/crystal-lang/crystal/pull/13483), thanks @HertzDevil)
- *(networking)* Ensure `Socket` checks `WinError.wsa_value` on Windows, not `Errno.value` ([#13494](https://github.com/crystal-lang/crystal/pull/13494), thanks @HertzDevil)
- *(numeric)* Disallow creating `Big*` numbers from infinity or NaN ([#13351](https://github.com/crystal-lang/crystal/pull/13351), thanks @HertzDevil)
- *(numeric)* Fix `LibM.hypotf` and `ldexpf` link errors on Windows ([#13485](https://github.com/crystal-lang/crystal/pull/13485), thanks @HertzDevil)
- *(numeric)* Make comparisons between `BigRational` and `BigFloat` exact ([#13538](https://github.com/crystal-lang/crystal/pull/13538), thanks @HertzDevil)
- *(runtime)* Fix size of type_id in `Object.set_crystal_type_id` ([#13338](https://github.com/crystal-lang/crystal/pull/13338), thanks @straight-shoota)
- *(runtime)* Allow `/SUBSYSTEM:WINDOWS` on Windows ([#13332](https://github.com/crystal-lang/crystal/pull/13332), thanks @HertzDevil)
- *(runtime)* Use correct format strings for crash stack traces ([#13408](https://github.com/crystal-lang/crystal/pull/13408), thanks @HertzDevil)
- *(serialization)* Fix handling of quoted boolean values in `YAML::Any` ([#13546](https://github.com/crystal-lang/crystal/pull/13546), thanks @willhbr)
- *(serialization)* Fix ambiguous call with untyped int literal in `{JSON,YAML}::Any.new` ([#13618](https://github.com/crystal-lang/crystal/pull/13618), thanks @straight-shoota)
- *(system)* Fix for Process: ensure chdir is a string ([#13503](https://github.com/crystal-lang/crystal/pull/13503), thanks @devnote-dev)
- *(system)* Windows: drop internal environment variables from `ENV` ([#13570](https://github.com/crystal-lang/crystal/pull/13570), thanks @HertzDevil)
- *(text)* Fix `String#underscore` with multi-character downcasing ([#13540](https://github.com/crystal-lang/crystal/pull/13540), thanks @HertzDevil)
- *(text)* Do not attempt downcasing first when case-folding a `Char` ([#13542](https://github.com/crystal-lang/crystal/pull/13542), thanks @HertzDevil)
- *(text)* Handle case folding in `String#compare` correctly ([#13532](https://github.com/crystal-lang/crystal/pull/13532), thanks @HertzDevil)
- *(time)* Update list of Windows time zones ([#13501](https://github.com/crystal-lang/crystal/pull/13501), thanks @HertzDevil)
- *(time)* Fix local timezones without DST on Windows ([#13516](https://github.com/crystal-lang/crystal/pull/13516), thanks @HertzDevil)
- *(time)* Fix leap second handling for timezone information files ([#13600](https://github.com/crystal-lang/crystal/pull/13600), thanks @HertzDevil)

#### compiler

- More accurate macro errors ([#13260](https://github.com/crystal-lang/crystal/pull/13260), thanks @Blacksmoke16)
- Do not drop `/LIBPATH` from Windows linker command ([#13530](https://github.com/crystal-lang/crystal/pull/13530), thanks @HertzDevil)
- Fix instantiated method signatures in error traces ([#13580](https://github.com/crystal-lang/crystal/pull/13580), thanks @HertzDevil)
- Place `--emit` files back in current directory when running source ([#13604](https://github.com/crystal-lang/crystal/pull/13604), thanks @HertzDevil)
- *(generics)* Fix free variable matching of bound numeric values ([#13606](https://github.com/crystal-lang/crystal/pull/13606), thanks @HertzDevil)
- *(parser)* Don't skip the token immediately after `lib` name ([#13407](https://github.com/crystal-lang/crystal/pull/13407), thanks @FnControlOption)
- *(parser)* Allow newline after hash rocket ([#13460](https://github.com/crystal-lang/crystal/pull/13460), thanks @FnControlOption)
- *(parser)* Add missing locations of various AST nodes ([#13452](https://github.com/crystal-lang/crystal/pull/13452), thanks @FnControlOption)
- *(parser)* Fix AST location of call name in operator assignment ([#13456](https://github.com/crystal-lang/crystal/pull/13456), thanks @FnControlOption)

#### tools

- Display `Bool`'s size as 1 byte in `crystal tool hierarchy`, not 0 ([#13588](https://github.com/crystal-lang/crystal/pull/13588), thanks @HertzDevil)

### Performance

#### stdlib

- *(collection)* Optimize `Array#concat(Indexable)` ([#13280](https://github.com/crystal-lang/crystal/pull/13280), thanks @HertzDevil)
- *(collection)* Optimize `Deque#concat(Indexable)` ([#13283](https://github.com/crystal-lang/crystal/pull/13283), thanks @HertzDevil)
- *(concurrency)* Support synchronous socket operations on Windows ([#13414](https://github.com/crystal-lang/crystal/pull/13414), thanks @HertzDevil)
- *(numeric)* Optimize `BigInt.new(Int::Primitive)` ([#13303](https://github.com/crystal-lang/crystal/pull/13303), thanks @HertzDevil)
- *(numeric)* Optimize `BigRational#<=>(Int)` ([#13555](https://github.com/crystal-lang/crystal/pull/13555), thanks @HertzDevil)
- *(text)* Improve `HTML.escape(string, io)` performance ([#13139](https://github.com/crystal-lang/crystal/pull/13139), thanks @BlobCodes)
- *(text)* Refactor `String.ends_with?` to use `MatchOptions::ENDANCHORED` ([#13551](https://github.com/crystal-lang/crystal/pull/13551), thanks @straight-shoota)

#### tools

- *(docs-generator)* Optimize `Doc::Method#compute_doc_info` to avoid duplicate regex ([#13324](https://github.com/crystal-lang/crystal/pull/13324), thanks @straight-shoota)

### Refactor

#### stdlib

- Use sentence case for all standard library exceptions ([#13400](https://github.com/crystal-lang/crystal/pull/13400), thanks @HertzDevil)
- *(collection)* Refactor code for `Deque` buffer resizing ([#13257](https://github.com/crystal-lang/crystal/pull/13257), thanks @HertzDevil)
- *(concurrency)* Clean up unused code for Windows event loop ([#13424](https://github.com/crystal-lang/crystal/pull/13424), thanks @HertzDevil)
- *(files)* Do not reopen current file in `File#utime` on Windows ([#13625](https://github.com/crystal-lang/crystal/pull/13625), thanks @HertzDevil)
- *(files)* Do not reopen current file in `File#chmod` on Windows ([#13627](https://github.com/crystal-lang/crystal/pull/13627), thanks @HertzDevil)
- *(llvm)* **[deprecation]** Deprecate `LLVM::Module#write_bitcode_with_summary_to_file` ([#13488](https://github.com/crystal-lang/crystal/pull/13488), thanks @HertzDevil)
- *(llvm)* **[deprecation]** Deprecate LLVM's legacy pass manager ([#13579](https://github.com/crystal-lang/crystal/pull/13579), thanks @HertzDevil)
- *(llvm)* Remove two outdated LLVM fun bindings ([#13438](https://github.com/crystal-lang/crystal/pull/13438), thanks @HertzDevil)
- *(llvm)* Split `LLVM::Builder` overloads that don't take an operand bundle ([#13564](https://github.com/crystal-lang/crystal/pull/13564), thanks @HertzDevil)
- *(networking)* Move more `Socket` methods to `Crystal::System::Socket` ([#13346](https://github.com/crystal-lang/crystal/pull/13346), thanks @HertzDevil)
- *(numeric)* Use `Int#bit_length` instead of `Math.log2` followed by `#to_i` ([#13440](https://github.com/crystal-lang/crystal/pull/13440), thanks @HertzDevil)
- *(numeric)* Use GMP's functions for `Float`-to-`BigRational` conversion ([#13352](https://github.com/crystal-lang/crystal/pull/13352), thanks @HertzDevil)
- *(serialization)* Simplify implementation of `Serializable#initialize` ([#13433](https://github.com/crystal-lang/crystal/pull/13433), thanks @straight-shoota)
- *(serialization)* Use per-thread libxml2 global state on Windows ([#13486](https://github.com/crystal-lang/crystal/pull/13486), thanks @HertzDevil)
- *(text)* Refactor String header layout reflection ([#13335](https://github.com/crystal-lang/crystal/pull/13335), thanks @straight-shoota)
- *(text)* Refactor symbol quoting into `Symbol.quote_for_named_argument` ([#13595](https://github.com/crystal-lang/crystal/pull/13595), thanks @straight-shoota)

#### compiler

- *(parser)* Crystal lexer cleanup ([#13270](https://github.com/crystal-lang/crystal/pull/13270), thanks @FnControlOption)
- *(parser)* Don't use symbols in `Crystal::Lexer#check_macro_opening_keyword` ([#13277](https://github.com/crystal-lang/crystal/pull/13277), thanks @HertzDevil)

### Documentation

#### stdlib

- *(concurrency)* Fix operators in `Atomic#add`, `#sub`, `#max`, `#min` ([#13523](https://github.com/crystal-lang/crystal/pull/13523), thanks @HertzDevil)
- *(concurrency)* Hide `Crystal::LibEvent` from public docs ([#13624](https://github.com/crystal-lang/crystal/pull/13624), thanks @HertzDevil)
- *(macros)* Fix doc for return type of `Crystal::Macros::Case#else` ([#13385](https://github.com/crystal-lang/crystal/pull/13385), thanks @HertzDevil)
- *(system)* Reference `Process.executable_path` at `PROGRAM_NAME` ([#13434](https://github.com/crystal-lang/crystal/pull/13434), thanks @straight-shoota)
- *(text)* Add note about graphemes in `String#reverse` ([#13536](https://github.com/crystal-lang/crystal/pull/13536), thanks @noraj)

#### compiler

- Add manual entry for `clear_cache` command ([#13621](https://github.com/crystal-lang/crystal/pull/13621), thanks @straight-shoota)

#### other

- Implemented ',' command in brainfuck sample program ([#13559](https://github.com/crystal-lang/crystal/pull/13559), thanks @ZeroPlayerRodent)

### Specs

#### stdlib

- *(files)* Fix `IO::FileDescriptor`'s `STDIN` mode spec ([#13365](https://github.com/crystal-lang/crystal/pull/13365), thanks @HertzDevil)
- *(files)* Fix file permission specs on Windows ([#13465](https://github.com/crystal-lang/crystal/pull/13465), thanks @HertzDevil)
- *(files)* Add `slow` tag to stdlib specs that compile a program ([#13498](https://github.com/crystal-lang/crystal/pull/13498), thanks @straight-shoota)
- *(serialization)* Refactor JSON, YAML specs for #13337 for simplicity ([#13358](https://github.com/crystal-lang/crystal/pull/13358), thanks @straight-shoota)
- *(system)* Disable `Process.pgid` spec on Windows ([#13476](https://github.com/crystal-lang/crystal/pull/13476), thanks @HertzDevil)
- *(text)* Reorder and enhance specs for `String.new(&)` ([#13333](https://github.com/crystal-lang/crystal/pull/13333), thanks @straight-shoota)
- *(text)* Remove incorrect `CRYSTAL` in comments ([#13500](https://github.com/crystal-lang/crystal/pull/13500), thanks @HertzDevil)
- *(time)* Skip `Time::Location.load_local` spec if unable to change time zone ([#13355](https://github.com/crystal-lang/crystal/pull/13355), thanks @HertzDevil)

#### compiler

- *(interpreter)* Regenerate `spec/interpreter_std_spec.cr` ([#13310](https://github.com/crystal-lang/crystal/pull/13310), thanks @cyangle)

### Infrastructure

- Update changelog with previous Crystal releases ([#13322](https://github.com/crystal-lang/crystal/pull/13322), [#13373](https://github.com/crystal-lang/crystal/pull/13373), [#13450](https://github.com/crystal-lang/crystal/pull/13450), thanks @straight-shoota)
- Merge `release/1.8` ([#13361](https://github.com/crystal-lang/crystal/pull/13361), [#13449](https://github.com/crystal-lang/crystal/pull/13449), thanks @straight-shoota)
- PR template: adding a line about force-pushes ([#12794](https://github.com/crystal-lang/crystal/pull/12794), thanks @beta-ziliani)
- Less verbose output in `Makefile.win` ([#13383](https://github.com/crystal-lang/crystal/pull/13383), thanks @HertzDevil)
- Update distribution-scripts ([#13457](https://github.com/crystal-lang/crystal/pull/13457), thanks @Blacksmoke16)
- Add `.gitattributes` to repository ([#13479](https://github.com/crystal-lang/crystal/pull/13479), thanks @HertzDevil)
- Update `shell.nix` to nixpkgs-23.05 ([#13571](https://github.com/crystal-lang/crystal/pull/13571), thanks @HertzDevil)
- Document `target` variable in Makefiles ([#13384](https://github.com/crystal-lang/crystal/pull/13384), thanks @HertzDevil)
- Fix `bin\crystal.ps1` writing to standard error stream ([#13372](https://github.com/crystal-lang/crystal/pull/13372), thanks @HertzDevil)
- Avoid calling realpath of parent crystal in wrapper script ([#13596](https://github.com/crystal-lang/crystal/pull/13596), thanks @straight-shoota)
- *(ci)* Show PCRE/PCRE2 configuration on CI ([#13307](https://github.com/crystal-lang/crystal/pull/13307), thanks @HertzDevil)
- *(ci)* Update cachix/install-nix-action action ([#13531](https://github.com/crystal-lang/crystal/pull/13531), [#13586](https://github.com/crystal-lang/crystal/pull/13586), thanks @renovate)
- *(ci)* Restrict Windows CI jobs for installer packages to release branches ([#13623](https://github.com/crystal-lang/crystal/pull/13623), thanks @HertzDevil)
- *(ci)* Build samples on Windows CI ([#13334](https://github.com/crystal-lang/crystal/pull/13334), thanks @HertzDevil)
- *(ci)* Do not cancel in progress CI jobs for master branch ([#13393](https://github.com/crystal-lang/crystal/pull/13393), thanks @Blacksmoke16)
- *(ci)* Upgrade Windows CI to LLVM 16 ([#13469](https://github.com/crystal-lang/crystal/pull/13469), thanks @HertzDevil)
- *(ci)* Distribute DLLs and import libraries on Windows ([#13543](https://github.com/crystal-lang/crystal/pull/13543), thanks @HertzDevil)
- *(ci)* Build Windows portable and installer packages on CI ([#13578](https://github.com/crystal-lang/crystal/pull/13578), thanks @HertzDevil)
- *(ci)* Split Windows library build scripts from CI ([#13478](https://github.com/crystal-lang/crystal/pull/13478), thanks @HertzDevil)

## [1.8.2] - 2023-05-08

[1.8.2]: https://github.com/crystal-lang/crystal/releases/1.8.2

### Standard Library

#### Collection

- Fix codegen bug with `Iterator::ChainIterator` ([#13412](https://github.com/crystal-lang/crystal/pull/13412), thanks @straight-shoota)

#### Log

- Fix `Log::Metadata#dup` crash with 2+ entries ([#13369](https://github.com/crystal-lang/crystal/pull/13369), thanks @HertzDevil)

#### Serialization

- Fixup for `JSON::Serializable` on certain recursively defined types ([#13430](https://github.com/crystal-lang/crystal/pull/13430), thanks @kostya)

#### Text

- Fix `String#scan` with empty `Regex` match at multibyte char ([#13387](https://github.com/crystal-lang/crystal/pull/13387), thanks @HertzDevil)
- **(performance)** Check subject UTF-8 validity just once for `String#gsub`, `#scan`, `#split` ([#13406](https://github.com/crystal-lang/crystal/pull/13406), thanks @HertzDevil)

### Compiler

#### Codegen

- Always use 0 for offset of `StaticArray`'s `@buffer` ([#13319](https://github.com/crystal-lang/crystal/pull/13319), thanks @HertzDevil)

### Other

- Backport bugfixes to release/1.8 for release 1.8.2 ([#3435](https://github.com/crystal-lang/crystal/pull/13435), thanks @straight-shoota)

## [1.8.1] - 2023-04-20

[1.8.1]: https://github.com/crystal-lang/crystal/releases/1.8.1

### Standard Library

#### Serialization

- Fix `JSON::Serializable` on certain recursively defined types ([#13344](https://github.com/crystal-lang/crystal/pull/13344), thanks @HertzDevil)

#### Text

- Fix `String#gsub` with empty match at multibyte char ([#13342](https://github.com/crystal-lang/crystal/pull/13342), thanks @straight-shoota)
- Fix PCRE2 `Regex` with more than 127 named capture groups ([#13349](https://github.com/crystal-lang/crystal/pull/13349), thanks @HertzDevil)

## [1.8.0] - 2023-04-14

[1.8.0]: https://github.com/crystal-lang/crystal/releases/1.8.0

### Language

- The compiler uses PCRE2 to validate regex literals ([#13084](https://github.com/crystal-lang/crystal/pull/13084), thanks @straight-shoota)
- Fill docs for `TupleLiteral` ([#12927](https://github.com/crystal-lang/crystal/pull/12927), thanks @straight-shoota)
- Allow namespaced `Path`s as type names for `lib` ([#12903](https://github.com/crystal-lang/crystal/pull/12903), thanks @HertzDevil)

### Standard Library

- Fix `SyntaxHighlighter::HTML` to escape identifier values ([#13212](https://github.com/crystal-lang/crystal/pull/13212), thanks @straight-shoota)
- Add workaround for `Value#not_nil!` copying the receiver ([#13264](https://github.com/crystal-lang/crystal/pull/13264), thanks @HertzDevil)
- Fix `Pointer#copy_to` overflow on unsigned size and different target type ([#13269](https://github.com/crystal-lang/crystal/pull/13269), thanks @HertzDevil)
- Docs: Added note about imports where necessary ([#13026](https://github.com/crystal-lang/crystal/pull/13026), [#13066](https://github.com/crystal-lang/crystal/pull/13066), thanks @Tamnac, @straight-shoota)
- Suppress compiler output in `compile_file` spec helper ([#13228](https://github.com/crystal-lang/crystal/pull/13228), thanks @straight-shoota)
- Define equality for `Process::Status` and `OAuth::RequestToken` ([#13014](https://github.com/crystal-lang/crystal/pull/13014), thanks @HertzDevil)
- Fix some Linux glibc bindings ([#13242](https://github.com/crystal-lang/crystal/pull/13242), [#13249](https://github.com/crystal-lang/crystal/pull/13249), thanks @ysbaddaden, @HertzDevil)

#### Collection

- **(breaking-change)** Fix `Enum#includes?` to require all bits set ([#13229](https://github.com/crystal-lang/crystal/pull/13229), thanks @straight-shoota)
- **(breaking-change)** Deprecate `Enum.flags` ([#12900](https://github.com/crystal-lang/crystal/pull/12900), thanks @straight-shoota)
- **(breaking-change)** Remove compile-time error for `Range#size`, `#each`, `#sample` ([#13278](https://github.com/crystal-lang/crystal/pull/13278), thanks @straight-shoota)
- **(breaking-change)** Docs: Require all `Indexable`s to be stable ([#13061](https://github.com/crystal-lang/crystal/pull/13061), thanks @HertzDevil)
- Add `Enum.[]` convenience constructor ([#12900](https://github.com/crystal-lang/crystal/pull/12900), thanks @straight-shoota)
- Rename internal `Iterator::Slice` type to not conflict with `::Slice` ([#12983](https://github.com/crystal-lang/crystal/pull/12983), thanks @Blacksmoke16)
- Fix `Array#replace` on shifted arrays ([#13256](https://github.com/crystal-lang/crystal/pull/13256), thanks @HertzDevil)
- Add `Tuple#to_static_array` ([#12930](https://github.com/crystal-lang/crystal/pull/12930), thanks @straight-shoota)
- Add `Enum#inspect` ([#13004](https://github.com/crystal-lang/crystal/pull/13004), thanks @straight-shoota)
- Add `Slice#+(Slice)` and `Slice.join` ([#12081](https://github.com/crystal-lang/crystal/pull/12081), thanks @HertzDevil)
- Add `Enumerable#min(count)` and `#max(count)` ([#13057](https://github.com/crystal-lang/crystal/pull/13057), thanks @nthiad)
- Fix `Array(T)#[]=(Int, Int, Array(T))` on shifted arrays ([#13275](https://github.com/crystal-lang/crystal/pull/13275), thanks @HertzDevil)

#### Concurrency

- Fix: Make sure to dup `Array` in `Channel.select_impl` ([#12827](https://github.com/crystal-lang/crystal/pull/12827), [#12962](https://github.com/crystal-lang/crystal/pull/12962), thanks @straight-shoota)
- Add memory barriers on lock/unlock of SpinLock ([#13050](https://github.com/crystal-lang/crystal/pull/13050), thanks @bcardiff)
- **(performance)** Avoid `Array` allocation in `Channel.select(Tuple)` ([#12960](https://github.com/crystal-lang/crystal/pull/12960), thanks @straight-shoota)

#### Files

- **(breaking-change)** Deprecate `Termios` ([#12940](https://github.com/crystal-lang/crystal/pull/12940), thanks @HertzDevil)
- **(breaking-change)** Windows: make `File.delete` remove symlink directories, not `Dir.delete` ([#13224](https://github.com/crystal-lang/crystal/pull/13224), thanks @HertzDevil)
- Leverage `fileapi` for opening files on windows ([#13178](https://github.com/crystal-lang/crystal/pull/13178), thanks @Blacksmoke16)
- Windows: fix error condition when `File.open` fails ([#13235](https://github.com/crystal-lang/crystal/pull/13235), thanks @HertzDevil)
- Skip eacces spec for superuser ([#13227](https://github.com/crystal-lang/crystal/pull/13227), thanks @straight-shoota)
- Improve `File.symlink` on Windows ([#13141](https://github.com/crystal-lang/crystal/pull/13141), thanks @HertzDevil)
- Implement `File.readlink` on Windows ([#13195](https://github.com/crystal-lang/crystal/pull/13195), thanks @HertzDevil)

#### LLVM

- **(breaking-change)** Drop support for LLVM < 8 ([#12906](https://github.com/crystal-lang/crystal/pull/12906), thanks @straight-shoota)
- **(breaking-change)** Support LLVM 15 ([#13173](https://github.com/crystal-lang/crystal/pull/13173), thanks @HertzDevil)
- Error when `find-llvm-config` is unsuccessful ([#13045](https://github.com/crystal-lang/crystal/pull/13045), thanks @straight-shoota)
- Remove `LibLLVM.has_constant?(:AttributeRef)` checks ([#13162](https://github.com/crystal-lang/crystal/pull/13162), thanks @HertzDevil)
- Refactor `LLVM::Attribute#each_kind` to use `Enum#each` ([#13234](https://github.com/crystal-lang/crystal/pull/13234), thanks @straight-shoota)

#### Networking

- Fix socket specs when network not available ([#12961](https://github.com/crystal-lang/crystal/pull/12961), thanks @straight-shoota)
- Fix wrong default address when binding sockets ([#13006](https://github.com/crystal-lang/crystal/pull/13006), thanks @etra0)
- Clarify WebSocket documentation ([#13096](https://github.com/crystal-lang/crystal/pull/13096), thanks @j8r)
- Add `Socket::IPAddress#link_local?` ([#13204](https://github.com/crystal-lang/crystal/pull/13204), thanks @GeopJr)
- Clean up `back\slash.txt` in `HTTP::StaticFileHandler` specs ([#12984](https://github.com/crystal-lang/crystal/pull/12984), thanks @HertzDevil)
- Add `MIME::Multipart.parse(HTTP::Client::Response, &)` ([#12890](https://github.com/crystal-lang/crystal/pull/12890), thanks @straight-shoota)
- Replace `LibC.ntohs` and `htons` with native code ([#13027](https://github.com/crystal-lang/crystal/pull/13027), thanks @HertzDevil)
- Add `OAuth2::Client#make_token_request` returning HTTP response ([#12921](https://github.com/crystal-lang/crystal/pull/12921), thanks @cyangle)
- Use exhaustive case in `HTTP::WebSocket#run` ([#13097](https://github.com/crystal-lang/crystal/pull/13097), thanks @j8r)
- Increase time drift for `HTTP::StaticFileHandler`'s gzip check ([#13138](https://github.com/crystal-lang/crystal/pull/13138), thanks @HertzDevil)
- OpenSSL: use Windows' system root certificate store ([#13187](https://github.com/crystal-lang/crystal/pull/13187), thanks @HertzDevil)
- Handle `Range` requests in `HTTP::StaticFileHandler` ([#12886](https://github.com/crystal-lang/crystal/pull/12886), thanks @jgaskins, @straight-shoota)
- Skip hostname spec if `hostname` command fails ([#12987](https://github.com/crystal-lang/crystal/pull/12987), thanks @Blacksmoke16)
- Fix `Socket#tty?` to `false` on Windows ([#13175](https://github.com/crystal-lang/crystal/pull/13175), thanks @Blacksmoke16)
- Fix `HTTP::Server::Response#reset` for `status_message` ([#13282](https://github.com/crystal-lang/crystal/pull/13282), thanks @straight-shoota)

#### Numeric

- Define `Math.pw2ceil` for all integer types ([#13127](https://github.com/crystal-lang/crystal/pull/13127), thanks @HertzDevil)
- Workaround for more `Int128`-and-float methods on Windows with LLVM 14+ ([#13218](https://github.com/crystal-lang/crystal/pull/13218), thanks @HertzDevil)
- Fix `Int128`-and-float conversion overflow checks on Windows LLVM 14+ ([#13222](https://github.com/crystal-lang/crystal/pull/13222), thanks @HertzDevil)
- Add `Char.to_i128` and `.to_u128` ([#12958](https://github.com/crystal-lang/crystal/pull/12958), thanks @meatball133)
- Docs: Add references to `Number` collection convenience constructors ([#13020](https://github.com/crystal-lang/crystal/pull/13020), thanks @straight-shoota)
- Docs: Fix examples for `#byte_swap` with different int types ([#13154](https://github.com/crystal-lang/crystal/pull/13154), [#13180](https://github.com/crystal-lang/crystal/pull/13180), thanks @pan, @Blacksmoke16)
- Make `BigRational.new(BigFloat)` exact ([#13295](https://github.com/crystal-lang/crystal/pull/13295), thanks @HertzDevil)

#### Runtime

- Increase timeout for slow specs ([#13043](https://github.com/crystal-lang/crystal/pull/13043), thanks @straight-shoota)
- Use `Crystal::System.print_error` instead of `LibC.printf` ([#13161](https://github.com/crystal-lang/crystal/pull/13161), thanks @HertzDevil)
- Windows: detect stack overflows on non-main `Fiber`s ([#13220](https://github.com/crystal-lang/crystal/pull/13220), thanks @HertzDevil)
- Add missing require for `Crystal::ThreadLocalValue` ([#13092](https://github.com/crystal-lang/crystal/pull/13092), thanks @Sija)

#### Serialization

- Remove obsolete error handling in `XPathContext` ([#13038](https://github.com/crystal-lang/crystal/pull/13038), thanks @straight-shoota)
- Fix JSON, YAML `use_*_discriminator` for recursive `Serializable::Strict` types ([#13238](https://github.com/crystal-lang/crystal/pull/13238), thanks @HertzDevil)
- Add more specs for `YAML::Any#[]` and `#[]?` ([#11646](https://github.com/crystal-lang/crystal/pull/11646), thanks @straight-shoota)
- Add `from_json` for 128-bit integers ([#13041](https://github.com/crystal-lang/crystal/pull/13041), thanks @straight-shoota)
- Reduce JSON, YAML serializable test types ([#13042](https://github.com/crystal-lang/crystal/pull/13042), thanks @straight-shoota)

#### Specs

- Format spec results with pretty inspect ([#11635](https://github.com/crystal-lang/crystal/pull/11635), thanks @JamesGood626)
- Spec: Add `--color` option to spec runner ([#12932](https://github.com/crystal-lang/crystal/pull/12932), thanks @straight-shoota)
- Add `Spec::Item#all_tags` ([#12915](https://github.com/crystal-lang/crystal/pull/12915), thanks @compumike)

#### System

- **(breaking-change)** Add full stub for Windows signals ([#13131](https://github.com/crystal-lang/crystal/pull/13131), thanks @HertzDevil)
- **(breaking-change)** Deprecate and internalize `Process.fork` ([#12934](https://github.com/crystal-lang/crystal/pull/12934), thanks @straight-shoota)
- Fix `Process` spec to wait on started processes ([#12941](https://github.com/crystal-lang/crystal/pull/12941), thanks @straight-shoota)
- Drop privileges in chroot spec ([#13226](https://github.com/crystal-lang/crystal/pull/13226), thanks @straight-shoota)
- Drop deprecated `from_winerror` overload for `flock_*` ([#13039](https://github.com/crystal-lang/crystal/pull/13039), thanks @HertzDevil)
- Add `Process.on_interrupt` ([#13034](https://github.com/crystal-lang/crystal/pull/13034), thanks @HertzDevil)
- Add `Process::Status#to_s` and `#inspect` ([#13044](https://github.com/crystal-lang/crystal/pull/13044), thanks @straight-shoota)
- Add `graceful` parameter to `Process#terminate` ([#13070](https://github.com/crystal-lang/crystal/pull/13070), thanks @HertzDevil)
- Add `Process::ExitReason` and `Process::Status#exit_reason` ([#13052](https://github.com/crystal-lang/crystal/pull/13052), thanks @HertzDevil)
- Implement `File.tempfile` in Crystal ([#12111](https://github.com/crystal-lang/crystal/pull/12111), thanks @straight-shoota)
- `System::User#name`: Fall back to `#username` if unavailable ([#13137](https://github.com/crystal-lang/crystal/pull/13137), thanks @HertzDevil)
- Implement `Process.ppid` on Windows ([#13140](https://github.com/crystal-lang/crystal/pull/13140), thanks @HertzDevil)
- AArch64 Android support ([#13065](https://github.com/crystal-lang/crystal/pull/13065), thanks @HertzDevil)
- Windows 7 support ([#11505](https://github.com/crystal-lang/crystal/pull/11505), thanks @konovod)

#### Text

- **(breaking-change)** Fix PCRE crashing on invalid UTF-8 ([#13240](https://github.com/crystal-lang/crystal/pull/13240), [#13311](https://github.com/crystal-lang/crystal/pull/13311), [#13313](https://github.com/crystal-lang/crystal/pull/13313), thanks @straight-shoota)
- **(breaking-change)** Switch default regex engine to PCRE2 ([#12978](https://github.com/crystal-lang/crystal/pull/12978), thanks @straight-shoota)
- **(breaking-change)** Add more members to `Regex::Options` ([#13223](https://github.com/crystal-lang/crystal/pull/13223), thanks @straight-shoota)
- **(breaking-change)** Add `Regex::MatchOptions` ([#13248](https://github.com/crystal-lang/crystal/pull/13248), thanks @straight-shoota)
- Fix PCRE2 implementation and tests ([#13105](https://github.com/crystal-lang/crystal/pull/13105), thanks @straight-shoota)
- Remove pending spec for `Path#drive` with IPv6 UNC host names ([#13190](https://github.com/crystal-lang/crystal/pull/13190), thanks @HertzDevil)
- Remove `Regex::PCRE2#finalize` redefinition ([#13309](https://github.com/crystal-lang/crystal/pull/13309), thanks @HertzDevil)
- Clarify behavior of strings with invalid UTF-8 byte sequences ([#13314](https://github.com/crystal-lang/crystal/pull/13314), thanks @HertzDevil)
- Refer to PCRE2 in `Regex`'s summary ([#13318](https://github.com/crystal-lang/crystal/pull/13318), thanks @HertzDevil)

### Compiler

- Escape filenames when running `crystal spec` with multiple files ([#12929](https://github.com/crystal-lang/crystal/pull/12929), thanks @HertzDevil)
- Handle ARM64 MSVC paths when cross-compiling on Windows ([#13073](https://github.com/crystal-lang/crystal/pull/13073), thanks @HertzDevil)
- Use relative paths to vendored shards" ([#13315](https://github.com/crystal-lang/crystal/pull/13315), thanks @straight-shoota)

#### Debugger
- Always use 0 for offsets of lib / extern union members ([#13305](https://github.com/crystal-lang/crystal/pull/13305), thanks @HertzDevil)

#### Codegen

- **(breaking-change)** Support LLVM 15 ([#13173](https://github.com/crystal-lang/crystal/pull/13173), thanks @HertzDevil)
- Remove obsolete functions from `llvm_ext.cc` ([#13177](https://github.com/crystal-lang/crystal/pull/13177), thanks @HertzDevil)

#### Generics

- Fix type names for generic instances with empty splat type vars ([#13189](https://github.com/crystal-lang/crystal/pull/13189), thanks @HertzDevil)

#### Interpreter

- Fix: Interpreter `value_to_bool` for module, generic module and generic module metaclass ([#12920](https://github.com/crystal-lang/crystal/pull/12920), thanks @asterite)
- Fix redundant cast in interpreter ([#12996](https://github.com/crystal-lang/crystal/pull/12996), thanks @asterite)
- Dynamic library loader: search in `-L` directories before default ones ([#13069](https://github.com/crystal-lang/crystal/pull/13069), thanks @HertzDevil)
- Simplify expectation of loader spec error messages ([#12858](https://github.com/crystal-lang/crystal/pull/12858), thanks @straight-shoota)
- Add support for 128-bit literals in the interpreter ([#12859](https://github.com/crystal-lang/crystal/pull/12859), thanks @straight-shoota)
- Fix interpreter `value_to_bool` for `NoReturn` ([#13290](https://github.com/crystal-lang/crystal/pull/13290), thanks @straight-shoota)

#### Parser

- Fix `x @y` and `x @@y` in def parameters when `y` is reserved ([#12922](https://github.com/crystal-lang/crystal/pull/12922), thanks @HertzDevil)
- Disallow empty exponents in number literals ([#12910](https://github.com/crystal-lang/crystal/pull/12910), thanks @HertzDevil)
- Stricter checks for multiple assignment syntax ([#12919](https://github.com/crystal-lang/crystal/pull/12919), thanks @HertzDevil)

#### Semantic

- Compiler: type declaration with initial value gets the value's type ([#13025](https://github.com/crystal-lang/crystal/pull/13025), thanks @asterite)
- Stricter checks for enum definitions ([#12945](https://github.com/crystal-lang/crystal/pull/12945), thanks @HertzDevil)
- Fix error handling in macro system method when execution fails ([#12893](https://github.com/crystal-lang/crystal/pull/12893), thanks @straight-shoota)
- Add comment for `LiteralExpander` `select` ([#12926](https://github.com/crystal-lang/crystal/pull/12926), thanks @straight-shoota)
- Improve locations of some AST nodes ([#12933](https://github.com/crystal-lang/crystal/pull/12933), thanks @straight-shoota)
- Refactor `SemanticVisitor` tighter `rescue` scope in `Require` visitor ([#12887](https://github.com/crystal-lang/crystal/pull/12887), thanks @straight-shoota)
- Add specs for regex literal expansion ([#13253](https://github.com/crystal-lang/crystal/pull/13253), thanks @straight-shoota)

### Tools

- Fix Crystal tool cursor parsing for filenames containing `:` ([#13129](https://github.com/crystal-lang/crystal/pull/13129), thanks @HertzDevil)

#### Formatter

- Formatter: fix end indent after comment inside begin ([#12994](https://github.com/crystal-lang/crystal/pull/12994), thanks @asterite)
- Parser: remove obsolete handling of `else` inside lib struct ([#13028](https://github.com/crystal-lang/crystal/pull/13028), thanks @HertzDevil)
- Fix formatter empty array literal with comment on extra line ([#12907](https://github.com/crystal-lang/crystal/pull/12907), thanks @straight-shoota)
- Fix formatter comment on extra line at end of method args ([#12908](https://github.com/crystal-lang/crystal/pull/12908), thanks @straight-shoota)
- Fix formatter not merge consecutive but separated comment lines ([#12909](https://github.com/crystal-lang/crystal/pull/12909), thanks @straight-shoota)
- Formatter: add `(&)` to param-less yielding defs before comment line ([#13126](https://github.com/crystal-lang/crystal/pull/13126), thanks @HertzDevil)
- Formatter: add `&` to yielding methods without a block parameter ([#12951](https://github.com/crystal-lang/crystal/pull/12951), thanks @HertzDevil)
- Formatter: Add feature flag for `method_signature_yield` ([#13215](https://github.com/crystal-lang/crystal/pull/13215), thanks @straight-shoota)
- Macro interpolation: add `&` to yielding `Def`s without a block parameter ([#12952](https://github.com/crystal-lang/crystal/pull/12952), thanks @HertzDevil)

### Infrastructure

- Fix `bin/crystal` print no error message when `crystal` is missing ([#12981](https://github.com/crystal-lang/crystal/pull/12981), thanks @straight-shoota)
- Prevent infinitely recursive wrapper script ([#11712](https://github.com/crystal-lang/crystal/pull/11712), thanks @ThunderKey)
- Changelog helper: Report error from HTTP request ([#13011](https://github.com/crystal-lang/crystal/pull/13011), thanks @straight-shoota)
- Fix wrapper script to handle `CRYSTAL` variable pointing to itself ([#13032](https://github.com/crystal-lang/crystal/pull/13032), thanks @straight-shoota)
- Propagate exit code correctly in Windows wrapper batch script ([#13048](https://github.com/crystal-lang/crystal/pull/13048), thanks @HertzDevil)
- Remove `__declspec(dllimport)` from Windows libiconv build ([#13219](https://github.com/crystal-lang/crystal/pull/13219), thanks @HertzDevil)
- Update previous Crystal release - 1.7.0 ([#12925](https://github.com/crystal-lang/crystal/pull/12925), thanks @straight-shoota)
- [CI] Remove `verbose=1` in `test_llvm` ([#12931](https://github.com/crystal-lang/crystal/pull/12931), thanks @straight-shoota)
- Missing quotes in Wrapper Script ([#12955](https://github.com/crystal-lang/crystal/pull/12955), thanks @stellarpower)
- Makefile: refactor test recipe ([#12979](https://github.com/crystal-lang/crystal/pull/12979), thanks @straight-shoota)
- Merge release branch for 1.7 into master ([#12998](https://github.com/crystal-lang/crystal/pull/12998), thanks @straight-shoota)
- Update previous Crystal release - 1.7.2 ([#13001](https://github.com/crystal-lang/crystal/pull/13001), thanks @straight-shoota)
- Update distribution-scripts ([#13051](https://github.com/crystal-lang/crystal/pull/13051), [#13068](https://github.com/crystal-lang/crystal/pull/13068), [#13188](https://github.com/crystal-lang/crystal/pull/13188), [#13213](https://github.com/crystal-lang/crystal/pull/13213), [#13298](https://github.com/crystal-lang/crystal/pull/13298), thanks @straight-shoota)
- [CI] Use Ubuntu 22.04 base image for LLVM tests ([#13035](https://github.com/crystal-lang/crystal/pull/13035), thanks @straight-shoota)
- Add instructions for other repos to pre-commit hook ([#10535](https://github.com/crystal-lang/crystal/pull/10535), thanks @straight-shoota)
- Makefile: Add `./scripts` to `format` recipe ([#13064](https://github.com/crystal-lang/crystal/pull/13064), thanks @straight-shoota)
- Crystal wrapper script enhancements ([#12959](https://github.com/crystal-lang/crystal/pull/12959), thanks @j8r)
- Fix sed command in `scripts/update-distribution-scripts.cr` ([#13071](https://github.com/crystal-lang/crystal/pull/13071), thanks @straight-shoota)
- Update GH Actions ([#13075](https://github.com/crystal-lang/crystal/pull/13075), [#13132](https://github.com/crystal-lang/crystal/pull/13132), thanks @renovate)
- CI: Enable testing with `libpcre2` on wasm32 ([#13109](https://github.com/crystal-lang/crystal/pull/13109), thanks @lbguilherme)
- Build the compiler with PCRE2 ([#13084](https://github.com/crystal-lang/crystal/pull/13084), [#13133](https://github.com/crystal-lang/crystal/pull/13133), thanks @straight-shoota)
- Prefer matching `llvm-config` in  `find-llvm-config` ([#13087](https://github.com/crystal-lang/crystal/pull/13087), thanks @straight-shoota)
- **(performance)** Run compiler specs in release mode ([#13122](https://github.com/crystal-lang/crystal/pull/13122), thanks @straight-shoota)
- [CI] Increase `no_output_timeout` on circleci ([#13151](https://github.com/crystal-lang/crystal/pull/13151), thanks @straight-shoota)
- Update NOTICE.md ([#13159](https://github.com/crystal-lang/crystal/pull/13159), thanks @HertzDevil)
- Merge `release/1.7`@1.7.3 ([#13168](https://github.com/crystal-lang/crystal/pull/13168), thanks @straight-shoota)
- [CI] Cancel in-progress jobs when another commit is pushed ([#13179](https://github.com/crystal-lang/crystal/pull/13179), thanks @Blacksmoke16)
- Mute shell comments in Makefile ([#13201](https://github.com/crystal-lang/crystal/pull/13201), thanks @straight-shoota)
- Update previous Crystal release - 1.7.3 ([#13167](https://github.com/crystal-lang/crystal/pull/13167), thanks @straight-shoota)
- [CI] Remove cross-compiliation on Windows ([#13207](https://github.com/crystal-lang/crystal/pull/13207), thanks @straight-shoota)
- [CI] Increase `no_output_timeout` on circleci (cont.) ([#13185](https://github.com/crystal-lang/crystal/pull/13185), thanks @straight-shoota)
- [CI] Update Windows job to LLVM 15 ([#13208](https://github.com/crystal-lang/crystal/pull/13208), thanks @straight-shoota)
- Clean up `.gitignore` ([#13241](https://github.com/crystal-lang/crystal/pull/13241), thanks @straight-shoota)
- [CI] Extract LLVM tests in separate workflow ([#13246](https://github.com/crystal-lang/crystal/pull/13246), thanks @straight-shoota)
- [CI] Extract interpreter workflow and split `std_spec` execution ([#13267](https://github.com/crystal-lang/crystal/pull/13267), thanks @straight-shoota)
- Avoid `test.cr` in root of repo conflicting with parser warning specs ([#13259](https://github.com/crystal-lang/crystal/pull/13259), thanks @Blacksmoke16)
- Fix `bin/crystal` in symlink working directory ([#13281](https://github.com/crystal-lang/crystal/pull/13281), thanks @straight-shoota)
- Fix `bin/crystal` when no global `crystal` command is installed ([#13286](https://github.com/crystal-lang/crystal/pull/13286), thanks @straight-shoota)
- Makefile: Add `interpreter_spec` ([#13251](https://github.com/crystal-lang/crystal/pull/13251), thanks @straight-shoota)
- Makefile: Add `all` target as default before including `Makfile.local` ([#13276](https://github.com/crystal-lang/crystal/pull/13276), thanks @straight-shoota)
- Update shards 0.17.3 ([#13296](https://github.com/crystal-lang/crystal/pull/13296), thanks @straight-shoota)

### Other

- Do not match expectations outside specs ([#13079](https://github.com/crystal-lang/crystal/pull/13079), thanks @HertzDevil)
- Enable or fix specs that already work on Windows ([#13186](https://github.com/crystal-lang/crystal/pull/13186), thanks @HertzDevil)

## [1.7.3] - 2023-03-07
[1.7.3]: https://github.com/crystal-lang/crystal/releases/1.7.3

### Standard Library

#### Text

- Do not use `@[ThreadLocal]` for PCRE2's JIT stack ([#13056](https://github.com/crystal-lang/crystal/pull/13056), thanks @HertzDevil)
- Fix `libpcre2` bindings with arch-dependent types (`SizeT`) ([#13088](https://github.com/crystal-lang/crystal/pull/13088), thanks @straight-shoota)
- Fix `libpcre2` bindings function pointers ([#13090](https://github.com/crystal-lang/crystal/pull/13090), thanks @straight-shoota)
- Fix PCRE2 do not allocate JIT stack if unavailable ([#13100](https://github.com/crystal-lang/crystal/pull/13100), thanks @straight-shoota)
- Backport PCRE2 fixes to 1.7 ([#13136](https://github.com/crystal-lang/crystal/pull/13136), thanks @straight-shoota)
- Fix `MatchData#[]` named capture with identical prefix ([#13147](https://github.com/crystal-lang/crystal/pull/13147), thanks @straight-shoota)
- Fix `Regex::Option` behaviour for unnamed members ([#13155](https://github.com/crystal-lang/crystal/pull/13155), thanks @straight-shoota)
- **(performance)** Improve PCRE2 match performance for JIT and interpreted ([#13146](https://github.com/crystal-lang/crystal/pull/13146), thanks @straight-shoota)

### Compiler

#### Generics

- Explicitly treat unbound type vars in generic class methods as free variables ([#13125](https://github.com/crystal-lang/crystal/pull/13125), thanks @HertzDevil)

### Other

- [CI] Fix add PCRE2 to GHA cache for win job ([#13089](https://github.com/crystal-lang/crystal/pull/13089), thanks @straight-shoota)
- [CI] Pin `use_pcre` in build environments where PCRE2 is not yet available ([#13102](https://github.com/crystal-lang/crystal/pull/13102), thanks @straight-shoota)

## [1.7.2] - 2023-01-23

[1.7.2]: https://github.com/crystal-lang/crystal/releases/1.7.2
### Standard Library

#### Runtime

- Fix: Add `Nil` return type restrictions to `load_debug_info` ([#12992](https://github.com/crystal-lang/crystal/pull/12992), thanks @straight-shoota)

### Compiler

#### Codegen

- Add error handling to compiler when linker is unavailable ([#12899](https://github.com/crystal-lang/crystal/pull/12899), thanks @straight-shoota)

#### Parser

- Revert "Parser: Fix restrict grammar for name and supertype in type def (#12622)" ([#12977](https://github.com/crystal-lang/crystal/pull/12977), thanks @straight-shoota)

### Other

- Update `VERSION` to `1.7.2-dev` ([#12993](https://github.com/crystal-lang/crystal/pull/12993), thanks @straight-shoota)

## [1.7.1] - 2023-01-17

[1.7.1]: https://github.com/crystal-lang/crystal/releases/1.7.1

### Tools

#### Playground

- Fix baked-in path in playground to resolve at runtime ([#12948](https://github.com/crystal-lang/crystal/pull/12948), thanks @straight-shoota)

### Other

- Update `VERSION` to 1.7.1-dev ([#12950](https://github.com/crystal-lang/crystal/pull/12950), thanks @straight-shoota)

## [1.7.0] - 2023-01-09

[1.7.0]: https://github.com/crystal-lang/crystal/releases/1.7.0

### Language

- Add lib functions earlier so that they are visible in top-level macros ([#12848](https://github.com/crystal-lang/crystal/pull/12848), thanks @asterite)

### Standard Library

- Improve `Benchmark` docs ([#12782](https://github.com/crystal-lang/crystal/pull/12782), thanks @r00ster91, @straight-shoota)
- Improve documentation for `Object#to_s` and `#inspect` ([#9974](https://github.com/crystal-lang/crystal/pull/9974), thanks @straight-shoota)
- Add methods to manipulate semantic versions ([#12834](https://github.com/crystal-lang/crystal/pull/12834), thanks @gabriel-ss)
- Add types to methods with defaults ([#12837](https://github.com/crystal-lang/crystal/pull/12837), thanks @caspiano)
- examples: fix (2022-10) ([#12665](https://github.com/crystal-lang/crystal/pull/12665), thanks @maiha)
- Fix documentation for `Pointer#move_to` ([#12677](https://github.com/crystal-lang/crystal/pull/12677), thanks @TheEEs)
- **(performance)** Eliminate `nil` from many predicate methods ([#12702](https://github.com/crystal-lang/crystal/pull/12702), thanks @HertzDevil)
- examples: fix (2022-12) ([#12870](https://github.com/crystal-lang/crystal/pull/12870), thanks @maiha)

#### Collection

- Fix missed elements in `Hash#select!(keys : Enumerable)` ([#12739](https://github.com/crystal-lang/crystal/pull/12739), thanks @caspiano)
- Add missing docs for `Indexable` combinations methods ([#10548](https://github.com/crystal-lang/crystal/pull/10548), thanks @keidax)
- **(performance)** Optimize `Range#sample(n)` for integers and floats ([#12535](https://github.com/crystal-lang/crystal/pull/12535), thanks @straight-shoota)
- Add `Iterable#each_cons_pair` ([#12726](https://github.com/crystal-lang/crystal/pull/12726), thanks @caspiano)
- Add links to equivalent `Iterator` methods in `Iterable` ([#12727](https://github.com/crystal-lang/crystal/pull/12727), thanks @caspiano)
- **(performance)** Optimize `Hash#select(Enumerable)` and `#merge!(Hash, &)` ([#12737](https://github.com/crystal-lang/crystal/pull/12737), thanks @HertzDevil)
- Add `Indexable#rindex!` method variant ([#12759](https://github.com/crystal-lang/crystal/pull/12759), thanks @Sija)
- **(performance)** Use mutating collection methods ([#12644](https://github.com/crystal-lang/crystal/pull/12644), thanks @caspiano)
- Fix `Enum#to_s` for flag enum containing named and unnamed members ([#12895](https://github.com/crystal-lang/crystal/pull/12895), thanks @straight-shoota)

#### Concurrency

- Allow the EventLoop implementation to be detected at runtime ([#12656](https://github.com/crystal-lang/crystal/pull/12656), thanks @lbguilherme)
- **(performance)** Optimize uniqueness filter in `Channel.select_impl` ([#12814](https://github.com/crystal-lang/crystal/pull/12814), thanks @straight-shoota)
- Implement multithreading primitives on Windows ([#11647](https://github.com/crystal-lang/crystal/pull/11647), thanks @HertzDevil)

#### Crypto

- **(breaking-change)** Implement `Digest` class in `Digest::CRC32` and `Digest::Adler32` ([#11535](https://github.com/crystal-lang/crystal/pull/11535), thanks @BlobCodes)
- Fix `OpenSSL::SSL::Context::Client#alpn_protocol=` ([#12724](https://github.com/crystal-lang/crystal/pull/12724), thanks @jaclarke)
- Fix `HTTP::Client` certificate validation error on FQDN (host with trailing dot) ([#12778](https://github.com/crystal-lang/crystal/pull/12778), thanks @compumike)
- Enable `arc4random(3)` on all supported BSDs and macOS/Darwin ([#12608](https://github.com/crystal-lang/crystal/pull/12608), thanks @dmgk)

#### Files

- Fix: Read `UInt` in zip directory header ([#12822](https://github.com/crystal-lang/crystal/pull/12822), thanks @pbrumm)
- Add `File.executable?` for Windows ([#9677](https://github.com/crystal-lang/crystal/pull/9677), thanks @nof1000)

#### Macros

- Fix `TypeNode#nilable?` for root types ([#12354](https://github.com/crystal-lang/crystal/pull/12354), thanks @HertzDevil)
- Add argless `#annotations` overload ([#9326](https://github.com/crystal-lang/crystal/pull/9326), thanks @Blacksmoke16)
- Add specs for addition between `ArrayLiteral` and `TupleLiteral` ([#12639](https://github.com/crystal-lang/crystal/pull/12639), thanks @caspiano)
- Add `ArrayLiteral#-(other)` and `TupleLiteral#-(other)` ([#12646](https://github.com/crystal-lang/crystal/pull/12646), [#12916](https://github.com/crystal-lang/crystal/pull/12916) thanks @caspiano, @straight-shoota)

#### Networking

- **(breaking-change)** Add `HTTP::Headers#serialize` ([#12765](https://github.com/crystal-lang/crystal/pull/12765), thanks @straight-shoota)
- Ensure `HTTP::Client` closes response when breaking out of block ([#12749](https://github.com/crystal-lang/crystal/pull/12749), thanks @straight-shoota)
- Add `HTTP::Server::Response#redirect` ([#12526](https://github.com/crystal-lang/crystal/pull/12526), thanks @straight-shoota)
- **(performance)** Websocket: write masked data to temporary buffer before sending it ([#12613](https://github.com/crystal-lang/crystal/pull/12613), thanks @asterite)
- Validate cookie name prefixes ([#10648](https://github.com/crystal-lang/crystal/pull/10648), thanks @Blacksmoke16)
- `IPAddress#loopback?` should consider `::ffff:127.0.0.1/104` loopback too ([#12783](https://github.com/crystal-lang/crystal/pull/12783), thanks @carlhoerberg)

#### Numeric

- Support new SI prefixes in `Number#humanize` ([#12761](https://github.com/crystal-lang/crystal/pull/12761), thanks @HertzDevil)
- Fix `BigInt#%` for unsigned integers ([#12773](https://github.com/crystal-lang/crystal/pull/12773), thanks @straight-shoota)
- [WASM] Add missing `__powisf2` and `__powidf2` compiler-rt functions ([#12569](https://github.com/crystal-lang/crystal/pull/12569), thanks @lbguilherme)
- Add docs for `Int#downto` ([#12468](https://github.com/crystal-lang/crystal/pull/12468), thanks @yb66)
- Upgrade the Dragonbox algorithm ([#12767](https://github.com/crystal-lang/crystal/pull/12767), thanks @HertzDevil)
- Support scientific notation in `BigDecimal#to_s` ([#10805](https://github.com/crystal-lang/crystal/pull/10805), thanks @HertzDevil)
- Add `#bit_reverse` and `#byte_swap` for primitive integers ([#12865](https://github.com/crystal-lang/crystal/pull/12865), thanks @HertzDevil)
- Fix Number comparison operator docs ([#12880](https://github.com/crystal-lang/crystal/pull/12880), thanks @fdocr)

#### Runtime

- `Exception::CallStack`: avoid allocations in `LibC.dl_iterate_phdr` ([#12625](https://github.com/crystal-lang/crystal/pull/12625), thanks @dmgk)
- Fix explicit type conversion to u64 for `GC::Stats` ([#12779](https://github.com/crystal-lang/crystal/pull/12779), thanks @straight-shoota)
- Add custom `message` parameter to `#not_nil!` ([#12797](https://github.com/crystal-lang/crystal/pull/12797), thanks @straight-shoota)
- Refactor specs for `Enum#to_s` using `assert_prints` ([#12882](https://github.com/crystal-lang/crystal/pull/12882), thanks @straight-shoota)

#### Serialization

- **(performance)** Leverage `GC.malloc_atomic` for XML ([#12692](https://github.com/crystal-lang/crystal/pull/12692), thanks @HertzDevil)
- Refactor libXML error handling to remove global state ([#12663](https://github.com/crystal-lang/crystal/pull/12663), [#12795](https://github.com/crystal-lang/crystal/pull/12795), thanks @straight-shoota)
- Use qualified type reference `YAML::Any` ([#12688](https://github.com/crystal-lang/crystal/pull/12688), thanks @zw963)
- Automatically cast Int to Float for `{JSON,YAML}::Any#as_f` ([#12835](https://github.com/crystal-lang/crystal/pull/12835), thanks @compumike)

#### Specs

- Print seed info at start and end of spec output ([#12755](https://github.com/crystal-lang/crystal/pull/12755), thanks @straight-shoota)

#### System

- **(breaking)** Rename `File.real_path` to `.realpath` ([#12552](https://github.com/crystal-lang/crystal/pull/12552), thanks @straight-shoota)
- **(breaking-change)** Drop FreeBSD 11 compatibility code ([#12612](https://github.com/crystal-lang/crystal/pull/12612), thanks @dmgk)
- Trap when trying to raise wasm32 exceptions ([#12572](https://github.com/crystal-lang/crystal/pull/12572), thanks @lbguilherme)
- Use single helper method to pass UTF-16 strings to Windows ([#12695](https://github.com/crystal-lang/crystal/pull/12695), [#12747](https://github.com/crystal-lang/crystal/pull/12747), thanks @HertzDevil, @straight-shoota)
- Implement `flock_*` fiber-aware, without blocking the thread ([#12861](https://github.com/crystal-lang/crystal/pull/12861), [#12728](https://github.com/crystal-lang/crystal/pull/12728), thanks @straight-shoota)
- Implement `flock_*` for Win32 ([#12766](https://github.com/crystal-lang/crystal/pull/12766), thanks @straight-shoota)
- Add docs to `ENV#has_key?` ([#12781](https://github.com/crystal-lang/crystal/pull/12781), thanks @straight-shoota)
- Improve specs by removing absolute path references ([#12776](https://github.com/crystal-lang/crystal/pull/12776), thanks @straight-shoota)
- Update FreeBSD LibC types ([#12651](https://github.com/crystal-lang/crystal/pull/12651), thanks @dmgk)
- Organize `Process` specs ([#12889](https://github.com/crystal-lang/crystal/pull/12889), thanks @straight-shoota)
- Add tests for `Process::Status` ([#12881](https://github.com/crystal-lang/crystal/pull/12881), thanks @straight-shoota)

#### Text

- Raise `IndexError` on unmatched subpattern for `MatchData#begin` and `#end` ([#12810](https://github.com/crystal-lang/crystal/pull/12810), thanks @straight-shoota)
- Swap documentation for `String#split` array and block versions ([#12808](https://github.com/crystal-lang/crystal/pull/12808), thanks @hugopl)
- Add `String#index/rindex!` methods ([#12730](https://github.com/crystal-lang/crystal/pull/12730), thanks @Sija)
- Re-organize and enhance specs for `Regex` and `Regex::MatchData` ([#12788](https://github.com/crystal-lang/crystal/pull/12788), [#12789](https://github.com/crystal-lang/crystal/pull/12789), thanks @straight-shoota)
- Add missing positive spec for `Regex#match` with option ([#12804](https://github.com/crystal-lang/crystal/pull/12804), thanks @straight-shoota)
- Replace `if !blank?` with `unless blank?` ([#12800](https://github.com/crystal-lang/crystal/pull/12800), thanks @vlazar)
- Add references between String equality, comparison methods ([#10531](https://github.com/crystal-lang/crystal/pull/10531), thanks @straight-shoota)
- Extract internal Regex API for PCRE backend ([#12802](https://github.com/crystal-lang/crystal/pull/12802), thanks @straight-shoota)
- Implement `Regex` engine on PCRE2 ([#12856](https://github.com/crystal-lang/crystal/pull/12856), [#12866](https://github.com/crystal-lang/crystal/pull/12866), [#12847](https://github.com/crystal-lang/crystal/pull/12847), thanks @straight-shoota, thanks @HertzDevil)
- Add missing overloads for `String#byte_slice` ([#12809](https://github.com/crystal-lang/crystal/pull/12809), thanks @straight-shoota)

### Compiler

- Improve error message when there are extra types ([#12734](https://github.com/crystal-lang/crystal/pull/12734), thanks @asterite)
- Handle triples without libc ([#12594](https://github.com/crystal-lang/crystal/pull/12594), thanks @GeopJr)
- Remove unused `Program#cache_dir` property ([#12669](https://github.com/crystal-lang/crystal/pull/12669), thanks @straight-shoota)
- Fix: Unwrap nested errors in error handler for `Crystal::Error` ([#12888](https://github.com/crystal-lang/crystal/pull/12888), thanks @straight-shoota)

#### Codegen

- Add missing specs for `->var.foo` semantics with assignments ([#9419](https://github.com/crystal-lang/crystal/pull/9419), thanks @makenowjust)
- Use `File#flock_exclusive` on win32 in compiler ([#12876](https://github.com/crystal-lang/crystal/pull/12876), thanks @straight-shoota)

#### Generics

- Redefine defs when constant and number in generic arguments are equal ([#12785](https://github.com/crystal-lang/crystal/pull/12785), thanks @HertzDevil)
- Fix restriction of numeral generic argument against non-free variable `Path` ([#12784](https://github.com/crystal-lang/crystal/pull/12784), thanks @HertzDevil)

#### Interpreter

- Interpreter: fix class var initializer that needs an upcast ([#12635](https://github.com/crystal-lang/crystal/pull/12635), thanks @asterite)
- Reverting #12405 Compiler: don't always use Array for node dependencies and observers  ([#12849](https://github.com/crystal-lang/crystal/pull/12849), thanks @beta-ziliani)
- Match Nix loader errors in compiler spec ([#12852](https://github.com/crystal-lang/crystal/pull/12852), thanks @bcardiff)
- Interpreter reply ([#12738](https://github.com/crystal-lang/crystal/pull/12738), thanks @I3oris)

#### Parser

- **(breaking-change)** Parser: Fix restrict grammar for name and supertype in type def ([#12622](https://github.com/crystal-lang/crystal/pull/12622), thanks @caspiano)
- Lexer: fix global capture vars ending with zero, e.g. `$10?` ([#12701](https://github.com/crystal-lang/crystal/pull/12701), thanks @FnControlOption)
- Lexer: allow regex after CRLF ([#12713](https://github.com/crystal-lang/crystal/pull/12713), thanks @FnControlOption)
- Assignment to global regex match data is not allowed ([#12714](https://github.com/crystal-lang/crystal/pull/12714), thanks @caspiano)
- Error when declaring a constant within another constant declaration ([#12566](https://github.com/crystal-lang/crystal/pull/12566), thanks @caspiano)
- Fix calls with do-end blocks within index operators ([#12824](https://github.com/crystal-lang/crystal/pull/12824), thanks @caspiano)
- Remove oct/bin floating point literals ([#12687](https://github.com/crystal-lang/crystal/pull/12687), thanks @BlobCodes)
- Parser: fix wrong/missing locations of various AST nodes ([#11798](https://github.com/crystal-lang/crystal/pull/11798), thanks @FnControlOption)
- Refactor: use helper method instead of duplicate code in lexer ([#12590](https://github.com/crystal-lang/crystal/pull/12590), thanks @straight-shoota)
- Simplify sequential character checks in Crystal lexer ([#12699](https://github.com/crystal-lang/crystal/pull/12699), thanks @caspiano)
- Lexer: delete redundant `scan_ident` calls ([#12691](https://github.com/crystal-lang/crystal/pull/12691), thanks @FnControlOption)
- Rename `Def#yields` to `Def#block_arity` ([#12833](https://github.com/crystal-lang/crystal/pull/12833), thanks @straight-shoota)
- Fix warning on space before colon with anonymous block arg ([#12869](https://github.com/crystal-lang/crystal/pull/12869), thanks @straight-shoota)
- Warn on missing space before colon in type declaration/restriction ([#12740](https://github.com/crystal-lang/crystal/pull/12740), thanks @straight-shoota)

#### Semantic

- Fix: Do not merge union types in truthy filter ([#12752](https://github.com/crystal-lang/crystal/pull/12752), thanks @straight-shoota)
- Fix crash when using `sizeof`, `instance_sizeof`, or `offsetof` as a type arg ([#12577](https://github.com/crystal-lang/crystal/pull/12577), thanks @keidax)
- Resolve type of free variable on block return type mismatch ([#12754](https://github.com/crystal-lang/crystal/pull/12754), thanks @caspiano)
- Order `_` after any other `Path` when comparing overloads ([#12855](https://github.com/crystal-lang/crystal/pull/12855), thanks @HertzDevil)
- [Experimental] Compiler: try to solve string interpolation exps at compile time ([#12524](https://github.com/crystal-lang/crystal/pull/12524), thanks @asterite)
- Support `@[Deprecated]` on `annotation` ([#12557](https://github.com/crystal-lang/crystal/pull/12557), thanks @caspiano)
- Add more specific error message for uninstantiated proc type ([#11219](https://github.com/crystal-lang/crystal/pull/11219), thanks @straight-shoota)
- Add specs for `system` macro method ([#12885](https://github.com/crystal-lang/crystal/pull/12885), thanks @straight-shoota)

### Tools

#### Docs-generator

- Fix range literals causing method lookups in docs generator  ([#12680](https://github.com/crystal-lang/crystal/pull/12680), thanks @caspiano)
- Fix method lookup for single char class names ([#12683](https://github.com/crystal-lang/crystal/pull/12683), thanks @caspiano)

#### Formatter

- Formatter: document stdin filename argument (`-`) ([#12620](https://github.com/crystal-lang/crystal/pull/12620), thanks @caspiano)

### Other

#### Infrastructure
- [CI] Drop Alpine libreSSL 3.1 test ([#12641](https://github.com/crystal-lang/crystal/pull/12641), thanks @straight-shoota)
- Bump version to 1.7.0-dev ([#12640](https://github.com/crystal-lang/crystal/pull/12640), thanks @straight-shoota)
- [CI] Update GHA actions ([#12501](https://github.com/crystal-lang/crystal/pull/12501), thanks @straight-shoota)
- Opt in to new overload ordering behavior in Makefile ([#12703](https://github.com/crystal-lang/crystal/pull/12703), thanks @HertzDevil)
- Merge release 1.6.2 into master ([#12719](https://github.com/crystal-lang/crystal/pull/12719), thanks @beta-ziliani)
- Configure Renovate ([#12678](https://github.com/crystal-lang/crystal/pull/12678), thanks @renovate)
- [CI] Add version pin for ilammy/msvc-dev-cmd in windows CI ([#12746](https://github.com/crystal-lang/crystal/pull/12746), thanks @straight-shoota)
- [CI] Update dependencies for windows CI ([#12745](https://github.com/crystal-lang/crystal/pull/12745), thanks @straight-shoota)
- Update GH Actions ([#12742](https://github.com/crystal-lang/crystal/pull/12742), thanks @renovate)
- [CI] Run specs in random order by default ([#12541](https://github.com/crystal-lang/crystal/pull/12541), thanks @straight-shoota)
- Update `shell.nix` for newer LLVM versions and aarch64-darwin ([#12591](https://github.com/crystal-lang/crystal/pull/12591), thanks @HertzDevil)
- Update previous Crystal release - 1.6.2 ([#12750](https://github.com/crystal-lang/crystal/pull/12750), thanks @straight-shoota)
- [CI] Update PCRE 8.45 for Windows CI ([#12762](https://github.com/crystal-lang/crystal/pull/12762), thanks @HertzDevil)
- Add WebAssembly specs ([#12571](https://github.com/crystal-lang/crystal/pull/12571), thanks @lbguilherme)
- Update actions/checkout action to v3 ([#12805](https://github.com/crystal-lang/crystal/pull/12805), thanks @renovate)
- Enable multithreading specs on Windows CI ([#12843](https://github.com/crystal-lang/crystal/pull/12843), thanks @HertzDevil)
- [CI] Update mwilliamson/setup-wasmtime-action action to v2 ([#12864](https://github.com/crystal-lang/crystal/pull/12864), thanks @renovate)
- [CI] Update distribution-scripts ([#12891](https://github.com/crystal-lang/crystal/pull/12891), thanks @straight-shoota)
- [CI] Update shards 0.17.2 ([#12875](https://github.com/crystal-lang/crystal/pull/12875), thanks @straight-shoota)
- Rotate breached credentials in CircleCI ([#12902](https://github.com/crystal-lang/crystal/pull/12902), thanks @matiasgarciaisaia)
- Update `NOTICE.md` ([#12901](https://github.com/crystal-lang/crystal/pull/12901), thanks @HertzDevil)
- Split pre-1.0 changelog ([#12898](https://github.com/crystal-lang/crystal/pull/12898), thanks @straight-shoota)

#### Code Improvements

- Style: Remove redundant begin blocks ([#12638](https://github.com/crystal-lang/crystal/pull/12638), thanks @caspiano)
- Lint: Fix variable name casing ([#12674](https://github.com/crystal-lang/crystal/pull/12674), thanks @Sija)
- Lint: Remove comparisons with boolean literals ([#12673](https://github.com/crystal-lang/crystal/pull/12673), thanks @Sija)
- Lint: Use `Object#in?` instead of multiple comparisons ([#12675](https://github.com/crystal-lang/crystal/pull/12675), thanks @Sija)
- Lint: Remove useless assignments ([#12648](https://github.com/crystal-lang/crystal/pull/12648), thanks @Sija)
- Use `Object#in?` in place of multiple comparisons ([#12700](https://github.com/crystal-lang/crystal/pull/12700), thanks @caspiano)
- Style: Remove explicit returns from the codebase ([#12637](https://github.com/crystal-lang/crystal/pull/12637), thanks @caspiano)
- Lint: Use `Enumerable#find!/#index!` variants ([#12686](https://github.com/crystal-lang/crystal/pull/12686), thanks @Sija)
- Style: Use short block notation for simple one-liners ([#12676](https://github.com/crystal-lang/crystal/pull/12676), thanks @Sija)
- Couple of ameba lint issues fixed ([#12685](https://github.com/crystal-lang/crystal/pull/12685), thanks @Sija)
- Use context-specific heredoc deliminators ([#12816](https://github.com/crystal-lang/crystal/pull/12816), thanks @straight-shoota)

## [1.6.2] - 2022-11-03

[1.6.2]: https://github.com/crystal-lang/crystal/releases/1.6.2

### Language

- Fix `VirtualMetaclassType#implements?` to ignore base type ([#12632](https://github.com/crystal-lang/crystal/pull/12632), thanks @straight-shoota)

### Compiler

- Compiler: handle yield expressions without a type ([#12679](https://github.com/crystal-lang/crystal/pull/12679), thanks @asterite)
- Partial revert "Compiler: refactor and slightly optimize merging two types (#12436)" ([#12709](https://github.com/crystal-lang/crystal/pull/12709), thanks @caspiano)

#### Semantic

- Compiler: ignore type filters when accepting cast for `obj` and `to` ([#12668](https://github.com/crystal-lang/crystal/pull/12668), thanks @asterite)

### Other

- **(security)** CI: Update to OpenSSL 3.0.7 for bundled lib on Windows ([#12712](https://github.com/crystal-lang/crystal/pull/12712), thanks @beta-ziliani)

## [1.6.1] - 2022-10-21

[1.6.1]: https://github.com/crystal-lang/crystal/releases/1.6.1

### Compiler

#### Interpreter

- Interpreter (repl): migrate types even if their size remains the same ([#12581](https://github.com/crystal-lang/crystal/pull/12581), thanks @asterite)
- Unbreak the interpreter on FreeBSD ([#12600](https://github.com/crystal-lang/crystal/pull/12600), thanks @dmgk)
- Fix FFI specs on release builds ([#12601](https://github.com/crystal-lang/crystal/pull/12601), thanks @HertzDevil)
- Adding welcome message to the interpreter ([#12511](https://github.com/crystal-lang/crystal/pull/12511), thanks @beta-ziliani)

#### Semantic

- Treat single splats with same restriction as equivalent ([#12584](https://github.com/crystal-lang/crystal/pull/12584), thanks @HertzDevil)

### Tools

#### Formatter

- Formatter: escape backslashes in macro literals when subformatting ([#12582](https://github.com/crystal-lang/crystal/pull/12582), thanks @asterite)

#### Playground

- Fix origin validation in playground server for localhost ([#12599](https://github.com/crystal-lang/crystal/pull/12599), thanks @straight-shoota)

### Other

- Fix doc typos in `Socket::IPAddress` ([#12583](https://github.com/crystal-lang/crystal/pull/12583), thanks @Blacksmoke16)
- Fix building Wasm32 on Crystal 1.6 (Regression) ([#12580](https://github.com/crystal-lang/crystal/pull/12580), thanks @lbguilherme)
- Bump version to 1.6.1-dev ([#12588](https://github.com/crystal-lang/crystal/pull/12588), thanks @straight-shoota)
- Disable failing specs on Windows CI ([#12585](https://github.com/crystal-lang/crystal/pull/12585), thanks @HertzDevil)
- Detect `llvm-configXX` while building compiler ([#12602](https://github.com/crystal-lang/crystal/pull/12602), thanks @HertzDevil)

## [1.6.0] - 2022-10-06

[1.6.0]: https://github.com/crystal-lang/crystal/releases/1.6.0

### Language

- Add 'wasm_import_module' option to the `@[Link]` annotation ([#11935](https://github.com/crystal-lang/crystal/pull/11935), thanks @lbguilherme)

### Standard Library

- Use `GC.malloc_atomic` with `GC.realloc`, not `Pointer#realloc` ([#12391](https://github.com/crystal-lang/crystal/pull/12391), thanks @HertzDevil)
- Improve syntax highlighter ([#12409](https://github.com/crystal-lang/crystal/pull/12409), thanks @I3oris)
- Enable miscellaneous parts of the standard library on Windows ([#12281](https://github.com/crystal-lang/crystal/pull/12281), thanks @HertzDevil)
- Use interpreter to run std spec tests ([#12355](https://github.com/crystal-lang/crystal/pull/12355), thanks @cyangle)
- Remove most uses of `Symbol` variables in standard library specs ([#12462](https://github.com/crystal-lang/crystal/pull/12462), thanks @HertzDevil)
- Use `@[::Primitive]` and `@[::Flags]` where necessary ([#11900](https://github.com/crystal-lang/crystal/pull/11900), thanks @HertzDevil)
- Document how to change base type of an enum ([#9803](https://github.com/crystal-lang/crystal/pull/9803), thanks @Blacksmoke16)
- Spec: bump and document timeouts in interpreted mode ([#12430](https://github.com/crystal-lang/crystal/pull/12430), thanks @asterite)

#### Collection

- Refactor and improve `NamedTuple` deserialization from JSON and YAML ([#12008](https://github.com/crystal-lang/crystal/pull/12008), thanks @HertzDevil)
- **(performance)** Optimize `BitArray#tally(hash)` ([#11909](https://github.com/crystal-lang/crystal/pull/11909), thanks @HertzDevil)
- Use `Slice#unsafe_slice_of` and `#to_unsafe_bytes` in the standard library and compiler ([#12280](https://github.com/crystal-lang/crystal/pull/12280), thanks @HertzDevil)
- **(performance)** Optimize block-less overloads of `BitArray#index` and `#rindex` ([#12087](https://github.com/crystal-lang/crystal/pull/12087), thanks @HertzDevil)
- Support tuple metaclass indexers with non-literal arguments ([#11834](https://github.com/crystal-lang/crystal/pull/11834), thanks @HertzDevil)
- Add `Indexable#index!` overloads with `offset` parameter ([#12089](https://github.com/crystal-lang/crystal/pull/12089), thanks @HertzDevil)

#### Concurrency

- Fix fiber clean loop on Windows ([#12300](https://github.com/crystal-lang/crystal/pull/12300), thanks @HertzDevil)
- Enable `Mutex` on Windows ([#12213](https://github.com/crystal-lang/crystal/pull/12213), thanks @HertzDevil)

#### Crypto

- Add support for Bcrypt algorithm version 2y ([#12447](https://github.com/crystal-lang/crystal/pull/12447), thanks @docelic)
- Allow using `U/Int128` in `Random` ([#11977](https://github.com/crystal-lang/crystal/pull/11977), thanks @BlobCodes)

#### Files

- **(breaking-change)** Define `#system_echo` and `#system_raw` on all systems ([#12352](https://github.com/crystal-lang/crystal/pull/12352), thanks @HertzDevil)
- **(breaking-change)** Do not expose `Crystal::System::FileInfo` through `File::Info` ([#12385](https://github.com/crystal-lang/crystal/pull/12385), thanks @HertzDevil)
- Fix `IO.pipe` spec on FreeBSD ([#12324](https://github.com/crystal-lang/crystal/pull/12324), thanks @dmgk)
- Fix docs error for `File.match?` `**` globbing pattern. ([#12343](https://github.com/crystal-lang/crystal/pull/12343), thanks @zw963)
- Add `Dir#info` ([#11991](https://github.com/crystal-lang/crystal/pull/11991), thanks @didactic-drunk)
- Implement `IO::FileDescriptor`'s console methods on Windows ([#12294](https://github.com/crystal-lang/crystal/pull/12294), thanks @HertzDevil)
- Fix typo: `LibC::DT_LINK` -> `DT_LNK` ([#11954](https://github.com/crystal-lang/crystal/pull/11954), thanks @HertzDevil)
- Document `IO::FileDescriptor#info` ([#12384](https://github.com/crystal-lang/crystal/pull/12384), thanks @HertzDevil)
- **(performance)** Introduce `IO::DEFAULT_BUFFER_SIZE` ([#12507](https://github.com/crystal-lang/crystal/pull/12507), thanks @straight-shoota)
- Add support for `IO::FileDescriptor` staying open on finalize ([#12367](https://github.com/crystal-lang/crystal/pull/12367), thanks @refi64)

#### Macros

- Enhance `record` documentation ([#12334](https://github.com/crystal-lang/crystal/pull/12334), thanks @straight-shoota)

#### Networking

- Add `Socket::IPAddress.valid?` ([#12489](https://github.com/crystal-lang/crystal/pull/12489), [#10492](https://github.com/crystal-lang/crystal/pull/10492), thanks @straight-shoota)
- Fix `HTTP::Client#exec` to abort retry when client was closed ([#12465](https://github.com/crystal-lang/crystal/pull/12465), thanks @straight-shoota)
- Fix specs with side effects ([#12539](https://github.com/crystal-lang/crystal/pull/12539), thanks @straight-shoota)
- Fix `HTTP::Client` implicit compression with retry ([#12536](https://github.com/crystal-lang/crystal/pull/12536), thanks @straight-shoota)
- `HTTP::StaticFileHandler`: Reduce max stat calls from 6 to 2 ([#12310](https://github.com/crystal-lang/crystal/pull/12310), thanks @didactic-drunk)
- Add warning about concurrent requests in `HTTP::Client` ([#12527](https://github.com/crystal-lang/crystal/pull/12527), thanks @straight-shoota)

#### Numeric

- Add full integer support to `sprintf` and `String#%` ([#10973](https://github.com/crystal-lang/crystal/pull/10973), thanks @HertzDevil)
- Make `Float#to_s` ignore NaN sign bit ([#12399](https://github.com/crystal-lang/crystal/pull/12399), thanks @HertzDevil)
- Make `sprintf` and `String#%` ignore NaN sign bit ([#12400](https://github.com/crystal-lang/crystal/pull/12400), thanks @HertzDevil)
- Fix `Complex#to_s` imaginary component sign for certain values ([#12244](https://github.com/crystal-lang/crystal/pull/12244), thanks @HertzDevil)
- More accurate definition of `Complex#sign` ([#12242](https://github.com/crystal-lang/crystal/pull/12242), thanks @HertzDevil)
- Fix overflow for `rand(Range(Int, Int))` when signed span is too large ([#12545](https://github.com/crystal-lang/crystal/pull/12545), thanks @HertzDevil)
- **(performance)** Add `#rotate_left` and `#rotate_right` for primitive integers ([#12307](https://github.com/crystal-lang/crystal/pull/12307), thanks @HertzDevil)
- **(performance)** Optimize `BigDecimal#div` for inexact divisions ([#10803](https://github.com/crystal-lang/crystal/pull/10803), thanks @HertzDevil)
- Implement the Dragonbox algorithm for `Float#to_s` ([#10913](https://github.com/crystal-lang/crystal/pull/10913), thanks @HertzDevil)
- Add `U/Int128` to `isqrt` spec ([#11976](https://github.com/crystal-lang/crystal/pull/11976), thanks @BlobCodes)

#### Runtime

- Fix: Parse DWARF5 Data16 values ([#12497](https://github.com/crystal-lang/crystal/pull/12497), thanks @stakach)
- macOS: Fix call stack when executable path contains symlinks ([#12504](https://github.com/crystal-lang/crystal/pull/12504), thanks @HertzDevil)
- WASM: Add support for `wasi-sdk 16`: don't rely on `__original_main` ([#12450](https://github.com/crystal-lang/crystal/pull/12450), thanks @lbguilherme)

#### Serialization

- Fix YAML serialization class name ambiguity ([#12537](https://github.com/crystal-lang/crystal/pull/12537), thanks @hugopl)
- Allow non-type converter instances in `ArrayConverter` and `HashValueConverter` ([#10638](https://github.com/crystal-lang/crystal/pull/10638), thanks @HertzDevil)
- Document `after_initialize` method for `yaml` and `json` serializers ([#12530](https://github.com/crystal-lang/crystal/pull/12530), thanks @analogsalad)

#### System

- Add missing fields to `LibC::Passwd` on FreeBSD ([#12315](https://github.com/crystal-lang/crystal/pull/12315), thanks @dmgk)
- Add platform-specific variants of `Process.parse_arguments` ([#12278](https://github.com/crystal-lang/crystal/pull/12278), thanks @HertzDevil)
- Make `Dir.current` respect `$PWD` ([#12471](https://github.com/crystal-lang/crystal/pull/12471), thanks @straight-shoota)

#### Text

- Fix `String` shift state specs on FreeBSD ([#12339](https://github.com/crystal-lang/crystal/pull/12339), thanks @dmgk)
- Disallow mixing of sequential and named `sprintf` parameters ([#12402](https://github.com/crystal-lang/crystal/pull/12402), thanks @HertzDevil)
- Fix `Colorize` doc example ([#12492](https://github.com/crystal-lang/crystal/pull/12492), thanks @zw963)
- **(performance)** Optimize `String#downcase` and `String#upcase` for single byte optimizable case ([#12389](https://github.com/crystal-lang/crystal/pull/12389), thanks @asterite)
- **(performance)** Optimize `String#valid_encoding?` ([#12145](https://github.com/crystal-lang/crystal/pull/12145), thanks @HertzDevil)
- Implement `String#unicode_normalize` and `String#unicode_normalized?` ([#11226](https://github.com/crystal-lang/crystal/pull/11226), thanks @HertzDevil)
- Support parameter numbers in `sprintf` ([#12448](https://github.com/crystal-lang/crystal/pull/12448), thanks @HertzDevil)
- Use `LibC.malloc` instead of `GC.malloc` for LibPCRE allocations ([#12456](https://github.com/crystal-lang/crystal/pull/12456), thanks @lbguilherme)
- Unicode: Update to version 15.0.0 ([#12479](https://github.com/crystal-lang/crystal/pull/12479), thanks @HertzDevil)
- Avoid free call in interpreted mode ([#12496](https://github.com/crystal-lang/crystal/pull/12496), thanks @straight-shoota)

### Compiler

- Improve recursive splat expansion detection ([#11790](https://github.com/crystal-lang/crystal/pull/11790), thanks @asterite)
- Compiler: fix `#to_s` for empty parameters of lib funs ([#12368](https://github.com/crystal-lang/crystal/pull/12368), thanks @HertzDevil)
- Compiler: transform `Proc(*T, Void)` to `Proc(*T, Nil)` ([#12388](https://github.com/crystal-lang/crystal/pull/12388), thanks @asterite)
- Compiler: indent `begin` `Expression`s that are direct node children ([#12362](https://github.com/crystal-lang/crystal/pull/12362), thanks @HertzDevil)
- Compiler: add missing location to node on literal expander for array ([#12403](https://github.com/crystal-lang/crystal/pull/12403), thanks @asterite)
- Compiler: a generic class type can also be reference-like ([#12347](https://github.com/crystal-lang/crystal/pull/12347), thanks @asterite)
- Hoist complex element expressions outside container literals ([#12366](https://github.com/crystal-lang/crystal/pull/12366), thanks @HertzDevil)
- **(performance)** Compiler: bind to tuple, not array ([#12423](https://github.com/crystal-lang/crystal/pull/12423), thanks @asterite)
- Use `Path.new(string)` instead of `Path.new([string])` ([#12419](https://github.com/crystal-lang/crystal/pull/12419), thanks @asterite)
- Decouple warning detection from program instances ([#12293](https://github.com/crystal-lang/crystal/pull/12293), thanks @HertzDevil)
- **(performance)** Compiler: only have `freeze_type` in select AST nodes ([#12428](https://github.com/crystal-lang/crystal/pull/12428), thanks @asterite)
- Correctly display codegen when cross-compiling ([#12414](https://github.com/crystal-lang/crystal/pull/12414), thanks @luislavena)
- Compiler: simplify some calls ([#12417](https://github.com/crystal-lang/crystal/pull/12417), thanks @asterite)
- **(performance)** Compiler: optimizations in `merge_if_vars` ([#12432](https://github.com/crystal-lang/crystal/pull/12432), [#12433](https://github.com/crystal-lang/crystal/pull/12433), thanks @asterite)
- Compiler refactor: extract `type_from_dependencies` ([#12437](https://github.com/crystal-lang/crystal/pull/12437), thanks @asterite)
- **(performance)** Compiler: refactor and slightly optimize merging two types ([#12436](https://github.com/crystal-lang/crystal/pull/12436), thanks @asterite)
- **(performance)** Compiler optimization: don't create call for hook unless needed ([#12452](https://github.com/crystal-lang/crystal/pull/12452), thanks @asterite)
- **(performance)** CrystalPath: Cache `Dir.current` to avoid thousands of allocations ([#12455](https://github.com/crystal-lang/crystal/pull/12455), thanks @yxhuvud)
- Better call error messages ([#12469](https://github.com/crystal-lang/crystal/pull/12469), thanks @asterite)
- **(performance)** Compiler optimization: avoid intermediate array when matching call arg types ([#12485](https://github.com/crystal-lang/crystal/pull/12485), thanks @asterite)

#### Codegen

- Codegen: fix how unions are represented to not miss bytes ([#12551](https://github.com/crystal-lang/crystal/pull/12551), thanks @asterite)
- Fix alignment typo in compiler comments ([#12564](https://github.com/crystal-lang/crystal/pull/12564), thanks @mdwagner)
- Remove redundant code from x86_64 abi ([#12443](https://github.com/crystal-lang/crystal/pull/12443), thanks @mattrberry)
- Codegen: use var pointer for `out` instead of an extra variable ([#10952](https://github.com/crystal-lang/crystal/pull/10952), thanks @asterite)

#### Debugger

- Basic GDB formatter support ([#12209](https://github.com/crystal-lang/crystal/pull/12209), thanks @HertzDevil)
- Add Visual Studio formatters for `String`, `Array`, and `Hash` ([#12212](https://github.com/crystal-lang/crystal/pull/12212), thanks @HertzDevil)

#### Interpreter

- Interpreter: handle the case of a def's body with no type ([#12220](https://github.com/crystal-lang/crystal/pull/12220), thanks @asterite)
- Interpreter: simplify ivar initialization ([#12222](https://github.com/crystal-lang/crystal/pull/12222), thanks @asterite)
- Interpreter: fix autocasting in multidispatch ([#12223](https://github.com/crystal-lang/crystal/pull/12223), thanks @asterite)
- Interpreter: handle `next` inside captured block ([#12237](https://github.com/crystal-lang/crystal/pull/12237), thanks @asterite)
- Interpreter: fix `crystal_type_id` for virtual metaclass type ([#12246](https://github.com/crystal-lang/crystal/pull/12246), thanks @asterite)
- Interpreter: handle yield with splat combined with tuple unpacking ([#12247](https://github.com/crystal-lang/crystal/pull/12247), thanks @asterite)
- Interpreter: handle inlined call that returns self for structs ([#12259](https://github.com/crystal-lang/crystal/pull/12259), thanks @asterite)
- Interpreter: implement `Int128`/`UInt128` intrinsics ([#12258](https://github.com/crystal-lang/crystal/pull/12258), thanks @asterite)
- Interpreter: fix some conversion primitives ([#12257](https://github.com/crystal-lang/crystal/pull/12257), thanks @asterite)
- Interpreter: don't override special vars inside block ([#12251](https://github.com/crystal-lang/crystal/pull/12251), thanks @asterite)
- Interpreter: add missing cast from tuple to other tuple inside union ([#12249](https://github.com/crystal-lang/crystal/pull/12249), thanks @asterite)
- Interpreter: allow declaring local vars during a pry session ([#12180](https://github.com/crystal-lang/crystal/pull/12180), thanks @asterite)
- Interpreter: handle bitreverse intrinsics ([#12273](https://github.com/crystal-lang/crystal/pull/12273), thanks @asterite)
- Interpreter: cache methods with captured block ([#12285](https://github.com/crystal-lang/crystal/pull/12285), thanks @asterite)
- Interpreter: missing downcast from `MixedUnionType` to `NilableProcType` ([#12286](https://github.com/crystal-lang/crystal/pull/12286), thanks @asterite)
- Interpreter: fix `with ... yield` with extra arguments ([#12301](https://github.com/crystal-lang/crystal/pull/12301), thanks @asterite)
- Interpreter: consider nodes without a type as `NoReturn` ([#12275](https://github.com/crystal-lang/crystal/pull/12275), thanks @asterite)
- Interpreter: take `with ... yield` scope into account for args bytesize ([#12317](https://github.com/crystal-lang/crystal/pull/12317), thanks @asterite)
- Fix loader spec on FreeBSD ([#12323](https://github.com/crystal-lang/crystal/pull/12323), thanks @dmgk)
- Interpreter: inline ivar access for virtual call with a single child ([#12321](https://github.com/crystal-lang/crystal/pull/12321), thanks @asterite)
- Interpreter: fix `as?` when there's no resulting type ([#12328](https://github.com/crystal-lang/crystal/pull/12328), thanks @asterite)
- Interpreter: handle missing closured struct self ([#12345](https://github.com/crystal-lang/crystal/pull/12345), thanks @asterite)
- Interpreter: use `non_nilable_type` in NilableCast ([#12348](https://github.com/crystal-lang/crystal/pull/12348), thanks @asterite)
- Interpreter: implement mixed union cast with compatible tuple types ([#12349](https://github.com/crystal-lang/crystal/pull/12349), thanks @asterite)
- Interpreter: fix missing `upcast_distinct` from `A+` to `B` (`Crystal::VirtualType` to `Crystal::NonGenericClassType`) ([#12374](https://github.com/crystal-lang/crystal/pull/12374), thanks @asterite)
- Interpreter: discard tuple and named tuple ([#12387](https://github.com/crystal-lang/crystal/pull/12387), thanks @asterite)
- Interpreter: cast proc call arguments to proc arg types ([#12375](https://github.com/crystal-lang/crystal/pull/12375), thanks @asterite)
- Interpreter: set correct scope for class var initializer ([#12441](https://github.com/crystal-lang/crystal/pull/12441), thanks @asterite)
- Interpreter (repl): use new `MainVisitor` each time we need to interpret code ([#12512](https://github.com/crystal-lang/crystal/pull/12512), thanks @asterite)
- Interpreter: allow inspecting block vars without affecting program ([#12520](https://github.com/crystal-lang/crystal/pull/12520), thanks @asterite)
- Interpreter: check upcast in nilable cast ([#12533](https://github.com/crystal-lang/crystal/pull/12533), thanks @asterite)
- Interpreter: implement variable autocast ([#12563](https://github.com/crystal-lang/crystal/pull/12563), thanks @asterite)
- Interpreter: handle missing upcast from `GenericClassInstanceMetaclassType` to `VirtualMetaclassType` ([#12562](https://github.com/crystal-lang/crystal/pull/12562), thanks @asterite)
- Interpreter: let local vars be seen by macros in repl and pry ([#12240](https://github.com/crystal-lang/crystal/pull/12240), thanks @asterite)
- Interpreter: handle local variable type declaration ([#12239](https://github.com/crystal-lang/crystal/pull/12239), thanks @asterite)
- Support libffi on Windows ([#12200](https://github.com/crystal-lang/crystal/pull/12200), thanks @HertzDevil)
- Add `$CRYSTAL_INTERPRETER_LOADER_INFO` to show loaded libraries ([#12221](https://github.com/crystal-lang/crystal/pull/12221), thanks @straight-shoota)
- Interpreter: node override ([#12287](https://github.com/crystal-lang/crystal/pull/12287), thanks @asterite)
- Interpreter: introduce a `Prompt` type ([#12288](https://github.com/crystal-lang/crystal/pull/12288), thanks @asterite)
- Interpreter: missing `i += 1` ([#12381](https://github.com/crystal-lang/crystal/pull/12381), thanks @asterite)
- Support building the interpreter on Windows ([#12397](https://github.com/crystal-lang/crystal/pull/12397), thanks @HertzDevil)
- Don't exit in interpreter spec and change type from `Nil` to `NoReturn` in `FixMissingTypes` ([#12230](https://github.com/crystal-lang/crystal/pull/12230), thanks @asterite)
- Interpreter: fix multidispatch with captured block ([#12236](https://github.com/crystal-lang/crystal/pull/12236), thanks @asterite)
- Interpreter: don't change compiled mode logic ([#12252](https://github.com/crystal-lang/crystal/pull/12252), thanks @asterite)
- Wait more in `HTTP::Server` specs in interpreted mode ([#12420](https://github.com/crystal-lang/crystal/pull/12420), thanks @asterite)

#### Parser

- Lexer: fix index out of bounds when scanning numbers ([#12482](https://github.com/crystal-lang/crystal/pull/12482), thanks @asterite)
- Fix parser to never create doc from trailing comment ([#11268](https://github.com/crystal-lang/crystal/pull/11268), thanks @straight-shoota)
- Parser: declare local vars of indirect type declarations in call args ([#11983](https://github.com/crystal-lang/crystal/pull/11983), thanks @asterite)
- Remove redundant conditional ([#12196](https://github.com/crystal-lang/crystal/pull/12196), thanks @potomak)
- Warn on suffix-less integer literals outside `Int64`'s range ([#12427](https://github.com/crystal-lang/crystal/pull/12427), thanks @HertzDevil)
- Use enum instead of symbols for keywords in the lexer ([#11871](https://github.com/crystal-lang/crystal/pull/11871), thanks @HertzDevil)
- Parser: Rename `arg*` to `param*` ([#12235](https://github.com/crystal-lang/crystal/pull/12235), thanks @potomak)
- Fix test cases ([#12508](https://github.com/crystal-lang/crystal/pull/12508), thanks @potomak)

#### Semantic

- **(breaking-change)** Allow `Union` restrictions to be ordered before all other restrictions ([#12335](https://github.com/crystal-lang/crystal/pull/12335), thanks @HertzDevil)
- **(breaking-change)** Use more robust ordering between def overloads ([#10711](https://github.com/crystal-lang/crystal/pull/10711), thanks @HertzDevil)
- Fix: Instance vars should not be allowed on `Class`, `Tuple`, `NamedTuple`, `Enum`, `Pointer` , `Proc`, `StaticArray` and `Union`. ([#12160](https://github.com/crystal-lang/crystal/pull/12160), thanks @I3oris)
- Compiler and interpreter: fix `is_a?` from virtual metaclass to generic metaclass ([#12306](https://github.com/crystal-lang/crystal/pull/12306), thanks @asterite)
- Compiler: fix type descendent for union metaclass ([#12308](https://github.com/crystal-lang/crystal/pull/12308), thanks @asterite)
- Compiler: fix `is_a?` from generic class against generic class instance type ([#12312](https://github.com/crystal-lang/crystal/pull/12312), thanks @asterite)
- Fix `self` in restrictions when instantiating macro def in subtypes ([#10954](https://github.com/crystal-lang/crystal/pull/10954), thanks @HertzDevil)
- Never resolve free variables as types during overload ordering ([#11973](https://github.com/crystal-lang/crystal/pull/11973), thanks @HertzDevil)
- Use instantiated type as `self` when inferring instance variable types ([#12466](https://github.com/crystal-lang/crystal/pull/12466), thanks @HertzDevil)
- Fix restriction comparison between `Metaclass` and `Path` ([#12523](https://github.com/crystal-lang/crystal/pull/12523), thanks @HertzDevil)
- **(performance)** Compiler: don't always use Array for node dependencies and observers ([#12405](https://github.com/crystal-lang/crystal/pull/12405), thanks @asterite)
- Compiler: better error message for symbol against enum ([#12478](https://github.com/crystal-lang/crystal/pull/12478), thanks @asterite)

### Tools

#### Docs-generator

- Fix docs generator search constants id ([#12262](https://github.com/crystal-lang/crystal/pull/12262), thanks @GeopJr)

#### Formatter

- Formatter: format comment after select ([#12506](https://github.com/crystal-lang/crystal/pull/12506), thanks @asterite)
- Formatter: try to format macros that don't interpolate content ([#12378](https://github.com/crystal-lang/crystal/pull/12378), thanks @asterite)

#### Playground

- Playground: Fix pass bound hostname to run sessions ([#12356](https://github.com/crystal-lang/crystal/pull/12356), thanks @orangeSi)
- Don't show stacktrace when playground port is already in use. ([#11844](https://github.com/crystal-lang/crystal/pull/11844), thanks @hugopl)
- Indent playground code using spaces ([#12231](https://github.com/crystal-lang/crystal/pull/12231), thanks @potomak)

### Other

- `bin/crystal`: Ensure `sh` compatibility ([#12486](https://github.com/crystal-lang/crystal/pull/12486), thanks @HertzDevil)
- bumping version 1.6.0-dev ([#12263](https://github.com/crystal-lang/crystal/pull/12263), thanks @beta-ziliani)
- updating CI to 1.5.0 ([#12260](https://github.com/crystal-lang/crystal/pull/12260), thanks @beta-ziliani)
- Add fish shell completion ([#12026](https://github.com/crystal-lang/crystal/pull/12026), thanks @TunkShif)
- Execute `compopt` only when it's present ([#12248](https://github.com/crystal-lang/crystal/pull/12248), thanks @potomak)
- Use `Makefile.win` and wrapper script on Windows CI ([#12344](https://github.com/crystal-lang/crystal/pull/12344), thanks @HertzDevil)
- [Makefile] Add format target ([#11420](https://github.com/crystal-lang/crystal/pull/11420), thanks @straight-shoota)
- Update contact section of CODE of CONDUCT ([#9219](https://github.com/crystal-lang/crystal/pull/9219), thanks @paulcsmith)
- Update nixpkgs 22.05 and LLVM 11 ([#12498](https://github.com/crystal-lang/crystal/pull/12498), thanks @straight-shoota)
- [Makefile] Use `EXPORT_CC` for `make crystal` ([#11760](https://github.com/crystal-lang/crystal/pull/11760), thanks @straight-shoota)
- Update distribution-scripts ([#12502](https://github.com/crystal-lang/crystal/pull/12502), [#12555](https://github.com/crystal-lang/crystal/pull/12555), thanks @straight-shoota)
- Fix and enhance `scripts/update-distribution-scripts.sh` ([#12503](https://github.com/crystal-lang/crystal/pull/12503), thanks @straight-shoota)
- [CI] Upgrade GitHub Actions to macos-11 ([#12500](https://github.com/crystal-lang/crystal/pull/12500), thanks @straight-shoota)
- Add icon and metadata to Windows Crystal compiler binary ([#12494](https://github.com/crystal-lang/crystal/pull/12494), thanks @HertzDevil)
- Remove `spec/win32_std_spec.cr` and `spec/generate_windows_spec.sh` ([#12282](https://github.com/crystal-lang/crystal/pull/12282), [#12549](https://github.com/crystal-lang/crystal/pull/12549), thanks @HertzDevil and @straight-shoota)

## [1.5.1] - 2022-09-07

[1.5.1]: https://github.com/crystal-lang/crystal/releases/1.5.1

### Standard Library

- Fix `Class#nilable?` for recursive unions and root types ([#12353](https://github.com/crystal-lang/crystal/pull/12353), thanks @HertzDevil)

#### Numeric

- Fix `Float#abs` and `Number#format` for `-0.0` ([#12424](https://github.com/crystal-lang/crystal/pull/12424), thanks @straight-shoota)

#### Text

- Fix null dereference when passing empty slice to `Base64.encode` ([#12377](https://github.com/crystal-lang/crystal/pull/12377), thanks @dscottboggs)

### Compiler

- Do not check abstract def parameter names on abstract types and modules ([#12434](https://github.com/crystal-lang/crystal/pull/12434), thanks @HertzDevil)

#### Codegen

- Compiler/codegen: reset `@needs_value` ([#12444](https://github.com/crystal-lang/crystal/pull/12444), thanks @asterite)
- Fix `homogeneous_aggregate?` check for aarch64 types ([#12445](https://github.com/crystal-lang/crystal/pull/12445), thanks @mattrberry)

#### Semantic

- Compiler: don't eagerly check cast type ([#12272](https://github.com/crystal-lang/crystal/pull/12272), thanks @asterite)
- Fix type restriction augmenter for `Union(*T)` and similar ([#12438](https://github.com/crystal-lang/crystal/pull/12438), thanks @asterite)

### Tools

#### Formatter

- Formatter: Fix assign followed by comment ([#12319](https://github.com/crystal-lang/crystal/pull/12319), thanks @straight-shoota)
- Handle formatting annotated method parameters ([#12446](https://github.com/crystal-lang/crystal/pull/12446), thanks @Blacksmoke16)

### Other

- Update distribution-scripts ([#12359](https://github.com/crystal-lang/crystal/pull/12359), thanks @straight-shoota)
- Update distribution-scripts ([#12333](https://github.com/crystal-lang/crystal/pull/12333), thanks @straight-shoota)
- [CI] Bumping xcode to 13.4.1 ([#12264](https://github.com/crystal-lang/crystal/pull/12264), thanks @beta-ziliani)

## [1.5.0] - 2022-07-06

[1.5.0]: https://github.com/crystal-lang/crystal/releases/1.5.0

### Language

- **(breaking-change)** Warn on positional parameter mismatches for abstract def implementations ([#11915](https://github.com/crystal-lang/crystal/pull/11915), [#12167](https://github.com/crystal-lang/crystal/pull/12167), thanks @HertzDevil)
- Fix `\{{...}}` syntax in macro inside comments ([#12175](https://github.com/crystal-lang/crystal/pull/12175), thanks @asterite)
- Let constant tuple indexers work with constants ([#12012](https://github.com/crystal-lang/crystal/pull/12012), thanks @asterite)
- Refactor restriction mechanism for autocasting ([#12014](https://github.com/crystal-lang/crystal/pull/12014), thanks @HertzDevil)
- Support unions in `Crystal::Macros::ASTNode#is_a?` ([#12086](https://github.com/crystal-lang/crystal/pull/12086), thanks @HertzDevil)
- Experimental: restriction augmenter ([#12103](https://github.com/crystal-lang/crystal/pull/12103), [#12136](https://github.com/crystal-lang/crystal/pull/12136), [#12143](https://github.com/crystal-lang/crystal/pull/12143), [#12130](https://github.com/crystal-lang/crystal/pull/12130), thanks @asterite)
- Method/macro parameter annotation support ([#12044](https://github.com/crystal-lang/crystal/pull/12044), thanks @Blacksmoke16)

### Standard Library

- Support `Path` for `chdir` arg in `Process` methods ([#11932](https://github.com/crystal-lang/crystal/pull/11932), thanks @caspiano)
- Add docs for `Enum#value` ([#11947](https://github.com/crystal-lang/crystal/pull/11947), thanks @lbguilherme)
- Fix positional parameter warnings in specs ([#12158](https://github.com/crystal-lang/crystal/pull/12158), thanks @straight-shoota)
- Use more specific expectations in specs ([#11951](https://github.com/crystal-lang/crystal/pull/11951), thanks @HertzDevil)
- Use `contain` expectations in more specs ([#11950](https://github.com/crystal-lang/crystal/pull/11950), thanks @HertzDevil)

#### Collection

- Fix `Hash#reject!` for non-equality key ([#10511](https://github.com/crystal-lang/crystal/pull/10511), thanks @straight-shoota)
- Introduce `Tuple.element_type` and `NamedTuple.element_type` ([#12011](https://github.com/crystal-lang/crystal/pull/12011), thanks @HertzDevil)
- Rename "take" to "first" ([#11988](https://github.com/crystal-lang/crystal/pull/11988), thanks @jmdyck)
- Add spec for `Array#-` with different generic type arguments ([#12049](https://github.com/crystal-lang/crystal/pull/12049), thanks @straight-shoota)

#### Concurrency

- Windows: Always use `GC_set_stackbottom` on Windows ([#12186](https://github.com/crystal-lang/crystal/pull/12186), thanks @HertzDevil)
- Windows: Event loop based on IOCP ([#12149](https://github.com/crystal-lang/crystal/pull/12149), thanks @straight-shoota, @wonderix, @yxhuvud, @HertzDevil)
- Use enum instead of symbol for `Atomic` primitives ([#11583](https://github.com/crystal-lang/crystal/pull/11583), thanks @HertzDevil)
- Allow `Enumerable(Channel)` parameter for  `Channel.send_first`, `.receive_first` ([#12101](https://github.com/crystal-lang/crystal/pull/12101), thanks @carlhoerberg)

#### Crypto

- **(performance)** Add faster `Digest#hexfinal` ([#9292](https://github.com/crystal-lang/crystal/pull/9292), thanks @didactic-drunk)
- Handle OpenSSL 3.0 KTLS ctrl calls ([#12034](https://github.com/crystal-lang/crystal/pull/12034), thanks @1player)

#### Files

- Fix `Path#join(Enumerable)` ([#12032](https://github.com/crystal-lang/crystal/pull/12032), thanks @straight-shoota)
- Fix `Path#join` to convert argument path to base kind ([#12033](https://github.com/crystal-lang/crystal/pull/12033), thanks @straight-shoota)
- Fix `Dir.glob` with multi components after recursive wildcard ([#12057](https://github.com/crystal-lang/crystal/pull/12057), thanks @straight-shoota)
- Add `File#delete?` and `Dir#delete?` ([#11887](https://github.com/crystal-lang/crystal/pull/11887), thanks @didactic-drunk)
- Accept `Path` arguments in `Compress::Zip` ([#11925](https://github.com/crystal-lang/crystal/pull/11925), thanks @didactic-drunk)
- Update file.cr ([#12024](https://github.com/crystal-lang/crystal/pull/12024), thanks @rdp)
- Add `File#chown` and `#chmod` ([#11886](https://github.com/crystal-lang/crystal/pull/11886), thanks @didactic-drunk)

#### Log

- Change `Log` emitters to not emit event when block output is `nil` ([#12000](https://github.com/crystal-lang/crystal/pull/12000), thanks @robacarp)

#### Networking

- Enable more networking specs on Windows ([#12176](https://github.com/crystal-lang/crystal/pull/12176), thanks @HertzDevil)
- Add specs for Windows directory separators in `StaticFileHandler` paths ([#11884](https://github.com/crystal-lang/crystal/pull/11884), thanks @straight-shoota)
- Add property `HTTP::Server::Response#status_message` ([#10416](https://github.com/crystal-lang/crystal/pull/10416), thanks @straight-shoota)

#### Numeric

- Fix `Complex.multiplicative_identity` ([#12051](https://github.com/crystal-lang/crystal/pull/12051), thanks @I3oris)
- Add docs for `Float`, `BigFloat` rounding methods ([#12004](https://github.com/crystal-lang/crystal/pull/12004), thanks @marksiemers)
- Implement rt builtins `__ashlti3`, `__ashrti3` and `__lshrti3` for wasm32 ([#11948](https://github.com/crystal-lang/crystal/pull/11948), thanks @lbguilherme)

#### Specs

- Align `Spec::Be`, `BeClose` failure message to other messages ([#11946](https://github.com/crystal-lang/crystal/pull/11946), thanks @jgaskins)

#### System

- **(security)** Fix check for null byte in `File#tempfile` args ([#12076](https://github.com/crystal-lang/crystal/pull/12076), thanks @straight-shoota)
- Add missing `SC_PAGESIZE` constant for `aarch64-darwin` ([#12037](https://github.com/crystal-lang/crystal/pull/12037), thanks @carlhoerberg)
- Docs: Add more prominent note about path traversal in `File.tempfile` ([#12077](https://github.com/crystal-lang/crystal/pull/12077), thanks @straight-shoota)
- Support `Enumerable` as argument to `File.join` ([#12102](https://github.com/crystal-lang/crystal/pull/12102), thanks @caspiano)

#### Runtime

- Mention `#value` explicitly in `Pointer` overview. ([#12184](https://github.com/crystal-lang/crystal/pull/12184), thanks @elebow)

#### Text

- Add specs for `String#char_bytesize_at` ([#11872](https://github.com/crystal-lang/crystal/pull/11872), thanks @straight-shoota)
- Flush shift state for `String#encode` ([#11993](https://github.com/crystal-lang/crystal/pull/11993), thanks @HertzDevil)
- Handle invalid bytes in single-byte optimizable `String`s correctly ([#12108](https://github.com/crystal-lang/crystal/pull/12108), thanks @HertzDevil)
- Fix: Don't stop on null byte in `String#%` ([#12125](https://github.com/crystal-lang/crystal/pull/12125), thanks @asterite)
- Add `UUID.parse?` ([#11998](https://github.com/crystal-lang/crystal/pull/11998), thanks @jgaskins)

#### Time

- Fix: Better error message for `Time.parse!` when end of input is reached ([#12124](https://github.com/crystal-lang/crystal/pull/12124), thanks @asterite)

### Compiler

- Clean up compiler warning specs ([#11916](https://github.com/crystal-lang/crystal/pull/11916), thanks @HertzDevil)
- Add support for `NO_COLOR` to `Colorize` ([#11984](https://github.com/crystal-lang/crystal/pull/11984), thanks @didactic-drunk)
- **(performance)** Use LLVM's new pass manager when possible ([#12116](https://github.com/crystal-lang/crystal/pull/12116), thanks @asterite)

#### Macros

- Document `Crystal::Macros::Self` and `Underscore` ([#12085](https://github.com/crystal-lang/crystal/pull/12085), thanks @HertzDevil)

#### Generics

- Allow the empty instantiation `NamedTuple()` ([#12009](https://github.com/crystal-lang/crystal/pull/12009), thanks @HertzDevil)

#### Interpreter

- Add missing `EXPORT` in interpreter spec ([#12201](https://github.com/crystal-lang/crystal/pull/12201), thanks @HertzDevil)
- Handle escaping exceptions in pry ([#12211](https://github.com/crystal-lang/crystal/pull/12211), thanks @asterite)
- Allow some options, and colorize whereami ([#12198](https://github.com/crystal-lang/crystal/pull/12198), thanks @asterite)
- Fix instance var offset of virtual struct ([#12189](https://github.com/crystal-lang/crystal/pull/12189), thanks @asterite)
- Handle explicit return when method type is Nil ([#12179](https://github.com/crystal-lang/crystal/pull/12179), thanks @asterite)
- `Crystal::Loader`: don't check if file exists, leave that to dlopen ([#12207](https://github.com/crystal-lang/crystal/pull/12207), thanks @asterite)
- Fix call receiver by value from VirtualType struct ([#12194](https://github.com/crystal-lang/crystal/pull/12194), thanks @asterite)
- Clear finished hooks after intepreting ([#12174](https://github.com/crystal-lang/crystal/pull/12174), thanks @asterite)
- Fix FFI bindings for libffi >= 3.4 ([#12192](https://github.com/crystal-lang/crystal/pull/12192), thanks @straight-shoota)
- Fix `.class` for modules and unions ([#12205](https://github.com/crystal-lang/crystal/pull/12205), thanks @asterite)
- Implement `Crystal::Loader` for MSVC ([#12140](https://github.com/crystal-lang/crystal/pull/12140), thanks @HertzDevil)
- Fix: cast from virtual metaclass to union ([#12163](https://github.com/crystal-lang/crystal/pull/12163), thanks @asterite)
- Allow inspect vars when inside a block ([#12165](https://github.com/crystal-lang/crystal/pull/12165), thanks @asterite)
- Let pry see closured vars ([#12169](https://github.com/crystal-lang/crystal/pull/12169), thanks @asterite)
- Fix caller ([#12182](https://github.com/crystal-lang/crystal/pull/12182), thanks @asterite)
- Apply shell expansion in ldflags ([#12094](https://github.com/crystal-lang/crystal/pull/12094), thanks @mdwagner)
- Fix expression value of constant assignment in interpreter ([#12016](https://github.com/crystal-lang/crystal/pull/12016), thanks @beta-ziliani)
- Fix: Don't link `librt` and `libdl` on GNU systems ([#12038](https://github.com/crystal-lang/crystal/pull/12038), thanks @1player)

#### Parser

- **(breaking-change)** Disallow empty parameter and argument names ([#11971](https://github.com/crystal-lang/crystal/pull/11971), thanks @HertzDevil)
- Disallow duplicate free variables in defs ([#11965](https://github.com/crystal-lang/crystal/pull/11965), thanks @HertzDevil)
- Disallow duplicate `fun` parameter names ([#11967](https://github.com/crystal-lang/crystal/pull/11967), thanks @HertzDevil)
- Remove redundant check for EOF on `Crystal::Parser` ([#12067](https://github.com/crystal-lang/crystal/pull/12067), thanks @lbguilherme)

#### Semantic

- Compiler: don't check ivar read forms a closure in `exp.@x` ([#12183](https://github.com/crystal-lang/crystal/pull/12183), thanks @asterite)
- Compiler: raise when allocating an abstract virtual type ([#12141](https://github.com/crystal-lang/crystal/pull/12141), thanks @asterite)
- Compiler: don't use `with_scope` if Call has a receiver ([#12138](https://github.com/crystal-lang/crystal/pull/12138), thanks @asterite)
- Compiler: fix proc return type restriction for `Proc(...)` ([#12129](https://github.com/crystal-lang/crystal/pull/12129), thanks @asterite)
- Compiler: simpler way to compute `Def#raises?` ([#12121](https://github.com/crystal-lang/crystal/pull/12121), thanks @asterite)
- Remove unused `ASTNode#unbind_all` ([#12120](https://github.com/crystal-lang/crystal/pull/12120), thanks @asterite)

#### Debugger

- Improve the LLDB spec driver script ([#12119](https://github.com/crystal-lang/crystal/pull/12119), thanks @HertzDevil)

### Tools

#### Docs-generator

- [Docs] Adjust method sort order to sort all operators first ([#12104](https://github.com/crystal-lang/crystal/pull/12104), thanks @straight-shoota)

#### Formatter

- Fix formatter lib-fun declaration with newlines ([#12071](https://github.com/crystal-lang/crystal/pull/12071), thanks @ftarulla)
- Fix formatter alias-def with no-space before equals ([#12073](https://github.com/crystal-lang/crystal/pull/12073), thanks @ftarulla)
- Fix formatter for parenthesized arg after space ([#11972](https://github.com/crystal-lang/crystal/pull/11972), thanks @straight-shoota)

#### Playground

- Playground: fix `modalContenDom` typo ([#12188](https://github.com/crystal-lang/crystal/pull/12188), thanks @HertzDevil)
- Fix: Unset executable bit from js/css files in playground ([#12053](https://github.com/crystal-lang/crystal/pull/12053), thanks @carlhoerberg)

### Other

- [CI] Add build compiler step to smoke tests ([#11814](https://github.com/crystal-lang/crystal/pull/11814), thanks @straight-shoota)
- Add Makefile for Windows ([#11773](https://github.com/crystal-lang/crystal/pull/11773), thanks @HertzDevil)
- [CI] Update distribution-scripts ([#12155](https://github.com/crystal-lang/crystal/pull/12155), thanks @straight-shoota)
- [CI] Add `update-distributions-scripts.sh` ([#12156](https://github.com/crystal-lang/crystal/pull/12156), thanks @straight-shoota)
- [CI] Ignore `pax_global_header` on Windows CI ([#12173](https://github.com/crystal-lang/crystal/pull/12173), thanks @HertzDevil)
- [CI] Invalidate cached libraries on new MSVC release ([#12064](https://github.com/crystal-lang/crystal/pull/12064), thanks @HertzDevil)
- Fix spelling ([#12040](https://github.com/crystal-lang/crystal/pull/12040), thanks @jsoref)
- Update previous Crystal release - 1.4.1 ([#12029](https://github.com/crystal-lang/crystal/pull/12029), thanks @straight-shoota)
- [CI] Pin version of ubuntu base image for circleci jobs ([#12030](https://github.com/crystal-lang/crystal/pull/12030), thanks @straight-shoota)
- Samples: avoid `Symbol` variables ([#11923](https://github.com/crystal-lang/crystal/pull/11923), thanks @HertzDevil)

## [1.4.1] - 2022-04-22

[1.4.1]: https://github.com/crystal-lang/crystal/releases/1.4.1

### Standard Library

#### Collection

- Avoid compile-time error on empty `NamedTuple`s. ([#12007](https://github.com/crystal-lang/crystal/pull/12007), thanks @I3oris)

#### Files

- Add missing fun def for `__xstat` ([#11985](https://github.com/crystal-lang/crystal/pull/11985), thanks @straight-shoota)

#### Runtime

- Add `pthread` link annotations in lib bindings ([#12013](https://github.com/crystal-lang/crystal/pull/12013), thanks @straight-shoota)
- Fix GC typedefs on Windows ([#11963](https://github.com/crystal-lang/crystal/pull/11963), thanks @HertzDevil)

### Compiler

#### Semantic

- Compiler: remove duplicate instance vars once we know them all ([#11995](https://github.com/crystal-lang/crystal/pull/11995), thanks @asterite)

## [1.4.0] - 2022-04-06

[1.4.0]: https://github.com/crystal-lang/crystal/releases/1.4.0

### Language

- Add support for `Int128` in codegen and macros ([#11576](https://github.com/crystal-lang/crystal/pull/11576), thanks @BlobCodes)
- Support `ProcPointer`s with global path and top-level method references ([#11777](https://github.com/crystal-lang/crystal/pull/11777), thanks @HertzDevil)
- Fix documentation for macros `system` and `run` ([#11740](https://github.com/crystal-lang/crystal/pull/11740), thanks @lbguilherme)
- Experimental: better type inference for ivars/cvars ([#11812](https://github.com/crystal-lang/crystal/pull/11812), thanks @asterite)
- Support `@[Deprecated]` on constants ([#11680](https://github.com/crystal-lang/crystal/pull/11680), thanks @HertzDevil)

### Standard Library

- Fix compiler flags with optional arg eating following flags ([#11201](https://github.com/crystal-lang/crystal/pull/11201), thanks @yb66)
- Support GNU style optional arguments in `OptionParser` ([#11546](https://github.com/crystal-lang/crystal/pull/11546), thanks @HertzDevil)
- Remove some unnecessary link annotations ([#11563](https://github.com/crystal-lang/crystal/pull/11563), thanks @straight-shoota)
- Remove useless assignments ([#11774](https://github.com/crystal-lang/crystal/pull/11774), thanks @IgorPolyakov)
- Use "truthy" and "falsey" in more places in the documentation ([#11784](https://github.com/crystal-lang/crystal/pull/11784), thanks @HertzDevil)
- Add missing code blocks for `self` in documentation ([#11718](https://github.com/crystal-lang/crystal/pull/11718), thanks @HertzDevil)
- Add support for LLVM 14.0 ([#11905](https://github.com/crystal-lang/crystal/pull/11905), thanks @HertzDevil)
- Fix code examples in doc comments (2022-03) ([#11927](https://github.com/crystal-lang/crystal/pull/11927), thanks @maiha)

#### Collection

- Remove `Iterator.of(Iterator.stop)` from implementations ([#11613](https://github.com/crystal-lang/crystal/pull/11613), thanks @asterite)
- Add allow `Enumerable` arguments for `Hash#select` and `#reject` ([#11750](https://github.com/crystal-lang/crystal/pull/11750), thanks @mamantoha)
- Add docs for `Hash#reject!` ([#11691](https://github.com/crystal-lang/crystal/pull/11691), thanks @wontruefree)
- Add raising method variants `Enumerable#find!` and `#index!` ([#11566](https://github.com/crystal-lang/crystal/pull/11566), thanks @yxhuvud)
- **(performance)** Optimize block-less overloads of `BitArray#fill` ([#11450](https://github.com/crystal-lang/crystal/pull/11450), thanks @HertzDevil)
- Adds docs for `Array#replace` ([#11682](https://github.com/crystal-lang/crystal/pull/11682), thanks @wontruefree)
- **(performance)** Optimize `BitArray`'s counting methods ([#11591](https://github.com/crystal-lang/crystal/pull/11591), thanks @HertzDevil)
- Add some return types to Array, Hash, Set and String ([#11822](https://github.com/crystal-lang/crystal/pull/11822), thanks @asterite)
- Add `Hash#update` ([#11881](https://github.com/crystal-lang/crystal/pull/11881), thanks @ftarulla)
- Allow `Bytes[]` to construct an empty `Bytes` ([#11897](https://github.com/crystal-lang/crystal/pull/11897), thanks @HertzDevil)
- Improve `BitArray`'s constructors ([#11898](https://github.com/crystal-lang/crystal/pull/11898), thanks @HertzDevil)
- Add overload to `Enumerable#tally` and `#tally_by` accepting a hash ([#11815](https://github.com/crystal-lang/crystal/pull/11815), thanks @mamantoha)

#### Crypto

- Add support for Bcrypt algorithm version `2b` ([#11595](https://github.com/crystal-lang/crystal/pull/11595), thanks @docelic)

#### Files

- Fix race condition in `chown` ([#11885](https://github.com/crystal-lang/crystal/pull/11885), thanks @didactic-drunk)
- Add docs for `Dir#each_child` ([#11688](https://github.com/crystal-lang/crystal/pull/11688), thanks @wontruefree)
- Add docs for `Dir#path` ([#11689](https://github.com/crystal-lang/crystal/pull/11689), thanks @wontruefree)
- Support read-write + binary file modes in `File.open` ([#11817](https://github.com/crystal-lang/crystal/pull/11817), thanks @HertzDevil)
- Add docs for `Dir#entries` ([#11701](https://github.com/crystal-lang/crystal/pull/11701), thanks @wontruefree)
- Add `IO#getb_to_end` ([#11830](https://github.com/crystal-lang/crystal/pull/11830), thanks @HertzDevil)
- Fix `IO::FileDescriptor#pos` giving incorrect position after write ([#10865](https://github.com/crystal-lang/crystal/pull/10865), thanks @didactic-drunk)
- Remove reference to binary file mode in `File.open` ([#11824](https://github.com/crystal-lang/crystal/pull/11824), thanks @HertzDevil)

#### Macros

- Add `#parse_type` ([#11126](https://github.com/crystal-lang/crystal/pull/11126), thanks @Blacksmoke16)

#### Networking

- **(performance)** Optimize `URI.decode` ([#11741](https://github.com/crystal-lang/crystal/pull/11741), thanks @asterite)
- Fix `address_spec` expectation for Windows Server 2022 ([#11794](https://github.com/crystal-lang/crystal/pull/11794), thanks @straight-shoota)
- Add `space_to_plus` option in `URI::Params` everywhere ([#11821](https://github.com/crystal-lang/crystal/pull/11821), thanks @asterite)
- Improve `URI::Params#inspect` to use hash-like literal ([#11880](https://github.com/crystal-lang/crystal/pull/11880), thanks @straight-shoota)
- Use enums instead of symbols for `MIME::Multipart` and `HTTP::FormData` ([#11617](https://github.com/crystal-lang/crystal/pull/11617), thanks @HertzDevil)

#### Numeric

- **(breaking-change)** Fix: Hide `BigDecimal::ZERO` and `BigDecimal::TEN` ([#11820](https://github.com/crystal-lang/crystal/pull/11820), thanks @lbguilherme)
- **(breaking-change)** Add support for scientific notation in `BigFloat#to_s` ([#10632](https://github.com/crystal-lang/crystal/pull/10632), thanks @HertzDevil)
- Fix: Inspect string in error message for number parsing ([#11883](https://github.com/crystal-lang/crystal/pull/11883), thanks @straight-shoota)
- Add docs for `Complex#zero?` ([#11697](https://github.com/crystal-lang/crystal/pull/11697), thanks @wontruefree)
- Fix E notation parsing in `BigDecimal` ([#9577](https://github.com/crystal-lang/crystal/pull/9577), thanks @stevegeek)
- **(performance)** Optimize Integer decoding from bytes ([#11796](https://github.com/crystal-lang/crystal/pull/11796), thanks @carlhoerberg)

#### Runtime

- Fix interpreter when shared library `pthread` is missing ([#11807](https://github.com/crystal-lang/crystal/pull/11807), thanks @straight-shoota)
- **(performance)** Implement `Intrinsics.pause` for aarch64 ([#11742](https://github.com/crystal-lang/crystal/pull/11742), thanks @lbguilherme, @jgaskins)
- Add crash handler on Windows ([#11570](https://github.com/crystal-lang/crystal/pull/11570), thanks @HertzDevil)
- Add specs for `NamedTuple#from` ([#11816](https://github.com/crystal-lang/crystal/pull/11816), thanks @straight-shoota)
- Improve error for incompatible generic arguments for `WeakRef` ([#11911](https://github.com/crystal-lang/crystal/pull/11911), thanks @straight-shoota)
- Add the wasm entrypoint defined in Crystal ([#11936](https://github.com/crystal-lang/crystal/pull/11936), thanks @lbguilherme)

#### Serialization

- Allow passing instance method or conditional expressions to option `ignore_serialize` on `JSON::Field` ([#11804](https://github.com/crystal-lang/crystal/pull/11804), thanks @cyangle)
- Implement `Iterator.from_json` and `#to_json` ([#10437](https://github.com/crystal-lang/crystal/pull/10437), thanks @wonderix)

#### Specs

- Add `file` and `line` arguments to `it_iterates` ([#11628](https://github.com/crystal-lang/crystal/pull/11628), thanks @straight-shoota)
- Remove duplicate word in documentation ([#11797](https://github.com/crystal-lang/crystal/pull/11797), thanks @samueleaton)

#### System

- **(breaking-change)** **(security)** Fix character mappings for Windows path conversions ([#11847](https://github.com/crystal-lang/crystal/pull/11847), thanks @straight-shoota)
- Add fallback for `Path.home` on Unix ([#11544](https://github.com/crystal-lang/crystal/pull/11544), thanks @HertzDevil)
- Relax `ENV.fetch(key, &)`'s block restriction ([#11779](https://github.com/crystal-lang/crystal/pull/11779), thanks @HertzDevil)
- Refactor target clauses for system implementations ([#11813](https://github.com/crystal-lang/crystal/pull/11813), thanks @straight-shoota)
- Fix `Path` support for UNC shares ([#11827](https://github.com/crystal-lang/crystal/pull/11827), thanks @straight-shoota)
- Fix regression for Linux older than 3.17: properly check that `getrandom` is available ([#11953](https://github.com/crystal-lang/crystal/pull/11953), thanks @lbguilherme)

#### Text

- Fix ensure PCRE JIT mode is available before running spec ([#11533](https://github.com/crystal-lang/crystal/pull/11533), thanks @Blacksmoke16)
- Add more `Colorize` overloads and fix docs ([#11832](https://github.com/crystal-lang/crystal/pull/11832), thanks @asterite)
- Refactor `Colorize::Mode` enum ([#11663](https://github.com/crystal-lang/crystal/pull/11663), thanks @straight-shoota)
- Add some docs for `UUID` ([#11683](https://github.com/crystal-lang/crystal/pull/11683), thanks @wontruefree)
- Add docs for `UUID#urn` ([#11693](https://github.com/crystal-lang/crystal/pull/11693), thanks @wontruefree)
- Add docs for `String#[]` ([#11690](https://github.com/crystal-lang/crystal/pull/11690), thanks @wontruefree)
- Allow explicit usage of `libiconv` ([#11876](https://github.com/crystal-lang/crystal/pull/11876), thanks @luislavena)
- **(breaking-change)** Fix: Honour encoding in `IO::Memory#to_s` ([#11875](https://github.com/crystal-lang/crystal/pull/11875), thanks @straight-shoota)
- Add `self` return type to `UUID` constructor methods ([#10539](https://github.com/crystal-lang/crystal/pull/10539), thanks @straight-shoota)
- Fix infinite loop for certain `StringPool` initial capacities ([#11929](https://github.com/crystal-lang/crystal/pull/11929), thanks @HertzDevil)

#### Time

- Add examples to `Time::Format` methods ([#11713](https://github.com/crystal-lang/crystal/pull/11713), thanks @ThunderKey)
- Support day of year (`%j`) in `Time` parsers ([#11791](https://github.com/crystal-lang/crystal/pull/11791), thanks @HertzDevil)

### Compiler

- Hello WebAssembly! (MVP implementation) ([#10870](https://github.com/crystal-lang/crystal/pull/10870), thanks @lbguilherme)
- Fix compiler specs git integration for configurable default branch ([#11754](https://github.com/crystal-lang/crystal/pull/11754), thanks @yxhuvud)
- `Crystal::ToSVisitor`: Remove `decorate_*` methods ([#11724](https://github.com/crystal-lang/crystal/pull/11724), thanks @HertzDevil)
- Use fewer symbols in the compiler source ([#11625](https://github.com/crystal-lang/crystal/pull/11625), thanks @HertzDevil)
- Add support for `--m*` flags to `crystal spec` and `crystal eval` ([#11767](https://github.com/crystal-lang/crystal/pull/11767), thanks @yxhuvud)
- Add local compiler wrapper script for Windows ([#11524](https://github.com/crystal-lang/crystal/pull/11524), thanks @HertzDevil)
- Add `Crystal::Program#check_deprecation` ([#11684](https://github.com/crystal-lang/crystal/pull/11684), thanks @HertzDevil)
- Refactor symbols for primitive number kinds to enums ([#11621](https://github.com/crystal-lang/crystal/pull/11621), thanks @HertzDevil)
- Remove useless assignments II ([#11843](https://github.com/crystal-lang/crystal/pull/11843), thanks @IgorPolyakov)
- Limit the number of rendered overloads on signature mismatch ([#10890](https://github.com/crystal-lang/crystal/pull/10890), thanks @caspiano)
- Support "can't infer type parameter" error for uninstantiated generic modules ([#11904](https://github.com/crystal-lang/crystal/pull/11904), thanks @HertzDevil)
- Fix: Accept only option flags in `CRYSTAL_OPTS` for build commands ([#11922](https://github.com/crystal-lang/crystal/pull/11922), thanks  @HertzDevil, @beta-ziliani)
- Evaluate `LibLLVM::IS_LT_*` during macro expansion time ([#11913](https://github.com/crystal-lang/crystal/pull/11913), thanks @HertzDevil)
- Fix incorrect var type inside nested exception handler ([#11928](https://github.com/crystal-lang/crystal/pull/11928), thanks @asterite)
- Fix: Look up return type in defining type ([#11962](https://github.com/crystal-lang/crystal/pull/11962), thanks @asterite)

#### Codegen

- **(performance)** Codegen: Do not always request value for `Proc#call` ([#11675](https://github.com/crystal-lang/crystal/pull/11675), thanks @HertzDevil)

#### Debugger

- Fix debug location of inlined `Proc#call` body ([#11676](https://github.com/crystal-lang/crystal/pull/11676), thanks @HertzDevil)

#### Generics

- Resolve non-type free variables in return type restrictions ([#11861](https://github.com/crystal-lang/crystal/pull/11861), thanks @HertzDevil)
- Fix recursive `pointerof` detection with generic splat type variables ([#11811](https://github.com/crystal-lang/crystal/pull/11811), thanks @HertzDevil)

#### Interpreter

- Fix for Crystal interpreter crash ([#11717](https://github.com/crystal-lang/crystal/pull/11717), thanks @wmoxam)
- Interpreter: support `Tuple#[]` with range literals ([#11783](https://github.com/crystal-lang/crystal/pull/11783), thanks @HertzDevil)
- Interpreter: Promote arguments of variadic function calls ([#11795](https://github.com/crystal-lang/crystal/pull/11795), thanks @straight-shoota)
- Check if libraries are present using `dlopen` ([#11852](https://github.com/crystal-lang/crystal/pull/11852), thanks @FnControlOption)
- Use `Crystal::Loader` in the interpreter ([#11579](https://github.com/crystal-lang/crystal/pull/11579), thanks @straight-shoota)
- Improve `Crystal::Loader` errors ([#11860](https://github.com/crystal-lang/crystal/pull/11860), thanks @straight-shoota)
- Enable interpreter integration specs for `YAML` ([#11801](https://github.com/crystal-lang/crystal/pull/11801), thanks @straight-shoota)

#### Parser

- Fix parser error with semicolon + newline in parenthesized `Expressions` ([#11769](https://github.com/crystal-lang/crystal/pull/11769), thanks @straight-shoota)
- Fix comment indentation in `ASTNode#to_s` ([#11851](https://github.com/crystal-lang/crystal/pull/11851), thanks @FnControlOption)
- Add locations for `else`, `ensure`, `end` keywords ([#11476](https://github.com/crystal-lang/crystal/pull/11476), thanks @FnControlOption)
- Add parser support to handle CRLF the same as LF ([#11810](https://github.com/crystal-lang/crystal/pull/11810), thanks @asterite)
- Lexer: use `Crystal::Token::Kind` enum instead of symbols ([#11616](https://github.com/crystal-lang/crystal/pull/11616), thanks @HertzDevil)
- Support `Generic` nodes with no type variables ([#11906](https://github.com/crystal-lang/crystal/pull/11906), thanks @HertzDevil)

#### Semantic

- **(breaking-change)** Drop `skip_abstract_def_check` flag support ([#9217](https://github.com/crystal-lang/crystal/pull/9217), thanks @makenowjust)
- Add error when instance variable is inherited from module and supertype ([#11768](https://github.com/crystal-lang/crystal/pull/11768), thanks @straight-shoota)
- Check file-private types for abstract defs and recursive structs ([#11838](https://github.com/crystal-lang/crystal/pull/11838), thanks @HertzDevil)
- Fix: Prevent eager `instance_sizeof` on structs ([#11856](https://github.com/crystal-lang/crystal/pull/11856), thanks @mattrberry)
- Fix: Do not consider global `Path` in def parameter restriction as free variable ([#11862](https://github.com/crystal-lang/crystal/pull/11862), thanks @HertzDevil)

### Tools

- Do not inherit from `Hash` in the compiler ([#11707](https://github.com/crystal-lang/crystal/pull/11707), thanks @HertzDevil)
- Use `OptionParser` in `crystal env` ([#11720](https://github.com/crystal-lang/crystal/pull/11720), thanks @HertzDevil)

#### Playground

- Replace PNG icon with optimized SVG for playground ([#7616](https://github.com/crystal-lang/crystal/pull/7616), thanks @straight-shoota)

### Other

- Update previous Crystal release - 1.3.2 ([#11715](https://github.com/crystal-lang/crystal/pull/11715), thanks @straight-shoota)
- Add `scripts/release-update.sh` ([#11716](https://github.com/crystal-lang/crystal/pull/11716), thanks @straight-shoota)
- [Makefile] Honour `$CC` in `EXPORT_CC` ([#11548](https://github.com/crystal-lang/crystal/pull/11548), thanks @straight-shoota)
- Fix typo in GHA aarch64 config ([#11793](https://github.com/crystal-lang/crystal/pull/11793), thanks @straight-shoota)
- [CI] Test against LLVM 13 ([#11343](https://github.com/crystal-lang/crystal/pull/11343), thanks @straight-shoota)
- [CI] Use parameters in circleci config ([#11714](https://github.com/crystal-lang/crystal/pull/11714), thanks @straight-shoota)
- Refactor `etc/completion.bash` ([#11719](https://github.com/crystal-lang/crystal/pull/11719), thanks @HertzDevil)
- [CI] Renaming jobs to be `arch-os-job` or `arch-build-job` ([#11207](https://github.com/crystal-lang/crystal/pull/11207), thanks @beta-ziliani)
- Improve documentation for review and merge processes ([#11800](https://github.com/crystal-lang/crystal/pull/11800), thanks @straight-shoota)
- Improve section ordering in `scripts/github-changelog.cr` ([#11770](https://github.com/crystal-lang/crystal/pull/11770), thanks @straight-shoota)
- Upload build artifacts to S3 bucket ([#11902](https://github.com/crystal-lang/crystal/pull/11902), thanks @matiasgarciaisaia, @straight-shoota)
- Fix `make install` for BSD ([#11758](https://github.com/crystal-lang/crystal/pull/11758), thanks @straight-shoota)
- Fix typo ([#11939](https://github.com/crystal-lang/crystal/pull/11939), thanks @taupiqueur)
- [CI] Update to shards 0.17.0 ([#11930](https://github.com/crystal-lang/crystal/pull/11930), thanks @straight-shoota)
- Use `be_empty` expectations in more specs ([#11937](https://github.com/crystal-lang/crystal/pull/11937), thanks @HertzDevil)
- [CI] Update distribution-scripts ([#11969](https://github.com/crystal-lang/crystal/pull/11969), thanks @straight-shoota)

## [1.3.2] - 2022-01-18

[1.3.2]: https://github.com/crystal-lang/crystal/releases/1.3.2

### Standard Library

#### Text

- Fix buffer overflow in `String#index` ([#11747](https://github.com/crystal-lang/crystal/pull/11747), thanks @asterite, @straight-shoota)

## [1.3.1] - 2022-01-13

[1.3.1]: https://github.com/crystal-lang/crystal/releases/1.3.1

### Standard Library

- Remove useless variable declarations in trailing position ([#11704](https://github.com/crystal-lang/crystal/pull/11704), thanks @HertzDevil)

#### Crypto

- Fix for missing `BIO_*` functions in OpenSSL < 1.1.0 ([#11736](https://github.com/crystal-lang/crystal/pull/11736), thanks @daliborfilus)

#### Runtime

- Remove string allocation from `GC_set_warn_proc` ([#11729](https://github.com/crystal-lang/crystal/pull/11729), thanks @straight-shoota)

### Tools

- Doc generator: Fix escape HTML in code span ([#11686](https://github.com/crystal-lang/crystal/pull/11686), thanks @straight-shoota)
- Fix formatter error for `ProcLiteral`s with `Union` return type ([#11709](https://github.com/crystal-lang/crystal/pull/11709), thanks @HertzDevil)

### Other

- Fix typos ([#11725](https://github.com/crystal-lang/crystal/pull/11725), thanks @kianmeng)

## [1.3.0] - 2022-01-06

[1.3.0]: https://github.com/crystal-lang/crystal/releases/1.3.0

### Compiler

- Refer to `T.class` as "metaclass" in error messages, not "class" ([#11378](https://github.com/crystal-lang/crystal/pull/11378), thanks @HertzDevil)
- Create `Reason` enum for exhaustive case in nil-reason check ([#11449](https://github.com/crystal-lang/crystal/pull/11449), thanks @rymiel)
- Improve cache directory behaviour on Windows ([#11436](https://github.com/crystal-lang/crystal/pull/11436), thanks @HertzDevil)
- Automatically detect MSVC tools on Windows via `vswhere` ([#11496](https://github.com/crystal-lang/crystal/pull/11496), thanks @HertzDevil)
- Clean up .pdb files for temporary executables on MSVC ([#11553](https://github.com/crystal-lang/crystal/pull/11553), thanks @HertzDevil)
- Disable incremental linking on MSVC ([#11552](https://github.com/crystal-lang/crystal/pull/11552), thanks @HertzDevil)
- Allow multiple `--emit` compiler options to stack ([#11556](https://github.com/crystal-lang/crystal/pull/11556), thanks @HertzDevil)
- Refactor some type restrictions in the compiler ([#11531](https://github.com/crystal-lang/crystal/pull/11531), thanks @straight-shoota)
- Detect `cl.exe`'s path for compiler specs requiring a C compiler ([#11560](https://github.com/crystal-lang/crystal/pull/11560), thanks @HertzDevil)
- Increase default stack size on MSVC to 8 MB ([#11569](https://github.com/crystal-lang/crystal/pull/11569), thanks @HertzDevil)
- Resolve compiler wildcard require ([#11562](https://github.com/crystal-lang/crystal/pull/11562), thanks @straight-shoota)
- Compiler: use enums instead of symbols in various places ([#11607](https://github.com/crystal-lang/crystal/pull/11607), thanks @HertzDevil)

#### Codegen

- Disable specs for `StaticArray#sort_by` on broken targets ([#11359](https://github.com/crystal-lang/crystal/pull/11359), thanks @straight-shoota)
- Fix link flag behaviour on Windows MSVC ([#11424](https://github.com/crystal-lang/crystal/pull/11424), thanks @HertzDevil)
- Attach debug locations to splat expansions inside array-like literals ([#11655](https://github.com/crystal-lang/crystal/pull/11655), thanks @HertzDevil)
- Use full name for private types' class variables during codegen ([#11651](https://github.com/crystal-lang/crystal/pull/11651), thanks @HertzDevil)
- Fix codegen when instantiating class methods of typedefs ([#11636](https://github.com/crystal-lang/crystal/pull/11636), thanks @HertzDevil)
- Add minimal load-time DLL support on Windows, support `dllimport` storage class ([#11573](https://github.com/crystal-lang/crystal/pull/11573), thanks @HertzDevil)

#### Debugger

- Attach debug locations to auto-generated `initialize` methods ([#11313](https://github.com/crystal-lang/crystal/pull/11313), thanks @HertzDevil)
- Fix debug location for `~check_proc_is_not_closure` ([#11311](https://github.com/crystal-lang/crystal/pull/11311), thanks @HertzDevil)

#### Interpreter

- `crystal i`, a Crystal interpreter ([#11159](https://github.com/crystal-lang/crystal/pull/11159), thanks @asterite)
- Implement FFI bindings ([#11475](https://github.com/crystal-lang/crystal/pull/11475), thanks @straight-shoota)
- Add `Crystal::Loader` ([#11434](https://github.com/crystal-lang/crystal/pull/11434), [#11662](https://github.com/crystal-lang/crystal/pull/11662), thanks @straight-shoota, @HertzDevil)
- Mark `bswap32` intrinsic with interpreter primitive annotation ([#11582](https://github.com/crystal-lang/crystal/pull/11582), thanks @rymiel)
- Split interpreter specs into separate files ([#11578](https://github.com/crystal-lang/crystal/pull/11578), thanks @straight-shoota)
- Workaround for GC issues in interpreter specs ([#11634](https://github.com/crystal-lang/crystal/pull/11634), thanks @straight-shoota)

#### Parser

- Parser: allow keyword as named argument inside macros ([#10377](https://github.com/crystal-lang/crystal/pull/10377), thanks @asterite)
- Parser: add missing end location to `IsA` node ([#11351](https://github.com/crystal-lang/crystal/pull/11351), thanks @FnControlOption)
- Fix node locations for `ProcLiteral`s with parameters ([#11365](https://github.com/crystal-lang/crystal/pull/11365), thanks @HertzDevil)
- Fix parser error with named argument `end` in macro body ([#11463](https://github.com/crystal-lang/crystal/pull/11463), thanks @straight-shoota)
- Report syntax error for too-long bin/hex/oct integer literals ([#11447](https://github.com/crystal-lang/crystal/pull/11447), thanks @oprypin)
- [lexer] Correctly increase nesting for escaped macro `unless` ([#11440](https://github.com/crystal-lang/crystal/pull/11440), thanks @rymiel)
- Show proper syntax errors in some edge cases in the parser ([#11446](https://github.com/crystal-lang/crystal/pull/11446), thanks @oprypin)
- Fix parse `yield` with parenthesis ([#11469](https://github.com/crystal-lang/crystal/pull/11469), thanks @straight-shoota)
- Lexer number parsing refactor ([#11211](https://github.com/crystal-lang/crystal/pull/11211), thanks @BlobCodes)
- Allow underscores after a leading zero in `String#to_i` (regression fix) ([#11672](https://github.com/crystal-lang/crystal/pull/11672), thanks @BlobCodes)
- Fix no comma before short block in `ToSVisitor` ([#11677](https://github.com/crystal-lang/crystal/pull/11677), thanks @homonoidian)
- Unify format of "unexpected token" error ([#11473](https://github.com/crystal-lang/crystal/pull/11473), thanks @straight-shoota)
- Implement lexer int128 support ([#11571](https://github.com/crystal-lang/crystal/pull/11571), thanks @BlobCodes)

#### Semantic

- Show proper owner for `Class`'s methods in error messages ([#10590](https://github.com/crystal-lang/crystal/pull/10590), thanks @HertzDevil)
- Be more strict about `ProcNotation` variable declarations ([#11372](https://github.com/crystal-lang/crystal/pull/11372), thanks @HertzDevil)
- Allow metaclass parameters in `Proc` literals and pointers ([#11367](https://github.com/crystal-lang/crystal/pull/11367), thanks @HertzDevil)
- Fix top-level multi-assign splat variable not working in macros ([#11600](https://github.com/crystal-lang/crystal/pull/11600), thanks @HertzDevil)
- Replace `semantic` with `assert_no_errors` in compiler specs whenever possible ([#11288](https://github.com/crystal-lang/crystal/pull/11288), thanks @HertzDevil)
- Make `inject_primitives = false` default for semantic specs  ([#11297](https://github.com/crystal-lang/crystal/pull/11297), thanks @HertzDevil)
- Add spec for #8428 ([#10073](https://github.com/crystal-lang/crystal/pull/10073), thanks @docelic)
- Remove and resolve spurious cast and its associated FIXME ([#11455](https://github.com/crystal-lang/crystal/pull/11455), thanks @rymiel)
- Add pending spec for recursive abstract struct ([#11470](https://github.com/crystal-lang/crystal/pull/11470), thanks @HertzDevil)

### Language

- **(breaking-change)** Require elements in 1-to-n assignments to match targets exactly ([#11145](https://github.com/crystal-lang/crystal/pull/11145), thanks @HertzDevil)
- **(breaking-change)** Require right-hand side of one-to-many assignments to be `Indexable` ([#11545](https://github.com/crystal-lang/crystal/pull/11545), thanks @HertzDevil)
- Support splats on left-hand sides of multiple assignment expressions ([#10410](https://github.com/crystal-lang/crystal/pull/10410), thanks @HertzDevil)
- Make all AST nodes immutable through container-returning methods ([#11397](https://github.com/crystal-lang/crystal/pull/11397), thanks @HertzDevil)
- Add auto upcast for integer and float values ([#11431](https://github.com/crystal-lang/crystal/pull/11431), [#11529](https://github.com/crystal-lang/crystal/pull/11529), thanks @asterite, @beta-ziliani)

### Standard Library

- Fix `Process::INITIAL_PWD` for non-existent path ([#10525](https://github.com/crystal-lang/crystal/pull/10525), thanks @straight-shoota)
- Resolve some TODOs ([#11369](https://github.com/crystal-lang/crystal/pull/11369), thanks @straight-shoota)
- Refactor some target flag uses ([#11466](https://github.com/crystal-lang/crystal/pull/11466), thanks @straight-shoota)
- Use `Slice(UInt8)#fill` in the standard library ([#11468](https://github.com/crystal-lang/crystal/pull/11468), thanks @HertzDevil)
- Update `spec/win32_std_spec.cr` ([#11432](https://github.com/crystal-lang/crystal/pull/11432), [#11637](https://github.com/crystal-lang/crystal/pull/11637), thanks @HertzDevil)
- Use strings instead of symbols in `#finalize` specs ([#11619](https://github.com/crystal-lang/crystal/pull/11619), thanks @HertzDevil)
- Fix `Enum.parse` to handle case-sensitive member names ([#11659](https://github.com/crystal-lang/crystal/pull/11659), thanks @straight-shoota)
- Improve docs for `Object#not_nil!` ([#11661](https://github.com/crystal-lang/crystal/pull/11661), thanks @straight-shoota)

#### Collection

- **(breaking-change)** Always use `start` as parameter in subrange-accepting methods ([#11350](https://github.com/crystal-lang/crystal/pull/11350), thanks @HertzDevil)
- **(breaking-change)** Refactor `Indexable::Mutable#fill`'s overloads ([#11368](https://github.com/crystal-lang/crystal/pull/11368), thanks @HertzDevil)
- Add sorting methods to `StaticArray` ([#10889](https://github.com/crystal-lang/crystal/pull/10889), thanks @HertzDevil)
- Add spaceship operator to `StaticArray` ([#11364](https://github.com/crystal-lang/crystal/pull/11364), thanks @henrikac)
- **(performance)** Optimize `BitArray#reverse!` ([#11363](https://github.com/crystal-lang/crystal/pull/11363), thanks @HertzDevil)
- **(performance)** Grow large arrays more slowly ([#11482](https://github.com/crystal-lang/crystal/pull/11482), thanks @mgomes)
- Fix docs for `Indexable::Mutable#map!` ([#11349](https://github.com/crystal-lang/crystal/pull/11349), thanks @HertzDevil)
- Add `Slice#unsafe_slice_of`, `#to_unsafe_bytes` ([#11379](https://github.com/crystal-lang/crystal/pull/11379), thanks @HertzDevil)
- **(performance)** Avoid reallocation in `Enumerable#each_cons` and `Iterator#cons`'s default reused array ([#10384](https://github.com/crystal-lang/crystal/pull/10384), thanks @HertzDevil)
- Fix `Array#unshift` for large arrays ([#11656](https://github.com/crystal-lang/crystal/pull/11656), thanks @HertzDevil)

#### Crypto

- Support OpenSSL on Windows ([#11477](https://github.com/crystal-lang/crystal/pull/11477), thanks @HertzDevil)
- Encode OpenSSL version on Windows ([#11516](https://github.com/crystal-lang/crystal/pull/11516), thanks @HertzDevil)
- Add docs to `Crypto::Bcrypt` ([#9647](https://github.com/crystal-lang/crystal/pull/9647), thanks @j8r)
- Fix `getrandom` for interpreter ([#11624](https://github.com/crystal-lang/crystal/pull/11624), thanks @straight-shoota)
- **(performance)** Use more efficient method to split `UInt32` to bytes in `Crypto::Blowfish` ([#11594](https://github.com/crystal-lang/crystal/pull/11594), thanks @BlobCodes)

#### Files

- Add bindings to `__xstat`, `__fxstat` and `__lxstat` for x86_64-linux-gnu ([#11361](https://github.com/crystal-lang/crystal/pull/11361), [#11536](https://github.com/crystal-lang/crystal/pull/11536), thanks @straight-shoota)
- Fix `IO::Memory#to_s` appending to itself ([#11643](https://github.com/crystal-lang/crystal/pull/11643), thanks @straight-shoota)

#### LLVM

- Fix `LLVMExtDIBuilderCreateArrayType` argument `alignInBits` should be `UInt64` ([#11644](https://github.com/crystal-lang/crystal/pull/11644), thanks @lbguilherme)

#### Log

- Add `Log.with_context` with kwargs ([#11517](https://github.com/crystal-lang/crystal/pull/11517), thanks @caspiano)
- Refactor `Log::BroadcastBackend#single_backend?` ([#11530](https://github.com/crystal-lang/crystal/pull/11530), thanks @straight-shoota)

#### Macros

- Add macro methods for `Return`, `Break`, `Next`, `Yield`, and exception handlers ([#10822](https://github.com/crystal-lang/crystal/pull/10822), thanks @HertzDevil)
- Add `Crystal::Macros::ProcNotation#resolve` and `#resolve?` ([#11373](https://github.com/crystal-lang/crystal/pull/11373), thanks @HertzDevil)
- Support explicit return types in `ProcLiteral`s ([#11402](https://github.com/crystal-lang/crystal/pull/11402), thanks @HertzDevil)
- Add several missing `ASTNode` macro methods ([#10811](https://github.com/crystal-lang/crystal/pull/10811), thanks @HertzDevil)
- Allow incomplete range arguments for `#[](Range)` macro methods ([#11380](https://github.com/crystal-lang/crystal/pull/11380), thanks @HertzDevil)
- Add macro methods for `Metaclass` nodes ([#11375](https://github.com/crystal-lang/crystal/pull/11375), thanks @HertzDevil)

#### Networking

- Datagram support for `UNIXServer` ([#11426](https://github.com/crystal-lang/crystal/pull/11426), thanks @carlhoerberg)
- Fix `WebSocket#stream` flushing for not exactly buffer size, add specs ([#11299](https://github.com/crystal-lang/crystal/pull/11299), thanks @will)
- Fix flag for UNIX-like OS ([#11382](https://github.com/crystal-lang/crystal/pull/11382), thanks @straight-shoota)
- Add more `check_headers` to `HTTP::Server::Response` ([#11253](https://github.com/crystal-lang/crystal/pull/11253), thanks @straight-shoota)
- Enable `LogHandler` address for win32 ([#11465](https://github.com/crystal-lang/crystal/pull/11465), thanks @straight-shoota)
- Enable two specs to run on all platforms ([#11467](https://github.com/crystal-lang/crystal/pull/11467), thanks @straight-shoota)
- `TCPServer`: explain how to get an ephemeral port ([#11407](https://github.com/crystal-lang/crystal/pull/11407), thanks @rdp)
- Fix `HTTP::Server::Response#close` when replaced output syncs close ([#11631](https://github.com/crystal-lang/crystal/pull/11631), thanks @straight-shoota)

#### Numeric

- **(breaking-change)** Fix `Random.rand(max : Float32)` return `Float32` ([#9946](https://github.com/crystal-lang/crystal/pull/9946), thanks @j8r)
- Fix `Math` linking errors on Windows MSVC ([#11435](https://github.com/crystal-lang/crystal/pull/11435), thanks @HertzDevil)
- Implement compiler-rt `__multi3` for arm ([#11499](https://github.com/crystal-lang/crystal/pull/11499), thanks @straight-shoota)
- Use MPIR for `Big*` numbers on Windows ([#11412](https://github.com/crystal-lang/crystal/pull/11412), thanks @HertzDevil)
- Add `BigRational#to_big_r` ([#11462](https://github.com/crystal-lang/crystal/pull/11462), thanks @HertzDevil)
- Move specs for arithmetic primitives to `primitives_spec` ([#11298](https://github.com/crystal-lang/crystal/pull/11298), thanks @HertzDevil)
- Implement compiler-rt's 128-bit integer conversions to/from floats ([#11437](https://github.com/crystal-lang/crystal/pull/11437), thanks @HertzDevil)
- Fix `Number.significant` to return `0` as is, not as `Float64` ([#11321](https://github.com/crystal-lang/crystal/pull/11321), thanks @Sija)
- Fix inequality for floating-point NaNs ([#11229](https://github.com/crystal-lang/crystal/pull/11229), thanks @HertzDevil)
- Add workaround for 128-bit integer division/modulo on Windows ([#11551](https://github.com/crystal-lang/crystal/pull/11551), thanks @HertzDevil)
- Reject near-boundary and NaN values for `Float`-to-`Int` conversions ([#11230](https://github.com/crystal-lang/crystal/pull/11230), thanks @HertzDevil)

#### Runtime

- GC/Boehm: Silence GC warnings about big allocations. ([#11289](https://github.com/crystal-lang/crystal/pull/11289), thanks @yxhuvud)
- Disable impossible spec on win32, previously marked as pending ([#11451](https://github.com/crystal-lang/crystal/pull/11451), thanks @straight-shoota)
- Support call stacks on Windows ([#11461](https://github.com/crystal-lang/crystal/pull/11461), thanks @HertzDevil)
- Make Windows PDB lookup relative to running executable ([#11493](https://github.com/crystal-lang/crystal/pull/11493), thanks @HertzDevil)

#### Serialization

- Parses JSON `UInt64` numbers. ([#11395](https://github.com/crystal-lang/crystal/pull/11395), thanks @hugopl)
- Fix `YAML::Any` deserialize with alias ([#11532](https://github.com/crystal-lang/crystal/pull/11532), thanks @straight-shoota)

#### Specs

- Use enums instead of symbols for `Spec`-related types ([#11585](https://github.com/crystal-lang/crystal/pull/11585), thanks @HertzDevil)

#### System

- Add native Linux syscall interface ([#10777](https://github.com/crystal-lang/crystal/pull/10777), thanks @lbguilherme)
- Implement `Path.home` on Windows ([#11503](https://github.com/crystal-lang/crystal/pull/11503), thanks @HertzDevil)
- Support `~\` for Windows paths in `Path#expand` and `File.expand_path` ([#11559](https://github.com/crystal-lang/crystal/pull/11559), thanks @HertzDevil)
- Support non-ASCII command-line arguments on Windows ([#11564](https://github.com/crystal-lang/crystal/pull/11564), thanks @HertzDevil)
- Enable `kernel_spec.cr` on Windows CI ([#11554](https://github.com/crystal-lang/crystal/pull/11554), thanks @HertzDevil)
- Fix `getrandom` syscall was blocking and didn't had proper error checking ([#11460](https://github.com/crystal-lang/crystal/pull/11460), thanks @lbguilherme)

#### Text

- Regex: use `PCRE_UCP` ([#11265](https://github.com/crystal-lang/crystal/pull/11265), thanks @asterite)
- Add missing `it` in `UUID` spec ([#11353](https://github.com/crystal-lang/crystal/pull/11353), thanks @darkstego)
- Add `Char#unicode_escape` and fix `#dump` and `#inspect` format ([#11421](https://github.com/crystal-lang/crystal/pull/11421), thanks @straight-shoota)
- Fix `Char#letter?` to include all letter categories ([#11474](https://github.com/crystal-lang/crystal/pull/11474), thanks @straight-shoota)
- Pass JIT Compile flag to `study` ([#11325](https://github.com/crystal-lang/crystal/pull/11325), thanks @Blacksmoke16)
- Add Comparison operator to UUID ([#11352](https://github.com/crystal-lang/crystal/pull/11352), thanks @darkstego)
- Add `Char#printable?` ([#11429](https://github.com/crystal-lang/crystal/pull/11429), thanks @straight-shoota)
- Fix `String#inspect` and `Char#inspect` escape all non-printable characters ([#11452](https://github.com/crystal-lang/crystal/pull/11452), [#11626](https://github.com/crystal-lang/crystal/pull/11626), thanks @straight-shoota)
- Support custom encodings on Windows through GNU libiconv ([#11480](https://github.com/crystal-lang/crystal/pull/11480), thanks @HertzDevil)
- **(breaking-change)** Change `Regex#name_table` to return `Hash(Int32, String)` ([#11539](https://github.com/crystal-lang/crystal/pull/11539), thanks @straight-shoota)
- Fix skip surrogates in `Char#succ` and `#pred` ([#11506](https://github.com/crystal-lang/crystal/pull/11506), thanks @straight-shoota)
- **(performance)** Improve Base64 decoding performance ([#11094](https://github.com/crystal-lang/crystal/pull/11094), thanks @BlobCodes)
- Refactor syntax highlighter and add ANSI escape code highlighter for console ([#11366](https://github.com/crystal-lang/crystal/pull/11366), thanks @straight-shoota)
- Fix UTF-8 console input/output on Windows ([#11557](https://github.com/crystal-lang/crystal/pull/11557), thanks @HertzDevil)
- Implement Unicode grapheme clusters ([#11472](https://github.com/crystal-lang/crystal/pull/11472), [#11611](https://github.com/crystal-lang/crystal/pull/11611), thanks @straight-shoota)
- **(breaking-change)** Fix `Char#ascii_control?` restrict to ASCII characters ([#11510](https://github.com/crystal-lang/crystal/pull/11510), thanks @straight-shoota)
- **(performance)** Performance: specify string sizes in advance ([#11592](https://github.com/crystal-lang/crystal/pull/11592), thanks @BlobCodes)
- **(performance)** Improve performance of `Char#to_s` ([#11593](https://github.com/crystal-lang/crystal/pull/11593), thanks @BlobCodes)
- Add docs to `Colorize` ([#11664](https://github.com/crystal-lang/crystal/pull/11664), thanks @straight-shoota)
- Support ANSI escape sequence output on more Windows consoles ([#11622](https://github.com/crystal-lang/crystal/pull/11622), thanks @HertzDevil)

### Tools

- [docs] Fix ditto with additional lines ([#11336](https://github.com/crystal-lang/crystal/pull/11336), thanks @straight-shoota)
- [docs] Compact some JSON fields for search ([#11438](https://github.com/crystal-lang/crystal/pull/11438), thanks @rymiel)
- [docs] Add 404.html page ([#11428](https://github.com/crystal-lang/crystal/pull/11428), thanks @straight-shoota)
- [docs] Improve search input a11y for generated docs ([#11604](https://github.com/crystal-lang/crystal/pull/11604), thanks @chances)
- [docs] use `shard.yml` version when no git tag present ([#11232](https://github.com/crystal-lang/crystal/pull/11232), thanks @superhawk610)
- [formatter] Fix weird interactions with comments near indentation ([#11441](https://github.com/crystal-lang/crystal/pull/11441), thanks @rymiel)
- [formatter] fix extra newline after comment in case else ([#11448](https://github.com/crystal-lang/crystal/pull/11448), thanks @rymiel)
- [formatter] Fix space between call name and parenthesized arg ([#11523](https://github.com/crystal-lang/crystal/pull/11523), thanks @straight-shoota)
- [playground] Refactor `PlaygroundPage` resources list ([#11608](https://github.com/crystal-lang/crystal/pull/11608), thanks @straight-shoota)

### Other

- Update previous Crystal release - 1.2.2 ([#11430](https://github.com/crystal-lang/crystal/pull/11430), thanks @straight-shoota)
- Prepare 1.3.0-dev ([#11317](https://github.com/crystal-lang/crystal/pull/11317), thanks @straight-shoota)
- [CI] Fix `test_dist_linux_on_docker` ([#11512](https://github.com/crystal-lang/crystal/pull/11512), thanks @straight-shoota)
- Improve compiler spec helpers for macro methods ([#11139](https://github.com/crystal-lang/crystal/pull/11139), thanks @HertzDevil)
- Add Makefile to build samples ([#11419](https://github.com/crystal-lang/crystal/pull/11419), thanks @straight-shoota)
- Verify downloads' hashes in Windows CI ([#11423](https://github.com/crystal-lang/crystal/pull/11423), thanks @matiasgarciaisaia)
- Make the Windows compiler artifact more portable ([#11494](https://github.com/crystal-lang/crystal/pull/11494), thanks @HertzDevil)
- Allow compiler executable under test to be overridden ([#11457](https://github.com/crystal-lang/crystal/pull/11457), thanks @HertzDevil)
- Fix CI rules for building libiconv on Windows ([#11504](https://github.com/crystal-lang/crystal/pull/11504), thanks @HertzDevil)
- Update license template ([#11498](https://github.com/crystal-lang/crystal/pull/11498), thanks @taupiqueur)
- Pin alpine repo for ssl libs to 3.15 ([#11500](https://github.com/crystal-lang/crystal/pull/11500), thanks @straight-shoota)
- Don't generate PDB for MPIR on Windows ([#11521](https://github.com/crystal-lang/crystal/pull/11521), thanks @HertzDevil)
- [Makefile] Check for `LLVM_CONFIG` only when LLVM is used ([#11519](https://github.com/crystal-lang/crystal/pull/11519), thanks @straight-shoota)
- Update distribution-scripts ([#11514](https://github.com/crystal-lang/crystal/pull/11514), [#11515](https://github.com/crystal-lang/crystal/pull/11515), thanks @straight-shoota)
- Add commit hash to Windows builds ([#11538](https://github.com/crystal-lang/crystal/pull/11538), thanks @HertzDevil)
- Support BuildTools and other VS variants in vswhere detection ([#11534](https://github.com/crystal-lang/crystal/pull/11534), thanks @neatorobito)
- Define `LIBXML_STATIC` when building xml2.lib on Windows ([#11574](https://github.com/crystal-lang/crystal/pull/11574), thanks @HertzDevil)
- Improve texts in `README.md` ([#11587](https://github.com/crystal-lang/crystal/pull/11587), thanks @athix)
- Include `shards` with Windows build artifacts ([#11543](https://github.com/crystal-lang/crystal/pull/11543), thanks @neatorobito)
- [CI] Remove `libatomic_ops` ([#11598](https://github.com/crystal-lang/crystal/pull/11598), thanks @straight-shoota)
- Update NOTICE Copyright year to 2022 ([#11679](https://github.com/crystal-lang/crystal/pull/11679), thanks @matiasgarciaisaia)

## [1.2.2] - 2021-11-10

[1.2.2]: https://github.com/crystal-lang/crystal/releases/1.2.2

### Compiler

- x86_64 ABI: pass structs indirectly if there are no more available registers ([#11344](https://github.com/crystal-lang/crystal/pull/11344), thanks @ggiraldez)
- Add parentheses around type name for metaclasses of unions ([#11315](https://github.com/crystal-lang/crystal/pull/11315), thanks @HertzDevil)
- **(regression)** Restrict virtual metaclasses to themselves against `Class` ([#11377](https://github.com/crystal-lang/crystal/pull/11377), thanks @HertzDevil)
- **(regression)** Add fallback for union debug type if current debug file is not set ([#11390](https://github.com/crystal-lang/crystal/pull/11390), thanks @maxfierke)
- **(regression)** Add missing debug locations to constant / class variable read calls ([#11417](https://github.com/crystal-lang/crystal/pull/11417), thanks @HertzDevil)

### Standard Library

#### Collection

- Fix `BitArray#toggle` when toggling empty subrange ([#11381](https://github.com/crystal-lang/crystal/pull/11381), thanks @HertzDevil)

#### Crypto

- Update for OpenSSL 3.0.0 ([#11360](https://github.com/crystal-lang/crystal/pull/11360), thanks @straight-shoota)
- Restore libressl support and add CI for that ([#11400](https://github.com/crystal-lang/crystal/pull/11400), thanks @straight-shoota)
- Replace lib version comparisons by functional feature checks ([#11374](https://github.com/crystal-lang/crystal/pull/11374), thanks @straight-shoota)

#### Runtime

- Add support for DWARF 5 ([#11399](https://github.com/crystal-lang/crystal/pull/11399), thanks @straight-shoota)
- Retrieve filename of shared libs, use in stacktraces ([#11408](https://github.com/crystal-lang/crystal/pull/11408), thanks @rdp)

### Other
- [CI] Fix enable nix-command as experimental feature ([#11398](https://github.com/crystal-lang/crystal/pull/11398), thanks @straight-shoota)
- [CI] Fix OpenSSL 3 apk package name ([#11418](https://github.com/crystal-lang/crystal/pull/11418), thanks @straight-shoota)
- Update distribution-scripts ([#11404](https://github.com/crystal-lang/crystal/pull/11404), thanks @straight-shoota)
- [CI] Fix pcre download URL ([#11422](https://github.com/crystal-lang/crystal/pull/11422), thanks @straight-shoota)

## [1.2.1] - 2021-10-21

[1.2.1]: https://github.com/crystal-lang/crystal/releases/1.2.1

### Compiler

- Adding location to the Path returned by the literal expander for regex ([#11334](https://github.com/crystal-lang/crystal/pull/11334), thanks @beta-ziliani)

### Standard Library

- Add support for LLVM 13 ([#11302](https://github.com/crystal-lang/crystal/pull/11302), thanks @maxfierke)

#### Runtime

- Move the `:nodoc:` flags to the right place to hide the `__mul*` functions. ([#11326](https://github.com/crystal-lang/crystal/pull/11326), thanks @wyhaines)

### Tools

- Update markd subtree to v0.4.2 ([#11338](https://github.com/crystal-lang/crystal/pull/11338), thanks @straight-shoota)

## [1.2.0] - 2021-10-13

[1.2.0]: https://github.com/crystal-lang/crystal/releases/1.2.0

### Compiler

- Fix variance checks between generic instances for `Proc#call` and abstract defs. ([#10899](https://github.com/crystal-lang/crystal/pull/10899), thanks @HertzDevil)
- Fix `proc_spec` forcing normal compilation instead of JIT ([#10964](https://github.com/crystal-lang/crystal/pull/10964), thanks @straight-shoota)
- Fix `ProcNotation#to_s` remove whitespace for nil output type ([#10935](https://github.com/crystal-lang/crystal/pull/10935), thanks @straight-shoota)
- Compiler: carry FileModule information inside Block ([#11039](https://github.com/crystal-lang/crystal/pull/11039), thanks @asterite)
- Splat values correctly inside return/break/next statements ([#10193](https://github.com/crystal-lang/crystal/pull/10193), thanks @HertzDevil)
- Handle already stripped column numbers in compiler exceptions ([#11008](https://github.com/crystal-lang/crystal/pull/11008), thanks @pyrsmk)
- Substitute unbound type parameters in virtual metaclass types ([#11067](https://github.com/crystal-lang/crystal/pull/11067), thanks @HertzDevil)
- Improve detection of instance variables in extended modules ([#10554](https://github.com/crystal-lang/crystal/pull/10554), thanks @HertzDevil)
- Don't compute instance variable initializers on unbound generic instances ([#11000](https://github.com/crystal-lang/crystal/pull/11000), thanks @HertzDevil)
- Syntax errors for invalid 128-bit integer literals ([#10975](https://github.com/crystal-lang/crystal/pull/10975), thanks @rymiel)
- Support auto-splatting in captured block literals ([#10251](https://github.com/crystal-lang/crystal/pull/10251), thanks @HertzDevil)
- Detect cyclic includes between generic modules ([#10529](https://github.com/crystal-lang/crystal/pull/10529), thanks @HertzDevil)
- Add stricter checks for arguments to macro methods on AST nodes ([#10498](https://github.com/crystal-lang/crystal/pull/10498), thanks @HertzDevil)
- Compiler: fix `is_a?` for virtual metaclass types ([#11121](https://github.com/crystal-lang/crystal/pull/11121), thanks @asterite)
- Fix edge cases with unicode method names ([#10978](https://github.com/crystal-lang/crystal/pull/10978), thanks @HertzDevil)
- Don't emit debug info for unused variable declarations ([#10957](https://github.com/crystal-lang/crystal/pull/10957), thanks @HertzDevil)
- Fix `Call.def_full_name` print full block parameter ([#10915](https://github.com/crystal-lang/crystal/pull/10915), thanks @straight-shoota)
- Allow union types to be unbound ([#11166](https://github.com/crystal-lang/crystal/pull/11166), thanks @HertzDevil)
- Make `typeof` start a nested lexical scope ([#10796](https://github.com/crystal-lang/crystal/pull/10796), thanks @HertzDevil)
- Fix edge case for intersection between virtual metaclasses ([#11185](https://github.com/crystal-lang/crystal/pull/11185), thanks @HertzDevil)
- Compiler: don't trigger "already had enclosing call" for same object ([#11202](https://github.com/crystal-lang/crystal/pull/11202), thanks @asterite)
- Properly handle indirect arguments for external C functions ([#11189](https://github.com/crystal-lang/crystal/pull/11189), thanks @ggiraldez)
- Fix resolve generic argument in block output type restriction mismatch ([#11186](https://github.com/crystal-lang/crystal/pull/11186), thanks @straight-shoota)
- Secure array slicing when expanding macro for stack trace ([#11109](https://github.com/crystal-lang/crystal/pull/11109), thanks @pyrsmk)
- Fix debug locations for `Proc` pointers ([#11243](https://github.com/crystal-lang/crystal/pull/11243), thanks @HertzDevil)
- Allow assignments from generic instance metaclasses to virtual metaclasses ([#11250](https://github.com/crystal-lang/crystal/pull/11250), thanks @HertzDevil)
- Refactor `CrystalPath#find_in_path_relative_to_dir` for readability ([#10876](https://github.com/crystal-lang/crystal/pull/10876), [#10990](https://github.com/crystal-lang/crystal/pull/10990), [#10988](https://github.com/crystal-lang/crystal/pull/10988), thanks @straight-shoota)
- Allow constants and instance / class variables as receivers for setter proc pointers ([#10741](https://github.com/crystal-lang/crystal/pull/10741), thanks @HertzDevil)
- Do not use globals for regex ([#10951](https://github.com/crystal-lang/crystal/pull/10951), thanks @asterite)
- Define type filtering through an intersection operation ([#10781](https://github.com/crystal-lang/crystal/pull/10781), thanks @HertzDevil)
- Fix no overflow check when primitive int converts to same type ([#11003](https://github.com/crystal-lang/crystal/pull/11003), thanks @HertzDevil)
- Attach debug locations to generated internal LLVM functions ([#10934](https://github.com/crystal-lang/crystal/pull/10934), thanks @HertzDevil)
- Add helpful error message for invalid number literal like '.42' ([#4665](https://github.com/crystal-lang/crystal/pull/4665), thanks @MakeNowJust)
- Add `CrystalPath.expand_paths`, expand relative to compiler path ([#11030](https://github.com/crystal-lang/crystal/pull/11030), thanks @straight-shoota)
- Clarify usage of "arguments" and "parameters" in error messages ([#10378](https://github.com/crystal-lang/crystal/pull/10378), thanks @HertzDevil)
- **(performance)** Don't generate type IDs for formal generic instances ([#11167](https://github.com/crystal-lang/crystal/pull/11167), thanks @HertzDevil)
- **(performance)** Don't generate unique type IDs for virtual metaclasses ([#11188](https://github.com/crystal-lang/crystal/pull/11188), thanks @HertzDevil)
- Add an environment variable for dumping type IDs ([#11168](https://github.com/crystal-lang/crystal/pull/11168), thanks @HertzDevil)
- Allow underscores in macro `for`'s loop variables ([#11141](https://github.com/crystal-lang/crystal/pull/11141), thanks @HertzDevil)
- **(performance)** Compiler: cache cleanup transformer ([#11197](https://github.com/crystal-lang/crystal/pull/11197), thanks @asterite)
- Avoid needless union in `LLVM::ABI::AArch64#homogeneous_aggregate?` ([#11199](https://github.com/crystal-lang/crystal/pull/11199), thanks @asterite)
- Removing ThinLTO support ([#11194](https://github.com/crystal-lang/crystal/pull/11194), thanks @beta-ziliani)
- Error if abstract def implementation is inherited from supertype ([#11056](https://github.com/crystal-lang/crystal/pull/11056), thanks @straight-shoota)
- **(performance)** Add `inject_primitives: false` to macro_spec ([#11269](https://github.com/crystal-lang/crystal/pull/11269), thanks @straight-shoota)
- Primitive annotations for interpreter ([#11147](https://github.com/crystal-lang/crystal/pull/11147), thanks @asterite)
- Support generic module instances in `TypeNode#includers` ([#11116](https://github.com/crystal-lang/crystal/pull/11116), thanks @HertzDevil)
- Reject hash literals with mixed syntax ([#11154](https://github.com/crystal-lang/crystal/pull/11154), thanks @MakeNowJust)

### Language

- Make `.as?(NoReturn)` always return `nil` ([#10896](https://github.com/crystal-lang/crystal/pull/10896), thanks @HertzDevil)
- Compiler: make `is_a?(union)` work correctly for virtual types ([#11176](https://github.com/crystal-lang/crystal/pull/11176), thanks @asterite)
- Adjust docs for `Crystal::Macros::HashLiteral#[]` ([#10930](https://github.com/crystal-lang/crystal/pull/10930), thanks @kevinsjoberg)
- Fix path lookup when ancestor finds type with same name as current scope ([#10901](https://github.com/crystal-lang/crystal/pull/10901), thanks @HertzDevil)
- Fix several compile-time operations on generic instance metaclasses ([#11101](https://github.com/crystal-lang/crystal/pull/11101), thanks @HertzDevil)
- Make `#is_a?` in macros respect the AST node hierarchy ([#11062](https://github.com/crystal-lang/crystal/pull/11062), thanks @HertzDevil)
- Add docs to string methods in `SymbolLiteral` and `MacroId` ([#9298](https://github.com/crystal-lang/crystal/pull/9298), thanks @MakeNowJust)
- Add clarification about when `instance_vars` can be called ([#11171](https://github.com/crystal-lang/crystal/pull/11171), thanks @willhbr)
- Add `file_exists?` macro method ([#10540](https://github.com/crystal-lang/crystal/pull/10540), thanks @Sija)

### Standard Library

- **(breaking-change)** Change nonsense return types to Nil: uncategorized ([#10625](https://github.com/crystal-lang/crystal/pull/10625), thanks @oprypin)
- **(breaking-change)** Change nonsense return types to Nil in formatter classes ([#10623](https://github.com/crystal-lang/crystal/pull/10623), thanks @oprypin)
- Add base64 to prelude ([#11050](https://github.com/crystal-lang/crystal/pull/11050), thanks @straight-shoota)
- Remove calls to deprecated `SystemError.from_winerror` ([#11220](https://github.com/crystal-lang/crystal/pull/11220), thanks @straight-shoota)
- Add support for LLVM 12 ([#10873](https://github.com/crystal-lang/crystal/pull/10873), [#11178](https://github.com/crystal-lang/crystal/pull/11178), thanks @maxfierke, @Blacksmoke16)
- Examples: fix (2021-09) ([#11234](https://github.com/crystal-lang/crystal/pull/11234), thanks @maiha)
- Don't use `:nodoc:` when overriding public methods ([#11096](https://github.com/crystal-lang/crystal/pull/11096), thanks @HertzDevil)
- Add internal registry implementation for win32 ([#11137](https://github.com/crystal-lang/crystal/pull/11137), thanks @straight-shoota)

#### Collection

- **(breaking-change)** Move `Array#product` to `Indexable#cartesian_product` ([#10013](https://github.com/crystal-lang/crystal/pull/10013), thanks @HertzDevil)
- Disallow `Slice(T).new(Int)` where `T` is a union of primitive number types ([#10982](https://github.com/crystal-lang/crystal/pull/10982), thanks @HertzDevil)
- Make `Array#transpose`, `Enumerable#reject`, `Enumerable#to_h` work with tuples ([#10445](https://github.com/crystal-lang/crystal/pull/10445), thanks @HertzDevil)
- Fix `Enumerable#each` block return type ([#10928](https://github.com/crystal-lang/crystal/pull/10928), thanks @straight-shoota)
- Fix key type for empty `NamedTuple` be `Symbol` ([#10942](https://github.com/crystal-lang/crystal/pull/10942), thanks @caspiano)
- Fix overflow in `BitArray#[](Int, Int)` for sizes between 33 and 64 ([#10809](https://github.com/crystal-lang/crystal/pull/10809), thanks @HertzDevil)
- Fix `Range#step` for non-integer `Steppable` types ([#11130](https://github.com/crystal-lang/crystal/pull/11130), thanks @straight-shoota)
- **(performance)** Construct an array literal in `NamedTuple#map` ([#10950](https://github.com/crystal-lang/crystal/pull/10950), thanks @caspiano)
- Add `Slice#fill` ([#10924](https://github.com/crystal-lang/crystal/pull/10924), thanks @HertzDevil)
- Add range overloads for `BitArray#toggle` ([#10743](https://github.com/crystal-lang/crystal/pull/10743), thanks @HertzDevil)
- Add stable sort implementation to `Slice`, `Array` and `Indexable::Mutable` ([#10163](https://github.com/crystal-lang/crystal/pull/10163), [#11029](https://github.com/crystal-lang/crystal/pull/11029), [#11254](https://github.com/crystal-lang/crystal/pull/11254), thanks @MakeNowJust, thanks @straight-shoota)
- Allow `Enumerable(T)#reduce`'s return type to differ from `T` ([#11065](https://github.com/crystal-lang/crystal/pull/11065), thanks @HertzDevil)
- Implement `Enumerable#tally_by` ([#10922](https://github.com/crystal-lang/crystal/pull/10922), thanks @caspiano)
- Add the `Indexable::Mutable(T)` module ([#11059](https://github.com/crystal-lang/crystal/pull/11059), thanks @HertzDevil)
- Remove restriction of bsearch block output type ([#11212](https://github.com/crystal-lang/crystal/pull/11212), thanks @straight-shoota)
- Add and improve type restrictions of block arguments ([#10467](https://github.com/crystal-lang/crystal/pull/10467), [#11246](https://github.com/crystal-lang/crystal/pull/11246), [#11267](https://github.com/crystal-lang/crystal/pull/11267, [#11308](https://github.com/crystal-lang/crystal/pull/11308), thanks @caspiano, thanks @straight-shoota, thanks @HertzDevil, thanks @beta-ziliani, thanks @caspiano)
- **(performance)** Optimize `#rotate!` ([#11198](https://github.com/crystal-lang/crystal/pull/11198), thanks @HertzDevil)

#### Concurrency

- Fix Documentation of `Fiber.timeout` ([#11271](https://github.com/crystal-lang/crystal/pull/11271), thanks @toddsundsted)
- **(performance)** `Scheduler#reschedule`: Shortcut lookup for current fiber. ([#11156](https://github.com/crystal-lang/crystal/pull/11156), thanks @yxhuvud)
- Add sleep support to win32 event loop ([#10605](https://github.com/crystal-lang/crystal/pull/10605), thanks @straight-shoota)

#### Files

- **(breaking-change)** Change nonsense return types to Nil in IO-related methods ([#10621](https://github.com/crystal-lang/crystal/pull/10621), thanks @oprypin)
- Fix `File.match?` to accept `Path` type as `path` argument ([#11075](https://github.com/crystal-lang/crystal/pull/11075), thanks @fishnibble)
- Add `FileUtils` method specs with `String` and `Path` arguments ([#10987](https://github.com/crystal-lang/crystal/pull/10987), thanks @straight-shoota)
- Make `IO#read_char`'s default behaviour UTF-8-strict ([#10446](https://github.com/crystal-lang/crystal/pull/10446), thanks @HertzDevil)
- Fix glob with multiple recurse patterns ([#10813](https://github.com/crystal-lang/crystal/pull/10813), thanks @straight-shoota)
- IO: fix bug in `gets` without peek involving `\r` and limit ([#11241](https://github.com/crystal-lang/crystal/pull/11241), thanks @asterite)
- Make `FileUtils.mv` work across filesystems ([#10783](https://github.com/crystal-lang/crystal/pull/10783), thanks @naqvis)
- **(performance)** Improve performance of `Path#dirname` and `Path#extension` ([#11001](https://github.com/crystal-lang/crystal/pull/11001), thanks @BlobCodes)

#### Networking

- **(breaking-change)** Change nonsense return types to `Nil` in HTTP-related methods and `Log` ([#10624](https://github.com/crystal-lang/crystal/pull/10624), thanks @oprypin)
- Fix trailing `rescue` syntax ([#11083](https://github.com/crystal-lang/crystal/pull/11083), thanks @straight-shoota)
- Fix spec for `HTTP::Params` can't run on its own ([#11128](https://github.com/crystal-lang/crystal/pull/11128), thanks @asterite)
- Fix parsing cookie `Domain` attribute with leading dot ([#11098](https://github.com/crystal-lang/crystal/pull/11098), thanks @mamantoha)
- Rescue `OpenSSL::SSL::Error` in `HTTP::Server#handle_client` ([#11146](https://github.com/crystal-lang/crystal/pull/11146), thanks @straight-shoota)
- Fix `TCPSocket` constructors ([#11049](https://github.com/crystal-lang/crystal/pull/11049), thanks @straight-shoota)
- Support basic auth from `URI` in websockets ([#10854](https://github.com/crystal-lang/crystal/pull/10854), thanks @willhbr)
- Tag std specs that need network access ([#11048](https://github.com/crystal-lang/crystal/pull/11048), thanks @toshokan)
- Proper handling of `max-age` and `expires` for cookies ([#10564](https://github.com/crystal-lang/crystal/pull/10564), thanks @straight-shoota, @watzon)
- Retry `HTTP::Client` requests once if io is closed ([#11088](https://github.com/crystal-lang/crystal/pull/11088), thanks @carlhoerberg)
- Implement `Socket` for win32 ([#10784](https://github.com/crystal-lang/crystal/pull/10784), thanks @straight-shoota)
- Add `URI.encode_path` and deprecate `URI.encode` ([#11248](https://github.com/crystal-lang/crystal/pull/11248), thanks @straight-shoota)

#### Numeric

- **(breaking-change)** Refine type restriction of `Math.frexp(BigFloat)` ([#10998](https://github.com/crystal-lang/crystal/pull/10998), thanks @straight-shoota)
- Fix `BigInt#to_s` emitting null bytes for certain values ([#11063](https://github.com/crystal-lang/crystal/pull/11063), thanks @HertzDevil)
- Fix `Float#humanize` for values outside `1e-4...1e15` ([#10881](https://github.com/crystal-lang/crystal/pull/10881), thanks @straight-shoota)
- Add type restrictions and fix return types of `BigFloat#to_x` methods ([#10996](https://github.com/crystal-lang/crystal/pull/10996), thanks @straight-shoota)
- Add integer square root ([#10549](https://github.com/crystal-lang/crystal/pull/10549), thanks @kimburgess)
- Add negative exponential support to BigDecimal ([#10892](https://github.com/crystal-lang/crystal/pull/10892), thanks @stakach)
- Add `#next_float` and `#prev_float` to `Float32` and `Float64` ([#10908](https://github.com/crystal-lang/crystal/pull/10908), thanks @HertzDevil)
- Add precision parameter to `Int#to_s` ([#10926](https://github.com/crystal-lang/crystal/pull/10926), thanks @HertzDevil)
- **(performance)** Improve Int parsing performance ([#11093](https://github.com/crystal-lang/crystal/pull/11093), thanks @BlobCodes)
- Implement `Int128` compiler-rt methods ([#11206](https://github.com/crystal-lang/crystal/pull/11206), thanks @BlobCodes)
- Fix `BigDecimal` operations with floats ([#10874](https://github.com/crystal-lang/crystal/pull/10874), thanks @stakach)
- Add `String#to_(u/i)128(?)` methods ([#11245](https://github.com/crystal-lang/crystal/pull/11245), thanks @BlobCodes)

#### Runtime

- Extract `libunwind` from callstack ([#11205](https://github.com/crystal-lang/crystal/pull/11205), thanks @straight-shoota)

#### Serialization

- **(breaking-change)** Change nonsense return types to `Nil`: JSON and YAML ([#10622](https://github.com/crystal-lang/crystal/pull/10622), thanks @oprypin)
- **(breaking-change)** Add type restriction and conversion to `YAML::PullParser#location` ([#10997](https://github.com/crystal-lang/crystal/pull/10997), thanks @straight-shoota)
- Allow EOF IO passed to `JSON::PullParser.new` ([#10864](https://github.com/crystal-lang/crystal/pull/10864), thanks @Blacksmoke16)
- Quote the named tuple's keys on deserialization ([#10919](https://github.com/crystal-lang/crystal/pull/10919), thanks @Blacksmoke16)
- Refactor `JSON::PullParser#consume_number` to use stdlib number parsing ([#10447](https://github.com/crystal-lang/crystal/pull/10447), thanks @straight-shoota)
- XML Namespace improvements ([#11072](https://github.com/crystal-lang/crystal/pull/11072), thanks @Blacksmoke16)
- Add JSON/YAML serialization to `URI` ([#10404](https://github.com/crystal-lang/crystal/pull/10404), thanks @straight-shoota)

#### Specs

- Add missing require in `iterator_spec` ([#11148](https://github.com/crystal-lang/crystal/pull/11148), thanks @asterite)
- Add missing requires to run a couple of specs standalone ([#11152](https://github.com/crystal-lang/crystal/pull/11152), thanks @asterite)
- Allow `describe` without requiring an argument ([#10974](https://github.com/crystal-lang/crystal/pull/10974), thanks @straight-shoota)

#### System

- SystemError: Fix inconsistent signature. ([#11002](https://github.com/crystal-lang/crystal/pull/11002), thanks @yxhuvud)

#### Text

- **(breaking-change)** Deprecate `String#unsafe_byte_at` ([#10559](https://github.com/crystal-lang/crystal/pull/10559), thanks @straight-shoota)
- **(breaking-change)** Rename `IO#write_utf8` to `#write_string`. ([#11051](https://github.com/crystal-lang/crystal/pull/11051), thanks @straight-shoota)
- Use `#write_string` instead of `#write` whenever writing strings to unknown `IO`s ([#11011](https://github.com/crystal-lang/crystal/pull/11011), thanks @HertzDevil)
- Don't use `#write_byte` whenever writing ASCII characters to unknown `IO`s ([#11124](https://github.com/crystal-lang/crystal/pull/11124), thanks @HertzDevil)
- Make `Int#chr` reject surrogate halves ([#10451](https://github.com/crystal-lang/crystal/pull/10451), thanks @HertzDevil)
- CSV: don't eagerly check next char after newline ([#11174](https://github.com/crystal-lang/crystal/pull/11174), thanks @asterite)
- Fix link on regex.cr ([#11204](https://github.com/crystal-lang/crystal/pull/11204), thanks @gemmaro)
- Disallow non-UTF-8 encoding settings for `String::Builder` ([#11025](https://github.com/crystal-lang/crystal/pull/11025), thanks @HertzDevil)
- Unicode: update to version 14.0.0 ([#11215](https://github.com/crystal-lang/crystal/pull/11215), thanks @Blacksmoke16)

### Tools

- Formatter: Handle `(-> )` correctly ([#10945](https://github.com/crystal-lang/crystal/pull/10945), thanks @HertzDevil)
- Use [markd](https://github.com/icyleaf/markd) for markdown rendering in the compiler ([#11040](https://github.com/crystal-lang/crystal/pull/11040), thanks @straight-shoota)
- Formatter: Handle leading tuple literals in multi-expression `return`/`break`/`next` properly ([#10597](https://github.com/crystal-lang/crystal/pull/10597), thanks @HertzDevil)
- Include parent headings in anchor links ([#9839](https://github.com/crystal-lang/crystal/pull/9839), thanks @Blacksmoke16)
- Fix formatting nested multiline array and tuple ([#11153](https://github.com/crystal-lang/crystal/pull/11153), thanks @MakeNowJust)
- `crystal init`: Improve transformation of project name with hyphens ([#11170](https://github.com/crystal-lang/crystal/pull/11170), thanks @Kanezoh)
- Fix formatting generic types with suffix ([#11187](https://github.com/crystal-lang/crystal/pull/11187), thanks @MakeNowJust)
- Make `WARNING` an admonition keyword ([#10898](https://github.com/crystal-lang/crystal/pull/10898), thanks @HertzDevil)
- Refactor hierarchy printers ([#10791](https://github.com/crystal-lang/crystal/pull/10791), thanks @HertzDevil)

### Other

- Fix typos ([#11045](https://github.com/crystal-lang/crystal/pull/11045), [#11163](https://github.com/crystal-lang/crystal/pull/11163), [#11138](https://github.com/crystal-lang/crystal/pull/11138), hanks @toshokan, thanks @MakeNowJust, thanks @schmijos)
- Update readme to point to IRC channel on libera.chat ([#11024](https://github.com/crystal-lang/crystal/pull/11024), thanks @jhass)
- [CI] Update ruby-install ([#11276](https://github.com/crystal-lang/crystal/pull/11276), thanks @straight-shoota)
- [CI] Remove `test_linux_32` and add smoke test for 32-bit gnu ([#11127](https://github.com/crystal-lang/crystal/pull/11127), thanks @straight-shoota)
- [CI] Remove obsolete `package_build` workflow ([#11240](https://github.com/crystal-lang/crystal/pull/11240), thanks @straight-shoota)
- [CI] Add build matrix with 1.0.0 and 1.1.1 ([#11278](https://github.com/crystal-lang/crystal/pull/11278), thanks @straight-shoota)
- [CI] Update aarch64.yml ([#11160](https://github.com/crystal-lang/crystal/pull/11160), thanks @beta-ziliani)
- [CI] Update distribution-scripts (universal darwin & demote alpine to 3.12)  ([#11228](https://github.com/crystal-lang/crystal/pull/11228), thanks @bcardiff)
- Update shards 0.16.0 ([#11292](https://github.com/crystal-lang/crystal/pull/11292), thanks @straight-shoota)
- Update previous release Crystal 1.1.0 ([#10955](https://github.com/crystal-lang/crystal/pull/10955), thanks @straight-shoota)
- Merge changelog entry for 1.1.1 ([#11028](https://github.com/crystal-lang/crystal/pull/11028), thanks @straight-shoota)
- Update previous release Crystal 1.1.1 ([#11053](https://github.com/crystal-lang/crystal/pull/11053), thanks @straight-shoota)
- PR template ([#10894](https://github.com/crystal-lang/crystal/pull/10894), thanks @beta-ziliani)
- Add github-changelog script ([#11155](https://github.com/crystal-lang/crystal/pull/11155), thanks @straight-shoota)
- Add `make install` ([#10878](https://github.com/crystal-lang/crystal/pull/10878), thanks @straight-shoota)
- [CI] Sanitize version from branch name ([#11294](https://github.com/crystal-lang/crystal/pull/11294), thanks @straight-shoota)
- Update libgc to 8.2.0 ([#11293](https://github.com/crystal-lang/crystal/pull/11293), thanks @straight-shoota)
- [CI] Unify `maintenance_release` and `tagged_release` workflows ([#11273](https://github.com/crystal-lang/crystal/pull/11273), thanks @straight-shoota)
- [CI] Update distribution-scripts (make install) ([#11307](https://github.com/crystal-lang/crystal/pull/11307), thanks @straight-shoota)
- [CI] Enable publish docker images on tagged release ([#11309](https://github.com/crystal-lang/crystal/pull/11309), thanks @straight-shoota)
- [CI] Update distribution-scripts (fix for libgc in alpine Docker image) ([#11310](https://github.com/crystal-lang/crystal/pull/11310), thanks @straight-shoota)
- [CI] Pin macOS runner to 10.15 ([#11282](https://github.com/crystal-lang/crystal/pull/11282), thanks @straight-shoota)
- [CI] Fix `push_obs_nightly` ([#11301](https://github.com/crystal-lang/crystal/pull/11301), thanks @straight-shoota)
- [CI] Update distribution-scripts ([#11285](https://github.com/crystal-lang/crystal/pull/11285), thanks @straight-shoota)
- [CI] Remove i386 builds ([#11287](https://github.com/crystal-lang/crystal/pull/11287), thanks @straight-shoota)

## [1.1.1] - 2021-07-26

[1.1.1]: https://github.com/crystal-lang/crystal/releases/1.1.1

### Language changes
- Revert name of top-level module to `main` ([#10993](https://github.com/crystal-lang/crystal/pull/10993), thanks @beta-ziliani)

### Standard Library

- Fix missing required args for `Socket::Addrinfo::Error.new` ([#10960](https://github.com/crystal-lang/crystal/pull/10960), thanks @straight-shoota)
- Fix disable unnecessary spec on win32 ([#10971](https://github.com/crystal-lang/crystal/pull/10971), thanks @straight-shoota)
- Remove incorrect type restrictions on index methods with offset ([#10972](https://github.com/crystal-lang/crystal/pull/10972), thanks @straight-shoota)
- Fix: documentation of `#step` in `Number` and `Char` ([#10966](https://github.com/crystal-lang/crystal/pull/10966), [#11006](https://github.com/crystal-lang/crystal/pull/11006), thanks @beta-ziliani and @straight-shoota)

### Compiler

- Fix parsing macro body with escaped backslash in literal ([#10995](https://github.com/crystal-lang/crystal/pull/10995), thanks @straight-shoota)

### Other

- Updating aarch64 actions to use 1.0.0 images ([#10976](https://github.com/crystal-lang/crystal/pull/10976), thanks @beta-ziliani)

## [1.1.0] - 2021-07-14

[1.1.0]: https://github.com/crystal-lang/crystal/releases/1.1.0

### Language changes

- Support splat expansions inside tuple and array literals. ([#10429](https://github.com/crystal-lang/crystal/pull/10429), thanks @HertzDevil)
- Support breaks with values inside `while` expressions. ([#10566](https://github.com/crystal-lang/crystal/pull/10566), thanks @HertzDevil)

#### Macros

- Add `@top_level` to access the top-level scope in macros. ([#10682](https://github.com/crystal-lang/crystal/pull/10682), thanks @beta-ziliani)
- Fix: preserve integer sizes in `NumberLiteral#int_bin_op`. ([#10713](https://github.com/crystal-lang/crystal/pull/10713), thanks @collidedscope)
- Add `NumberLiteral#to_number`. ([#10802](https://github.com/crystal-lang/crystal/pull/10802), thanks @straight-shoota)
- **(breaking-change)** Add `Crystal::Macros::Path#global?` deprecating the old `Crystal::Macros::Path#global`. ([#10812](https://github.com/crystal-lang/crystal/pull/10812), thanks @HertzDevil)
- Minor fixes to docs of `UnaryExpression` macro nodes. ([#10816](https://github.com/crystal-lang/crystal/pull/10816), thanks @HertzDevil)
- Add macro method `ASTNode#nil?`. ([#10850](https://github.com/crystal-lang/crystal/pull/10850), [#10616](https://github.com/crystal-lang/crystal/pull/10616), thanks @straight-shoota)

### Standard library

#### Global changes

##### Windows support

  - Port `Socket::Address` to win32 . ([#10610](https://github.com/crystal-lang/crystal/pull/10610), thanks @straight-shoota)
  - Port `Socket::Addrinfo` to win32. ([#10650](https://github.com/crystal-lang/crystal/pull/10650), thanks @straight-shoota)
  - Extract system-specifics from Socket. ([#10706](https://github.com/crystal-lang/crystal/pull/10706), thanks @straight-shoota)
  - Make `WinError` portable and add it to prelude. ([#10725](https://github.com/crystal-lang/crystal/pull/10725), thanks @straight-shoota)
  - Improve portability of `SystemError`. ([#10726](https://github.com/crystal-lang/crystal/pull/10726), thanks @straight-shoota)
  - Refactor `Socket::Addrinfo::Error` based on `os_error `. ([#10761](https://github.com/crystal-lang/crystal/pull/10761), thanks @straight-shoota)
  - Add `WinError.wsa_value` and specs for `WinError`. ([#10762](https://github.com/crystal-lang/crystal/pull/10762), thanks @straight-shoota)
  - Add specs for `Errno`. ([#10763](https://github.com/crystal-lang/crystal/pull/10763), thanks @straight-shoota)
  - Refactor: Move win32 libc bindings from `winbase.cr` to appropriate files. ([#10771](https://github.com/crystal-lang/crystal/pull/10771), thanks @straight-shoota)
  - Refactor: Change protocol socket fd to `Socket::Handle`. ([#10772](https://github.com/crystal-lang/crystal/pull/10772), thanks @straight-shoota)
  - Fix `Socket::Connect` error in addrinfo inherit `os_error`. ([#10782](https://github.com/crystal-lang/crystal/pull/10782), thanks @straight-shoota)
  - Reorganize some win32 libc bindings ([#10776](https://github.com/crystal-lang/crystal/pull/10776), thanks @straight-shoota)

##### Type annotations

  - Add type restriction to private `Process` constructor. ([#7040](https://github.com/crystal-lang/crystal/pull/7040), thanks @z64)
  - Add various return type restrictions (thanks @oprypin, @straight-shoota, and @caspiano):
    [#10578](https://github.com/crystal-lang/crystal/pull/10578), [#10579](https://github.com/crystal-lang/crystal/pull/10579),
    [#10580](https://github.com/crystal-lang/crystal/pull/10580), [#10581](https://github.com/crystal-lang/crystal/pull/10581),
    [#10582](https://github.com/crystal-lang/crystal/pull/10582), [#10583](https://github.com/crystal-lang/crystal/pull/10583),
    [#10584](https://github.com/crystal-lang/crystal/pull/10584), [#10585](https://github.com/crystal-lang/crystal/pull/10585),
    [#10586](https://github.com/crystal-lang/crystal/pull/10586), [#10587](https://github.com/crystal-lang/crystal/pull/10587),
    [#10588](https://github.com/crystal-lang/crystal/pull/10588), [#10849](https://github.com/crystal-lang/crystal/pull/10849),
    [#10856](https://github.com/crystal-lang/crystal/pull/10856), [#10857](https://github.com/crystal-lang/crystal/pull/10857),
    [#10858](https://github.com/crystal-lang/crystal/pull/10858), [#10905](https://github.com/crystal-lang/crystal/pull/10905)
  - Add type restrictions for splat-less overloads of some methods. ([#10594](https://github.com/crystal-lang/crystal/pull/10594), thanks @HertzDevil)

#### Numeric

- Add `Number.new` overload for `String`. ([#10422](https://github.com/crystal-lang/crystal/pull/10422), thanks @Blacksmoke16)
- Fix `Math.pw2ceil` for zero and 64-bit integers. ([#10555](https://github.com/crystal-lang/crystal/pull/10555), thanks @straight-shoota)
- Add `#positive?` & `#negative?` to `Number` and `Time::Span`. ([#10601](https://github.com/crystal-lang/crystal/pull/10601), thanks @Blacksmoke16)
- Fix imprecise `Number#significant` algorithm. ([#10615](https://github.com/crystal-lang/crystal/pull/10615), thanks @straight-shoota)
- Add `BigFloat`'s rounding modes. ([#10618](https://github.com/crystal-lang/crystal/pull/10618), thanks @HertzDevil)
- Fix handling of arithmetic overflow in `BigDecimal#div`. ([#10628](https://github.com/crystal-lang/crystal/pull/10628), thanks @kellydanma)
- Clarify behaviour of unsafe `Float`-to-number conversions. ([#10631](https://github.com/crystal-lang/crystal/pull/10631), thanks @HertzDevil)
- Fix return type restriction for `Number#humanize` overload. ([#10633](https://github.com/crystal-lang/crystal/pull/10633), thanks @HertzDevil)
- Fix `printf` float with many digits. ([#10719](https://github.com/crystal-lang/crystal/pull/10719), thanks @straight-shoota)
- Add `BigDecimal`'s missing rounding modes. ([#10798](https://github.com/crystal-lang/crystal/pull/10798), thanks @HertzDevil)
- Add support for using big rational `#**` with unsigned ints. ([#10887](https://github.com/crystal-lang/crystal/pull/10887), thanks @stakach)
- Add overflow detection to `BigFloat#to_i64` and `#to_u64`. ([#10630](https://github.com/crystal-lang/crystal/pull/10630), thanks @HertzDevil)

#### Text

- **(performance)** Optimize `Levenshtein.distance`. ([#8324](https://github.com/crystal-lang/crystal/pull/8324), thanks @r00ster91)
- Refactor: add private `Slice#hexdump(io : IO)` overload. ([#10496](https://github.com/crystal-lang/crystal/pull/10496), thanks @HertzDevil)
- Restrict `MatchData#begin` and `#end` to `Int32`. ([#10656](https://github.com/crystal-lang/crystal/pull/10656), thanks @straight-shoota)
- Refactor: remove `#check_needs_resize` from `IO::Memory`, `String::Builder`. ([#10732](https://github.com/crystal-lang/crystal/pull/10732), thanks @straight-shoota)
- Fix `Base64#encode`, exclude last 3 bytes from bswap. ([#10752](https://github.com/crystal-lang/crystal/pull/10752), thanks @kostya)
- Refactor: avoid union type in `Char::Reader#decode_char_at`. ([#10758](https://github.com/crystal-lang/crystal/pull/10758), thanks @asterite)

#### Collections

- Add sub/superset checking methods to `Hash`. ([#7500](https://github.com/crystal-lang/crystal/pull/7500), thanks @Sija)
- Improve documentation of `Array#[](Range)`. ([#10243](https://github.com/crystal-lang/crystal/pull/10243), thanks @straight-shoota)
- Add `Steppable` module as generalized `Number#step`. ([#10279](https://github.com/crystal-lang/crystal/pull/10279), thanks @straight-shoota)
- Add docs for `#map_with_index`. ([#10512](https://github.com/crystal-lang/crystal/pull/10512), thanks @wontruefree)
- Add `Array#truncate`. ([#10712](https://github.com/crystal-lang/crystal/pull/10712), thanks @HertzDevil)
- Fix: Always copy `Hash`'s default block on `#dup` and `#clone`. ([#10744](https://github.com/crystal-lang/crystal/pull/10744), thanks @HertzDevil)
- Apply `Array#push`'s resizing heuristic to `#unshift`. ([#10750](https://github.com/crystal-lang/crystal/pull/10750), thanks @HertzDevil)
- Refactor index / count normalization in range-like methods. ([#10753](https://github.com/crystal-lang/crystal/pull/10753), thanks @HertzDevil)
- Add methods for cumulative folding and prefix sums. ([#10789](https://github.com/crystal-lang/crystal/pull/10789), thanks @HertzDevil)
- Fix: Pass read-only flag to peeked slice in `IO::Memory`. ([#10891](https://github.com/crystal-lang/crystal/pull/10891), thanks @z64)

#### Crypto

- Add methods for getting peer certificates and signatures in `OpenSSL`. ([#8005](https://github.com/crystal-lang/crystal/pull/8005), thanks @will)
- Add docs for `OpenSSL::Cipher`. ([#9934](https://github.com/crystal-lang/crystal/pull/9934), thanks @sol-vin)
- Fix format of `src/openssl/cipher.cr`. ([#10705](https://github.com/crystal-lang/crystal/pull/10705), thanks @straight-shoota)
- Refine documentation for `Random#urlsafe_base64`. ([#10724](https://github.com/crystal-lang/crystal/pull/10724), thanks @straight-shoota)
- Fix ssl context required for `add_x509_verify_flags`. ([#10756](https://github.com/crystal-lang/crystal/pull/10756), thanks @stakach)

#### Time

- Improve error handling for `load_localtime` on unix. ([#10654](https://github.com/crystal-lang/crystal/pull/10654), thanks @straight-shoota)
- Fix broken call to `Time#to_s`. ([#10778](https://github.com/crystal-lang/crystal/pull/10778), thanks @straight-shoota)
- Fix `Time#shift` cover date boundaries with zone offset. ([#10871](https://github.com/crystal-lang/crystal/pull/10871), thanks @straight-shoota)

#### Files

- Fix and unify documentation for `puts`. ([#10614](https://github.com/crystal-lang/crystal/pull/10614), thanks @straight-shoota)
- Fix `Path#sibling` return type. ([#10655](https://github.com/crystal-lang/crystal/pull/10655), thanks @Sija)
- Add `Path` in `FileUtils`'s methods to match the interfaces it's wrapping. ([#10747](https://github.com/crystal-lang/crystal/pull/10747), thanks @yb66)
- Fix `FileDescriptor#pos` return `Int64` on armv6 ([#10845](https://github.com/crystal-lang/crystal/pull/10845), thanks @straight-shoota)

#### Fibers

- Clarify documentation on `Path#join` and `#==`. ([#10455](https://github.com/crystal-lang/crystal/pull/10455), thanks @straight-shoota)

#### Networking

- Add an example middleware for `remote_address`. ([#10408](https://github.com/crystal-lang/crystal/pull/10408), thanks @oprypin)
- Add `OAuth2::Client#http_client`. ([#10452](https://github.com/crystal-lang/crystal/pull/10452), thanks @straight-shoota)
- Fix undefined constant error for `http/params`. ([#10537](https://github.com/crystal-lang/crystal/pull/10537), thanks @stakach)
- Fix looping forever at 100% CPU if socket is closed. ([#10658](https://github.com/crystal-lang/crystal/pull/10658), thanks @didactic-drunk)
- Fix documentation of `HTTP::Cookies#[]=` empty path. ([#10669](https://github.com/crystal-lang/crystal/pull/10669), thanks @straight-shoota)
- Fix handling of `EAI_SYSTEM` for `getaddrinfo`. ([#10757](https://github.com/crystal-lang/crystal/pull/10757), thanks @straight-shoota)
- **(performance)** Cache `socket.local_address` and `socket.remote_address`. ([#10765](https://github.com/crystal-lang/crystal/pull/10765), thanks @lbguilherme)
- Fix: `IO::ARGF#read` should always return `i32`. ([#10828](https://github.com/crystal-lang/crystal/pull/10828), thanks @stakach)
- Fix `HTTP::Cookie` parse quoted cookie value. ([#10853](https://github.com/crystal-lang/crystal/pull/10853), thanks @straight-shoota)
- Add `Socket::Addrinfo#inspect` ([#10775](https://github.com/crystal-lang/crystal/pull/10775), thanks @straight-shoota)

#### System

- Fix sentence structure in `process.cr`. ([#9259](https://github.com/crystal-lang/crystal/pull/9259), thanks @matthewmcgarvey)

#### Runtime

- Implement segfault handler in Crystal. ([#10463](https://github.com/crystal-lang/crystal/pull/10463), thanks @maxfierke)
- Improve documentation for `Pointer.malloc` and `GC` methods. ([#10644](https://github.com/crystal-lang/crystal/pull/10644), thanks @straight-shoota)
- Add links to literal types in the language reference. ([#10827](https://github.com/crystal-lang/crystal/pull/10827), thanks @straight-shoota)

#### Serialization

- Add docs for some json methods. ([#10257](https://github.com/crystal-lang/crystal/pull/10257), thanks @rdp)
- Add `UUID.from_json_object_key?`. ([#10517](https://github.com/crystal-lang/crystal/pull/10517), thanks @kalinon)
- Fix `JSON::Lexer`'s UTF-16 escape sequence parsing. ([#10450](https://github.com/crystal-lang/crystal/pull/10450), thanks @HertzDevil)
- Fix `YAML::Serializable.use_yaml_discriminator` with typed enum. ([#10460](https://github.com/crystal-lang/crystal/pull/10460), thanks @straight-shoota)
- Fix YAML to not parse empty string as `nil`. ([#10608](https://github.com/crystal-lang/crystal/pull/10608), thanks @straight-shoota)
- Add `UUID` to yaml parsing. ([#10715](https://github.com/crystal-lang/crystal/pull/10715), thanks @kalinon)
- Fix double flushing json/yaml builders. ([#10716](https://github.com/crystal-lang/crystal/pull/10716), thanks @matthewmcgarvey)

#### Specs

- Add spec helper `it_iterates` for iteration methods. ([#10158](https://github.com/crystal-lang/crystal/pull/10158), [#10797](https://github.com/crystal-lang/crystal/pull/10797), thanks @straight-shoota)
- Add usage instructions for spec runner to compiler. ([#10046](https://github.com/crystal-lang/crystal/pull/10046), thanks @straight-shoota)
- Fix: Handle invalid option errors on `crystal spec`. ([#10787](https://github.com/crystal-lang/crystal/pull/10787), thanks @hugopl)
- Include `spec/**` in docs_main. ([#10863](https://github.com/crystal-lang/crystal/pull/10863), thanks @straight-shoota)

### Compiler

- Add support for type var splats inside `Tuple` during generic parameter substitution. ([#10232](https://github.com/crystal-lang/crystal/pull/10232), thanks @HertzDevil)
- Fix: consider free vars in parameters of abstract def implementations before existing types, in particular fixing the creation of empty types. ([#10503](https://github.com/crystal-lang/crystal/pull/10503), thanks @HertzDevil)
- Replace `Crystal::Type#covariant?` with `#implements?` ([#10507](https://github.com/crystal-lang/crystal/pull/10507), thanks @HertzDevil)
- Fix error message when default parameter value doesn't match non-type restriction. ([#10515](https://github.com/crystal-lang/crystal/pull/10515), thanks @HertzDevil)
- Fix type restriction logic for generic module instances. ([#10519](https://github.com/crystal-lang/crystal/pull/10519), thanks @HertzDevil)
- Fix logic for subclass restricted against uninstantiated nested generic superclass. ([#10522](https://github.com/crystal-lang/crystal/pull/10522), [#10560](https://github.com/crystal-lang/crystal/pull/10560), thanks @HertzDevil)
- Fix: eliminate extraneous types in certain non-commutative unions. ([#10527](https://github.com/crystal-lang/crystal/pull/10527), thanks @HertzDevil)
- Fix: exclude variables' final types inside `while true` if re-assigned before first break. ([#10538](https://github.com/crystal-lang/crystal/pull/10538), thanks @HertzDevil)
- Make `Pointer(T)#value=` even stricter for generic arguments. ([#10553](https://github.com/crystal-lang/crystal/pull/10553), thanks @HertzDevil)
- Fix body locations for def nodes that have default args . ([#10619](https://github.com/crystal-lang/crystal/pull/10619), thanks @oprypin)
- Fix call nodes' location after transforming its splats. ([#10620](https://github.com/crystal-lang/crystal/pull/10620), thanks @oprypin)
- Fix `check_type_allowed_as_proc_argument` to show the type name. ([#10688](https://github.com/crystal-lang/crystal/pull/10688), thanks @straight-shoota)
- Add free variables to "no overload matches" errors. ([#10692](https://github.com/crystal-lang/crystal/pull/10692), thanks @HertzDevil)
- Fix: make virtual unbound types also unbound. ([#10704](https://github.com/crystal-lang/crystal/pull/10704), thanks @HertzDevil)
- Fix: run instance variable initializers on instantiated generic superclasses only. ([#10729](https://github.com/crystal-lang/crystal/pull/10729), thanks @HertzDevil)
- Fix: allow `previous_def` to init superclass's non-nilable ivars. ([#10733](https://github.com/crystal-lang/crystal/pull/10733), thanks @HertzDevil)
- Fix: Use only last sub-expression of `Expressions` nodes for conditional type filters. ([#10738](https://github.com/crystal-lang/crystal/pull/10738), thanks @HertzDevil)
- Fix: Don't compute type filters inside `typeof`'s argument. ([#10739](https://github.com/crystal-lang/crystal/pull/10739), thanks @HertzDevil)
- Fix: Devirtualize types in `TypeNode#==(other : TypeNode)` and `#!=`. ([#10742](https://github.com/crystal-lang/crystal/pull/10742), thanks @HertzDevil)
- Fix exit types of variables assigned inside `while` conditions. ([#10759](https://github.com/crystal-lang/crystal/pull/10759), thanks @HertzDevil)
- Fix logic for `responds_to?` of generic module instances. ([#10760](https://github.com/crystal-lang/crystal/pull/10760), thanks @HertzDevil)
- Add support for accessing a common value of a union type. ([#10770](https://github.com/crystal-lang/crystal/pull/10770), thanks @asterite)
- Fix subtype relation when generic type variable is a virtual abstract struct. ([#10779](https://github.com/crystal-lang/crystal/pull/10779), thanks @HertzDevil)
- Fix array literals consisting entirely of splat expansions. ([#10792](https://github.com/crystal-lang/crystal/pull/10792), thanks @HertzDevil)
- Fix parsing macro literal containing char literal. ([#10799](https://github.com/crystal-lang/crystal/pull/10799), thanks @straight-shoota)
- Refactor: Use type instead of `is_a?` in filters. ([#10815](https://github.com/crystal-lang/crystal/pull/10815), thanks @caspiano)
- Expand named macro expression arguments before outer macro call expansion. ([#10819](https://github.com/crystal-lang/crystal/pull/10819), thanks @HertzDevil)
- Be more strict about printing operator calls as short forms. ([#10825](https://github.com/crystal-lang/crystal/pull/10825), thanks @HertzDevil)
- Fix union logic between metaclasses of uninstantiated generic classes in same hierarchy. ([#10832](https://github.com/crystal-lang/crystal/pull/10832), thanks @HertzDevil)
- Fix uninstantiated generic classes casting to themselves. ([#10883](https://github.com/crystal-lang/crystal/pull/10883), thanks @HertzDevil)
- Allow underscore in block return type even if the type can't be computed ([#10933](https://github.com/crystal-lang/crystal/pull/10933), thanks @asterite)
- Fix parser identifies call with named args as var ([#10842](https://github.com/crystal-lang/crystal/pull/10842), thanks @straight-shoota)

### Tools

#### Formatter

- Fix: allow trailing space in parenthesized unions. ([#10595](https://github.com/crystal-lang/crystal/pull/10595), thanks @HertzDevil)
- Fix: don't consume newline after endless range literals. ([#10596](https://github.com/crystal-lang/crystal/pull/10596), thanks @HertzDevil)
- Fix indentation of heredocs relative to delimiter. ([#10806](https://github.com/crystal-lang/crystal/pull/10806), thanks @HertzDevil)
- Fix heredoc indent with outer indent. ([#10867](https://github.com/crystal-lang/crystal/pull/10867), thanks @straight-shoota)

#### Doc generator

- Fix escaping of argument lists in doc generator, expose JSON. ([#10109](https://github.com/crystal-lang/crystal/pull/10109), [#10821](https://github.com/crystal-lang/crystal/pull/10821), thanks @oprypin and @Sija)
- Print named generic type arguments of type restrictions in docs. ([#10424](https://github.com/crystal-lang/crystal/pull/10424), thanks @HertzDevil)
- Fix: respect overload order between methods. ([#10609](https://github.com/crystal-lang/crystal/pull/10609), thanks @HertzDevil)
- Fix `PropagateDocVisitor` visit macro def. ([#10634](https://github.com/crystal-lang/crystal/pull/10634), thanks @straight-shoota)
- Fix: remove superclass from `ASTNode` in API docs. ([#10664](https://github.com/crystal-lang/crystal/pull/10664), thanks @beta-ziliani)
- **(breaking-change)** Remove deprecated `ditto` doc directive. ([#10755](https://github.com/crystal-lang/crystal/pull/10755), thanks @caspiano)
  (Note that it was scheduled for removal since 0.34)
- Fix: Restrict macro types' ancestors to `ASTNode`. ([#10722](https://github.com/crystal-lang/crystal/pull/10722), thanks @HertzDevil)
- Fix docs generator search use `html_id`. ([#10875](https://github.com/crystal-lang/crystal/pull/10875), thanks @straight-shoota)
- Fix `--sitemap-priority`, `--sitemap-changefreq`. ([#10906](https://github.com/crystal-lang/crystal/pull/10906), thanks @HertzDevil)

### Others

- CI: Update to use 1.0.0. ([#10533](https://github.com/crystal-lang/crystal/pull/10533), thanks @bcardiff)
- Bump distribution-scripts. ([#10639](https://github.com/crystal-lang/crystal/pull/10639), [#10673](https://github.com/crystal-lang/crystal/pull/10673), [#10754](https://github.com/crystal-lang/crystal/pull/10754), thanks @straight-shoota and @bcardiff)
- Fix contribution instructions. ([#10558](https://github.com/crystal-lang/crystal/pull/10558), thanks @straight-shoota)
- Remove `.dockerignore`. ([#10642](https://github.com/crystal-lang/crystal/pull/10642), thanks @miry)
- Add section about pull requests to the contributing guide. ([#10683](https://github.com/crystal-lang/crystal/pull/10683), thanks @straight-shoota)
- Publish nightly builds to OBS. ([#10684](https://github.com/crystal-lang/crystal/pull/10684), thanks @straight-shoota)
- Remove broken travis.yml config from `crystal init`. ([#10800](https://github.com/crystal-lang/crystal/pull/10800), thanks @straight-shoota)
- Disable broken `test_darwin` job on circleci. ([#10823](https://github.com/crystal-lang/crystal/pull/10823), thanks @straight-shoota)
- Update distribution-scripts for shards 0.15.0. ([#10862](https://github.com/crystal-lang/crystal/pull/10862), thanks @straight-shoota)
- Add smoke tests for platforms where we don't run full tests ([#10848](https://github.com/crystal-lang/crystal/pull/10848), thanks @straight-shoota)

## [1.0.0] - 2021-03-22

[1.0.0]: https://github.com/crystal-lang/crystal/releases/1.0.0

### Language changes

- Support `Tuple#[](Range)` with compile-time range literals. ([#10379](https://github.com/crystal-lang/crystal/pull/10379), thanks @HertzDevil)

#### Macros

- Don't use named argument key names as parameters for `method_missing` calls. ([#10388](https://github.com/crystal-lang/crystal/pull/10388), thanks @HertzDevil)

### Standard library

- **(breaking-change)** Drop deprecated definitions. ([#10386](https://github.com/crystal-lang/crystal/pull/10386), thanks @bcardiff)
- Fix example codes in multiple places. ([#10505](https://github.com/crystal-lang/crystal/pull/10505), thanks @maiha)

#### Macros

- **(breaking-change)** Always add explicit return types in getter/property macros. ([#10405](https://github.com/crystal-lang/crystal/pull/10405), thanks @Sija)

#### Numeric

- **(breaking-change)** Change default rounding mode to `TIES_EVEN`. ([#10508](https://github.com/crystal-lang/crystal/pull/10508), thanks @straight-shoota)
- Fix downcasting float infinity. ([#10420](https://github.com/crystal-lang/crystal/pull/10420), thanks @straight-shoota)
- Fix `String#to_f` out of range behaviour. ([#10425](https://github.com/crystal-lang/crystal/pull/10425), thanks @straight-shoota)
- Implement rounding mode for `Number#round`. ([#10413](https://github.com/crystal-lang/crystal/pull/10413), [#10360](https://github.com/crystal-lang/crystal/pull/10360), [#10479](https://github.com/crystal-lang/crystal/pull/10479), thanks @straight-shoota)

#### Text

- Add missing unicode whitespace support to `String` methods. ([#10367](https://github.com/crystal-lang/crystal/pull/10367), thanks @straight-shoota)

#### Collections

- Fix `Range#==` to ignore generic type arguments. ([#10309](https://github.com/crystal-lang/crystal/pull/10309), thanks @straight-shoota)
- Make `Enumerable#flat_map`, `Iterator#flat_map` work with mixed element types. ([#10329](https://github.com/crystal-lang/crystal/pull/10329), thanks @HertzDevil)
- Remove duplicated `sort` related specs. ([#10208](https://github.com/crystal-lang/crystal/pull/10208), thanks @MakeNowJust)
- Fix docs regarding `Set#each` return type. ([#10477](https://github.com/crystal-lang/crystal/pull/10477), thanks @kachick)
- Fix docs examples regarding `Set#*set_of?`. ([#10285](https://github.com/crystal-lang/crystal/pull/10285), thanks @oddp)
- Fix expectation on set specs. ([#10482](https://github.com/crystal-lang/crystal/pull/10482), thanks @kachick)

#### Serialization

- **(breaking-change)** Serialize `Enum` to underscored `String` by default. ([#10431](https://github.com/crystal-lang/crystal/pull/10431), thanks @straight-shoota, @caspiano)
- **(breaking-change)** Use class instead of struct for types in XML module. ([#10436](https://github.com/crystal-lang/crystal/pull/10436), thanks @hugopl)
- Add `YAML::Nodes::Node#kind`. ([#10432](https://github.com/crystal-lang/crystal/pull/10432), thanks @straight-shoota)

#### Files

- Let `IO::Memory` not be writable with read-only `Slice`. ([#10391](https://github.com/crystal-lang/crystal/pull/10391), thanks @straight-shoota)
- Allow `Int64` values within `IO#read_at`. ([#10356](https://github.com/crystal-lang/crystal/pull/10356), thanks @Blacksmoke16)
- Add `IO::Sized#remaining=(value)` to reuse an existing instance. ([#10520](https://github.com/crystal-lang/crystal/pull/10520), thanks @jgaskins)

#### Networking

- **(security)** Remove Cookie Name Decoding. ([#10442](https://github.com/crystal-lang/crystal/pull/10442), thanks @security-curious)
- **(breaking-change)** Remove implicit en-/decoding for cookie values. ([#10485](https://github.com/crystal-lang/crystal/pull/10485), thanks @straight-shoota)
- **(breaking-change)** Split `HTTP::Cookies.from_headers` into separate methods for server/client. ([#10486](https://github.com/crystal-lang/crystal/pull/10486), thanks @straight-shoota)
- **(performance)** Minor performance improvements to `HTTP::Cookies`. ([#10488](https://github.com/crystal-lang/crystal/pull/10488), thanks @straight-shoota)
- Respect subclasses when constructing `HTTP::Client` from class methods. ([#10375](https://github.com/crystal-lang/crystal/pull/10375), thanks @oprypin)
- Make the `content-length` header more RFC compliant. ([#10353](https://github.com/crystal-lang/crystal/pull/10353), thanks @Blacksmoke16)
- Fix `#respond_with_status` when headers written or closed. ([#10415](https://github.com/crystal-lang/crystal/pull/10415), thanks @straight-shoota)
- Fix `Cookie#==` to take all ivars into account. ([#10487](https://github.com/crystal-lang/crystal/pull/10487), thanks @straight-shoota)
- Remove implicit `path=/` from `HTTP::Cookie`. ([#10491](https://github.com/crystal-lang/crystal/pull/10491), thanks @straight-shoota)
- Add `HTTP::Request#local_address`. ([#10385](https://github.com/crystal-lang/crystal/pull/10385), thanks @carlhoerberg)

#### Logging

- Close `AsyncDispatcher` on `#finalize`. ([#10390](https://github.com/crystal-lang/crystal/pull/10390), thanks @straight-shoota)

#### System

- Fix `Process.parse_argument` behavior against a quote in a word. ([#10337](https://github.com/crystal-lang/crystal/pull/10337), thanks @MakeNowJust)
- Add aarch64 support for macOS/darwin targets. ([#10348](https://github.com/crystal-lang/crystal/pull/10348), thanks @maxfierke, @RomainFranceschini)
- Add `LibC::MAP_ANONYMOUS` to x86_64-darwin to match other platforms. ([#10398](https://github.com/crystal-lang/crystal/pull/10398), thanks @sourgrasses)

#### Runtime

- Improve error message for ELF reader on uninitialized runtime. ([#10282](https://github.com/crystal-lang/crystal/pull/10282), thanks @straight-shoota)

### Compiler

- **(breaking-change)** Disallow surrogate halves in escape sequences of string and character literals, use `\x` for arbitrary binary values. ([#10443](https://github.com/crystal-lang/crystal/pull/10443), thanks @HertzDevil)
- Fix ICE when exhaustive in-clause calls pseudo-method. ([#10382](https://github.com/crystal-lang/crystal/pull/10382), thanks @HertzDevil)
- Fix ICE when parsing `foo.%` calls. ([#10351](https://github.com/crystal-lang/crystal/pull/10351), thanks @MakeNowJust)
- Fix edge cases for symbol quoting rules. ([#10389](https://github.com/crystal-lang/crystal/pull/10389), thanks @HertzDevil)
- Support closured vars inside `Const` initializer. ([#10478](https://github.com/crystal-lang/crystal/pull/10478), thanks @RX14)
- Documentation grammar fix. ([#10369](https://github.com/crystal-lang/crystal/pull/10369), thanks @szTheory)

#### Language semantics

- Don't fail on untyped `is_a?`. ([#10320](https://github.com/crystal-lang/crystal/pull/10320), thanks @asterite)
- Fix named arguments in `super` and `previous_def` calls. ([#10400](https://github.com/crystal-lang/crystal/pull/10400), thanks @HertzDevil)
- Fix assignments in array literals. ([#10009](https://github.com/crystal-lang/crystal/pull/10009), thanks @straight-shoota)
- Consider type var splats in generic type restrictions. ([#10168](https://github.com/crystal-lang/crystal/pull/10168), thanks @HertzDevil)
- Align `Proc.new(&block)`'s behaviour with other captured blocks. ([#10263](https://github.com/crystal-lang/crystal/pull/10263), thanks @HertzDevil)
- Don't merge `NamedTuple` metaclasses through instance types. ([#10501](https://github.com/crystal-lang/crystal/pull/10501), thanks @HertzDevil)
- Access instantiations of `NamedTuple` and other generics uniformly. ([#10401](https://github.com/crystal-lang/crystal/pull/10401), thanks @HertzDevil)
- Improve error message for auto-cast error at Var assign. ([#10327](https://github.com/crystal-lang/crystal/pull/10327), thanks @straight-shoota)
- Exclude abstract defs from "no overload matches" errors. ([#10483](https://github.com/crystal-lang/crystal/pull/10483), thanks @HertzDevil)
- Support splats inside tuple literals in type names. ([#10430](https://github.com/crystal-lang/crystal/pull/10430), thanks @HertzDevil)
- Accept pointer instance types on falsey conditional branches. ([#10464](https://github.com/crystal-lang/crystal/pull/10464), thanks @HertzDevil)
- Match named arguments by external parameter names when checking overload cover. ([#10530](https://github.com/crystal-lang/crystal/pull/10530), thanks @HertzDevil)

#### Doc generator

- Detect source locations in more situations. ([#10439](https://github.com/crystal-lang/crystal/pull/10439), thanks @oprypin)

### Others

- CI improvements and housekeeping. ([#10299](https://github.com/crystal-lang/crystal/pull/10299), [#10340](https://github.com/crystal-lang/crystal/pull/10340), [#10476](https://github.com/crystal-lang/crystal/pull/10476), [#10480](https://github.com/crystal-lang/crystal/pull/10480), thanks @bcardiff, @Sija, @straight-shoota)
- Update distribution-scripts to use Shards v0.14.1. ([#10494](https://github.com/crystal-lang/crystal/pull/10494), thanks @bcardiff)
- Add GitHub issue templates. ([#8934](https://github.com/crystal-lang/crystal/pull/8934), thanks @j8r)
- Add LLVM 11.1 to the list of supported versions. ([#10523](https://github.com/crystal-lang/crystal/pull/10523), thanks @Sija)
- Fix SDL examples crashes. ([#10470](https://github.com/crystal-lang/crystal/pull/10470), thanks @megatux)

### 0.x

Older entries in [CHANGELOG.0.md](./CHANGELOG.0.md)
