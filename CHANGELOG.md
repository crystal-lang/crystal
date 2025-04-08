# Changelog

## [1.16.0] (2025-04-09)

_Feature freeze: 2025-03-26_

[1.16.0]: https://github.com/crystal-lang/crystal/releases/1.16.0

### Features

#### lang

- Support `Slice.literal` in the interpreter ([#15531], thanks @HertzDevil)
- Support `Slice.literal` with inferred element type ([#15529], thanks @HertzDevil)
- *(macros)* Error on `TypeNode#instance_vars`, `#has_inner_pointers?` macros in top-level scope ([#15293], thanks @straight-shoota)
- *(macros)* Support `sizeof` and `alignof` inside macros for stable types ([#15497], thanks @HertzDevil)

[#15531]: https://github.com/crystal-lang/crystal/pull/15531
[#15529]: https://github.com/crystal-lang/crystal/pull/15529
[#15293]: https://github.com/crystal-lang/crystal/pull/15293
[#15497]: https://github.com/crystal-lang/crystal/pull/15497

#### stdlib

- Fix `Box(Pointer).box` to not allocate pointer storage on the heap ([#15562], thanks @ysbaddaden)
- *(collection)* Add `Indexable#find` and `#find!` ([#15552], [#15589], thanks @punteek, @Sija)
- *(llvm)* Add `LLVM.version` ([#15354], thanks @straight-shoota)
- *(llvm)* Support LLVM 20 ([#15412], [#15418], thanks @HertzDevil, @straight-shoota)
- *(llvm)* Add `LLVM.init_native_target` and `LLVM.init_all_targets` ([#15466], thanks @HertzDevil)
- *(llvm)* Support `$LLVM_VERSION`, `$LLVM_TARGETS`, and `$LLVM_LDFLAGS` ([#15091], thanks @HertzDevil)
- *(llvm)* Add `LLVM::CodeModel::Tiny` ([#15608], thanks @HertzDevil)
- *(macros)* Implement `StringLiteral#scan` ([#15398], thanks @homonoidian)
- *(networking)* Add `Path` as possible argument type to `UNIXSocket` and `UNIXServer` ([#15260], thanks @BigBoyBarney)
- *(networking)* Add `Cookies#==` ([#15463], thanks @straight-shoota)
- *(runtime)* Add `EventLoop#wait_readable`, `#wait_writable` methods methods ([#15376], thanks @ysbaddaden)
- *(runtime)* Initialize `Fiber` with an explicit stack ([#15409], thanks @ysbaddaden)
- *(runtime)* Add fiber queues for execution context schedulers ([#15345], thanks @ysbaddaden)
- *(runtime)* RFC 2: Skeleton for ExecutionContext  ([#15350], [#15596], thanks @ysbaddaden)
- *(runtime)* RFC 2: Add `Fiber::ExecutionContext::SingleThreaded` scheduler ([#15511], thanks @ysbaddaden)
- *(runtime)* RFC 2: Add `Fiber::ExecutionContext::Isolated` ([#15513], thanks @ysbaddaden)
- *(runtime)* RFC 2: Add `Fiber::ExecutionContext::Monitor` ([#15599], thanks @ysbaddaden)
- *(runtime)* RFC 2: Add `Fiber::ExecutionContext::MultiThreaded` ([#15517], thanks @ysbaddaden)
- *(serialization)* Add `Union.from_json_object_key?` ([#15411], thanks @straight-shoota)
- *(system)* Add `Process::Status#description` ([#15468], thanks @straight-shoota)
- *(text)* Add `IO` overloads to `Char#upcase`, `#downcase`, `#titlecase` ([#15508], thanks @HertzDevil)
- *(text)* **[breaking]** New algorithm for `File.match?` ([#15607], thanks @straight-shoota)

[#15562]: https://github.com/crystal-lang/crystal/pull/15562
[#15552]: https://github.com/crystal-lang/crystal/pull/15552
[#15589]: https://github.com/crystal-lang/crystal/pull/15589
[#15354]: https://github.com/crystal-lang/crystal/pull/15354
[#15412]: https://github.com/crystal-lang/crystal/pull/15412
[#15418]: https://github.com/crystal-lang/crystal/pull/15418
[#15466]: https://github.com/crystal-lang/crystal/pull/15466
[#15091]: https://github.com/crystal-lang/crystal/pull/15091
[#15608]: https://github.com/crystal-lang/crystal/pull/15608
[#15398]: https://github.com/crystal-lang/crystal/pull/15398
[#15260]: https://github.com/crystal-lang/crystal/pull/15260
[#15463]: https://github.com/crystal-lang/crystal/pull/15463
[#15376]: https://github.com/crystal-lang/crystal/pull/15376
[#15409]: https://github.com/crystal-lang/crystal/pull/15409
[#15345]: https://github.com/crystal-lang/crystal/pull/15345
[#15350]: https://github.com/crystal-lang/crystal/pull/15350
[#15596]: https://github.com/crystal-lang/crystal/pull/15596
[#15511]: https://github.com/crystal-lang/crystal/pull/15511
[#15513]: https://github.com/crystal-lang/crystal/pull/15513
[#15599]: https://github.com/crystal-lang/crystal/pull/15599
[#15517]: https://github.com/crystal-lang/crystal/pull/15517
[#15411]: https://github.com/crystal-lang/crystal/pull/15411
[#15468]: https://github.com/crystal-lang/crystal/pull/15468
[#15508]: https://github.com/crystal-lang/crystal/pull/15508
[#15607]: https://github.com/crystal-lang/crystal/pull/15607

#### compiler

- *(cli)* Support `--output` long option in `crystal build` ([#15519], thanks @HertzDevil)
- *(cli)* Support directory name in `--output` CLI option ([#15471], thanks @straight-shoota)
- *(cli)* **[breaking]** Add compiler path to `$PATH` and `$CRYSTAL_EXEC_PATH` for subcommands ([#15186], thanks @straight-shoota)
- *(cli)* Respect `--mcpu=help` in the compiler ([#15595], thanks @HertzDevil)
- *(cli)* Add `CRYSTAL_EXEC_PATH` to `crystal env` [followup #15186] ([#15632], thanks @straight-shoota)
- *(codegen)* Set linkage of `__crystal_*` funs to internal ([#15439], thanks @ysbaddaden)
- *(codegen)* Add function name to `CRYSTAL_DEBUG_CODEGEN` log helper ([#15506], thanks @HertzDevil)
- *(parser)* Handle properly stringifying multiline macro expressions ([#15305], thanks @Blacksmoke16)
- *(parser)* **[breaking]** Check that def, macro, and block parameters don't end with `?` or `!` ([#12197], thanks @potomak)

[#15519]: https://github.com/crystal-lang/crystal/pull/15519
[#15471]: https://github.com/crystal-lang/crystal/pull/15471
[#15186]: https://github.com/crystal-lang/crystal/pull/15186
[#15595]: https://github.com/crystal-lang/crystal/pull/15595
[#15632]: https://github.com/crystal-lang/crystal/pull/15632
[#15439]: https://github.com/crystal-lang/crystal/pull/15439
[#15506]: https://github.com/crystal-lang/crystal/pull/15506
[#15305]: https://github.com/crystal-lang/crystal/pull/15305
[#12197]: https://github.com/crystal-lang/crystal/pull/12197

#### tools

- *(docs-generator)* Add docs to enum member helper methods ([#15379], thanks @nobodywasishere)
- *(docs-generator)* Add `:showdoc:` directive for `private` and `protected` objects (RFC #0011) ([#15337], thanks @nobodywasishere)
- *(docs-generator)* Add documentation support for `lib`, `fun`, `union`, `cstruct`, `external`, and `type` (RFC #0011) ([#15447], thanks @nobodywasishere)

[#15379]: https://github.com/crystal-lang/crystal/pull/15379
[#15337]: https://github.com/crystal-lang/crystal/pull/15337
[#15447]: https://github.com/crystal-lang/crystal/pull/15447

### Bugfixes

#### stdlib

- *(collection)* Fix hash `@indices` can grow larger than `Int32::MAX` bytes ([#15347], thanks @ysbaddaden)
- *(collection)* Fix `Tuple#to_a(&)` for arbitrary block output type ([#15431], thanks @straight-shoota)
- *(collection)* Fix `Range#size` for unsigned edge cases ([#14978], thanks @straight-shoota)
- *(collection)* **[breaking]** Fix the return type of `Enumerable#sum`, `#product` for union elements ([#15314], thanks @rvprasad)
- *(concurrency)* Fix `Reference#exec_recursive`, `#exec_recursive_clone` to be fiber aware ([#15361], thanks @ysbaddaden)
- *(concurrency)* RFC 2: MT safe fiber context switch on ARM ([#15582], thanks @ysbaddaden)
- *(crypto)* Fix argument type for `EVP_CIPHER_get_flags` ([#15392], thanks @miry)
- *(files)* Never remove UNC share name in `Path#dirname` ([#15583], thanks @HertzDevil)
- *(files)* Fix `File.exists?` for special devices on Windows ([#15587], thanks @HertzDevil)
- *(llvm)* Fix LLVM version detection for `-rc1` ([#15410], thanks @HertzDevil)
- *(networking)* **[breaking]** Fix parsing HTTP resource string that looks like absolute URL ([#15499], thanks @straight-shoota)
- *(runtime)* Fix `pkg_config` name for `libgc` bindings on FreeBSD ([#15532], thanks @straight-shoota)
- *(runtime)* RFC 2: MT safe fiber context switch on AArch64 ([#15581], thanks @ysbaddaden)
- *(runtime)* Add thread safety to `at_exit` ([#15598], thanks @ysbaddaden)
- *(runtime)* Remove top-level calls to `LibGC.has_method?` for backwards compat ([#15635], thanks @straight-shoota)
- *(serialization)* Fix `Union.from_yaml` to prioritize `String` for quoted scalar ([#15405], thanks @straight-shoota)
- *(system)* signal handler mustn't depend on the event loop ([#15325], thanks @ysbaddaden)
- *(system)* Corrects Windows lib lookup in case-sensitive OSes ([#15362], thanks @luislavena)
- *(system)* Fix permissions application in `File.copy` ([#15520], thanks @straight-shoota)
- *(system)* **[security]** Strip periods, spaces for batch file filtering on Windows ([#15573], thanks @GeopJr)
- *(system)* Extend Windows `Process` completion key's lifetime ([#15597], thanks @HertzDevil)

[#15347]: https://github.com/crystal-lang/crystal/pull/15347
[#15431]: https://github.com/crystal-lang/crystal/pull/15431
[#14978]: https://github.com/crystal-lang/crystal/pull/14978
[#15314]: https://github.com/crystal-lang/crystal/pull/15314
[#15361]: https://github.com/crystal-lang/crystal/pull/15361
[#15582]: https://github.com/crystal-lang/crystal/pull/15582
[#15392]: https://github.com/crystal-lang/crystal/pull/15392
[#15583]: https://github.com/crystal-lang/crystal/pull/15583
[#15587]: https://github.com/crystal-lang/crystal/pull/15587
[#15410]: https://github.com/crystal-lang/crystal/pull/15410
[#15499]: https://github.com/crystal-lang/crystal/pull/15499
[#15532]: https://github.com/crystal-lang/crystal/pull/15532
[#15581]: https://github.com/crystal-lang/crystal/pull/15581
[#15598]: https://github.com/crystal-lang/crystal/pull/15598
[#15635]: https://github.com/crystal-lang/crystal/pull/15635
[#15405]: https://github.com/crystal-lang/crystal/pull/15405
[#15325]: https://github.com/crystal-lang/crystal/pull/15325
[#15362]: https://github.com/crystal-lang/crystal/pull/15362
[#15520]: https://github.com/crystal-lang/crystal/pull/15520
[#15573]: https://github.com/crystal-lang/crystal/pull/15573
[#15597]: https://github.com/crystal-lang/crystal/pull/15597

#### compiler

- *(cli)* Fix query runtime version of LLVM ([#15355], thanks @straight-shoota)
- *(cli)* Fix handling of double dashes `--` in crystal `eval` command ([#15477], thanks @kojix2)
- *(codegen)* don't set external linkage when `@[NoInline]` is specified ([#15424], thanks @ysbaddaden)
- *(codegen)* Allow multiple redefinitions of the same top-level fun ([#15553], thanks @HertzDevil)
- *(codegen)* Respect `$MACOSX_DEPLOYMENT_TARGET` on macOS hosts ([#15603], thanks @HertzDevil)
- *(interpreter)* Fix `pkg_config` name for `libffi` bindings ([#15533], thanks @straight-shoota)
- *(parser)* Lexer: Fix location of token after line continuation ([#15454], thanks @FnControlOption)
- *(parser)* Add locations to `When` nodes ([#15481], thanks @Sija)
- *(parser)* Fix end location of call with block arg and no parentheses ([#15502], thanks @FnControlOption)
- *(parser)* Fix location of `MacroExpression` nodes ([#15524], thanks @Sija)
- *(parser)* Reject invalid operator names for implicit object calls ([#15526], thanks @nobodywasishere)

[#15355]: https://github.com/crystal-lang/crystal/pull/15355
[#15477]: https://github.com/crystal-lang/crystal/pull/15477
[#15424]: https://github.com/crystal-lang/crystal/pull/15424
[#15553]: https://github.com/crystal-lang/crystal/pull/15553
[#15603]: https://github.com/crystal-lang/crystal/pull/15603
[#15533]: https://github.com/crystal-lang/crystal/pull/15533
[#15454]: https://github.com/crystal-lang/crystal/pull/15454
[#15481]: https://github.com/crystal-lang/crystal/pull/15481
[#15502]: https://github.com/crystal-lang/crystal/pull/15502
[#15524]: https://github.com/crystal-lang/crystal/pull/15524
[#15526]: https://github.com/crystal-lang/crystal/pull/15526

#### tools

- *(formatter)* Add uninitialized variables to formatter variable scopes ([#15578], thanks @HertzDevil)

[#15578]: https://github.com/crystal-lang/crystal/pull/15578

### Chores

#### stdlib

- *(llvm)* **[breaking]** Remove the `LibLLVM::IS_*` constants ([#15464], thanks @HertzDevil)

[#15464]: https://github.com/crystal-lang/crystal/pull/15464

#### compiler

- *(interpreter:repl)* Update REPLy version ([#15328], thanks @oprypin)

[#15328]: https://github.com/crystal-lang/crystal/pull/15328

### Performance

#### stdlib

- *(files)* Optimize `Path#drive`, `#root`, and `#anchor` ([#15584], thanks @HertzDevil)
- *(files)* Optimize `Path#relative_to?` ([#15594], thanks @HertzDevil)
- *(runtime)* Shrink `Crystal::System.print_error`'s output size ([#15490], thanks @HertzDevil)

[#15584]: https://github.com/crystal-lang/crystal/pull/15584
[#15594]: https://github.com/crystal-lang/crystal/pull/15594
[#15490]: https://github.com/crystal-lang/crystal/pull/15490

#### compiler

- *(codegen)* Replace inline type IDs with global constants in LLVM IR ([#15485], [#15505], thanks @HertzDevil)
- *(codegen)* Do not load `Path` call receiver if known to be pure load ([#15488], thanks @HertzDevil)
- *(codegen)* Only refer to LLVM symbol table in calls to `Symbol#to_s` ([#15486], thanks @HertzDevil)
- *(debugger)* Read all DWARF abbreviations tables in a single pass ([#15515], thanks @HertzDevil)
- *(debugger)* Use binary search to search DWARF line numbers ([#15539], thanks @HertzDevil)
- *(debugger)* Remove `op_index` and `end_sequence` from `Crystal::DWARF::LineNumbers::Row` ([#15538], thanks @HertzDevil)

[#15485]: https://github.com/crystal-lang/crystal/pull/15485
[#15505]: https://github.com/crystal-lang/crystal/pull/15505
[#15488]: https://github.com/crystal-lang/crystal/pull/15488
[#15486]: https://github.com/crystal-lang/crystal/pull/15486
[#15515]: https://github.com/crystal-lang/crystal/pull/15515
[#15539]: https://github.com/crystal-lang/crystal/pull/15539
[#15538]: https://github.com/crystal-lang/crystal/pull/15538

### Refactor

#### stdlib

- Use splat parameter to put `Tuple`s in large `Array` constants ([#15495], thanks @HertzDevil)
- *(collection)* Simplify `Enumerable#to_a` ([#15432], thanks @straight-shoota)
- *(concurrency)* Use `Crystal::PointerLinkedList` instead of `Deque` in `Mutex` ([#15330], thanks @ysbaddaden)
- *(concurrency)* Add fiber safety to crystal/once ([#15370], thanks @ysbaddaden)
- *(concurrency)* ARM: reduce duplication in fiber context switch ([#15585], thanks @ysbaddaden)
- *(files)* Add nanosecond precision to `File.utime` on Unix ([#15335], thanks @ysbaddaden)
- *(llvm)* **[deprecation]** Make `LLVM::ABI` internal ([#15559], thanks @HertzDevil)
- *(llvm)* Only initialize `LLVM::Attribute`'s class variables on demand ([#15534], thanks @HertzDevil)
- *(macros)* Generate Object getter/property macros to remove duplications ([#15386], thanks @ysbaddaden)
- *(networking)* Refactor extract `HTTP::Cookies` to its own file ([#15500], [#15618], thanks @straight-shoota)
- *(runtime)* Add `Crystal.print_buffered(io)` and `Crystal.print_error_buffered` ([#15343], thanks @ysbaddaden)
- *(runtime)* Explicit init of Thread and Fiber class variables ([#15369], thanks @ysbaddaden)
- *(runtime)* Add `Crystal.once_init` replacing `__crystal_once_init` ([#15371], thanks @ysbaddaden)
- *(runtime)* Move shadow space reservation to x86_64 makecontext ([#15434], thanks @ysbaddaden)
- *(runtime)* Add `Crystal::EventLoop#sleep(duration)` method ([#15564], thanks @ysbaddaden)
- *(system)* Extract `File.match?` to separate source file ([#15574], thanks @straight-shoota)

[#15495]: https://github.com/crystal-lang/crystal/pull/15495
[#15432]: https://github.com/crystal-lang/crystal/pull/15432
[#15330]: https://github.com/crystal-lang/crystal/pull/15330
[#15370]: https://github.com/crystal-lang/crystal/pull/15370
[#15585]: https://github.com/crystal-lang/crystal/pull/15585
[#15335]: https://github.com/crystal-lang/crystal/pull/15335
[#15559]: https://github.com/crystal-lang/crystal/pull/15559
[#15534]: https://github.com/crystal-lang/crystal/pull/15534
[#15386]: https://github.com/crystal-lang/crystal/pull/15386
[#15500]: https://github.com/crystal-lang/crystal/pull/15500
[#15618]: https://github.com/crystal-lang/crystal/pull/15618
[#15343]: https://github.com/crystal-lang/crystal/pull/15343
[#15369]: https://github.com/crystal-lang/crystal/pull/15369
[#15371]: https://github.com/crystal-lang/crystal/pull/15371
[#15434]: https://github.com/crystal-lang/crystal/pull/15434
[#15564]: https://github.com/crystal-lang/crystal/pull/15564
[#15574]: https://github.com/crystal-lang/crystal/pull/15574

#### compiler

- *(codegen)* Rework initialization of constants & class variables ([#15333], thanks @ysbaddaden)
- *(codegen)* Remove unnecessary calls to `Crystal::CodeGenVisitor#union_type_and_value_pointer` ([#15491], thanks @HertzDevil)
- *(parser)* Simplify `Call.new` convenience overloads ([#15427], thanks @straight-shoota)
- *(parser)* Add `Call.new` constructor overload without `obj` parameter ([#15441], thanks @straight-shoota)
- *(semantic)* Extract `regex_value` helper for macro methods ([#15435], thanks @straight-shoota)

[#15333]: https://github.com/crystal-lang/crystal/pull/15333
[#15491]: https://github.com/crystal-lang/crystal/pull/15491
[#15427]: https://github.com/crystal-lang/crystal/pull/15427
[#15441]: https://github.com/crystal-lang/crystal/pull/15441
[#15435]: https://github.com/crystal-lang/crystal/pull/15435

### Documentation

#### lang

- Document `alignof` and `instance_alignof` ([#15576], thanks @HertzDevil)
- *(macros)* Document macro `sizeof` and `alignof` [followup #15497] ([#15575], thanks @HertzDevil)

[#15576]: https://github.com/crystal-lang/crystal/pull/15576
[#15575]: https://github.com/crystal-lang/crystal/pull/15575

#### stdlib

- Fix `Colorize::ObjectExtensions#colorize(r, g, b)` comment ([#15521], thanks @Sija)
- Rework docs for `getter`, `setter` and `property` macros ([#15428], thanks @ysbaddaden)
- Add missing files for API docs ([#15622], thanks @straight-shoota)
- *(runtime)* Document `::debugger` ([#15579], thanks @HertzDevil)

[#15521]: https://github.com/crystal-lang/crystal/pull/15521
[#15428]: https://github.com/crystal-lang/crystal/pull/15428
[#15622]: https://github.com/crystal-lang/crystal/pull/15622
[#15579]: https://github.com/crystal-lang/crystal/pull/15579

#### compiler

- *(cli)* Convert `crystal.1` manpage to asciidoc ([#15478], thanks @straight-shoota)
- *(cli)* Split combined manpage into individual ones for each command ([#15509], thanks @straight-shoota)
- *(cli)* Document environment variable `CRYSTAL_EXEC_PATH` [followup #15186] ([#15631], thanks @straight-shoota)

[#15478]: https://github.com/crystal-lang/crystal/pull/15478
[#15509]: https://github.com/crystal-lang/crystal/pull/15509
[#15631]: https://github.com/crystal-lang/crystal/pull/15631

#### other

- Add sample fibonacci numbers ([#15550], thanks @666hwll)

[#15550]: https://github.com/crystal-lang/crystal/pull/15550

### Specs

#### stdlib

- Fix invalid returns in class getter's lazy evaluation blocks ([#15364], thanks @ysbaddaden)
- *(specs)* Add specs for `File.match?` ([#15348], thanks @straight-shoota)
- *(text)* Add specs for `File.match?` from fast-glob ([#15604], thanks @straight-shoota)
- *(text)* Add specs for `File.match?` with multibyte characters ([#15601], thanks @straight-shoota)

[#15364]: https://github.com/crystal-lang/crystal/pull/15364
[#15348]: https://github.com/crystal-lang/crystal/pull/15348
[#15604]: https://github.com/crystal-lang/crystal/pull/15604
[#15601]: https://github.com/crystal-lang/crystal/pull/15601

#### compiler

- *(parser)* Add specs for block association in nested calls ([#15461], thanks @straight-shoota)

[#15461]: https://github.com/crystal-lang/crystal/pull/15461

### Infrastructure

- Changelog for 1.16.0 ([#15602], thanks @straight-shoota)
- Update previous Crystal release 1.15.0 ([#15339], thanks @straight-shoota)
- Make: Fix `make uninstall` to remove fish completion ([#15367], thanks @straight-shoota)
- Merge `release/1.15`@1.15.1 ([#15422], thanks @straight-shoota)
- Fix: Remove reverted PR from changelog for 1.15.1 ([#15415], thanks @straight-shoota)
- Update previous release: 1.15.1 ([#15417], thanks @straight-shoota)
- Add backports to changelog generator ([#15413], thanks @straight-shoota)
- Makefile: Expand `DESTDIR` outside of prefixed dir variables ([#15444], thanks @straight-shoota)
- Add git mailmap ([#15396], thanks @straight-shoota)
- Rename `find-llvm-config` to `find-llvm-config.sh` ([#15448], thanks @straight-shoota)
- Makefile: Remove `crystal` from `DATADIR` ([#15467], thanks @straight-shoota)
- Add `scripts/update-shards.sh` ([#15462], thanks @straight-shoota)
- Enhance `.gitignore` ([#15469], thanks @straight-shoota)
- Introduce shellcheck to lint shell scripts ([#15169], thanks @straight-shoota)
- Trim `CHANGELOG.md` ([#15627], thanks @straight-shoota)
- Update `scripts/generate_llvm_version_info.cr` ([#15465], thanks @HertzDevil)
- *(ci)* Fix shards packaging for mingw-w64 ([#15451], thanks @straight-shoota)
- *(ci)* Add workflow for backporting PRs to release branches ([#15372], [#15378], thanks @straight-shoota)
- *(ci)* Update cygwin/cygwin-install-action action to v5 ([#15346], thanks @renovate)
- *(ci)* Extract forward compatibility checks and run on nightly schedule ([#15437], thanks @straight-shoota)
- *(ci)* Use MSYS2 Crystal package for `mingw-w64` workflow ([#15453], [#15476], thanks @HertzDevil, @straight-shoota)
- *(ci)* Filter runs of LLVM Test workflow ([#15458], thanks @straight-shoota)
- *(ci)* Filter runs of regex engine workflow ([#15460], thanks @straight-shoota)
- *(ci)* Filter runs of OpenSSL Test workflow ([#15459], thanks @straight-shoota)
- *(ci)* Filter runs of Smoke Test workflow ([#15457], thanks @straight-shoota)
- *(ci)* Introduce actionlint to lint GitHub Actions workflows ([#15449], thanks @straight-shoota)
- *(ci)* Fix MinGW-W64 workflow to run compiler tests with fresh compiler ([#15522], thanks @straight-shoota)
- *(ci)* Update GH Actions ([#15525], thanks @renovate)
- *(ci)* Update GH Actions ([#15551], thanks @renovate)
- *(ci)* Update library versions for MSVC CI ([#15554], thanks @HertzDevil)
- *(ci)* Increase memory for `aarch64-*-test-compiler` runners to 16GB ([#15572], thanks @straight-shoota)
- *(ci)* Add AArch64 Linux workflow using GitHub's runner ([#15600], thanks @HertzDevil)

[#15602]: https://github.com/crystal-lang/crystal/pull/15602
[#15339]: https://github.com/crystal-lang/crystal/pull/15339
[#15367]: https://github.com/crystal-lang/crystal/pull/15367
[#15422]: https://github.com/crystal-lang/crystal/pull/15422
[#15415]: https://github.com/crystal-lang/crystal/pull/15415
[#15417]: https://github.com/crystal-lang/crystal/pull/15417
[#15413]: https://github.com/crystal-lang/crystal/pull/15413
[#15444]: https://github.com/crystal-lang/crystal/pull/15444
[#15396]: https://github.com/crystal-lang/crystal/pull/15396
[#15448]: https://github.com/crystal-lang/crystal/pull/15448
[#15467]: https://github.com/crystal-lang/crystal/pull/15467
[#15462]: https://github.com/crystal-lang/crystal/pull/15462
[#15469]: https://github.com/crystal-lang/crystal/pull/15469
[#15169]: https://github.com/crystal-lang/crystal/pull/15169
[#15627]: https://github.com/crystal-lang/crystal/pull/15627
[#15465]: https://github.com/crystal-lang/crystal/pull/15465
[#15451]: https://github.com/crystal-lang/crystal/pull/15451
[#15372]: https://github.com/crystal-lang/crystal/pull/15372
[#15378]: https://github.com/crystal-lang/crystal/pull/15378
[#15346]: https://github.com/crystal-lang/crystal/pull/15346
[#15437]: https://github.com/crystal-lang/crystal/pull/15437
[#15453]: https://github.com/crystal-lang/crystal/pull/15453
[#15476]: https://github.com/crystal-lang/crystal/pull/15476
[#15458]: https://github.com/crystal-lang/crystal/pull/15458
[#15460]: https://github.com/crystal-lang/crystal/pull/15460
[#15459]: https://github.com/crystal-lang/crystal/pull/15459
[#15457]: https://github.com/crystal-lang/crystal/pull/15457
[#15449]: https://github.com/crystal-lang/crystal/pull/15449
[#15522]: https://github.com/crystal-lang/crystal/pull/15522
[#15525]: https://github.com/crystal-lang/crystal/pull/15525
[#15551]: https://github.com/crystal-lang/crystal/pull/15551
[#15554]: https://github.com/crystal-lang/crystal/pull/15554
[#15572]: https://github.com/crystal-lang/crystal/pull/15572
[#15600]: https://github.com/crystal-lang/crystal/pull/15600

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
