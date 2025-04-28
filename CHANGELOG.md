# Changelog

## [1.16.2] (2025-04-29)

[1.16.2]: https://github.com/crystal-lang/crystal/releases/1.16.2

### Bugfixes

#### stdlib

- *(numeric)* Fix show `unit_separator` in `#humanize_bytes` with empty prefix ([#15717], backported from [#15683], thanks @straight-shoota)
- *(runtime)* Fix `Fiber::ExecutionContext::Isolated#wait` must suspend fiber ([#15723], backported from [#15720], thanks @ysbaddaden)
- *(runtime)* Fix run win32 console reader in thread instead of isolated context ([#15714], thanks @ysbaddaden)
- *(runtime)* Fix: `CRYSTAL_LOAD_DEBUG_INFO=1` fails with `-Dexecution_context` ([#15715], thanks @crysbot)
- *(runtime)* Fix `-Dtracing` raises math overflows on fiber sleep ([#15725], backported from [#15722], thanks @ysbaddaden)

[#15717]: https://github.com/crystal-lang/crystal/pull/15717
[#15683]: https://github.com/crystal-lang/crystal/pull/15683
[#15723]: https://github.com/crystal-lang/crystal/pull/15723
[#15720]: https://github.com/crystal-lang/crystal/pull/15720
[#15714]: https://github.com/crystal-lang/crystal/pull/15714
[#15715]: https://github.com/crystal-lang/crystal/pull/15715
[#15725]: https://github.com/crystal-lang/crystal/pull/15725
[#15722]: https://github.com/crystal-lang/crystal/pull/15722

#### compiler

- *(semantic)* Do not add `ReferenceStorage` to `Value`'s subclasses twice ([#15718], backported from [#15706], thanks @HertzDevil)

[#15718]: https://github.com/crystal-lang/crystal/pull/15718
[#15706]: https://github.com/crystal-lang/crystal/pull/15706

### Refactor

#### compiler

- *(codegen)* Add `__crystal_raise_cast_failed` for non-interpreted code ([#15712], backported from [#15708], thanks @HertzDevil)

[#15712]: https://github.com/crystal-lang/crystal/pull/15712
[#15708]: https://github.com/crystal-lang/crystal/pull/15708

### Infrastructure

- Changelog for 1.16.2 ([#15716], thanks @straight-shoota)
- *(ci)* Fix package shards on MinGW ([#15719], thanks @straight-shoota)
- *(ci)* Only set up Cygwin on Windows CI if truly required ([#15713], backported from [#15661], thanks @HertzDevil)

[#15716]: https://github.com/crystal-lang/crystal/pull/15716
[#15719]: https://github.com/crystal-lang/crystal/pull/15719
[#15713]: https://github.com/crystal-lang/crystal/pull/15713
[#15661]: https://github.com/crystal-lang/crystal/pull/15661

## [1.16.1] (2025-04-16)

[1.16.1]: https://github.com/crystal-lang/crystal/releases/1.16.1

### Bugfixes

#### stdlib

- *(runtime)* Correctly transfer FD ownership in polling event loop ([#15650], thanks @ysbaddaden)
- *(runtime)* Fix error message when `PollDescriptor` can't transfer fd ([#15663], thanks @ysbaddaden)
- *(runtime)* Fix `libgc` pkg-config name for version discovery ([#15636], thanks @straight-shoota)
- *(serialization)* **[regression]** Fix link `bcrypt` with `libxml2` on Windows ([#15651], thanks @straight-shoota)

[#15650]: https://github.com/crystal-lang/crystal/pull/15650
[#15663]: https://github.com/crystal-lang/crystal/pull/15663
[#15636]: https://github.com/crystal-lang/crystal/pull/15636
[#15651]: https://github.com/crystal-lang/crystal/pull/15651

#### compiler

- *(cli)* **[regression]** Fix `crystal eval` read from stdin ([#15655], thanks @straight-shoota)

[#15655]: https://github.com/crystal-lang/crystal/pull/15655

### Documentation

#### stdlib

- *(runtime)* Enable docs for `ExecutionContext` ([#15644], thanks @straight-shoota)
- *(runtime)* Fix mark method overrides on `ExecutionContext` as `:nodoc:` ([#15659], thanks @ysbaddaden)
- *(runtime)* Update docs for `Fiber::ExecutionContext.default_workers_count` ([#15664], thanks @ysbaddaden)
- *(runtime)* Enhance documentation for `ExecutionContext` ([#15665], thanks @straight-shoota)

[#15644]: https://github.com/crystal-lang/crystal/pull/15644
[#15659]: https://github.com/crystal-lang/crystal/pull/15659
[#15664]: https://github.com/crystal-lang/crystal/pull/15664
[#15665]: https://github.com/crystal-lang/crystal/pull/15665

### Infrastructure

- Changelog for 1.16.1 ([#15666], thanks @straight-shoota)

[#15666]: https://github.com/crystal-lang/crystal/pull/15666

## [1.16.0] (2025-04-09)

[1.16.0]: https://github.com/crystal-lang/crystal/releases/1.16.0

### Features

#### lang

- Support `Slice.literal` in the interpreter ([#15531], thanks @HertzDevil)
- Support `Slice.literal` with inferred element type ([#15529], thanks @HertzDevil)
- _(macros)_ Error on `TypeNode#instance_vars`, `#has_inner_pointers?` macros in top-level scope ([#15293], thanks @straight-shoota)
- _(macros)_ Support `sizeof` and `alignof` inside macros for stable types ([#15497], thanks @HertzDevil)

[#15531]: https://github.com/crystal-lang/crystal/pull/15531
[#15529]: https://github.com/crystal-lang/crystal/pull/15529
[#15293]: https://github.com/crystal-lang/crystal/pull/15293
[#15497]: https://github.com/crystal-lang/crystal/pull/15497

#### stdlib

- Fix `Box(Pointer).box` to not allocate pointer storage on the heap ([#15562], thanks @ysbaddaden)
- _(collection)_ Add `Indexable#find` and `#find!` ([#15552], [#15589], thanks @punteek, @Sija)
- _(llvm)_ Add `LLVM.version` ([#15354], thanks @straight-shoota)
- _(llvm)_ Support LLVM 20 ([#15412], [#15418], thanks @HertzDevil, @straight-shoota)
- _(llvm)_ Add `LLVM.init_native_target` and `LLVM.init_all_targets` ([#15466], thanks @HertzDevil)
- _(llvm)_ Support `$LLVM_VERSION`, `$LLVM_TARGETS`, and `$LLVM_LDFLAGS` ([#15091], thanks @HertzDevil)
- _(llvm)_ Add `LLVM::CodeModel::Tiny` ([#15608], thanks @HertzDevil)
- _(macros)_ Implement `StringLiteral#scan` ([#15398], thanks @homonoidian)
- _(networking)_ Add `Path` as possible argument type to `UNIXSocket` and `UNIXServer` ([#15260], thanks @BigBoyBarney)
- _(networking)_ Add `Cookies#==` ([#15463], thanks @straight-shoota)
- _(runtime)_ Add `EventLoop#wait_readable`, `#wait_writable` methods methods ([#15376], thanks @ysbaddaden)
- _(runtime)_ Initialize `Fiber` with an explicit stack ([#15409], thanks @ysbaddaden)
- _(runtime)_ Add fiber queues for execution context schedulers ([#15345], thanks @ysbaddaden)
- _(runtime)_ RFC 2: Skeleton for ExecutionContext  ([#15350], [#15596], thanks @ysbaddaden)
- _(runtime)_ RFC 2: Add `Fiber::ExecutionContext::SingleThreaded` scheduler ([#15511], thanks @ysbaddaden)
- _(runtime)_ RFC 2: Add `Fiber::ExecutionContext::Isolated` ([#15513], thanks @ysbaddaden)
- _(runtime)_ RFC 2: Add `Fiber::ExecutionContext::Monitor` ([#15599], thanks @ysbaddaden)
- _(runtime)_ RFC 2: Add `Fiber::ExecutionContext::MultiThreaded` ([#15517], thanks @ysbaddaden)
- _(serialization)_ Add `Union.from_json_object_key?` ([#15411], thanks @straight-shoota)
- _(system)_ Add `Process::Status#description` ([#15468], thanks @straight-shoota)
- _(text)_ Add `IO` overloads to `Char#upcase`, `#downcase`, `#titlecase` ([#15508], thanks @HertzDevil)
- _(text)_ **[breaking]** New algorithm for `File.match?` ([#15607], thanks @straight-shoota)

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

- _(cli)_ Support `--output` long option in `crystal build` ([#15519], thanks @HertzDevil)
- _(cli)_ Support directory name in `--output` CLI option ([#15471], thanks @straight-shoota)
- _(cli)_ **[breaking]** Add compiler path to `$PATH` and `$CRYSTAL_EXEC_PATH` for subcommands ([#15186], thanks @straight-shoota)
- _(cli)_ Respect `--mcpu=help` in the compiler ([#15595], thanks @HertzDevil)
- _(cli)_ Add `CRYSTAL_EXEC_PATH` to `crystal env` [followup #15186] ([#15632], thanks @straight-shoota)
- _(codegen)_ Set linkage of `__crystal_*` funs to internal ([#15439], thanks @ysbaddaden)
- _(codegen)_ Add function name to `CRYSTAL_DEBUG_CODEGEN` log helper ([#15506], thanks @HertzDevil)
- _(parser)_ Handle properly stringifying multiline macro expressions ([#15305], thanks @Blacksmoke16)
- _(parser)_ **[breaking]** Check that def, macro, and block parameters don't end with `?` or `!` ([#12197], thanks @potomak)

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

- _(docs-generator)_ Add docs to enum member helper methods ([#15379], thanks @nobodywasishere)
- _(docs-generator)_ Add `:showdoc:` directive for `private` and `protected` objects (RFC #0011) ([#15337], thanks @nobodywasishere)
- _(docs-generator)_ Add documentation support for `lib`, `fun`, `union`, `cstruct`, `external`, and `type` (RFC #0011) ([#15447], thanks @nobodywasishere)

[#15379]: https://github.com/crystal-lang/crystal/pull/15379
[#15337]: https://github.com/crystal-lang/crystal/pull/15337
[#15447]: https://github.com/crystal-lang/crystal/pull/15447

### Bugfixes

#### stdlib

- _(collection)_ Fix hash `@indices` can grow larger than `Int32::MAX` bytes ([#15347], thanks @ysbaddaden)
- _(collection)_ Fix `Tuple#to_a(&)` for arbitrary block output type ([#15431], thanks @straight-shoota)
- _(collection)_ Fix `Range#size` for unsigned edge cases ([#14978], thanks @straight-shoota)
- _(collection)_ **[breaking]** Fix the return type of `Enumerable#sum`, `#product` for union elements ([#15314], thanks @rvprasad)
- _(concurrency)_ Fix `Reference#exec_recursive`, `#exec_recursive_clone` to be fiber aware ([#15361], thanks @ysbaddaden)
- _(concurrency)_ RFC 2: MT safe fiber context switch on ARM ([#15582], thanks @ysbaddaden)
- _(crypto)_ Fix argument type for `EVP_CIPHER_get_flags` ([#15392], thanks @miry)
- _(files)_ Never remove UNC share name in `Path#dirname` ([#15583], thanks @HertzDevil)
- _(files)_ Fix `File.exists?` for special devices on Windows ([#15587], thanks @HertzDevil)
- _(llvm)_ Fix LLVM version detection for `-rc1` ([#15410], thanks @HertzDevil)
- _(networking)_ **[breaking]** Fix parsing HTTP resource string that looks like absolute URL ([#15499], thanks @straight-shoota)
- _(runtime)_ Fix `pkg_config` name for `libgc` bindings on FreeBSD ([#15532], thanks @straight-shoota)
- _(runtime)_ RFC 2: MT safe fiber context switch on AArch64 ([#15581], thanks @ysbaddaden)
- _(runtime)_ Add thread safety to `at_exit` ([#15598], thanks @ysbaddaden)
- _(runtime)_ Remove top-level calls to `LibGC.has_method?` for backwards compat ([#15635], thanks @straight-shoota)
- _(serialization)_ Fix `Union.from_yaml` to prioritize `String` for quoted scalar ([#15405], thanks @straight-shoota)
- _(system)_ signal handler mustn't depend on the event loop ([#15325], thanks @ysbaddaden)
- _(system)_ Corrects Windows lib lookup in case-sensitive OSes ([#15362], thanks @luislavena)
- _(system)_ Fix permissions application in `File.copy` ([#15520], thanks @straight-shoota)
- _(system)_ **[security]** Strip periods, spaces for batch file filtering on Windows ([#15573], thanks @GeopJr)
- _(system)_ Extend Windows `Process` completion key's lifetime ([#15597], thanks @HertzDevil)

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

- _(cli)_ Fix query runtime version of LLVM ([#15355], thanks @straight-shoota)
- _(cli)_ Fix handling of double dashes `--` in crystal `eval` command ([#15477], thanks @kojix2)
- _(codegen)_ don't set external linkage when `@[NoInline]` is specified ([#15424], thanks @ysbaddaden)
- _(codegen)_ Allow multiple redefinitions of the same top-level fun ([#15553], thanks @HertzDevil)
- _(codegen)_ Respect `$MACOSX_DEPLOYMENT_TARGET` on macOS hosts ([#15603], thanks @HertzDevil)
- _(interpreter)_ Fix `pkg_config` name for `libffi` bindings ([#15533], thanks @straight-shoota)
- _(parser)_ Lexer: Fix location of token after line continuation ([#15454], thanks @FnControlOption)
- _(parser)_ Add locations to `When` nodes ([#15481], thanks @Sija)
- _(parser)_ Fix end location of call with block arg and no parentheses ([#15502], thanks @FnControlOption)
- _(parser)_ Fix location of `MacroExpression` nodes ([#15524], thanks @Sija)
- _(parser)_ Reject invalid operator names for implicit object calls ([#15526], thanks @nobodywasishere)

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

- _(formatter)_ Add uninitialized variables to formatter variable scopes ([#15578], thanks @HertzDevil)

[#15578]: https://github.com/crystal-lang/crystal/pull/15578

### Chores

#### stdlib

- _(llvm)_ **[breaking]** Remove the `LibLLVM::IS_*` constants ([#15464], thanks @HertzDevil)

[#15464]: https://github.com/crystal-lang/crystal/pull/15464

#### compiler

- _(interpreter:repl)_ Update REPLy version ([#15328], thanks @oprypin)

[#15328]: https://github.com/crystal-lang/crystal/pull/15328

### Performance

#### stdlib

- _(files)_ Optimize `Path#drive`, `#root`, and `#anchor` ([#15584], thanks @HertzDevil)
- _(files)_ Optimize `Path#relative_to?` ([#15594], thanks @HertzDevil)
- _(runtime)_ Shrink `Crystal::System.print_error`'s output size ([#15490], thanks @HertzDevil)

[#15584]: https://github.com/crystal-lang/crystal/pull/15584
[#15594]: https://github.com/crystal-lang/crystal/pull/15594
[#15490]: https://github.com/crystal-lang/crystal/pull/15490

#### compiler

- _(codegen)_ Replace inline type IDs with global constants in LLVM IR ([#15485], [#15505], thanks @HertzDevil)
- _(codegen)_ Do not load `Path` call receiver if known to be pure load ([#15488], thanks @HertzDevil)
- _(codegen)_ Only refer to LLVM symbol table in calls to `Symbol#to_s` ([#15486], thanks @HertzDevil)
- _(debugger)_ Read all DWARF abbreviations tables in a single pass ([#15515], thanks @HertzDevil)
- _(debugger)_ Use binary search to search DWARF line numbers ([#15539], thanks @HertzDevil)
- _(debugger)_ Remove `op_index` and `end_sequence` from `Crystal::DWARF::LineNumbers::Row` ([#15538], thanks @HertzDevil)

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
- _(collection)_ Simplify `Enumerable#to_a` ([#15432], thanks @straight-shoota)
- _(concurrency)_ Use `Crystal::PointerLinkedList` instead of `Deque` in `Mutex` ([#15330], thanks @ysbaddaden)
- _(concurrency)_ Add fiber safety to crystal/once ([#15370], thanks @ysbaddaden)
- _(concurrency)_ ARM: reduce duplication in fiber context switch ([#15585], thanks @ysbaddaden)
- _(files)_ Add nanosecond precision to `File.utime` on Unix ([#15335], thanks @ysbaddaden)
- _(llvm)_ **[deprecation]** Make `LLVM::ABI` internal ([#15559], thanks @HertzDevil)
- _(llvm)_ Only initialize `LLVM::Attribute`'s class variables on demand ([#15534], thanks @HertzDevil)
- _(macros)_ Generate Object getter/property macros to remove duplications ([#15386], thanks @ysbaddaden)
- _(networking)_ Refactor extract `HTTP::Cookies` to its own file ([#15500], [#15618], thanks @straight-shoota)
- _(runtime)_ Add `Crystal.print_buffered(io)` and `Crystal.print_error_buffered` ([#15343], thanks @ysbaddaden)
- _(runtime)_ Explicit init of Thread and Fiber class variables ([#15369], thanks @ysbaddaden)
- _(runtime)_ Add `Crystal.once_init` replacing `__crystal_once_init` ([#15371], thanks @ysbaddaden)
- _(runtime)_ Move shadow space reservation to x86_64 makecontext ([#15434], thanks @ysbaddaden)
- _(runtime)_ Add `Crystal::EventLoop#sleep(duration)` method ([#15564], thanks @ysbaddaden)
- _(system)_ Extract `File.match?` to separate source file ([#15574], thanks @straight-shoota)

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

- _(codegen)_ Rework initialization of constants & class variables ([#15333], thanks @ysbaddaden)
- _(codegen)_ Remove unnecessary calls to `Crystal::CodeGenVisitor#union_type_and_value_pointer` ([#15491], thanks @HertzDevil)
- _(parser)_ Simplify `Call.new` convenience overloads ([#15427], thanks @straight-shoota)
- _(parser)_ Add `Call.new` constructor overload without `obj` parameter ([#15441], thanks @straight-shoota)
- _(semantic)_ Extract `regex_value` helper for macro methods ([#15435], thanks @straight-shoota)

[#15333]: https://github.com/crystal-lang/crystal/pull/15333
[#15491]: https://github.com/crystal-lang/crystal/pull/15491
[#15427]: https://github.com/crystal-lang/crystal/pull/15427
[#15441]: https://github.com/crystal-lang/crystal/pull/15441
[#15435]: https://github.com/crystal-lang/crystal/pull/15435

### Documentation

#### lang

- Document `alignof` and `instance_alignof` ([#15576], thanks @HertzDevil)
- _(macros)_ Document macro `sizeof` and `alignof` [followup #15497] ([#15575], thanks @HertzDevil)

[#15576]: https://github.com/crystal-lang/crystal/pull/15576
[#15575]: https://github.com/crystal-lang/crystal/pull/15575

#### stdlib

- Fix `Colorize::ObjectExtensions#colorize(r, g, b)` comment ([#15521], thanks @Sija)
- Rework docs for `getter`, `setter` and `property` macros ([#15428], thanks @ysbaddaden)
- Add missing files for API docs ([#15622], thanks @straight-shoota)
- _(runtime)_ Document `::debugger` ([#15579], thanks @HertzDevil)

[#15521]: https://github.com/crystal-lang/crystal/pull/15521
[#15428]: https://github.com/crystal-lang/crystal/pull/15428
[#15622]: https://github.com/crystal-lang/crystal/pull/15622
[#15579]: https://github.com/crystal-lang/crystal/pull/15579

#### compiler

- _(cli)_ Convert `crystal.1` manpage to asciidoc ([#15478], thanks @straight-shoota)
- _(cli)_ Split combined manpage into individual ones for each command ([#15509], thanks @straight-shoota)
- _(cli)_ Document environment variable `CRYSTAL_EXEC_PATH` [followup #15186] ([#15631], thanks @straight-shoota)

[#15478]: https://github.com/crystal-lang/crystal/pull/15478
[#15509]: https://github.com/crystal-lang/crystal/pull/15509
[#15631]: https://github.com/crystal-lang/crystal/pull/15631

#### other

- Add sample fibonacci numbers ([#15550], thanks @666hwll)

[#15550]: https://github.com/crystal-lang/crystal/pull/15550

### Specs

#### stdlib

- Fix invalid returns in class getter's lazy evaluation blocks ([#15364], thanks @ysbaddaden)
- _(specs)_ Add specs for `File.match?` ([#15348], thanks @straight-shoota)
- _(text)_ Add specs for `File.match?` from fast-glob ([#15604], thanks @straight-shoota)
- _(text)_ Add specs for `File.match?` with multibyte characters ([#15601], thanks @straight-shoota)

[#15364]: https://github.com/crystal-lang/crystal/pull/15364
[#15348]: https://github.com/crystal-lang/crystal/pull/15348
[#15604]: https://github.com/crystal-lang/crystal/pull/15604
[#15601]: https://github.com/crystal-lang/crystal/pull/15601

#### compiler

- _(parser)_ Add specs for block association in nested calls ([#15461], thanks @straight-shoota)

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
- _(ci)_ Fix shards packaging for mingw-w64 ([#15451], thanks @straight-shoota)
- _(ci)_ Add workflow for backporting PRs to release branches ([#15372], [#15378], thanks @straight-shoota)
- _(ci)_ Update cygwin/cygwin-install-action action to v5 ([#15346], thanks @renovate)
- _(ci)_ Extract forward compatibility checks and run on nightly schedule ([#15437], thanks @straight-shoota)
- _(ci)_ Use MSYS2 Crystal package for `mingw-w64` workflow ([#15453], [#15476], thanks @HertzDevil, @straight-shoota)
- _(ci)_ Filter runs of LLVM Test workflow ([#15458], thanks @straight-shoota)
- _(ci)_ Filter runs of regex engine workflow ([#15460], thanks @straight-shoota)
- _(ci)_ Filter runs of OpenSSL Test workflow ([#15459], thanks @straight-shoota)
- _(ci)_ Filter runs of Smoke Test workflow ([#15457], thanks @straight-shoota)
- _(ci)_ Introduce actionlint to lint GitHub Actions workflows ([#15449], thanks @straight-shoota)
- _(ci)_ Fix MinGW-W64 workflow to run compiler tests with fresh compiler ([#15522], thanks @straight-shoota)
- _(ci)_ Update GH Actions ([#15525], thanks @renovate)
- _(ci)_ Update GH Actions ([#15551], thanks @renovate)
- _(ci)_ Update library versions for MSVC CI ([#15554], thanks @HertzDevil)
- _(ci)_ Increase memory for `aarch64-*-test-compiler` runners to 16GB ([#15572], thanks @straight-shoota)
- _(ci)_ Add AArch64 Linux workflow using GitHub's runner ([#15600], thanks @HertzDevil)

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

## Previous Releases

For information on prior releases, refer to their changelogs:

* [1.0 to 1.15](https://github.com/crystal-lang/crystal/blob/release/1.15/CHANGELOG.md)
* [before 1.0](https://github.com/crystal-lang/crystal/blob/release/0.36/CHANGELOG.md)
