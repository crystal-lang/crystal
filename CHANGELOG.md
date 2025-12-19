# Changelog

## [1.19.0] (2026-01-14)

[1.19.0]: https://github.com/crystal-lang/crystal/releases/1.19.0

### Breaking changes

#### stdlib

- _(crypto)_ Require OpenSSL 1.1.1+ or LibreSSL 3+ ([#16480], thanks @ysbaddaden)

[#16480]: https://github.com/crystal-lang/crystal/pull/16480

### Features

#### lang

- _(macros)_ **[breaking]** Add compiler flag values ([#16310], thanks @straight-shoota)
- _(macros)_ Add yielding variant of `StringLiteral#gsub` ([#16378], thanks @Blacksmoke16)
- _(macros)_ Support `StringLiteral#split(RegexLiteral)` ([#16423], thanks @HertzDevil)
- _(macros)_ Add `StringLiteral#match` ([#16464], thanks @HertzDevil)
- _(macros)_ Make all overloads of `ArrayLiteral#[]` return `nil` on out of bounds ([#16453], thanks @HertzDevil)

[#16310]: https://github.com/crystal-lang/crystal/pull/16310
[#16378]: https://github.com/crystal-lang/crystal/pull/16378
[#16423]: https://github.com/crystal-lang/crystal/pull/16423
[#16464]: https://github.com/crystal-lang/crystal/pull/16464
[#16453]: https://github.com/crystal-lang/crystal/pull/16453

#### stdlib

- _(collection)_ Add `NamedTuple#reverse_merge` ([#16229], thanks @andrykonchin)
- _(collection)_ Pad `Hash#inspect`, `Tuple#inspect` before `{` from first element ([#16245], thanks @andrykonchin)
- _(collection)_ Add `Set#map!` ([#16271], thanks @andrykonchin)
- _(collection)_ Add `Hash#transform_keys!` ([#16280], thanks @andrykonchin)
- _(collection)_ Enhance error message for `Hash#[]` when key is wrong type for default block ([#16442], thanks @Blacksmoke16)
- _(concurrency)_ Add `Sync::Mutex` and `Sync::RWLock` ([#16399], thanks @ysbaddaden)
- _(concurrency)_ Add `Sync::ConditionVariable` ([#16440], thanks @ysbaddaden)
- _(concurrency)_ Import `Sync::Exclusive` and `Sync::Shared` ([#16487], thanks @ysbaddaden)
- _(crypto)_ Add `OpenSSL::SSL::Context::Server#on_server_name` for SNI ([#16452], thanks @carlhoerberg)
- _(networking)_ Loosen type restrictions in `StaticFileHandler` helper methods from `File` to `IO` ([#16238], thanks @andrykonchin)
- _(networking)_ Add `IPSocket#ipv6_only` ([#16347], thanks @stakach)
- _(numeric)_ Add `Int.from_digits` as inverse of `Int#digits` ([#16237], thanks @andrykonchin)
- _(numeric)_ Add `BigInt.from_digits` ([#16259], thanks @HertzDevil)
- _(numeric)_ Add `Int#tdivmod` ([#16258], thanks @andrykonchin)
- _(runtime)_ Protect `Box.unbox` from dereferencing null pointer ([#16514], thanks @straight-shoota)
- _(runtime)_ Add `Fiber::ExecutionContext::Scheduler.current?` ([#16521], thanks @ysbaddaden)
- _(runtime)_ Register execution context schedulers with the event loop ([#16519], thanks @ysbaddaden)
- _(runtime)_ Add `Proc#[]` as alias to `#call` ([#16220], thanks @andrykonchin)
- _(runtime)_ Add `#unshift`, `#pop` and `#pop?` to `Crystal::PointerLinkedList` ([#16287], thanks @ysbaddaden)
- _(runtime)_ Add `Random.next_bool` and `.next_int` ([#16297], thanks @ysbaddaden)
- _(runtime)_ Add `Random#split` and `#split_internal` API for splittable PRNGs ([#16342], [#16495], thanks @ysbaddaden)
- _(runtime)_ Add `Pointer#fill` ([#16338], thanks @straight-shoota)
- _(runtime)_ Add `Crystal::PointerLinkedList#first?` ([#16400], thanks @ysbaddaden)
- _(runtime)_ Ensure single reader and writer to system fd on Unix ([#16209], thanks @ysbaddaden)
- _(serialization)_ Support deserialization of YAML anchors of value types ([#16186], thanks @HertzDevil)
- _(serialization)_ Add end locations to scalars and aliases in `YAML::Nodes.parse` ([#16187], thanks @HertzDevil)
- _(serialization)_ Set `JSON::SerializableError#attribute` when appropriate ([#16158], thanks @spuun)
- _(serialization)_ Support large JSON files ([#16211], thanks @RX14)
- _(serialization)_ Add `YAML::Nodes.parse_all` ([#16247], thanks @HertzDevil)
- _(specs)_ Rescale execution context in spec runner with `CRYSTAL_WORKERS` ([#16444], [#16471], thanks @straight-shoota, @ysbaddaden)
- _(system)_ Add `Process.debugger_present?` for Windows and Linux ([#16248], thanks @HertzDevil)
- _(system)_ Implement `execvpe_impl` ([#16322], [#16344], thanks @straight-shoota)
- _(system)_ Add `::exit(Process::Status)` ([#16436], thanks @straight-shoota)
- _(system)_ Standardize system error codes for `File::Error` ([#16024], thanks @straight-shoota)
- _(system)_ Add `Path#relative?` ([#16473], thanks @Sija)
- _(text)_ PCRE2: use thread local for jit stack and match data ([#16175], thanks @ysbaddaden)
- _(text)_ Support 0X, 0O, 0B prefixes in string to integer conversion ([#16226], thanks @andrykonchin)
- _(text)_ Add `String#each_line` parameter `remove_empty` ([#16232], thanks @andrykonchin)
- _(time)_ **[breaking]** Adjust monotonic clocks to include suspended time with precision ([#16516], thanks @straight-shoota)
- _(time)_ Add `weeks` parameter to `Time::Span.new` ([#16208], thanks @Sija)
- _(time)_ Treat GMT as a legacy alias of UTC ([#16292], thanks @straight-shoota)
- _(time)_ Add `/etc/zoneinfo` to zoneinfo lookup paths ([#16463], thanks @straight-shoota)
- _(time)_ Add support for `$TZDIR` ([#16466], thanks @straight-shoota)
- _(time)_ Add `Time::Instant` ([#16490], thanks @straight-shoota)

[#16229]: https://github.com/crystal-lang/crystal/pull/16229
[#16245]: https://github.com/crystal-lang/crystal/pull/16245
[#16271]: https://github.com/crystal-lang/crystal/pull/16271
[#16280]: https://github.com/crystal-lang/crystal/pull/16280
[#16442]: https://github.com/crystal-lang/crystal/pull/16442
[#16399]: https://github.com/crystal-lang/crystal/pull/16399
[#16440]: https://github.com/crystal-lang/crystal/pull/16440
[#16487]: https://github.com/crystal-lang/crystal/pull/16487
[#16452]: https://github.com/crystal-lang/crystal/pull/16452
[#16238]: https://github.com/crystal-lang/crystal/pull/16238
[#16347]: https://github.com/crystal-lang/crystal/pull/16347
[#16237]: https://github.com/crystal-lang/crystal/pull/16237
[#16259]: https://github.com/crystal-lang/crystal/pull/16259
[#16258]: https://github.com/crystal-lang/crystal/pull/16258
[#16514]: https://github.com/crystal-lang/crystal/pull/16514
[#16521]: https://github.com/crystal-lang/crystal/pull/16521
[#16519]: https://github.com/crystal-lang/crystal/pull/16519
[#16220]: https://github.com/crystal-lang/crystal/pull/16220
[#16287]: https://github.com/crystal-lang/crystal/pull/16287
[#16297]: https://github.com/crystal-lang/crystal/pull/16297
[#16342]: https://github.com/crystal-lang/crystal/pull/16342
[#16495]: https://github.com/crystal-lang/crystal/pull/16495
[#16338]: https://github.com/crystal-lang/crystal/pull/16338
[#16400]: https://github.com/crystal-lang/crystal/pull/16400
[#16209]: https://github.com/crystal-lang/crystal/pull/16209
[#16186]: https://github.com/crystal-lang/crystal/pull/16186
[#16187]: https://github.com/crystal-lang/crystal/pull/16187
[#16158]: https://github.com/crystal-lang/crystal/pull/16158
[#16211]: https://github.com/crystal-lang/crystal/pull/16211
[#16247]: https://github.com/crystal-lang/crystal/pull/16247
[#16444]: https://github.com/crystal-lang/crystal/pull/16444
[#16471]: https://github.com/crystal-lang/crystal/pull/16471
[#16248]: https://github.com/crystal-lang/crystal/pull/16248
[#16322]: https://github.com/crystal-lang/crystal/pull/16322
[#16344]: https://github.com/crystal-lang/crystal/pull/16344
[#16436]: https://github.com/crystal-lang/crystal/pull/16436
[#16024]: https://github.com/crystal-lang/crystal/pull/16024
[#16473]: https://github.com/crystal-lang/crystal/pull/16473
[#16175]: https://github.com/crystal-lang/crystal/pull/16175
[#16226]: https://github.com/crystal-lang/crystal/pull/16226
[#16232]: https://github.com/crystal-lang/crystal/pull/16232
[#16516]: https://github.com/crystal-lang/crystal/pull/16516
[#16208]: https://github.com/crystal-lang/crystal/pull/16208
[#16292]: https://github.com/crystal-lang/crystal/pull/16292
[#16463]: https://github.com/crystal-lang/crystal/pull/16463
[#16466]: https://github.com/crystal-lang/crystal/pull/16466
[#16490]: https://github.com/crystal-lang/crystal/pull/16490

#### compiler

- _(codegen)_ Build compiler with `-Dexecution_context` ([#16447], [#16502], thanks @ysbaddaden, @straight-shoota)
- _(interpreter)_ Support `->LibX.fun_name` in the interpreter ([#16194], thanks @ysbaddaden)
- _(semantic)_ Add error message to `CrystalPath::NotFoundError` ([#16365], thanks @willhbr)
- _(semantic)_ Retain original location for errors in `included`, `extended` hooks ([#13261], thanks @Blacksmoke16)

[#16447]: https://github.com/crystal-lang/crystal/pull/16447
[#16502]: https://github.com/crystal-lang/crystal/pull/16502
[#16194]: https://github.com/crystal-lang/crystal/pull/16194
[#16365]: https://github.com/crystal-lang/crystal/pull/16365
[#13261]: https://github.com/crystal-lang/crystal/pull/13261

#### tools

- _(docs-generator)_ Add optional sanitizer to docs generator ([#14646], [#16251], thanks @nobodywasishere, @straight-shoota)

[#14646]: https://github.com/crystal-lang/crystal/pull/14646
[#16251]: https://github.com/crystal-lang/crystal/pull/16251

### Bugfixes

#### lang

- _(macros)_ Fix nested sigil delimiter parsing inside macros ([#16266], thanks @HertzDevil)

[#16266]: https://github.com/crystal-lang/crystal/pull/16266

#### stdlib

- Fix `OptionParser` subcommand help to respect custom `summary_indent` ([#16334], thanks @kojix2)
- _(collection)_ Fix `Hash` methods to retain `compare_by_identity` flag ([#16356], thanks @andrykonchin)
- _(collection)_ Fix Hash methods and retaining default value ([#16374], thanks @andrykonchin)
- _(files)_ Fix condition for no-op `lock_write` to work without sockets ([#16304], thanks @straight-shoota)
- _(networking)_ Fix `HTTP::Cookie` parsing trailing semicolons ([#16328], thanks @alexkutsan)
- _(runtime)_ Add thread safety to default random ([#16174], thanks @ysbaddaden)
- _(runtime)_ default execution context is `Parallel` ([#16367], thanks @ysbaddaden)
- _(runtime)_ `Crystal::PointerLinkedList#each` stops iterating when deleting head ([#16401], thanks @ysbaddaden)
- _(runtime)_ closing system fd is thread unsafe ([#16289], thanks @ysbaddaden)
- _(runtime)_ `Crystal::System::Process#rwlock` with Crystal < 1.7 (UNIX) ([#16482], thanks @ysbaddaden)
- _(runtime)_ urandom initialization isn't thread safe + refactor ([#16479], thanks @ysbaddaden)
- _(runtime)_ execution context queue stress tests failures ([#16472], thanks @ysbaddaden)
- _(runtime)_ don't use `Time.monotonic` in `Fiber::ExecutionContext::Monitor` ([#16500], thanks @ysbaddaden)
- _(runtime)_ thread safety of `Exception::Callstack` ([#16504], thanks @ysbaddaden)
- _(serialization)_ memory leak in `XML.parse` and `XML.parse_html` methods ([#16414], thanks @ysbaddaden)
- _(serialization)_ memory leak in `XML::Document#finalize` ([#16418], thanks @toddsundsted)
- _(serialization)_ memory leak in `XML::Node#content=` ([#16419], thanks @toddsundsted)
- _(serialization)_ Fix use after unlink in `XML::Node` ([#16432], thanks @toddsundsted)
- _(specs)_ Resolve inconsistent use of `#inspect` in `expect_raises` ([#16265], [#16375], thanks @andrykonchin, @straight-shoota)
- _(system)_ Create `argv` before `fork` ([#16286], [#16321], thanks @straight-shoota)
- _(system)_ Pass `envp` to `execvpe` ([#16340], thanks @straight-shoota)
- _(system)_ Move `make_envp` before `fork` ([#16351], thanks @straight-shoota)
- _(system)_ Replace `Dir.cd` with a non-raising alternative in pre-exec ([#16352], [#16369], thanks @straight-shoota)
- _(system)_ Fix reset directory if `Process.exec` fails ([#16383], thanks @straight-shoota)
- _(system)_ Fix reorder `Process.lock_write` outside of `.block_signals` ([#16465], thanks @straight-shoota)
- _(system)_ Disable process cancellation during `fork` ([#16446], thanks @straight-shoota)

[#16334]: https://github.com/crystal-lang/crystal/pull/16334
[#16356]: https://github.com/crystal-lang/crystal/pull/16356
[#16374]: https://github.com/crystal-lang/crystal/pull/16374
[#16304]: https://github.com/crystal-lang/crystal/pull/16304
[#16328]: https://github.com/crystal-lang/crystal/pull/16328
[#16174]: https://github.com/crystal-lang/crystal/pull/16174
[#16367]: https://github.com/crystal-lang/crystal/pull/16367
[#16401]: https://github.com/crystal-lang/crystal/pull/16401
[#16289]: https://github.com/crystal-lang/crystal/pull/16289
[#16482]: https://github.com/crystal-lang/crystal/pull/16482
[#16479]: https://github.com/crystal-lang/crystal/pull/16479
[#16472]: https://github.com/crystal-lang/crystal/pull/16472
[#16500]: https://github.com/crystal-lang/crystal/pull/16500
[#16504]: https://github.com/crystal-lang/crystal/pull/16504
[#16414]: https://github.com/crystal-lang/crystal/pull/16414
[#16418]: https://github.com/crystal-lang/crystal/pull/16418
[#16419]: https://github.com/crystal-lang/crystal/pull/16419
[#16432]: https://github.com/crystal-lang/crystal/pull/16432
[#16265]: https://github.com/crystal-lang/crystal/pull/16265
[#16375]: https://github.com/crystal-lang/crystal/pull/16375
[#16286]: https://github.com/crystal-lang/crystal/pull/16286
[#16321]: https://github.com/crystal-lang/crystal/pull/16321
[#16340]: https://github.com/crystal-lang/crystal/pull/16340
[#16351]: https://github.com/crystal-lang/crystal/pull/16351
[#16352]: https://github.com/crystal-lang/crystal/pull/16352
[#16369]: https://github.com/crystal-lang/crystal/pull/16369
[#16383]: https://github.com/crystal-lang/crystal/pull/16383
[#16465]: https://github.com/crystal-lang/crystal/pull/16465
[#16446]: https://github.com/crystal-lang/crystal/pull/16446

#### compiler

- _(cli)_ chore: correct progress step count to 14 ([#16269], thanks @miry)
- _(codegen)_ Fix System V ABI for arrays of packed structs with misaligned fields ([#16314], thanks @HertzDevil)
- _(debugger)_ Fix debug info for closured variables ([#16393], thanks @HertzDevil)
- _(interpreter)_ interpreter musn't reuse dead fiber stacks ([#16518], thanks @ysbaddaden)
- _(interpreter)_ interpreter handles `self` in inlined method with arguments ([#16307], thanks @cyangle)
- _(interpreter)_ interpreter `typeof` should return concrete type ([#16379], thanks @cyangle)
- _(interpreter)_ Fix variable shadowing bug in interpreter ([#16335], thanks @cyangle)
- _(parser)_ Fix internal error if multi-assign RHS has splats ([#16182], thanks @HertzDevil)
- _(parser)_ Fix regex delimiter detection in syntax highlighter ([#16394], thanks @HertzDevil)
- _(parser)_ Merge adjacent StringLiterals before yielding ([#16427], thanks @Blacksmoke16)
- _(semantic)_ Fix instantiation of abstract generic structs in virtual type lookup ([#16513], thanks @Blacksmoke16)
- _(semantic)_ Fix variables assigned inside `&&` conditions with method calls incorrectly got `Nil` added to their type ([#16512], thanks @Blacksmoke16)

[#16269]: https://github.com/crystal-lang/crystal/pull/16269
[#16314]: https://github.com/crystal-lang/crystal/pull/16314
[#16393]: https://github.com/crystal-lang/crystal/pull/16393
[#16518]: https://github.com/crystal-lang/crystal/pull/16518
[#16307]: https://github.com/crystal-lang/crystal/pull/16307
[#16379]: https://github.com/crystal-lang/crystal/pull/16379
[#16335]: https://github.com/crystal-lang/crystal/pull/16335
[#16182]: https://github.com/crystal-lang/crystal/pull/16182
[#16394]: https://github.com/crystal-lang/crystal/pull/16394
[#16427]: https://github.com/crystal-lang/crystal/pull/16427
[#16513]: https://github.com/crystal-lang/crystal/pull/16513
[#16512]: https://github.com/crystal-lang/crystal/pull/16512

#### tools

- _(docs-generator)_ Fix doc generation when nesting multiple `:inherit:` directives ([#16443], thanks @Blacksmoke16)
- _(formatter)_ Fix incorrect formatting of multi-line macro expression with comment as first line ([#16429], thanks @Blacksmoke16)
- _(formatter)_ Add multi-line formatting support to `Generic` formatter visitor ([#16430], thanks @Blacksmoke16)

[#16443]: https://github.com/crystal-lang/crystal/pull/16443
[#16429]: https://github.com/crystal-lang/crystal/pull/16429
[#16430]: https://github.com/crystal-lang/crystal/pull/16430

### Chores

#### lang

- _(macros)_ **[deprecation]** Deprecate single-letter macro fresh variables with indices ([#16267], thanks @HertzDevil)
- _(macros)_ **[deprecation]** Deprecate macro fresh variables with constant names ([#16293], thanks @HertzDevil)

[#16267]: https://github.com/crystal-lang/crystal/pull/16267
[#16293]: https://github.com/crystal-lang/crystal/pull/16293

#### stdlib

- _(macros)_ **[deprecation]** Deprecate `StringLiteral#split(ASTNode)` for non-separator arguments ([#16439], thanks @HertzDevil)
- _(time)_ **[deprecation]** Deprecate `Time#inspect(io, *, with_nanoseconds)` ([#16416], thanks @straight-shoota)

[#16439]: https://github.com/crystal-lang/crystal/pull/16439
[#16416]: https://github.com/crystal-lang/crystal/pull/16416

#### compiler

- _(cli)_ Error when trying to build aarch64 with LLVM 12 and below ([#15018], thanks @straight-shoota)

[#15018]: https://github.com/crystal-lang/crystal/pull/15018

### Performance

#### stdlib

- Avoid calling `times.map` ([#16422], thanks @HertzDevil)
- _(runtime)_ Skip initialization of `Pointer.malloc` with zero value ([#16333], thanks @straight-shoota)
- _(runtime)_ Call `Pointer.malloc(size, value)` in `Slice.new(size, value)` ([#16358], thanks @straight-shoota)

[#16422]: https://github.com/crystal-lang/crystal/pull/16422
[#16333]: https://github.com/crystal-lang/crystal/pull/16333
[#16358]: https://github.com/crystal-lang/crystal/pull/16358

#### compiler

- Group temporary variables by file name: splats ([#16242], thanks @HertzDevil)
- _(codegen)_ **[regression]** Only define the type name table in the main LLVM module ([#16260], thanks @HertzDevil)
- _(codegen)_ Allow closures to use atomic allocation ([#16360], thanks @HertzDevil)

[#16242]: https://github.com/crystal-lang/crystal/pull/16242
[#16260]: https://github.com/crystal-lang/crystal/pull/16260
[#16360]: https://github.com/crystal-lang/crystal/pull/16360

### Refactor

#### stdlib

- Refactor flag and value parsing into a separate method ([#16300], thanks @straight-shoota)
- _(cli)_ Refactor `OptionParser#parse` ([#16233], thanks @kojix2)
- _(cli)_ Simplify `OptionParser#handle_flag` with guard clauses ([#16309], thanks @kojix2)
- _(files)_ Fix: don't flush twice in `File#truncate` (UNIX) ([#16395], thanks @ysbaddaden)
- _(llvm)_ simplify target initialization and support more targets ([#16437], thanks @ysbaddaden)
- _(log)_ `Log::Metadata` should put parent entries first on extend (like `Hash#merge`) ([#16098], thanks @spuun)
- _(networking)_ Split `HTTP::Headers#get(Key)` into undocumented overload ([#16283], thanks @straight-shoota)
- _(networking)_ Remove internal type `OAuth::Params` ([#16319], thanks @AnandRaj2224)
- _(runtime)_ Refactor `Crystal::DWARF::LineNumbers::Sequence` ([#16214], thanks @HertzDevil)
- _(runtime)_ Extract `Crystal::EventLoop#shutdown` from `#close` ([#16288], [#16366], thanks @ysbaddaden)
- _(runtime)_ Prefer `Random::Secure.random_bytes` ([#16298], thanks @ysbaddaden)
- _(runtime)_ Set default `random` arg to `nil` instead of `Random::DEFAULT` ([#16299], thanks @ysbaddaden)
- _(runtime)_ Drop `EventLoop#after_fork_before_exec` ([#16332], thanks @straight-shoota)
- _(runtime)_ Cleanup node on `Crystal::PointerLinkedList#delete` ([#16398], thanks @ysbaddaden)
- _(runtime)_ Add `Fiber::Stack#size` ([#16420], thanks @ysbaddaden)
- _(runtime)_ Fix: `new_thread` spec helper must return isolated context (not thread) ([#16421], thanks @ysbaddaden)
- _(runtime)_ Fix: always use getrandom on Linux and Android >= 28 ([#16478], thanks @ysbaddaden)
- _(system)_ Extract `Crystal::System::Env.each_pointer` on Unix ([#16200], thanks @straight-shoota)
- _(system)_ Refactor internal `Crystal::System::Process#fork` on UNIX ([#16191], [#16373], thanks @ysbaddaden, @straight-shoota)
- _(system)_ Use `execvpe` when available ([#16294], [#16311], thanks @straight-shoota)
- _(system)_ Add `Env.make_envp` ([#16320], [#16384], thanks @straight-shoota)
- _(system)_ Fix pre-exec for closed file descriptor ([#16359], thanks @straight-shoota)
- _(system)_ Move `prepare_args` into system implementation internals ([#16362], thanks @straight-shoota)
- _(system)_ Extract `unix/spawn.cr` as a separate file ([#16388], thanks @straight-shoota)
- _(system)_ Extract internal `Process.block_signals` helper ([#16402], thanks @straight-shoota)
- _(system)_ Rename target `aarch64-android` to `aarch64-linux-android` ([#16409], thanks @straight-shoota)
- _(text)_ Simplify `String#byte_slice(Int)` and `String#byte_slice?(Int)` ([#16235], thanks @andrykonchin)
- _(time)_ Replace `Time.monotonic` with `Time.instant` [follow-up #16490] ([#16498], thanks @straight-shoota)
- _(time)_ Use `clock_gettime` on darwin ([#16492], thanks @straight-shoota)
- _(time)_ Add `Crystal::System::Time.instant` ([#16506], thanks @straight-shoota)

[#16300]: https://github.com/crystal-lang/crystal/pull/16300
[#16233]: https://github.com/crystal-lang/crystal/pull/16233
[#16309]: https://github.com/crystal-lang/crystal/pull/16309
[#16395]: https://github.com/crystal-lang/crystal/pull/16395
[#16437]: https://github.com/crystal-lang/crystal/pull/16437
[#16098]: https://github.com/crystal-lang/crystal/pull/16098
[#16283]: https://github.com/crystal-lang/crystal/pull/16283
[#16319]: https://github.com/crystal-lang/crystal/pull/16319
[#16214]: https://github.com/crystal-lang/crystal/pull/16214
[#16288]: https://github.com/crystal-lang/crystal/pull/16288
[#16366]: https://github.com/crystal-lang/crystal/pull/16366
[#16298]: https://github.com/crystal-lang/crystal/pull/16298
[#16299]: https://github.com/crystal-lang/crystal/pull/16299
[#16332]: https://github.com/crystal-lang/crystal/pull/16332
[#16398]: https://github.com/crystal-lang/crystal/pull/16398
[#16420]: https://github.com/crystal-lang/crystal/pull/16420
[#16421]: https://github.com/crystal-lang/crystal/pull/16421
[#16478]: https://github.com/crystal-lang/crystal/pull/16478
[#16200]: https://github.com/crystal-lang/crystal/pull/16200
[#16191]: https://github.com/crystal-lang/crystal/pull/16191
[#16373]: https://github.com/crystal-lang/crystal/pull/16373
[#16294]: https://github.com/crystal-lang/crystal/pull/16294
[#16311]: https://github.com/crystal-lang/crystal/pull/16311
[#16320]: https://github.com/crystal-lang/crystal/pull/16320
[#16384]: https://github.com/crystal-lang/crystal/pull/16384
[#16359]: https://github.com/crystal-lang/crystal/pull/16359
[#16362]: https://github.com/crystal-lang/crystal/pull/16362
[#16388]: https://github.com/crystal-lang/crystal/pull/16388
[#16402]: https://github.com/crystal-lang/crystal/pull/16402
[#16409]: https://github.com/crystal-lang/crystal/pull/16409
[#16235]: https://github.com/crystal-lang/crystal/pull/16235
[#16498]: https://github.com/crystal-lang/crystal/pull/16498
[#16492]: https://github.com/crystal-lang/crystal/pull/16492
[#16506]: https://github.com/crystal-lang/crystal/pull/16506

### Documentation

#### lang

- _(annotations)_ Fix `@[Deprecated]` doc comment ([#16302], thanks @jgaskins)

[#16302]: https://github.com/crystal-lang/crystal/pull/16302

#### stdlib

- _(collection)_ Clarify `Set`'s enumeration order ([#16274], thanks @HertzDevil)
- _(networking)_ Add type restrictions to `OAuth::Consumer#get_authorize_uri` ([#16285], thanks @straight-shoota)
- _(runtime)_ Use `to_slice` for presentation in `Pointer` doc examples ([#16345], thanks @straight-shoota)
- _(system)_ Add type restrictions to process ([#16065], thanks @Vici37)
- _(text)_ Document `String#split(Regex)`'s capture group behavior ([#16207], thanks @HertzDevil)
- _(text)_ Add type restrictions to regex directory ([#16066], thanks @Vici37)

[#16274]: https://github.com/crystal-lang/crystal/pull/16274
[#16285]: https://github.com/crystal-lang/crystal/pull/16285
[#16345]: https://github.com/crystal-lang/crystal/pull/16345
[#16065]: https://github.com/crystal-lang/crystal/pull/16065
[#16207]: https://github.com/crystal-lang/crystal/pull/16207
[#16066]: https://github.com/crystal-lang/crystal/pull/16066

### Specs

#### lang

- _(macros)_ Enhance specs for `flag?` macro ([#16336], thanks @straight-shoota)

[#16336]: https://github.com/crystal-lang/crystal/pull/16336

#### stdlib

- _(collection)_ Add specs for `Slice.new` ([#16424], thanks @straight-shoota)
- _(concurrency)_ Fix thread name expectation with parallel execution context ([#16517], thanks @straight-shoota)
- _(crypto)_ Fix: remove 1 second sleep in openssl/ssl/server spec ([#16454], thanks @ysbaddaden)
- _(files)_ Add specs for `IO#read_bytes` with converter ([#16250], thanks @straight-shoota)
- _(networking)_ Fix TCP specs to accept `EAI_NODATA` instead of `EAI_NONAME` for unresolvable hostname ([#16496], thanks @straight-shoota)
- _(system)_ Add specs for `Process.run` ([#16306], [#16325], thanks @straight-shoota)
- _(time)_ Update zoneinfo to TZDB version 2025c ([#16501], thanks @straight-shoota)

[#16424]: https://github.com/crystal-lang/crystal/pull/16424
[#16517]: https://github.com/crystal-lang/crystal/pull/16517
[#16454]: https://github.com/crystal-lang/crystal/pull/16454
[#16250]: https://github.com/crystal-lang/crystal/pull/16250
[#16496]: https://github.com/crystal-lang/crystal/pull/16496
[#16306]: https://github.com/crystal-lang/crystal/pull/16306
[#16325]: https://github.com/crystal-lang/crystal/pull/16325
[#16501]: https://github.com/crystal-lang/crystal/pull/16501

#### compiler

- _(semantic)_ Drop `assert_expand_second` and `assert_expand_third` helpers ([#16244], thanks @HertzDevil)

[#16244]: https://github.com/crystal-lang/crystal/pull/16244

### Infrastructure

- Changelog for 1.19.0 ([#16510], thanks @ysbaddaden)
- Update previous Crystal release 1.18.1 ([#16212], thanks @matiasgarciaisaia)
- Fix shellcheck violations ([#16221], thanks @straight-shoota)
- Fix markdownlint violations ([#16222], [#16252], thanks @straight-shoota)
- Merge `release/1.18`@`1.18.2` into `master` ([#16246], thanks @straight-shoota)
- Enable ameba rule `Lint/SpecFilename` ([#16223], thanks @straight-shoota)
- Encourage +1 reactions on issues and PRs for prioritization ([#16241], thanks @straight-shoota)
- Update previous Crystal release 1.18.2 ([#16249], thanks @straight-shoota)
- Add `devenv` ([#16263], thanks @straight-shoota)
- Add `ameba` to `git-hooks` ([#16276], [#16295], thanks @straight-shoota)
- Add `devenv` profile `lint` ([#16291], thanks @straight-shoota)
- Update distribution-scripts ([#16301], thanks @straight-shoota)
- Makefile: Extract variable `COMPILER_FLAGS` ([#16349], [#16372], thanks @straight-shoota)
- Fix `shell.nix` on Linux ([#16346], thanks @straight-shoota)
- Build compiler with `-Dpreview_mt` ([#16380], thanks @straight-shoota)
- Update `devenv.lock` ([#16386], thanks @github-actions)
- Update `devenv.lock` ([#16408], thanks @github-actions)
- Drop committed `.envrc` ([#16462], thanks @straight-shoota)
- Add git-hook to ensure changing both `Makefile` and `Makefile.win` at the same time ([#16503], thanks @straight-shoota)
- Makefile: Use simply expanded variables to avoid costly duplicate evaluation ([#16509], thanks @straight-shoota)
- Update typos 1.38.1 ([#16219], thanks @straight-shoota)
- Build snap arm64 target + drop publish_snap target ([#16491], thanks @ysbaddaden)
- _(ci)_ Update darwin jobs in circleci to `m4pro.medium` resource class ([#16389], thanks @straight-shoota)
- _(ci)_ Update xcode to 26.0.1 on circleci ([#16201], thanks @straight-shoota)
- _(ci)_ Update korthout/backport-action action to v3.4.1 ([#16215], thanks @renovate)
- _(ci)_ **[security]** Pin GitHub action uses to commit hash ([#16253], thanks @straight-shoota)
- _(ci)_ Add lint workflow running `pre-commit` ([#16275], [#16296], thanks @straight-shoota)
- _(ci)_ Fix issues in GHA workflows ([#16282], thanks @straight-shoota)
- _(ci)_ Update GH Actions ([#16290], thanks @renovate)
- _(ci)_ Update crate-ci/typos action to v1.39.0 ([#16326], thanks @renovate)
- _(ci)_ Refactor matrix configuration in Linux workflow ([#16331], thanks @straight-shoota)
- _(ci)_ Reduce smoke tests to building only `std_spec` ([#16337], thanks @straight-shoota)
- _(ci)_ Merge gnu and musl tests into a single matrix ([#16341], thanks @straight-shoota)
- _(ci)_ Fix `pull_request` trigger for `smoke` workflow ([#16343], thanks @straight-shoota)
- _(ci)_ Update GH Actions ([#16385], thanks @renovate)
- _(ci)_ Add workflow `update-devenv` ([#16387], thanks @straight-shoota)
- _(ci)_ Update GH Actions ([#16434], thanks @renovate)
- _(ci)_ Update distribution-scripts ([#16411], thanks @straight-shoota)
- _(ci)_ Run smoke tests on docker images ([#16441], thanks @straight-shoota)
- _(ci)_ Update actions/checkout digest to 8e8c483 ([#16474], thanks @renovate)
- _(ci)_ Remove `test_dist_linux_on_docker` job ([#16410], thanks @straight-shoota)
- _(ci)_ Push docker images directly to registry ([#16488], thanks @straight-shoota)
- _(ci)_ Enable multiarch docker builds ([#16493], thanks @straight-shoota)
- _(ci)_ Run multi-threading test job with execution context ([#16339], thanks @straight-shoota)
- _(ci)_ build linux aarch64 tarballs ([#16330], thanks @ysbaddaden)

[#16510]: https://github.com/crystal-lang/crystal/pull/16510
[#16212]: https://github.com/crystal-lang/crystal/pull/16212
[#16221]: https://github.com/crystal-lang/crystal/pull/16221
[#16222]: https://github.com/crystal-lang/crystal/pull/16222
[#16252]: https://github.com/crystal-lang/crystal/pull/16252
[#16246]: https://github.com/crystal-lang/crystal/pull/16246
[#16223]: https://github.com/crystal-lang/crystal/pull/16223
[#16241]: https://github.com/crystal-lang/crystal/pull/16241
[#16249]: https://github.com/crystal-lang/crystal/pull/16249
[#16263]: https://github.com/crystal-lang/crystal/pull/16263
[#16276]: https://github.com/crystal-lang/crystal/pull/16276
[#16295]: https://github.com/crystal-lang/crystal/pull/16295
[#16291]: https://github.com/crystal-lang/crystal/pull/16291
[#16301]: https://github.com/crystal-lang/crystal/pull/16301
[#16349]: https://github.com/crystal-lang/crystal/pull/16349
[#16372]: https://github.com/crystal-lang/crystal/pull/16372
[#16346]: https://github.com/crystal-lang/crystal/pull/16346
[#16380]: https://github.com/crystal-lang/crystal/pull/16380
[#16386]: https://github.com/crystal-lang/crystal/pull/16386
[#16408]: https://github.com/crystal-lang/crystal/pull/16408
[#16462]: https://github.com/crystal-lang/crystal/pull/16462
[#16503]: https://github.com/crystal-lang/crystal/pull/16503
[#16509]: https://github.com/crystal-lang/crystal/pull/16509
[#16219]: https://github.com/crystal-lang/crystal/pull/16219
[#16491]: https://github.com/crystal-lang/crystal/pull/16491
[#16389]: https://github.com/crystal-lang/crystal/pull/16389
[#16201]: https://github.com/crystal-lang/crystal/pull/16201
[#16215]: https://github.com/crystal-lang/crystal/pull/16215
[#16253]: https://github.com/crystal-lang/crystal/pull/16253
[#16275]: https://github.com/crystal-lang/crystal/pull/16275
[#16296]: https://github.com/crystal-lang/crystal/pull/16296
[#16282]: https://github.com/crystal-lang/crystal/pull/16282
[#16290]: https://github.com/crystal-lang/crystal/pull/16290
[#16326]: https://github.com/crystal-lang/crystal/pull/16326
[#16331]: https://github.com/crystal-lang/crystal/pull/16331
[#16337]: https://github.com/crystal-lang/crystal/pull/16337
[#16341]: https://github.com/crystal-lang/crystal/pull/16341
[#16343]: https://github.com/crystal-lang/crystal/pull/16343
[#16385]: https://github.com/crystal-lang/crystal/pull/16385
[#16387]: https://github.com/crystal-lang/crystal/pull/16387
[#16434]: https://github.com/crystal-lang/crystal/pull/16434
[#16411]: https://github.com/crystal-lang/crystal/pull/16411
[#16441]: https://github.com/crystal-lang/crystal/pull/16441
[#16474]: https://github.com/crystal-lang/crystal/pull/16474
[#16410]: https://github.com/crystal-lang/crystal/pull/16410
[#16488]: https://github.com/crystal-lang/crystal/pull/16488
[#16493]: https://github.com/crystal-lang/crystal/pull/16493
[#16339]: https://github.com/crystal-lang/crystal/pull/16339
[#16330]: https://github.com/crystal-lang/crystal/pull/16330

## Previous Releases

For information on prior releases, refer to their changelogs:

- [1.18](https://github.com/crystal-lang/crystal/blob/release/1.18/CHANGELOG.md)
- [1.17](https://github.com/crystal-lang/crystal/blob/release/1.17/CHANGELOG.md)
- [1.16](https://github.com/crystal-lang/crystal/blob/release/1.16/CHANGELOG.md)
- [1.0 to 1.15](https://github.com/crystal-lang/crystal/blob/release/1.15/CHANGELOG.md)
- [before 1.0](https://github.com/crystal-lang/crystal/blob/release/0.36/CHANGELOG.md)
