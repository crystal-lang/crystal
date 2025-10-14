# Changelog

## [1.18.0] (2025-10-14)

[1.18.0]: https://github.com/crystal-lang/crystal/releases/1.18.0

### Features

#### lang

- Support `ProcPointer`s of lib funs with parameter types ([#16089], thanks @HertzDevil)
- _(annotations)_ Print deprecation warning on types and aliases ([#15962], thanks @ysbaddaden)
- _(annotations)_ Print deprecation warnings on deprecated method argument ([#15999], thanks @ysbaddaden)
- _(macros)_ **[breaking]** Expand empty `(Named)TupleLiteral` to `(Named)Tuple.new` instead of `{}` ([#16108], thanks @spuun)
- _(macros)_ Add `ArrayLiteral#*`, `StringLiteral#*` and `TupleLiteral#*` ([#16154], [#16206], thanks @jneen, @ysbaddaden)

[#16089]: https://github.com/crystal-lang/crystal/pull/16089
[#15962]: https://github.com/crystal-lang/crystal/pull/15962
[#15999]: https://github.com/crystal-lang/crystal/pull/15999
[#16108]: https://github.com/crystal-lang/crystal/pull/16108
[#16154]: https://github.com/crystal-lang/crystal/pull/16154
[#16206]: https://github.com/crystal-lang/crystal/pull/16206

#### stdlib

- Add `summary_width` and `summary_indent` to `OptionParser` ([#15326], thanks @kojix2)
- _(collection)_ Add `Set#select!` and `#reject!` ([#16060], thanks @HertzDevil)
- _(concurrency)_ Speed up `Parallel::Scheduler#quick_dequeue?` for `max=1` ([#15961], thanks @ysbaddaden)
- _(concurrency)_ Default execution context is now parallel (MT:1) ([#16136], thanks @ysbaddaden)
- _(files)_ **[deprecation]** Add `.set_blocking` to `Socket` and `IO::FileDescriptor` and deprecate `#blocking` property ([#16033], [#16129], thanks @ysbaddaden)
- _(llvm)_ Support LLVM 21.1 and 22.0 ([#16062], [#16198], thanks @HertzDevil, @straight-shoota)
- _(macros)_ Add `NumberLiteral#zero?` ([#10248], thanks @Sija)
- _(macros)_ Add `thread_local` macro ([#16173], thanks @ysbaddaden)
- _(networking)_ Fix `URI#host=` to wrap IPv6 address in brackets ([#16164], thanks @stakach)
- _(runtime)_ Lazily instantiate the event loop of isolated execution contexts ([#16063], thanks @ysbaddaden)
- _(runtime)_ Add `Fiber::ExecutionContext::Parallel#resize` ([#15956], thanks @ysbaddaden)
- _(runtime)_ Add `Crystal::System.effective_cpu_count` ([#16148], thanks @ysbaddaden)
- _(runtime)_ Improve `Fiber::ExecutionContext.default_workers_count` ([#16149], thanks @ysbaddaden)
- _(serialization)_ Add `Time::Location.from_json_object_key` ([#15957], thanks @Sija)
- _(serialization)_ Resolve YAML aliases in `YAML::Any` ([#15941], thanks @willhbr)
- _(serialization)_ Embed libxml2 version number on Windows MSVC ([#16104], thanks @HertzDevil)
- _(serialization)_ Add `JSON::Any` wrapper around `JSON::Any#inspect` output ([#15979], thanks @jneen)
- _(specs)_ Add `with_tempdir` spec helper ([#16005], thanks @straight-shoota)
- _(system)_ Add `File.readlink?` ([#16004], thanks @straight-shoota)
- _(text)_ Add `SemanticVersion.valid?` & `SemanticVersion.parse?` ([#15051], thanks @devnote-dev)
- _(text)_ Add `String.additive_identity` ([#15998], thanks @straight-shoota)
- _(text)_ Use proper ANSI reset codes in `Colorize` ([#16052], thanks @Blacksmoke16)
- _(text)_ Update Unicode to 17.0.0 ([#16160], thanks @HertzDevil)
- _(time)_ Use canonical IANA name for the local Windows system time zone ([#15967], thanks @HertzDevil)
- _(time)_ Load `Location.local` by symlink name ([#16002], [#16022], thanks @straight-shoota)
- _(time)_ Add `Time::Location.load?` ([#16121], thanks @straight-shoota)
- _(time)_ Format `Time#inspect` with Internet Extended Date/Time Format ([#16039], thanks @straight-shoota)

[#15326]: https://github.com/crystal-lang/crystal/pull/15326
[#16060]: https://github.com/crystal-lang/crystal/pull/16060
[#15961]: https://github.com/crystal-lang/crystal/pull/15961
[#16136]: https://github.com/crystal-lang/crystal/pull/16136
[#16033]: https://github.com/crystal-lang/crystal/pull/16033
[#16129]: https://github.com/crystal-lang/crystal/pull/16129
[#16062]: https://github.com/crystal-lang/crystal/pull/16062
[#16198]: https://github.com/crystal-lang/crystal/pull/16198
[#10248]: https://github.com/crystal-lang/crystal/pull/10248
[#16173]: https://github.com/crystal-lang/crystal/pull/16173
[#16164]: https://github.com/crystal-lang/crystal/pull/16164
[#16063]: https://github.com/crystal-lang/crystal/pull/16063
[#15956]: https://github.com/crystal-lang/crystal/pull/15956
[#16148]: https://github.com/crystal-lang/crystal/pull/16148
[#16149]: https://github.com/crystal-lang/crystal/pull/16149
[#15957]: https://github.com/crystal-lang/crystal/pull/15957
[#15941]: https://github.com/crystal-lang/crystal/pull/15941
[#16104]: https://github.com/crystal-lang/crystal/pull/16104
[#15979]: https://github.com/crystal-lang/crystal/pull/15979
[#16005]: https://github.com/crystal-lang/crystal/pull/16005
[#16004]: https://github.com/crystal-lang/crystal/pull/16004
[#15051]: https://github.com/crystal-lang/crystal/pull/15051
[#15998]: https://github.com/crystal-lang/crystal/pull/15998
[#16052]: https://github.com/crystal-lang/crystal/pull/16052
[#16160]: https://github.com/crystal-lang/crystal/pull/16160
[#15967]: https://github.com/crystal-lang/crystal/pull/15967
[#16002]: https://github.com/crystal-lang/crystal/pull/16002
[#16022]: https://github.com/crystal-lang/crystal/pull/16022
[#16121]: https://github.com/crystal-lang/crystal/pull/16121
[#16039]: https://github.com/crystal-lang/crystal/pull/16039

#### compiler

- _(cli)_ Add the ability to dump type information to a JSON file ([#16027], thanks @HertzDevil)
- _(interpreter)_ Support `Proc.new(Void*, Void*)` in the interpreter ([#16044], thanks @HertzDevil)
- _(interpreter:repl)_ Fully exit the process on `exit!` from REPL ([#16171], thanks @jneen)
- _(semantic)_ Resolve types when guessing return type from class method overloads ([#16118], thanks @HertzDevil)
- _(semantic)_ Guess instance variable types from global method calls ([#16119], thanks @HertzDevil)

[#16027]: https://github.com/crystal-lang/crystal/pull/16027
[#16044]: https://github.com/crystal-lang/crystal/pull/16044
[#16171]: https://github.com/crystal-lang/crystal/pull/16171
[#16118]: https://github.com/crystal-lang/crystal/pull/16118
[#16119]: https://github.com/crystal-lang/crystal/pull/16119

#### tools

- _(docs-generator)_ Add support for deprecated parameters in doc generator ([#16012], thanks @straight-shoota)
- _(hierarchy)_ Show extern union types in hierarchy tool ([#16026], thanks @HertzDevil)

[#16012]: https://github.com/crystal-lang/crystal/pull/16012
[#16026]: https://github.com/crystal-lang/crystal/pull/16026

### Bugfixes

#### stdlib

- _(files)_ Fix `fcntl` reference for `fds[1]` in socketpair setup ([#16072], thanks @kojix2)
- _(log)_ Make crystal log resilient to empty LOG_LEVEL env var ([#15963], thanks @anaPerezGhiglia)
- _(networking)_ Preserve query params in `StaticFileHandler` redirects ([#15789], thanks @syeopite)
- _(networking)_ Fix `StaticFileHandler` to return 404 on file error ([#16025], [#16077], thanks @straight-shoota)
- _(networking)_ Run `before_request` callback in `HTTP::Client` only once ([#16064], thanks @straight-shoota)
- _(networking)_ Fix `HTTP::Request#query=` typing ([#16143], thanks @Blacksmoke16)
- _(runtime)_ `Fiber::ExecutionContext::Parallel::Scheduler#tick` must be unsigned ([#16155], thanks @ysbaddaden)
- _(serialization)_ Fix add missing `#==` overloads for `Log::Metadata::Value` and `YAML::Any` ([#15732], thanks @straight-shoota)
- _(serialization)_ Fix pointer access bug in `XML::NodeSet` ([#16055], thanks @toddsundsted)
- _(serialization)_ Remove `NOERROR` from LibXML default options ([#16103], thanks @straight-shoota)
- _(serialization)_ Move `*::Serializable`'s private constructors into `macro included` hook ([#16147], thanks @HertzDevil)
- _(serialization)_ Correctly reference global JSON/YAML modules ([#16161], [#16169], thanks @Sija, @straight-shoota)
- _(serialization)_ Fix element type inference in `YAML::ArrayConverter.from_yaml` ([#16166], thanks @HertzDevil)
- _(system)_ Fix return type of `system_close_on_exec=` on Windows ([#16095], thanks @straight-shoota)
- _(time)_ Fix time zone identifier `America/Argentina/Buenos_Aires` ([#16078], thanks @straight-shoota)
- _(time)_ Fix `Time#at_beginning_of_week`,`#at_end_of_week` to respect local timezone ([#16113], thanks @straight-shoota)

[#16072]: https://github.com/crystal-lang/crystal/pull/16072
[#15963]: https://github.com/crystal-lang/crystal/pull/15963
[#15789]: https://github.com/crystal-lang/crystal/pull/15789
[#16025]: https://github.com/crystal-lang/crystal/pull/16025
[#16077]: https://github.com/crystal-lang/crystal/pull/16077
[#16064]: https://github.com/crystal-lang/crystal/pull/16064
[#16143]: https://github.com/crystal-lang/crystal/pull/16143
[#16155]: https://github.com/crystal-lang/crystal/pull/16155
[#15732]: https://github.com/crystal-lang/crystal/pull/15732
[#16055]: https://github.com/crystal-lang/crystal/pull/16055
[#16103]: https://github.com/crystal-lang/crystal/pull/16103
[#16147]: https://github.com/crystal-lang/crystal/pull/16147
[#16161]: https://github.com/crystal-lang/crystal/pull/16161
[#16169]: https://github.com/crystal-lang/crystal/pull/16169
[#16166]: https://github.com/crystal-lang/crystal/pull/16166
[#16095]: https://github.com/crystal-lang/crystal/pull/16095
[#16078]: https://github.com/crystal-lang/crystal/pull/16078
[#16113]: https://github.com/crystal-lang/crystal/pull/16113

#### compiler

- _(codegen)_ Never generate assignments to a block's underscore parameters ([#16057], thanks @HertzDevil)
- _(codegen)_ Fix `@[Primitive]` codegen for typedefs ([#16110], thanks @HertzDevil)
- _(interpreter)_ never generate assignments to a block's underscore parameters ([#16058], thanks @HertzDevil)
- _(interpreter)_ Add `writer.close_on_finalize = false` for signal pipe ([#16167], thanks @straight-shoota)
- _(interpreter:repl)_ Continue REPL prompt if input consists entirely of annotations ([#16045], thanks @HertzDevil)
- _(parser)_ Disallow unterminated escaped heredoc without trailing newline ([#16046], thanks @HertzDevil)
- _(parser)_ Require space, semicolon, or newline after class/module/etc. header ([#13375], thanks @FnControlOption)
- _(parser)_ Fix parsing `ReadInstanceVar` in short block syntax ([#16099], thanks @nobodywasishere)
- _(semantic)_ Pass through variable types unchanged in a while loop ([#15980], thanks @HertzDevil)
- _(semantic)_ deprecation warning for (expanded) deprecated def ([#15997], thanks @ysbaddaden)
- _(semantic)_ Copy annotations in  `Crystal::Arg#copy_without_location` ([#16008], thanks @ysbaddaden)
- _(semantic)_ Copy annotations in `Crystal::Def#expand_default_arguments` ([#16007], thanks @ysbaddaden)
- _(semantic)_ Copy annotations in `Crystal::Def#expand_new_default_arguments` ([#16013], thanks @ysbaddaden)
- _(semantic)_ Fix error message for `StaticArray` with non-integer generic argument `N` ([#16037], thanks @straight-shoota)
- _(semantic)_ Resolve bound type parameters from generic superclass during path lookup ([#10839], thanks @HertzDevil)
- _(semantic)_ **[regression]** Ensure hash literals are evaluated from left to right ([#16124], thanks @HertzDevil)

[#16057]: https://github.com/crystal-lang/crystal/pull/16057
[#16110]: https://github.com/crystal-lang/crystal/pull/16110
[#16058]: https://github.com/crystal-lang/crystal/pull/16058
[#16167]: https://github.com/crystal-lang/crystal/pull/16167
[#16045]: https://github.com/crystal-lang/crystal/pull/16045
[#16046]: https://github.com/crystal-lang/crystal/pull/16046
[#13375]: https://github.com/crystal-lang/crystal/pull/13375
[#16099]: https://github.com/crystal-lang/crystal/pull/16099
[#15980]: https://github.com/crystal-lang/crystal/pull/15980
[#15997]: https://github.com/crystal-lang/crystal/pull/15997
[#16008]: https://github.com/crystal-lang/crystal/pull/16008
[#16007]: https://github.com/crystal-lang/crystal/pull/16007
[#16013]: https://github.com/crystal-lang/crystal/pull/16013
[#16037]: https://github.com/crystal-lang/crystal/pull/16037
[#10839]: https://github.com/crystal-lang/crystal/pull/10839
[#16124]: https://github.com/crystal-lang/crystal/pull/16124

### Chores

#### stdlib

- Drop `Thread::Local(T)` ([#16179], thanks @ysbaddaden)
- _(concurrency)_ **[deprecation]** Deprecate `Atomic::Flag` ([#15805], thanks @ysbaddaden)
- _(files)_ **[deprecation]** Deprecate the `blocking` parameter of `File`, `Socket` and `IO::FileDescriptor` constructors ([#16034], [#16043], [#16047], thanks @ysbaddaden, @Blacksmoke16)
- _(numeric)_ **[deprecation]** Deprecate `Float::Printer::IEEE` ([#16050], thanks @HertzDevil)
- _(system)_ **[deprecation]** Deprecate `Process::Status#exit_signal` ([#16003], thanks @straight-shoota)

[#16179]: https://github.com/crystal-lang/crystal/pull/16179
[#15805]: https://github.com/crystal-lang/crystal/pull/15805
[#16034]: https://github.com/crystal-lang/crystal/pull/16034
[#16043]: https://github.com/crystal-lang/crystal/pull/16043
[#16047]: https://github.com/crystal-lang/crystal/pull/16047
[#16050]: https://github.com/crystal-lang/crystal/pull/16050
[#16003]: https://github.com/crystal-lang/crystal/pull/16003

### Performance

#### lang

- Optimize `Enum.parse?`, avoiding allocations ([#15927], [#16192], thanks @jgaskins, @straight-shoota)

[#15927]: https://github.com/crystal-lang/crystal/pull/15927
[#16192]: https://github.com/crystal-lang/crystal/pull/16192

#### stdlib

- _(numeric)_ Do not use equality checks in `Int#upto` and `#downto` ([#16076], thanks @HertzDevil)
- _(system)_ Simplify buffer for `File.readlink` ([#16021], thanks @straight-shoota)
- _(time)_ Optimize `Time#to_s` ([#16042], thanks @straight-shoota)

[#16076]: https://github.com/crystal-lang/crystal/pull/16076
[#16021]: https://github.com/crystal-lang/crystal/pull/16021
[#16042]: https://github.com/crystal-lang/crystal/pull/16042

#### compiler

- Inline `Crystal.check_type_can_be_stored` ([#16130], thanks @HertzDevil)
- _(codegen)_ Group temporary variables by file name: compound array assignments ([#16122], thanks @HertzDevil)

[#16130]: https://github.com/crystal-lang/crystal/pull/16130
[#16122]: https://github.com/crystal-lang/crystal/pull/16122

### Refactor

#### stdlib

- _(concurrency)_ Refactor redundant `begin ... end` blocks ([#16011], thanks @straight-shoota)
- _(networking)_ Reorder implementation of `HTTP::Cookies#<<` and `[]=` ([#16107], thanks @straight-shoota)
- _(runtime)_ Remove nilable pointers in `Crystal::PointerPairingHeap` ([#15973], thanks @HertzDevil)
- _(runtime)_ Remove nilable pointer in `Crystal::EventLoop::IOCP#@timer_packet` ([#15975], thanks @HertzDevil)
- _(runtime)_ Remove minimum in `Fiber::ExecutionContext::Parallel` ([#15946], thanks @ysbaddaden)
- _(runtime)_ Pass `fd` implicitly to `System::FileDescriptor` and `System::Socket` ([#16137], [#16183], thanks @ysbaddaden)
- _(runtime)_ Drop custom implementation of `Fiber::ExecutionContext::Concurrent` ([#16135], thanks @ysbaddaden)
- _(specs)_ Keep own colorization state in `Spec::CLI` ([#15926], thanks @HertzDevil)
- _(text)_ Use `ensure_suffix` instead of manually checking for suffixes ([#15858], thanks @MatheusRich)
- _(time)_ Remove the old Windows time zone name table ([#16006], thanks @HertzDevil)

[#16011]: https://github.com/crystal-lang/crystal/pull/16011
[#16107]: https://github.com/crystal-lang/crystal/pull/16107
[#15973]: https://github.com/crystal-lang/crystal/pull/15973
[#15975]: https://github.com/crystal-lang/crystal/pull/15975
[#15946]: https://github.com/crystal-lang/crystal/pull/15946
[#16137]: https://github.com/crystal-lang/crystal/pull/16137
[#16183]: https://github.com/crystal-lang/crystal/pull/16183
[#16135]: https://github.com/crystal-lang/crystal/pull/16135
[#15926]: https://github.com/crystal-lang/crystal/pull/15926
[#15858]: https://github.com/crystal-lang/crystal/pull/15858
[#16006]: https://github.com/crystal-lang/crystal/pull/16006

#### compiler

- _(codegen)_ Refactor `Compiler#must_compile?` to clarify the rules. ([#16056], thanks @kojix2)
- _(parser)_ Add `#has_any_args?` method for `ASTNode`s ([#16115], thanks @straight-shoota)

[#16056]: https://github.com/crystal-lang/crystal/pull/16056
[#16115]: https://github.com/crystal-lang/crystal/pull/16115

#### tools

- _(formatter)_ Simplify control flow in formatter for `Call` nodes ([#16170], thanks @straight-shoota)

[#16170]: https://github.com/crystal-lang/crystal/pull/16170

#### other

- Refactor `unless ... else` ([#16010], thanks @straight-shoota)
- Removed unused variables ([#16014], thanks @straight-shoota)

[#16010]: https://github.com/crystal-lang/crystal/pull/16010
[#16014]: https://github.com/crystal-lang/crystal/pull/16014

### Documentation

#### lang

- _(annotations)_ Enhance documentation of `Deprecated` annotation ([#16195], thanks @straight-shoota)

[#16195]: https://github.com/crystal-lang/crystal/pull/16195

#### stdlib

- _(benchmark)_ Add type restrictions to benchmark directory ([#15688], thanks @Vici37)
- _(concurrency)_ Improve docs for `Channel#close` ([#15910], thanks @anaPerezGhiglia)
- _(crypto)_ Fix doc example for `Crypto::BCrypt.new(String, String, Int)` ([#15931], thanks @hugopl)
- _(crypto)_ Add type restrictions to crypto directory ([#15694], thanks @Vici37)
- _(files)_ Add type restrictions to mime ([#15834], thanks @Vici37)
- _(files)_ Fix `IO::TimeoutError` documentation use of deprecated `read_timeout=` ([#16073], thanks @lachlan)
- _(files)_ Add type restrictions to io ([#15698], thanks @Vici37)
- _(llvm)_ Deprecate each `LLVM::ABI::*` classes ([#15989], thanks @ysbaddaden)
- _(log)_ Add type restrictions to Log directory ([#15777], thanks @Vici37)
- _(networking)_ Add type restrictions to Oauth directory ([#15687], thanks @Vici37)
- _(networking)_ Add type restrictions to http ([#15710], thanks @Vici37)
- _(numeric)_ Add type restrictions to big ([#15689], thanks @Vici37)
- _(runtime)_ Fix typo in `Object` docs ([#16035], thanks @plambert)
- _(runtime)_ Tweak docs for `Fiber::ExecutionContext` ([#16196], thanks @ysbaddaden)
- _(serialization)_ Add type restrictions to json ([#15840], [#16142], thanks @Vici37, @Sija)
- _(serialization)_ Add note about default constructor in `*::Serializable` ([#16080], thanks @HertzDevil)
- _(system)_ Add type restrictions to `args` parameter in `Process` ([#16031], thanks @BigBoyBarney)
- _(system)_ Add missing `File::NotFoundError` exception documentation for `File.open` ([#15826], thanks @Fijxu)
- _(text)_ Fix return type definition of `String#match_full!` method ([#16001], thanks @Sija)
- _(time)_ Update links to ISO-8601 to point to an archived version of the page ([#15985], thanks @nobodywasishere)
- _(time)_ Improve docs for `Time#to_local_in` ([#16041], thanks @straight-shoota)

[#15688]: https://github.com/crystal-lang/crystal/pull/15688
[#15910]: https://github.com/crystal-lang/crystal/pull/15910
[#15931]: https://github.com/crystal-lang/crystal/pull/15931
[#15694]: https://github.com/crystal-lang/crystal/pull/15694
[#15834]: https://github.com/crystal-lang/crystal/pull/15834
[#16073]: https://github.com/crystal-lang/crystal/pull/16073
[#15698]: https://github.com/crystal-lang/crystal/pull/15698
[#15989]: https://github.com/crystal-lang/crystal/pull/15989
[#15777]: https://github.com/crystal-lang/crystal/pull/15777
[#15687]: https://github.com/crystal-lang/crystal/pull/15687
[#15710]: https://github.com/crystal-lang/crystal/pull/15710
[#15689]: https://github.com/crystal-lang/crystal/pull/15689
[#16035]: https://github.com/crystal-lang/crystal/pull/16035
[#16196]: https://github.com/crystal-lang/crystal/pull/16196
[#15840]: https://github.com/crystal-lang/crystal/pull/15840
[#16142]: https://github.com/crystal-lang/crystal/pull/16142
[#16080]: https://github.com/crystal-lang/crystal/pull/16080
[#16031]: https://github.com/crystal-lang/crystal/pull/16031
[#15826]: https://github.com/crystal-lang/crystal/pull/15826
[#16001]: https://github.com/crystal-lang/crystal/pull/16001
[#15985]: https://github.com/crystal-lang/crystal/pull/15985
[#16041]: https://github.com/crystal-lang/crystal/pull/16041

### Specs

#### stdlib

- _(networking)_ Disable UDP multicast spec on macOS ([#15990], thanks @straight-shoota)
- _(networking)_ Extract specs for `HTTP::Cookies` to their own file ([#16106], thanks @straight-shoota)
- _(networking)_ Overhaul `HTTP::Cookies` specs ([#16117], thanks @straight-shoota)
- _(networking)_ Fix `UDPSocket` broadcast spec to not use `connect` ([#16165], thanks @ysbaddaden)
- _(runtime)_ Disable flaky spec for `Fiber::ExecutionContext::GlobalQueue` on macOS ([#16146], thanks @ysbaddaden)
- _(system)_ Enable specs for `close_on_exec` on Windows ([#14716], thanks @straight-shoota)

[#15990]: https://github.com/crystal-lang/crystal/pull/15990
[#16106]: https://github.com/crystal-lang/crystal/pull/16106
[#16117]: https://github.com/crystal-lang/crystal/pull/16117
[#16165]: https://github.com/crystal-lang/crystal/pull/16165
[#16146]: https://github.com/crystal-lang/crystal/pull/16146
[#14716]: https://github.com/crystal-lang/crystal/pull/14716

#### compiler

- Use `<<-CRYSTAL` in compiler specs consistently ([#16083], thanks @HertzDevil)
- Style the remaining multi-line compiler specs using heredocs ([#16125], thanks @HertzDevil)
- _(codegen)_ Style multi-line codegen specs using heredocs ([#16081], thanks @HertzDevil)
- _(codegen)_ Style `test_c` codegen specs using heredocs ([#16082], thanks @HertzDevil)
- _(semantic)_ Style multi-line `assert_type` specs using heredocs ([#16088], thanks @HertzDevil)
- _(semantic)_ Style multi-line `assert_error` specs using heredocs ([#16093], thanks @HertzDevil)
- _(semantic)_ Move `crystal_path_spec` fixtures to `spec/compiler/data` ([#16086], thanks @straight-shoota)

[#16083]: https://github.com/crystal-lang/crystal/pull/16083
[#16125]: https://github.com/crystal-lang/crystal/pull/16125
[#16081]: https://github.com/crystal-lang/crystal/pull/16081
[#16082]: https://github.com/crystal-lang/crystal/pull/16082
[#16088]: https://github.com/crystal-lang/crystal/pull/16088
[#16093]: https://github.com/crystal-lang/crystal/pull/16093
[#16086]: https://github.com/crystal-lang/crystal/pull/16086

#### tools

- _(formatter)_ Add specs for `x.[](y)` syntax ([#16109], thanks @straight-shoota)

[#16109]: https://github.com/crystal-lang/crystal/pull/16109

### Infrastructure

- Changelog for 1.18.0 ([#16153], thanks @straight-shoota)
- Update previous Crystal release 1.17.0 ([#15988], thanks @straight-shoota)
- Support debug builds for the MSVC Boehm GC libraries ([#15968], thanks @HertzDevil)
- Fix funding.json well-known file name ([#16000], thanks @matiasgarciaisaia)
- Lint the Bash auto-completion script ([#15993], thanks @HertzDevil)
- Merge `release/1.17`@`1.17.1` into `master` ([#16017], thanks @straight-shoota)
- Update previous Crystal release 1.17.1 ([#16016], thanks @straight-shoota)
- Add new types to GitHub issue templates ([#15811], thanks @straight-shoota)
- Disable ameba rule `Lint/Formatting` ([#16015], thanks @straight-shoota)
- Add `REUSE.toml` ([#15992], thanks @straight-shoota)
- Default to LLVM 16 in `shell.nix` ([#16023], thanks @ysbaddaden)
- Avoid updating `forward-compatibility.yml` on release update for patch releases ([#16019], thanks @straight-shoota)
- Disable `Lint/LiteralsComparison` in more spec files ([#16087], thanks @straight-shoota)
- Fix typo in Makefile comment ([#16126], thanks @kojix2)
- Fix duplicate `--error-trace` option in man page ([#16133], thanks @kojix2)
- Makefile: Skip grisu3 float printer deprecations in `std_spec` ([#16185], thanks @ysbaddaden)
- Fix changelog format for Markdown linter ([#16188], thanks @straight-shoota)
- _(ci)_ Add `fail-fast: false` for strategy CI jobs ([#15960], thanks @straight-shoota)
- _(ci)_ Add tests for latest OpenSSL and LibreSSL in Alpine edge ([#15812], thanks @straight-shoota)
- _(ci)_ Use MSYS2 Crystal package for ARM64 Windows CI ([#15991], thanks @HertzDevil)
- _(ci)_ Add macos-15 runner ([#15982], thanks @straight-shoota)
- _(ci)_ Update GH Actions ([#16067], thanks @renovate)
- _(ci)_ Update GH Actions ([#16084], thanks @renovate)
- _(ci)_ Update crate-ci/typos action to v1.35.5 ([#16102], thanks @renovate)
- _(ci)_ Update GH Actions ([#16131], thanks @renovate)
- _(ci)_ Update deprecated `macos-13` to `macos-15-intel` ([#16197], thanks @straight-shoota)
- _(ci)_ Trigger LLVM CI when codegen files are changed ([#16116], thanks @HertzDevil)
- _(ci)_ Do not use D drive on MSVC CI ([#15986], thanks @HertzDevil)

[#16153]: https://github.com/crystal-lang/crystal/pull/16153
[#15988]: https://github.com/crystal-lang/crystal/pull/15988
[#15968]: https://github.com/crystal-lang/crystal/pull/15968
[#16000]: https://github.com/crystal-lang/crystal/pull/16000
[#15993]: https://github.com/crystal-lang/crystal/pull/15993
[#16017]: https://github.com/crystal-lang/crystal/pull/16017
[#16016]: https://github.com/crystal-lang/crystal/pull/16016
[#15811]: https://github.com/crystal-lang/crystal/pull/15811
[#16015]: https://github.com/crystal-lang/crystal/pull/16015
[#15992]: https://github.com/crystal-lang/crystal/pull/15992
[#16023]: https://github.com/crystal-lang/crystal/pull/16023
[#16019]: https://github.com/crystal-lang/crystal/pull/16019
[#16087]: https://github.com/crystal-lang/crystal/pull/16087
[#16126]: https://github.com/crystal-lang/crystal/pull/16126
[#16133]: https://github.com/crystal-lang/crystal/pull/16133
[#16185]: https://github.com/crystal-lang/crystal/pull/16185
[#16188]: https://github.com/crystal-lang/crystal/pull/16188
[#15960]: https://github.com/crystal-lang/crystal/pull/15960
[#15812]: https://github.com/crystal-lang/crystal/pull/15812
[#15991]: https://github.com/crystal-lang/crystal/pull/15991
[#15982]: https://github.com/crystal-lang/crystal/pull/15982
[#16067]: https://github.com/crystal-lang/crystal/pull/16067
[#16084]: https://github.com/crystal-lang/crystal/pull/16084
[#16102]: https://github.com/crystal-lang/crystal/pull/16102
[#16131]: https://github.com/crystal-lang/crystal/pull/16131
[#16197]: https://github.com/crystal-lang/crystal/pull/16197
[#16116]: https://github.com/crystal-lang/crystal/pull/16116
[#15986]: https://github.com/crystal-lang/crystal/pull/15986

## Previous Releases

For information on prior releases, refer to their changelogs:

- [1.17](https://github.com/crystal-lang/crystal/blob/release/1.17/CHANGELOG.md)
- [1.16](https://github.com/crystal-lang/crystal/blob/release/1.16/CHANGELOG.md)
- [1.0 to 1.15](https://github.com/crystal-lang/crystal/blob/release/1.15/CHANGELOG.md)
- [before 1.0](https://github.com/crystal-lang/crystal/blob/release/0.36/CHANGELOG.md)
