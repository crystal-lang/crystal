## [1.17.0] (2025-07-16)

_Feature freeze: 2025-07-02_

[1.17.0]: https://github.com/crystal-lang/crystal/releases/1.17.0

### Breaking changes

#### stdlib

- Make `Colorize.on_tty_only!` the default behavior ([#15881], thanks @HertzDevil)
- *(files)* Fix: set `IO::Stapled.pipe` blocking args to nil, as per `IO.pipe` ([#15925], thanks @ysbaddaden)
- *(files)* Refactor `IO.pipe` blocking mode ([#15823], thanks @ysbaddaden)
- *(networking)* Refactor `Socket` blocking mode ([#15804], thanks @ysbaddaden)
- *(serialization)* Fix: libxml manual memory management ([#15906], thanks @ysbaddaden)
- *(system)* Turn `SystemError.from_errno` into a macro ([#15874], thanks @straight-shoota)

[#15881]: https://github.com/crystal-lang/crystal/pull/15881
[#15925]: https://github.com/crystal-lang/crystal/pull/15925
[#15823]: https://github.com/crystal-lang/crystal/pull/15823
[#15804]: https://github.com/crystal-lang/crystal/pull/15804
[#15906]: https://github.com/crystal-lang/crystal/pull/15906
[#15874]: https://github.com/crystal-lang/crystal/pull/15874

### Features

#### lang

- *(macros)* Support `{% elsif %}` when stringifying `MacroIf` nodes ([#15928], thanks @HertzDevil)
- *(macros)* Handle properly stringifying single line blocks ([#15568], thanks @Blacksmoke16)
- *(macros)* Handle properly stringifying multiline named tuple literals ([#15566], thanks @Blacksmoke16)
- *(macros)* Handle properly stringifying multiline calls ([#15691], thanks @Blacksmoke16)
- *(macros)* Handle significant whitespace before a blocks body ([#15692], thanks @Blacksmoke16)
- *(macros)* Support `{% if ...; end; ... %}` macro expressions ([#15917], thanks @HertzDevil)

[#15928]: https://github.com/crystal-lang/crystal/pull/15928
[#15568]: https://github.com/crystal-lang/crystal/pull/15568
[#15566]: https://github.com/crystal-lang/crystal/pull/15566
[#15691]: https://github.com/crystal-lang/crystal/pull/15691
[#15692]: https://github.com/crystal-lang/crystal/pull/15692
[#15917]: https://github.com/crystal-lang/crystal/pull/15917

#### stdlib

- Add `Colorize.default_enabled?` ([#15912], thanks @HertzDevil)
- **[experimental]** Add `Struct.pre_initialize` ([#15896], thanks @HertzDevil)
- *(files)* Support Windows local device paths in `Path` ([#15590], thanks @HertzDevil)
- *(llvm)* Support LLVM 21.0 (development branch) ([#15771], thanks @HertzDevil)
- *(networking)* Extract `WebSocket#do_ping`, `#do_close` helper methods for overrides ([#15545], thanks @luislavena)
- *(networking)* Add support for IPv6 scoped addresses (RFC4007) ([#15263], thanks @foxxx0)
- *(networking)* Expose `HTTP::Request#uri` ([#15816], thanks @syeopite)
- *(numeric)* Add `BigRational#to_i` ([#15809], thanks @HertzDevil)
- *(numeric)* Add `Float::Primitive#sign_bit` ([#15830], thanks @HertzDevil)
- *(runtime)* Add explicit `Crystal::EventLoop#reopened(FileDescriptor)` hook ([#15640], thanks @ysbaddaden)
- *(runtime)* Add `Crystal::EventLoop::FileDescriptor#open` ([#15750], thanks @ysbaddaden)
- *(serialization)* Add `XML.libxml2_version` ([#15623], thanks @straight-shoota)
- *(serialization)* Add `YAML::Builder#start_document(*, implicit_start_indicator)` ([#15835], thanks @straight-shoota)
- *(serialization)* Support pretty printing of `XML` types ([#15833], thanks @HertzDevil)
- *(serialization)* Expose error message from libyaml on emitter errors ([#15841], thanks @straight-shoota)
- *(serialization)* Add `Path.from_json_object_key` ([#15877], thanks @jneen)
- *(text)* **[experimental]** Add `Crystal::System.wstr_literal` on Windows ([#15747], thanks @HertzDevil)
- *(text)* Add `String#ensure_suffix` and `String#ensure_prefix` ([#15782], thanks @MatheusRich)
- *(text)* Add `truncate_at_null` parameter to `String.new(Bytes)` and `.from_utf16` ([#15887], thanks @HertzDevil)
- *(time)* Add `Time.month_week_date` ([#15620], thanks @HertzDevil)
- *(time)* Improve the TZif database file parser ([#15825], thanks @HertzDevil)
- *(time)* Support POSIX TZ environment variable strings ([#15792], thanks @HertzDevil)
- *(time)* Improve whitespace handling in `Time::Format` ([#15890], thanks @HertzDevil)
- *(time)* Support Windows system time zone transitions in all years ([#15891], thanks @HertzDevil)
- *(time)* Support POSIX TZ strings in TZif databases ([#15863], thanks @HertzDevil)

[#15912]: https://github.com/crystal-lang/crystal/pull/15912
[#15896]: https://github.com/crystal-lang/crystal/pull/15896
[#15590]: https://github.com/crystal-lang/crystal/pull/15590
[#15771]: https://github.com/crystal-lang/crystal/pull/15771
[#15545]: https://github.com/crystal-lang/crystal/pull/15545
[#15263]: https://github.com/crystal-lang/crystal/pull/15263
[#15816]: https://github.com/crystal-lang/crystal/pull/15816
[#15809]: https://github.com/crystal-lang/crystal/pull/15809
[#15830]: https://github.com/crystal-lang/crystal/pull/15830
[#15640]: https://github.com/crystal-lang/crystal/pull/15640
[#15750]: https://github.com/crystal-lang/crystal/pull/15750
[#15623]: https://github.com/crystal-lang/crystal/pull/15623
[#15835]: https://github.com/crystal-lang/crystal/pull/15835
[#15833]: https://github.com/crystal-lang/crystal/pull/15833
[#15841]: https://github.com/crystal-lang/crystal/pull/15841
[#15877]: https://github.com/crystal-lang/crystal/pull/15877
[#15747]: https://github.com/crystal-lang/crystal/pull/15747
[#15782]: https://github.com/crystal-lang/crystal/pull/15782
[#15887]: https://github.com/crystal-lang/crystal/pull/15887
[#15620]: https://github.com/crystal-lang/crystal/pull/15620
[#15825]: https://github.com/crystal-lang/crystal/pull/15825
[#15792]: https://github.com/crystal-lang/crystal/pull/15792
[#15890]: https://github.com/crystal-lang/crystal/pull/15890
[#15891]: https://github.com/crystal-lang/crystal/pull/15891
[#15863]: https://github.com/crystal-lang/crystal/pull/15863

#### compiler

- *(cli)* Support `--x86-asm-syntax` for emitting Intel style assembly ([#15612], thanks @HertzDevil)
- *(debugger)* Support debug info of 128-bit enum members ([#15770], thanks @HertzDevil)
- *(parser)* More robust trailing expressions newline implementation ([#15614], thanks @Blacksmoke16)
- *(parser)* Handle properly stringifying multiline (boolean) expressions ([#15709], thanks @Blacksmoke16)
- *(parser)* Stringify `MacroIf` `unless` nodes properly ([#15919], thanks @HertzDevil)
- *(parser)* Support `elsif` when stringifying `If` nodes ([#15918], thanks @HertzDevil)
- *(semantic)* Improve error message for `pointerof` ([#15876], thanks @straight-shoota)

[#15612]: https://github.com/crystal-lang/crystal/pull/15612
[#15770]: https://github.com/crystal-lang/crystal/pull/15770
[#15614]: https://github.com/crystal-lang/crystal/pull/15614
[#15709]: https://github.com/crystal-lang/crystal/pull/15709
[#15919]: https://github.com/crystal-lang/crystal/pull/15919
[#15918]: https://github.com/crystal-lang/crystal/pull/15918
[#15876]: https://github.com/crystal-lang/crystal/pull/15876

#### tools

- Macro code coverage tool ([#15738], thanks @Blacksmoke16)
- *(docs-generator)* Limit paragraph `max-width` in API docs ([#15672], thanks @straight-shoota)

[#15738]: https://github.com/crystal-lang/crystal/pull/15738
[#15672]: https://github.com/crystal-lang/crystal/pull/15672

### Bugfixes

#### lang

- **[experimental]** Do not use private linkage for slice literal buffers ([#15746], thanks @HertzDevil)

[#15746]: https://github.com/crystal-lang/crystal/pull/15746

#### stdlib

- Require `NO_COLOR` to be non-empty ([#15880], thanks @HertzDevil)
- *(benchmark)* Use `UInt64` to track iteration count during warm-up calculation in `Benchmark::IPS` ([#15780], thanks @syeopite)
- *(collection)* Fix `Array#|` for different item types ([#15756], thanks @straight-shoota)
- *(concurrency)* Fix calling `Fiber::ExecutionContext#enqueue` from bare `Thread` ([#15767], thanks @ysbaddaden)
- *(concurrency)* Simplify `Crystal::System::Fiber::RESERVED_STACK_SIZE` initializer on Windows ([#15820], thanks @HertzDevil)
- *(concurrency)* Do not print adjacent nodes in `Thread::LinkedList#inspect` ([#15829], thanks @HertzDevil)
- *(files)* Fix async append to file in IOCP ([#15681], thanks @ysbaddaden)
- *(numeric)* **[regression]** Fix `BigFloat#format` not compiling ([#15796], thanks @HertzDevil)
- *(numeric)* Never output exponent in `BigDecimal#format` ([#15795], thanks @HertzDevil)
- *(numeric)* Preserve precision when passing `BigDecimal` or `BigFloat` to `sprintf` `%i` ([#15808], thanks @HertzDevil)
- *(numeric)* Fix `Float32#abs` for signed zeros ([#15814], thanks @HertzDevil)
- *(numeric)* Ensure unary `Float32#-` and `Float64#-` flip sign bit ([#15857], thanks @HertzDevil)
- *(runtime)* reopen async `File` passed to `Process.exec` and `.run` (win32) ([#15703], thanks @ysbaddaden)
- *(runtime)* raise on manual fiber resume from sleep ([#15744], thanks @ysbaddaden)
- *(runtime)* race condition in `Fiber::ExecutionContext::Isolated#wait` ([#15872], thanks @ysbaddaden)
- *(runtime)* Prevent leaking memory when `exec_recursive`'s block raises ([#15893], thanks @straight-shoota)
- *(runtime)* thread specs must test `Thread`, not `Fiber::ExecutionContext::Isolated` ([#15909], thanks @ysbaddaden)
- *(system)* Fix `Path#relative_to` for non-normalized anchor ([#15737], thanks @straight-shoota)
- *(system)* **[regression]** Skip `src/termios.cr` on Windows ([#15852], thanks @HertzDevil)
- *(system)* Suspend Windows processes until job objects are set up ([#15850], thanks @HertzDevil)
- *(time)* Fix `Time::Location::InvalidTZDataError` dropping default message ([#15824], thanks @HertzDevil)
- *(time)* Fix IANA time zone names for Windows system time zones ([#15914], thanks @HertzDevil)

[#15880]: https://github.com/crystal-lang/crystal/pull/15880
[#15780]: https://github.com/crystal-lang/crystal/pull/15780
[#15756]: https://github.com/crystal-lang/crystal/pull/15756
[#15767]: https://github.com/crystal-lang/crystal/pull/15767
[#15820]: https://github.com/crystal-lang/crystal/pull/15820
[#15829]: https://github.com/crystal-lang/crystal/pull/15829
[#15681]: https://github.com/crystal-lang/crystal/pull/15681
[#15796]: https://github.com/crystal-lang/crystal/pull/15796
[#15795]: https://github.com/crystal-lang/crystal/pull/15795
[#15808]: https://github.com/crystal-lang/crystal/pull/15808
[#15814]: https://github.com/crystal-lang/crystal/pull/15814
[#15857]: https://github.com/crystal-lang/crystal/pull/15857
[#15703]: https://github.com/crystal-lang/crystal/pull/15703
[#15744]: https://github.com/crystal-lang/crystal/pull/15744
[#15872]: https://github.com/crystal-lang/crystal/pull/15872
[#15893]: https://github.com/crystal-lang/crystal/pull/15893
[#15909]: https://github.com/crystal-lang/crystal/pull/15909
[#15737]: https://github.com/crystal-lang/crystal/pull/15737
[#15852]: https://github.com/crystal-lang/crystal/pull/15852
[#15850]: https://github.com/crystal-lang/crystal/pull/15850
[#15824]: https://github.com/crystal-lang/crystal/pull/15824
[#15914]: https://github.com/crystal-lang/crystal/pull/15914

#### compiler

- *(codegen)* Add file name to file-private virtual types during codegen ([#15897], thanks @HertzDevil)
- *(interpreter)* Fix interpreter guard clauses for signal handling ([#15892], thanks @straight-shoota)
- *(parser)* Add end locations for `Case`, `Asm`, and `Select` ([#15452], thanks @FnControlOption)
- *(parser)* **[regression]** Fix stringification of `Not` as call receiver ([#15801], thanks @Blacksmoke16)
- *(semantic)* Fix cleanup of one-to-many assignment with untyped RHS ([#15755], thanks @HertzDevil)
- *(semantic)* Do not consider type in `Crystal::Var#==` ([#15884], thanks @HertzDevil)

[#15897]: https://github.com/crystal-lang/crystal/pull/15897
[#15892]: https://github.com/crystal-lang/crystal/pull/15892
[#15452]: https://github.com/crystal-lang/crystal/pull/15452
[#15801]: https://github.com/crystal-lang/crystal/pull/15801
[#15755]: https://github.com/crystal-lang/crystal/pull/15755
[#15884]: https://github.com/crystal-lang/crystal/pull/15884

#### tools

- *(docs-generator)* Handle doc locations when file is in parent directory ([#15898], thanks @Blacksmoke16)

[#15898]: https://github.com/crystal-lang/crystal/pull/15898

### Chores

#### stdlib

- **[breaking]** Make `Enum.from_value` raise `ArgumentError` instead of `Exception` ([#15624], thanks @HertzDevil)
- Fix duplicate keys in hash literals ([#15843], thanks @straight-shoota)
- Remove unused code ([#15845], thanks @straight-shoota)
- Remove shadowed method arguments ([#15846], thanks @straight-shoota)
- Replace some `not_nil!` calls with bang methods ([#15847], thanks @straight-shoota)
- Use `be_nil` and `be_true`/`be_false` everywhere in specs ([#15867], thanks @straight-shoota)
- Remove trailing whitespace ([#15869], thanks @straight-shoota)
- Add trailing newlines ([#15870], thanks @straight-shoota)
- *(collection)* Replace literal conditions with nilable casts ([#15844], thanks @straight-shoota)
- *(time)* Update Windows zone names ([#15728], thanks @straight-shoota)
- *(time)* Update Windows zone names using local database ([#15837], thanks @HertzDevil)

[#15624]: https://github.com/crystal-lang/crystal/pull/15624
[#15843]: https://github.com/crystal-lang/crystal/pull/15843
[#15845]: https://github.com/crystal-lang/crystal/pull/15845
[#15846]: https://github.com/crystal-lang/crystal/pull/15846
[#15847]: https://github.com/crystal-lang/crystal/pull/15847
[#15867]: https://github.com/crystal-lang/crystal/pull/15867
[#15869]: https://github.com/crystal-lang/crystal/pull/15869
[#15870]: https://github.com/crystal-lang/crystal/pull/15870
[#15844]: https://github.com/crystal-lang/crystal/pull/15844
[#15728]: https://github.com/crystal-lang/crystal/pull/15728
[#15837]: https://github.com/crystal-lang/crystal/pull/15837

#### compiler

- Replace `is_a?` calls with convenient alternatives ([#15860], thanks @straight-shoota)

[#15860]: https://github.com/crystal-lang/crystal/pull/15860

#### other

- Remove useless condition literal ([#15859], thanks @straight-shoota)
- Fix typos and add `typos` integration ([#15873], thanks @straight-shoota)

[#15859]: https://github.com/crystal-lang/crystal/pull/15859
[#15873]: https://github.com/crystal-lang/crystal/pull/15873

### Performance

#### lang

- **[experimental]** Optimize slice literal codegen on LLVM 21 ([#15803], thanks @HertzDevil)

[#15803]: https://github.com/crystal-lang/crystal/pull/15803

#### stdlib

- *(collection)* Optimize `Indexable#find` ([#15674], thanks @straight-shoota)
- *(numeric)* Add specialized implementations for `Float#infinite?` and `#nan?` ([#15813], thanks @HertzDevil)

[#15674]: https://github.com/crystal-lang/crystal/pull/15674
[#15813]: https://github.com/crystal-lang/crystal/pull/15813

#### compiler

- Apply performance improvement suggestions from ameba ([#15839], thanks @straight-shoota)
- *(codegen)* Simplify codegen of mixed-type checked integer addition and subtraction ([#15878], thanks @HertzDevil)

[#15839]: https://github.com/crystal-lang/crystal/pull/15839
[#15878]: https://github.com/crystal-lang/crystal/pull/15878

### Refactor

#### stdlib

- *(collection)* Make `offset` a required parameter in `Indexable#find` ([#15671], thanks @straight-shoota)
- *(crypto)* Add extra `Digest.update` overloads for `Bytes` ([#15736], thanks @straight-shoota)
- *(crypto)* **[experimental]** Use `Slice` literals in `Crypto::Bcrypt` ([#15781], thanks @HertzDevil)
- *(files)* Ask system to decide non-blocking `IO::FileDescriptor` (win32) ([#15753], thanks @ysbaddaden)
- *(files)* `Crystal::EventLoop::FileDescriptor#open` now sets the non/blocking flag ([#15754], thanks @ysbaddaden)
- *(networking)* Use relative requires for `http/` files ([#15675], thanks @straight-shoota)
- *(networking)* Split `StaticFileHandler#call` into structured components ([#15678], thanks @straight-shoota)
- *(numeric)* **[experimental]** Use `Slice.literal` for `fast_float` when supported ([#15667], thanks @HertzDevil)
- *(numeric)* Combine the decimal number printing implementations ([#15815], thanks @HertzDevil)
- *(runtime)* Extract bindings for LibC errno to `src/lib_c/` ([#15565], thanks @ysbaddaden)
- *(runtime)* Extract `Exception::CallStack.decode_backtrace_frame` helper ([#15615], thanks @ysbaddaden)
- *(runtime)* Let `Crystal::EventLoop#close` do the actual close (not just cleanup) ([#15641], thanks @ysbaddaden)
- *(serialization)* Replace deprecated `LibXML.xmlGcMemSetup` with `.xmlMemSetup` ([#15626], thanks @straight-shoota)
- *(serialization)* XML: modernize API when available & workaround issues with legacy versions ([#15899], thanks @ysbaddaden)
- *(specs)* Support arbitrary `IO`s in `Spec::CLI` ([#15882], thanks @HertzDevil)
- *(specs)* Replace some lookup hashes in `Spec` with exhaustive cases ([#15879], thanks @HertzDevil)
- *(text)* **[experimental]** Use slice literals for `String::CHAR_TO_DIGIT` and `CHAR_TO_DIGIT62` ([#15745], thanks @HertzDevil)
- *(text)* Replace some uses of `String#%` with justification methods ([#15821], thanks @HertzDevil)
- *(text)* Avoid calling `chars.size` on `String`s ([#15822], thanks @HertzDevil)
- *(time)* Move most POSIX TZ string functionality to a module ([#15866], thanks @HertzDevil)

[#15671]: https://github.com/crystal-lang/crystal/pull/15671
[#15736]: https://github.com/crystal-lang/crystal/pull/15736
[#15781]: https://github.com/crystal-lang/crystal/pull/15781
[#15753]: https://github.com/crystal-lang/crystal/pull/15753
[#15754]: https://github.com/crystal-lang/crystal/pull/15754
[#15675]: https://github.com/crystal-lang/crystal/pull/15675
[#15678]: https://github.com/crystal-lang/crystal/pull/15678
[#15667]: https://github.com/crystal-lang/crystal/pull/15667
[#15815]: https://github.com/crystal-lang/crystal/pull/15815
[#15565]: https://github.com/crystal-lang/crystal/pull/15565
[#15615]: https://github.com/crystal-lang/crystal/pull/15615
[#15641]: https://github.com/crystal-lang/crystal/pull/15641
[#15626]: https://github.com/crystal-lang/crystal/pull/15626
[#15899]: https://github.com/crystal-lang/crystal/pull/15899
[#15882]: https://github.com/crystal-lang/crystal/pull/15882
[#15879]: https://github.com/crystal-lang/crystal/pull/15879
[#15745]: https://github.com/crystal-lang/crystal/pull/15745
[#15821]: https://github.com/crystal-lang/crystal/pull/15821
[#15822]: https://github.com/crystal-lang/crystal/pull/15822
[#15866]: https://github.com/crystal-lang/crystal/pull/15866

### Documentation

#### stdlib

- *(crypto)* Add type restrictions to `Digest` ([#15696], thanks @Vici37)
- *(macros)* **[experimental]** Document `Crystal::Macros::StringLiteral#to_utf16` ([#15748], thanks @HertzDevil)
- *(runtime)* Document `GC::Stats` properties ([#15676], thanks @ysbaddaden)
- *(runtime)* Add links to language specification in docs for pseudo methods ([#15864], thanks @straight-shoota)
- *(serialization)* Add type restrictions to `CSV` ([#15695], thanks @Vici37)
- *(system)* Add type restrictions to `Dir` ([#15697], thanks @Vici37)
- *(text)* Improve docs for `String#lines` and `#each_line` ([#15894], thanks @straight-shoota)

[#15696]: https://github.com/crystal-lang/crystal/pull/15696
[#15748]: https://github.com/crystal-lang/crystal/pull/15748
[#15676]: https://github.com/crystal-lang/crystal/pull/15676
[#15864]: https://github.com/crystal-lang/crystal/pull/15864
[#15695]: https://github.com/crystal-lang/crystal/pull/15695
[#15697]: https://github.com/crystal-lang/crystal/pull/15697
[#15894]: https://github.com/crystal-lang/crystal/pull/15894

#### compiler

- *(parser)* Improve examples for the syntax highlighter documentation ([#15699], thanks @tamdaz)

[#15699]: https://github.com/crystal-lang/crystal/pull/15699

### Specs

#### stdlib

- Drop `to_a` in expectations with `Slice` ([#15735], thanks @straight-shoota)
- *(crypto)* Unroll test data in specs for `crypto/subtle` ([#15702], thanks @straight-shoota)
- *(networking)* Add test for `HTTP::Request` with resource string `//` ([#15546], thanks @miry)
- *(networking)* Pick TCP and UDP local ports differently in socket specs ([#15828], thanks @HertzDevil)
- *(text)* Simplify specs for string comparison ([#15868], thanks @straight-shoota)

[#15735]: https://github.com/crystal-lang/crystal/pull/15735
[#15702]: https://github.com/crystal-lang/crystal/pull/15702
[#15546]: https://github.com/crystal-lang/crystal/pull/15546
[#15828]: https://github.com/crystal-lang/crystal/pull/15828
[#15868]: https://github.com/crystal-lang/crystal/pull/15868

#### compiler

- *(interpreter)* Enable interpreter integration test for XML ([#15628], thanks @straight-shoota)
- *(parser)* Cleanup parser specs ([#15446], thanks @FnControlOption)

[#15628]: https://github.com/crystal-lang/crystal/pull/15628
[#15446]: https://github.com/crystal-lang/crystal/pull/15446

#### tools

- *(formatter)* Fix formatter specs with string interpolation ([#15842], thanks @straight-shoota)

[#15842]: https://github.com/crystal-lang/crystal/pull/15842

### Infrastructure

- Changelog for 1.17.0 ([#15900], thanks @straight-shoota)
- Update previous Crystal release 1.16.1 ([#15649], thanks @straight-shoota)
- Update `release-update` script: Truncate CHANGELOG ([#15679], thanks @straight-shoota)
- Merge `release/1.16` into master ([#15729], thanks @straight-shoota)
- Simplify `docs_main.cr` ([#15621], thanks @straight-shoota)
- Update previous Crystal release 1.16.2 ([#15730], thanks @straight-shoota)
- Fix order of title clean steps in github-changelog helper ([#15727], thanks @straight-shoota)
- Fix `scripts/release-update.sh` idempotent previous CHANGELOG entry ([#15731], thanks @straight-shoota)
- Merge `release/1.16`@1.16.3 into master ([#15774], thanks @straight-shoota)
- Update previous Crystal release 1.16.3 ([#15773], thanks @straight-shoota)
- Makefile: Fix target location for `install_docs` ([#15853], thanks @straight-shoota)
- Add ameba ([#15875], thanks @straight-shoota)
- Allow `LLVM_VERSION` override inside `Makefile` ([#15765], thanks @HertzDevil)
- Add build script for `spec/std/data/zoneinfo.zip` ([#15831], thanks @HertzDevil)
- *(ci)* Update GH Actions ([#15668], thanks @renovate)
- *(ci)* Drop the static LLVM libraries on Windows MSVC CI ([#15797], thanks @HertzDevil)
- *(ci)* Set up Inno Setup explicitly on MSVC CI ([#15851], [#15861], thanks @HertzDevil)
- *(ci)* Update library versions for MSVC CI ([#15921], thanks @HertzDevil)
- *(ci)* Add CI workflow for MinGW-w64 ARM64 builds ([#15794], thanks @HertzDevil)
- *(ci)* **[regression]** Use `CMAKE_MSVC_RUNTIME_LIBRARY` for the MSVC PCRE2 static library ([#15802], thanks @HertzDevil)

[#15900]: https://github.com/crystal-lang/crystal/pull/15900
[#15649]: https://github.com/crystal-lang/crystal/pull/15649
[#15679]: https://github.com/crystal-lang/crystal/pull/15679
[#15729]: https://github.com/crystal-lang/crystal/pull/15729
[#15621]: https://github.com/crystal-lang/crystal/pull/15621
[#15730]: https://github.com/crystal-lang/crystal/pull/15730
[#15727]: https://github.com/crystal-lang/crystal/pull/15727
[#15731]: https://github.com/crystal-lang/crystal/pull/15731
[#15774]: https://github.com/crystal-lang/crystal/pull/15774
[#15773]: https://github.com/crystal-lang/crystal/pull/15773
[#15853]: https://github.com/crystal-lang/crystal/pull/15853
[#15875]: https://github.com/crystal-lang/crystal/pull/15875
[#15765]: https://github.com/crystal-lang/crystal/pull/15765
[#15831]: https://github.com/crystal-lang/crystal/pull/15831
[#15668]: https://github.com/crystal-lang/crystal/pull/15668
[#15797]: https://github.com/crystal-lang/crystal/pull/15797
[#15851]: https://github.com/crystal-lang/crystal/pull/15851
[#15861]: https://github.com/crystal-lang/crystal/pull/15861
[#15921]: https://github.com/crystal-lang/crystal/pull/15921
[#15794]: https://github.com/crystal-lang/crystal/pull/15794
[#15802]: https://github.com/crystal-lang/crystal/pull/15802

