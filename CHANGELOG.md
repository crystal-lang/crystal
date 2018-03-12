# 0.24.2 (2018-03-08)

- Fixed an `Index out of bounds` raised during `at_exit` (#5224, #5565, thanks @ysbaddaden)
- Re-add `Dir#each` so it complies with `Enumerable` (#5458, thanks @bcardiff)
- Fixed `SSL::Context` bug verifying certificates (#5266, #5601, thanks @waj)
- Fixed UUID documentation that was missing (#5478, #5542, thanks @asterite)
- Fixed a bug with single expressions in parenthesis (#5482, #5511, #5513, thanks @MakeNowJust)
- Fixed `skip_file` macro docs (#5488, thanks @straight-shoota)
- Fixed CI `build` script's `LIBRARY_PATH` (#5457, #5461, thanks @bcardiff)
- Fixed formatter bug with upper-cased `fun` names (#5432, #5434, thanks @bew)

# 0.24.1 (2017-12-23)

## New features
- Add ThinLTO support for faster release builds in LLVM 4.0 and above. ([#4367](https://github.com/crystal-lang/crystal/issues/4367), thanks @bcardiff)
- **(breaking-change)** Add `UUID` type. `Random::Secure.uuid` has been replaced with `UUID.random`. ([#4453](https://github.com/crystal-lang/crystal/issues/4453), thanks @wontruefree)
- Add a `BigDecimal` class for arbitrary precision, exact, decimal numbers. ([#4876](https://github.com/crystal-lang/crystal/issues/4876) and [#5255](https://github.com/crystal-lang/crystal/issues/5255), thanks @vegai and @Sija)
- Allow `Set` to work as a case condition, which matches when the case variable is inside the set. ([#5269](https://github.com/crystal-lang/crystal/issues/5269), thanks @MakeNowJust)
- **(breaking-change)** Change `Time::Format` codes to allow more robust options for parsing sub-second precision times. ([#5317](https://github.com/crystal-lang/crystal/issues/5317), thanks @bcardiff)
- Add `Time.utc`, an alias of `Time.new` which shortens creating UTC times. ([#5321](https://github.com/crystal-lang/crystal/issues/5321), thanks @straight-shoota)
- Add custom extension support to `Tempfile`. ([#5264](https://github.com/crystal-lang/crystal/issues/5264), thanks @jreinert)
- Add `reduce` method to `TupleLiteral` and `ArrayLiteral` when using macros. ([#5294](https://github.com/crystal-lang/crystal/issues/5294), thanks @javanut13)
- Export a JSON representation of the documentation in the generated output. ([#4746](https://github.com/crystal-lang/crystal/issues/4746) and [#5228](https://github.com/crystal-lang/crystal/issues/5228), thanks @straight-shoota)
- Make `gc/none` garbage collection compile again and allow it to be enbled using `-Dgc_none` compiler flag. ([#5314](https://github.com/crystal-lang/crystal/issues/5314), thanks @ysbaddaden)

## Standard library bugs fixed
- Make `String#[]` unable to read out-of-bounds when the string ends in a unicode character. ([#5257](https://github.com/crystal-lang/crystal/issues/5257), thanks @Papierkorb)
- Fix incorrect parsing of long JSON floating point values. ([#5323](https://github.com/crystal-lang/crystal/issues/5323), thanks @benoist)
- Replace the default hash function with one resistant to hash DoS. ([#5146](https://github.com/crystal-lang/crystal/issues/5146), thanks @funny-falcon)
- Ensure equal numbers always have the same hashcode. ([#5276](https://github.com/crystal-lang/crystal/issues/5276), thanks @akzhan)
- Fix struct equality when two structs descend from the same abstract struct. ([#5254](https://github.com/crystal-lang/crystal/issues/5254), thanks @hinrik)
- Fix `URI#full_path` not to append a `?` unless the query params are nonempty. ([#5340](https://github.com/crystal-lang/crystal/issues/5340), thanks @paulcsmith)
- Fix `HTTP::Params.parse` to parse `&&` correctly. ([#5274](https://github.com/crystal-lang/crystal/issues/5274), thanks @akiicat)
- Disallow null bytes in `ENV` keys and values. ([#5216](https://github.com/crystal-lang/crystal/issues/5216), thanks @Papierkorb)
- Disallow null bytes in `XML::Node` names and content. ([#5200](https://github.com/crystal-lang/crystal/issues/5200), thanks @RX14)
- Fix `IO#blocking=` on OpenBSD. ([#5283](https://github.com/crystal-lang/crystal/issues/5283), thanks @wmoxam)
- Fix linking programs in OpenBSD. ([#5282](https://github.com/crystal-lang/crystal/issues/5282), thanks @wmoxam)

## Compiler bugs fixed
- Stop incorrectly finding top-level methods when searching for a `super` method. ([#5202](https://github.com/crystal-lang/crystal/issues/5202), thanks @lbguilherme)
- Fix parsing regex literals starting with a `;` directly after a call (ex `p /;/`). ([#5208](https://github.com/crystal-lang/crystal/issues/5208), thanks @MakeNowJust)
- Correct a case where `Expressions#to_s` could produce invalid output, causing macro expansion to fail. ([#5226](https://github.com/crystal-lang/crystal/issues/5226), thanks @asterite)
- Give error instead of crashing when `self` is used at the top level. ([#5227](https://github.com/crystal-lang/crystal/issues/5227), thanks @MakeNowJust)
- Give error instead of crashing when using `instance_sizeof` on a generic type without providing it's type arguments. ([#5209](https://github.com/crystal-lang/crystal/issues/5209), thanks @lbguilherme)
- Fix parsing calls when short block syntax (`&.foo`) is followed by a newline. ([#5237](https://github.com/crystal-lang/crystal/issues/5237), thanks @MakeNowJust)
- Give error instead of crashing when an unterminated string array literal (`%w()`) sits at the end of a file. ([#5241](https://github.com/crystal-lang/crystal/issues/5241), thanks @asterite)
- Give error when attempting to use macro yield (`{{yield}}`) outside a macro. ([#5307](https://github.com/crystal-lang/crystal/issues/5307), thanks @MakeNowJust)
- Fix error related to generic inheritance. ([#5284](https://github.com/crystal-lang/crystal/issues/5284), thanks @MakeNowJust)
- Fix compiler crash when using recursive alias and generics. ([#5330](https://github.com/crystal-lang/crystal/issues/5330), thanks @MakeNowJust)
- Fix parsing `foo(+1)` as `foo + 1` instead of `foo(1)` where `foo` was a local variable. ([#5336](https://github.com/crystal-lang/crystal/issues/5336), thanks @MakeNowJust)
- Documentation generator: Keep quoted symbol literals quoted when syntax highlighting code blocks in documentation output. ([#5238](https://github.com/crystal-lang/crystal/issues/5238), thanks @MakeNowJust)
- Documentation generator: Keep the original delimiter used when syntax highlighting string array literals. ([#5297](https://github.com/crystal-lang/crystal/issues/5297), thanks @MakeNowJust)
- Documentation generator: Fix XSS vulnerability when syntax highlighting string array literals. ([#5259](https://github.com/crystal-lang/crystal/issues/5259), thanks @MakeNowJust)
- Formatter: fix indentation of the last comment in a `begin`/`end` block. ([#5198](https://github.com/crystal-lang/crystal/issues/5198), thanks @MakeNowJust)
- Formatter: fix formatting parentheses with multiple lines in. ([#5268](https://github.com/crystal-lang/crystal/issues/5268), thanks @MakeNowJust)
- Formatter: fix formatting `$1?`. ([#5313](https://github.com/crystal-lang/crystal/issues/5313), thanks @MakeNowJust)
- Formatter: ensure to insert a space between `{` and `%` characters to avoid forming `{%` macros. ([#5278](https://github.com/crystal-lang/crystal/issues/5278), thanks @MakeNowJust)

## Misc
- Fix `Makefile`, CI, and gitignore to use the new documentation path after [#4937](https://github.com/crystal-lang/crystal/issues/4937). ([#5217](https://github.com/crystal-lang/crystal/issues/5217), thanks @straight-shoota)
- Miscellaneous code cleanups. ([#5318](https://github.com/crystal-lang/crystal/issues/5318), [#5341](https://github.com/crystal-lang/crystal/issues/5341) and [#5366](https://github.com/crystal-lang/crystal/issues/5366), thanks @bew and @mig-hub)
- Documentation fixes. ([#5253](https://github.com/crystal-lang/crystal/issues/5253), [#5296](https://github.com/crystal-lang/crystal/issues/5296), [#5300](https://github.com/crystal-lang/crystal/issues/5300) and [#5322](https://github.com/crystal-lang/crystal/issues/5322), thanks @arcage, @icyleaf, @straight-shoota and @bew)
- Fix the in-repository changelog to include 0.24.0. ([#5331](https://github.com/crystal-lang/crystal/pull/5331), thanks @sdogruyol)

# 0.24.0 (2017-10-30)

- **(breaking-change)** HTTP::Client#post_form is now HTTP::Client.post(form: ...)
- **(breaking-change)** Array#reject!, Array#compact! and Array#select! now return self ([#5154](https://github.com/crystal-lang/crystal/pull/5154))
- **(breaking-change)** Remove the possibility to require big_int, big_float or big_rational individually: use require "big" instead ([#5121](https://github.com/crystal-lang/crystal/pull/5121))
- **(breaking-change)** Spec: remove expect_raises without type argument ([#5096](https://github.com/crystal-lang/crystal/pull/5096))
- **(breaking-change)** IO is now a class, no longer a module ([#4901](https://github.com/crystal-lang/crystal/pull/4901))
- **(breaking-change)** Time constructors now have nanosecond and kind as named argument ([#5072](https://github.com/crystal-lang/crystal/pull/5072))
- **(breaking-change)** Removed XML.escape. Use HTML.escape instead ([#5046](https://github.com/crystal-lang/crystal/pull/5046))
- **(breaking-change)** Removed macro def ([#5040](https://github.com/crystal-lang/crystal/pull/5040))
- **(breaking-change)** SecureRandom is now Random::Secure ([#4894](https://github.com/crystal-lang/crystal/pull/4894))
- **(breaking-change)** HTML.escape now only escapes &<>"' ([#5012](https://github.com/crystal-lang/crystal/pull/5012))
- **(breaking-change)** To define a custom hash method you must now define hash(hasher) ([#4946](https://github.com/crystal-lang/crystal/pull/4946))
- **(breaking-change)** Flate::Reader.new(&block) and Flate::Writer.new(&block) now use the name open ([#4887](https://github.com/crystal-lang/crystal/pull4887/))
- **(breaking-change)** Use an Enum for Process stdio redirections ([#4445](https://github.com/crystal-lang/crystal/pull/4445))
- **(breaking-change)** Remove '$0' special syntax
- **(breaking-change)** Remove bare array creation from multi assign (a = 1, 2, 3) ([#4824](https://github.com/crystal-lang/crystal/pull/4824))
- **(breaking-change)** Rename skip macro method to skip_file ([#4709](https://github.com/crystal-lang/crystal/pull/4709))
- **(breaking-change)** StaticArray#map and Slice#map now return their same type instead of Array ([#5124](https://github.com/crystal-lang/crystal/pull/5124))
- **(breaking-change)** Tuple#map_with_index now returns a Tuple. ([#5086](https://github.com/crystal-lang/crystal/pull/5086))
- Packages built with LLVM 3.9.1. They should (hopefully) fix [#4719](https://github.com/crystal-lang/crystal/issues/4719)
- Syntax: Allow flat rescue/ensure/else block in do/end block ([#5114](https://github.com/crystal-lang/crystal/pull/5114))
- Syntax: fun names and lib function calls can now start with Uppercase
- Macros: Using an alias in macros will now automatically resolve it to is aliased type ([#4995](https://github.com/crystal-lang/crystal/pull/4995))
- Macros: The flags bits32 and bits64 are now automatically defined in macros
- The YAML module has now full support for the 1.1 core schema with additional types, and properly supports aliases and merge keys ([#5007](https://github.com/crystal-lang/crystal/pull/5007))
- Add --output option to crystal docs ([#4937](https://github.com/crystal-lang/crystal/pull/4937))
- Add Time#days_in_year: it returns the no of days in a given year ([#5163](https://github.com/crystal-lang/crystal/pull/5163))
- Add Time.monotonic to return monotonic clock ([#5108](https://github.com/crystal-lang/crystal/pull/5108))
- Add remove_empty option to many String#split overloads
- Add Math.sqrt overloads for Bigs ([#5113](https://github.com/crystal-lang/crystal/pull/5113))
- Add --stdin-filename to crystal command to compile source from STDIN ([#4571](https://github.com/crystal-lang/crystal/pull/4571))
- Add Crystal.main to more easily redefine the main of a program ([#4998](https://github.com/crystal-lang/crystal/pull/4998))
- Add Tuple.types that returns a tuple of types ([#4962](https://github.com/crystal-lang/crystal/pull/4962))
- Add NamedTuple.types that returns a named tuple of types ([#4962](https://github.com/crystal-lang/crystal/pull/4962))
- Add NamedTuple#merge(other : NamedTuple) ([#4688](https://github.com/crystal-lang/crystal/pull/4688))
- Add YAML and JSON.mapping presence: true option ([#4843](https://github.com/crystal-lang/crystal/pull/4843))
- Add Dir.each_child(&block) ([#4811](https://github.com/crystal-lang/crystal/pull/4811))
- Add Dir.children ([#4808](https://github.com/crystal-lang/crystal/pull/4808))
- HTML.unescape now supports all HTML5 named entities ([#5064](https://github.com/crystal-lang/crystal/pull/5064))
- Regex now supports duplicated named captures ([#5061](https://github.com/crystal-lang/crystal/pull/5061))
- rand(0) is now valid and returns 0
- Tuple#[] now supports a negative index ([#4735](https://github.com/crystal-lang/crystal/pull/4735))
- JSON::Builder#field now accepts non-scalar values ([#4706](https://github.com/crystal-lang/crystal/pull/4706))
- Number#inspect now shows the number type
- Some additions to Big arithmetics ([#4653](https://github.com/crystal-lang/crystal/pull/4653))
- Increase the precision of Time and Time::Span to nanoseconds ([#5022](https://github.com/crystal-lang/crystal/pull/5022))
- Upgrade Unicode to 10.0.0 ([#5122](https://github.com/crystal-lang/crystal/pull/5122))
- Support LLVM 5.0 ([#4821](https://github.com/crystal-lang/crystal/pull/4821))
- [Lots of bugs fixed](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.24.0)

# 0.23.1 (2017-07-01)

* Added `Random::PCG32` generator (See #4536, thanks @konovod)
* WebSocket should compare "Upgrade" header value with case insensitive (See #4617, thanks @MakeNowJust)
* Fixed macro lookup from included module (See #4639, thanks @asterite)
* Explained "crystal tool expand" in crystal(1) man page (See #4643, thanks @MakeNowJust)
* Explained how to detect end of file in `IO` (See #4661, thanks @oprypin)

# 0.23.0 (2017-06-27)

* **(breaking-change)** `Logger#formatter` takes a `Severity` instead of a `String` (See #4355, #4369, thanks @Sija)
* **(breaking-change)** Removed `IO.select` (See #4392, thanks @RX14)
* Added `Crystal::System::Random` namespace (See #4450, thanks @ysbaddaden)
* Added `Path#resolve?` macro method (See #4370, #4408, thanks @RX14)
* Added range methods to `BitArray` (See #4397, #3968, thanks @RX14)
* Added some well-known HTTP Status messages (See #4419, thanks @akzhan)
* Added compiler progress indicator (See #4182, thanks @RX14)
* Added `System.cpu_cores` (See #4449, #4226, thanks @miketheman)
* Added `separator` and `quote_char` to `CSV#each_row` (See #4448, thanks @timsu)
* Added `map_with_index!` to `Pointer`, `Array` and `StaticArray` (See #4456, #3356, #3354, thanks @Nephos)
* Added `headers` parameter to `HTTP::WebSocket` constructors (See #4227, #4222, thanks @adamtrilling)
* Added `unlink` to `XML::Node` (See #4515, #4331, thanks @RX14 and @MrSorcus)
* Added `Math.frexp` (See #4560, thanks @akzhan)
* Added `Regex::MatchData` support for negative indexes (See #4566, thanks @MakeNowJust)
* Added `captures`, `named_captures`, `to_a` and `to_h` to `Regex::MatchData` (See #3783, thanks @MakeNowJust)
* Added `|` as a string delimiter to allow `q|string|` syntax (See #3467, thanks @RX14)
* Added support for Windows linker (See #4491, thanks @RX14)
* Added llvm operand bundle def and catch pad/ret/switch in order to support Windows SEH (See #4501, thanks @bcardiff)
* Added `Float::Printer` based on Grisu3 to speed up float to string convertion (See #4333, thanks @will)
* Added `Object.unsafe_as` to unsafely reinterpret the bytes of an object as being of another `type` (See #4333, thanks @asterite)
* Added `.downcase(Unicode::CaseOptions::Fold)` option which convert strings to casefolded strings for caseless matching (See #4512, thanks @akzhan)
* Added `OpenSSL::DigestIO` to wrap an IO while calculating a digest (See #4260, thanks @spalladino)
* Added `zero?` to numbers and time spans (See #4026, thanks @jellymann)
* Added `TypeNode#has_method?` method (See #4474, thanks @Sija)
* `Regex::MatchData#size` renamed to `#group_size` (See #4565, thanks @MakeNowJust)
* `HTTP::StaticFileHandler` can disable directory listing (See #4403, #4398, thanks @joaodiogocosta)
* `bin/crystal` now uses `/bin/sh` instead of `/bin/bash` (See #3809, #4410, thanks @TheLonelyGhost)
* `crystal init` generates a `.editorconfig` file (See #4422, #297, thanks @akzhan)
* `man` page for `crystal` command (See #2989, #1291, thanks @dread-uo)
* Re-raising an exception doesn't overwrite its callstack (See #4487, #4482, thanks @akzhan)
* MD5 and SHA1 documentation clearly states they are not cryptographically secure anymore (See #4426, thanks @RX14)
* Documentation about constructor methods now rendered separately (See #4216, thanks @Sija)
* Turn `Random::System` into a module (See #4542, thanks @oprypin)
* `Regex::MatchData` pretty printed (See #4574, thanks @MakeNowJust)
* `String.underscore` treats digits as downcase or upcase characters depending previous characters (See #4280, thanks @MakeNowJust)
* Refactor time platform specific implementation (See #4502, thanks @bcardiff)
* Fixed Crystal not reusing .o files across builds (See #4336)
* Fixed `SomeClass.class.is_a?(SomeConst)` causing an "already had enclosing call" exception (See #4364, #4390, thanks @rockwyc992)
* Fixed `HTTP::Params.parse` query string with two `=` gave wrong result (See #4388, #4389, thanks @akiicat)
* Fixed `Class.class.is_a?(Class.class.class.class.class)` 🎉 (See #4375, #4374, thanks @rockwyc992)
* Fixed select hanging when sending before receive (See #3862, #3899, thanks @kostya)
* Fixed "Unknown key in access token json: id_token" error in OAuth2 client (See #4437)
* Fixed macro lookup conflicting with method lookup when including on top level (See #236)
* Fixed Vagrant images (See #4510, #4508, thanks @Val)
* Fixed `IO::FileDescriptor#seek` from current position (See #4558, thanks @ysbaddaden)
* Fixed `IO::Memory#gets_to_end` to consume the `IO` (See #4415, thanks @jhass)
* Fixed setting of XML attributes (See #4562, thanks @asterite)
* Fixed "SSL_shutdown: Operation now in progress" error by retrying (See #3168, thanks @akzhan)
* Fixed WebSocket negotiation (See #4386, thanks @RX14)

# 0.22.0 (2017-04-20)

* **(breaking-change)** Removed `Process.new(pid)` is now private (See #4197)
* **(breaking-change)** IO#peek now returns an empty slice on EOF (See #4240, #4261)
* **(breaking-change)** Rename `WeakRef#target` to `WeakRef#value` (See #4293)
* **(breaking-change)** Rename `HTTP::Params.from_hash` to `HTTP::Params.encode` (See #4205)
* **(breaking-change)** `'\"'` is now invalid, use `'"'` (See #4309)
* Improved backtrace function names are now read from DWARF sections (See #3958, thanks @ysbaddaden)
* Improved sigfaults and exceptions are printed to STDERR (See #4163, thanks @Sija)
* Improved SSL Sockets are now buffered (See #4248)
* Improved type inference on loops (See #4242, #4243)
* Improved `pp` and `p`, the printed value is returned (See #4285, #4283, thanks @MakeNowJust)
* Added support for OpenSSL 1.1.0 (See #4215, #4230, thanks @ysbaddaden)
* Added `SecureRandom#random_bytes(Bytes)` (See #4191, thanks @konovod)
* Added setting and deleting of attributes on `XML::Node` (See #3902, thanks @bmmcginty)
* Added `File.touch` and `FileUtils.touch` methods (See #4069, thanks @Sija)
* Added `#values_at` for `CSV` (See #4157, thanks @need47)
* Added `Time#clone` (See #4174, thanks @Sija)
* Added `ancestors` macro method (See #3875, thanks @david50407)
* Added `skip` macro method (#4237, thanks @mverzilli)
* Added `Colorize.on_tty_only!` for easier toggling (See #4075, #4271, thanks @MakeNowJust)
* Added `WebSocket#on_binary` to receive binary messages (See #2774, thanks @lbguilherme)
* Fixed `Iterator.of` stops iterating when `Iterator.stop` is returned (See #4208)
* Fixed `String#insert` for non-ascii Char (See #4164, thanks @Papierkorb)
* Fixed `File.link` now creates a hard link (#4116, thanks @KCreate)
* Fixed error message for `#to_h` over empty `NamedTuple` (See #4076, thanks @karlseguin)
* Fixed `NamedTuple#to_h` does no longer call to value's `#clone` (See #4203)
* Fixed `Math#gamma` and `Math#lgamma` (See #4229, thanks @KCreate)
* Fixed `TCPSocket` creation for 0 port for Mac OSX (See #4177, thanks @will)
* Fixed repo name extraction from git remote in doc tool (See #4132, thanks @Sija)
* Fixed `self` resolution when including a generic module (See #3972, thanks @MakeNowJust)
* Fixed debug information was missing in some cases (See #4166, #4202, #4254)
* Fixed use generic ARM architecture target triple for all ARM architectures (See #4167, thanks @ysbaddaden)
* Fixed macro run arguments escaping
* Fixed zsh completion (See #4284, thanks @veelenga)
* Fixed honor `--no-color` option in spec (See #4306, thanks @luislavena)
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.22.0)

# 0.21.1 (2017-03-06)

* Improved lookup of abstract def implementors (see #4052)
* Improved allocation of objects without pointer instance variables using `malloc_atomic` (see #4081)
* Added `crystal --version` reports also the LLVM version (see #4095, thanks @matiasgarciaisaia)
* Fixed instance variables initializers corner cases (see #3988)
* Fixed `crystal play` was broken (see #4061)
* Fixed `Atomic` can be set to `nil` (see #4062)
* Fixed `GZip::Header` extra byte (see #4068, thanks @crisward)
* Fixed `ASTNode#to_s` for `Attribute` (see #4098, thanks @olbat)
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.21.1)

# 0.21.0 (2017-02-20)

* **(breaking-change)** The compiler now reuses previous macro run compilations so `{{ run(...) }}` is only re-run if the code changes
* **(breaking-change)** Spec: `assert { ... }` is now `it { ... }` (thanks @TheLonelyGhost)
* **(breaking-change)** Renamed `Set#merge!` to `Set#concat`
* **(breaking-change)** `Zlib` was split into `Flate`, `Gzip` and `Zlib` ([bda40f](https://github.com/crystal-lang/crystal/commit/bda40f))
* **(breaking-change)** `Crypto::MD5` is now `Digest::MD5`
* **(breaking-change)** `String#chop` is now `String#rchop`
* **(breaking-change)** `String#to_slice` now returns a read-only Slice
* **(breaking-change)** `String` can now hold invalid UTF-8 byte sequences, and they produce a unicode replacement character when traversed
* **(breaking-change)** Removed `String#lchomp`. Use `String#lchop`
* **(breaking-change)** Octal escapes inside strings incorrectly produced a codepoint value instead of a byte value
* **(breaking-change)** Removed octal escape from char literals
* Fixed compiler performance regression related to cached files ([f69e37e](https://github.com/crystal-lang/crystal/commit/f69e37e))
* Added `\xHH` escape sequence in string literals
* `Char::Reader` can now traverse a string backwards
* `Enum#to_s` now uses pipes instead of commas for flag enums
* `IO#read_string` is now encoding-aware
* `OAuth2::Client` now sends `application/json` Accept header, and considers the `expires_in` access token property as optional
* `Slice` can now be read-only
* `TCPServer` no longer set SO_REUSEPORT to true by default
* Added `HTTP::Multipart` and `HTTP::FormData` (thanks @RX14)
* Added `File::Stat#pipe?`
* Added `File.utime`
* Added `IO#peek`
* Added `String#strip(arg)`, `String#lstrip(arg)`, `String#rstrip(arg)`
* Added `String#lchop`, `String#lchop(prefix)`, `String#rchop` and `String#rchop(suffix)`
* Added `String#hexbytes` and `String#hexbytes?`
* Added `String#scrub` and `String#valid_encoding?`
* Added `include?` macro method for StringLiteral, SymbolLiteral and MacroId (thanks @karlseguin)
* Added "view source" links to GitLab (thanks @ezrast)
* Updated CONTRIBUTING.md guidelines
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.21.0)

# 0.20.5 (2017-01-20)

* Improved performance in `String#index`, `String#rindex` due to Rabin-Karp algorithm (thanks @MakeNowJust).
* Improved performance in `Crypto::Bcrypt` (see #3880, thanks @ysbaddaden).
* `expect_raises` returns raised exception (thanks @kostya).
* Line numbers debug information is always generated (see #3831, thanks @ysbaddaden).
* Added `Zip::File`, `Zip::Reader` and `Zip::Writer`. Native readers for zip files that delegate compression to existing zlib module.
* Added `Hash#delete` with block (see #3856, thanks @bmulvihill).
* Added `String#[](char : Char)` (see #3855, thanks @Sija).
* Added `crystal tool expand` to expand macro call in a given location (see #3732, thanks @MakeNowJust).
* Fixed `crystal play` is able to show compilation errors again.
* `crystal doc` recognizes `crystal-lang/crystal` in any remote (thanks @MaxLap).
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.20.5)

# 0.20.4 (2017-01-06)

* **(breaking change)** A type that wants to convert itself to JSON now must override `to_json(builder : JSON::Builder)` instead of `to_json(io : IO)`. The same is true for custom JSON converters. If you are using `JSON.mapping` then your code will continue to work without changes.
* **(breaking change)** Defining a `finalize` method on a struct now gives a compile error
* **(breaking change)** Default argument types now must match their restriction, if any (for example `def foo(x : Int32 = nil)` will now fail to compile if `foo` is invoked without arguments) (thanks @MakeNowJust)
* **(breaking change)** `each` methods now return `Nil`
* **(breaking change)** `IO#skip(bytes)` will now raise if there aren't at least the given amount of bytes in the `IO` (previously it would work well if there were less bytes, and it would hang if there were more)
* **(breaking change)** `MemoryIO` was removed (use `IO::Memory` instead)
* **(breaking change)** `Number#step` now requires named arguments, `to` and `by`, to avoid argument order confusion
* **(breaking change)** `YAML::Emitter` was renamed to `YAML::Builder`, and some of its methods were also renamed
* **(breaking change)** `XML::Node#[]` now always returns a `String` (previously it could also return `Nil`, which was incorrect)
* **(breaking change)** `XML::Node#content` now returns an empty `String` when no content is available
* `HTTP::Client` now automatically reconnects on a dropped keep-alive connection
* `with ... yield` now works well with `method_missing`
* Class variables can now be used in generic types (all generic instances share the same variable, and subclasses get their own copy, as usual)
* Added support for LLVM 4 (thanks @ysbaddaden)
* Added `Enum.each` and `Enum#each` (thanks @ysbaddaden)
* Added `Hash#compact` and `Hash#compact!` (thanks @MakeNowJust)
* Added `IO#read_string(bytesize)`
* Added `IO#skip_to_end`
* Added `Iterator#flat_map` (thanks @MakeNowJust)
* Added `JSON.build` and `JSON::Builder`
* Added `NamedTuple#has_key?(String)` (thanks @Sija)
* Added `p(NamedTuple)` (thanks @splattael)
* Added `Regex::MatchData#==` (thanks @MakeNowJust)
* Added `String#sub(Regex, NamedTuple)` (thanks @maiha)
* Added `XML.build` and `XML::Builder`
* Lots of improvements and applied consistencies to doc comments (thanks @Sija and @maiha)
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.20.4)

## 0.20.3 (2016-12-23)

* **(breaking change)** `IO#gets`, `IO#each_line`, `String#lines`, `String#each_line`, etc. now chomp lines by default. You can pass `chomp: false` to prevent automatic chomping. Note that `chomp` is `true` by default for argless `IO#gets` (read line) but `false` if args are given.
* **(breaking change)** `HTTP::Handler` is now a module instead of a class (thanks @andrewhamon)
* **(breaking change)** Free variables now must be specified with `forall`, a single uppercase letter will not work anymore
* **(breaking change)** The `libs` directory is no longer in the default CRYSTAL_PATH, use `lib` (running `crystal deps` should fix this)
* Optimized compile times, specially on linux
* `private` can now be used with macros inside types (thanks @MakeNowJust)
* CLI: the `-s`/`--stats` option now also shows execution time (thanks @MakeNowJust)
* CLI: added `-t`/`--time` to show execution time (thanks @MakeNowJust)
* `Socket` now allows any family/type/protocol association, [and many other improvements](https://github.com/crystal-lang/crystal/pull/3750) (thanks @ysbaddaden)
* YAML: an `IO` can now be passed to `from_yaml` (thanks @MakeNowJust)
* Added `class_getter`, `class_setter`, `class_property`, etc. (thanks @Sija)
* Added `String#lchomp` (thanks @Sija)
* Added `IO#read_fully?`
* Added `Iterator#flatten` (thanks @MakeNowJust)
* Added `HTTP::WebSocket#ping`, `pong`, `on_ping`, `on_pong`, and now a ping message is automatically replied with a pong message (thanks @Sija)
* Added `File#empty?` and `Dir#empty?` (thanks @dylandrop)
* Added `Time::Span#/(Time::Span)` (thanks @RX14)
* Added `String#split` versions that accept a block (thanks @splattael)
* Added `URI#normalize` and `normalize!` (thanks @taylorfinnell)
* Added `reuse` optional argument to many `Array`, `Enumerable` and `Iterable` methods that allow you to reuse the yielded/return array for better performance and less memory footprint
* The `:debug` flag is now present when compiled with `--debug`, useful for doing `flag?(:debug)` in macros (thanks @luislavena)
* [Many bug fixes and performance improvements](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.20.3)

## 0.20.1 (2016-12-05)

* **(breaking change)** `Set#merge` as renamed to `Set#merge!`
* **(breaking change)** `Slice.new(size)` no longer works with non primitive integers and floats
* **(breaking change)** The macro method `argify` was renamed to `splat`
* Added pretty printing. The methods `p` and `pp` now use it. To get the old behaviour use `puts obj.inspect`
* Added `ArrayLiteral#[]=`, `TypeNode#constant`, `TypeNode#overrides?` and `HashLiteral#double_splat` in macros
* Added a `finished` macro hook that runs at the end of the program
* Added support for declaring the type of a local variable
* Added `Slice.empty`
* Flags enums now have a `none?` method
* `IO::ByteFormat` has now methods to encode/decode to/from a `Slice`
* Spec: the line number passed to run a specific `it` block can now be inside any line of that block
* The `CallConvention` attribute can now also be applied to a `lib` declaration, and all `fun`s inside it will inherit it
* The `method_missing` hook can now define a method, useful for specifying block arguments
* Support double splat in macros (`{{**...}}`)
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.20.1)

## 0.20.0 (2016-11-22)

* **(breaking change)** Removed `ifdef` from the language
* **(breaking change)** Removed `PointerIO`
* **(breaking change)** The `body` property of `HTTP::Request` is now an `IO?` (previously it was `String`). Use `request.body.try(&.gets_to_end)`  if you need the entire body as a String.
* **(breaking change)** `MemoryIO` has been renamed to `IO::Memory`. The old name can still be used but will produce a compile-time warning. `MemoryIO` will be removed immediately after 0.20.0.
* **(breaking change)** `Char#digit?` was split into `Char#ascii_number?` and `Char#number?`. The old name is still available and will produce a compile-time warning, but will be removed immediately after 0.20.0.
* **(breaking change)** `Char#alpha?` was split into `Char#ascii_letter?` and `Char#letter?`. The old name is still available and will produce a compile-time warning, but will be removed immediately after 0.20.0.
* **(breaking change)** The `Iterable` module is now generic
* Many `String` and `Char` methods are now unicode-aware, for example `String#downcase`, `String#upcase`, `Char#downcase`, `Char#upcase`, `Char#whitespace?`, etc.
* Added support for HTTP client and server streaming.
* Added support for ARM (thanks @ysbaddaden)
* Added support for AArch64 (thanks @ysbaddaden)
* Added support for LLVM 3.9 (thanks @ysbaddaden)
* Added `__END_LINE__` magic constant in method default arguments: will be the last line of a call (if the call has a block, it will be the last line of that block)
* Added `@def` inside macros that takes the value of the current method
* API docs have a nicer style now, and notes like TODO and DEPRECATED are better highlighted (thanks @samueleaton)
* Slight improvement to debugging support (thanks @ggiraldez)
* Line numbers in backtraces (linux only for now) (thanks @ysbaddaden)
* Added iteration times to `Benchmark.ips` (thanks @RX14)
* Allow `HTTP::Client` block initializer to be used when passing an URI (thanks @philnash)
* `JSON.mapping` and `YAML.mapping` getter/setter generation can now be controlled (thanks @zatherz)
* `Time` is now serializable to JSON and YAML using ISO 8601 date-time format
* Added `IO::MultiWriter` (thanks @RX14)
* Added `String#index(Regex)` and `String#rindex(Regex)` (thanks @zatherz)
* Added `String#partition` and `String#rpartition` (thanks @johnjansen)
* Added `FileUtils.cd`, `FileUtils.mkdir`, `FileUtils.mkdir_p`, `FileUtils.mv`, `FileUtils.pwd`, `FileUtils.rm`, `FileUtils.rm_r`, `FileUtils.rmdir` (thanks @ghivert)
* Added `JSON::Builder#raw_field` (thanks @kostya)
* Added `Enumerable#chunks` and `Iterator#chunk` (thanks @kostya)
* Added `Iterator#with_index`
* Several enhancements to the Random module: now works for any integer type and avoids overflows (thanks @BlaXpirit)
* Optimized `Array#sort` by using introsort (thanks @c910335)
* [Several bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.20.0)

## 0.19.4  (2016-10-07)

* Added support for OpenBSD (thanks @wmoxam and @ysbaddaden)
* More iconv fixes for FreeBSD (thanks @ysbaddaden)
* Changed how `require` works for the upcoming `shards` release (this is backwards compatible). See https://github.com/crystal-lang/crystal/pull/2788
* Added `Atomic` and exposed all LLVM atomic instructions to Crystal (needed to implemented multiple-thread support)
* Added `Process.executable_path` (thanks @kostya, @whereami and @ysbaddaden)
* Added `HTML.unescape` (thanks @dukex)
* Added `Char#+(Int)` and `Char#-(Int)`
* [A few bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.4)

## 0.19.3  (2016-09-30)

* `crystal eval` now accepts some flags like `--stats`, `--release` and `--help`
* Added `File.chown` and `File.chmod` (thanks @ysbaddaden)
* Added `Time::Span.zero` (useful for doing `sum`) (thanks @RX14)
* Added docs to `OAuth` and `OAuth2`
* [Several bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.3)

## 0.19.2  (2016-09-16)

* Generic type variables no longer need to be single-letter names (for example `class Gen(Foo)` is now possible)
* Added syntax to denote free variables: `def foo(x : T) forall T`. The old rule of single-letter name still applies but will be removed in the future.
* Removed the restriction that top-level types and constants can't have single-letter names
* Added `@[Extern]` attribute to mark regular Crystal structs as being able to be used in C bindings
* Faster `Char#to_s` when it's ASCII: this improves the performance of JSON and CSV parsing
* `crystal spec`: allow passing `--release` and other options
* `crystal spec`: allow running all specs in a given directory
* `crystal playground`: support custom workbook resources (thanks @bcardiff)
* `crystal playground`: standard output now understands ANSI colors (thanks @bcardiff)
* Added many more macro methods to traverse AST nodes (thanks @BlaXpirit)
* Error messages no longer include a type trace by default, pass `--error-trace` to show the full trace (the trace is often useless and makes it harder to understand error messages)
* [Several bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.2)

## 0.19.1  (2016-09-09)

* Types (class, module, etc.) can now be marked as `private`.
* Added `WeakRef`  (thanks @bcardiff)
* [Several bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.1)

## 0.19.0  (2016-09-02)

* **(breaking change)** Added `select` keyword
* **(breaking change)** Removed $global variables. Use @@class variables instead.
* **(breaking change)** Heredoc now ends when the matching identifier is found, either followed by a space or by a non-identifier
* **(breaking change)** Assignment to a local variable inside an assignment to that same variable is now an error
* **(breaking change)** Type names like `T`, `T1`, `U`, etc., are now disallowed at the top level, to avoid conflicts with free variables
* **(breaking change)** Type lookup (`Foo::Bar::Baz`) had some incorrect behaviour that now is fixed. This can break existing code that relied on this incorrect behaviour. The fix is to fully qualify types (`::Foo::Bar::Baz`)
* **(breaking change)** In relationships like `class Bar < Foo(Baz)` and `include Moo(Baz)`, all of `Foo`, `Moo` and `Baz` must be defined before that point (this was not always the case in previous versions)
* **(breaking change)** Removed the deprecated syntax `x as T`
* **(breaking change)** Removed block form of `String#match`
* **(breaking change)** Removed `IO#read_nonblock`
* **(breaking change)** `Int#/` now performs floored division. Use `Int#tdiv` for truncated division (see their docs to learn the difference)
* Added support for LLVM 3.8 (thanks @omarroth)
* `||` now does type filtering
* Generic inheritance should now work well, and (instantiated) generic modules can now be used as the type of instance variables
* `NamedTuple` can now be accessed with strings too (thanks @jhass)
* `Base64` can now encode and decode directly to an `IO` (thanks @kostya)
* `BigInt` now uses GMP implementation of gcd and lcm (thanks @endSly)
* `ECR` now supports removing leading and trailing whitespace (`<%-`, `-%>`)
* `HTTP::Request#path` now never returns `nil`: it fallbacks to `"/"` (thanks @jhass)
* `String#tr(..., "")` is now the same as `String#delete`
* `tool hierarchy` now supports `--format json` (thanks @bmulvihill)
* Added `Char#ascii?`
* Added `Class#nilable?` and `Union#nilable?`
* Added `Hash#has_value?` (thanks @kachick)
* Added `IO::Sized` and `IO::Delimited` (thanks @RX14)
* Added `IO::Hexdump` (thanks @ysbaddaden)
* Added `IO#noecho` and `IO#noecho!` (thanks @jhass)
* Added `Logger.new(nil)` to create a null logger
* Added `OptionParser#missing_option` and `OptionParser#invalid_option` (thanks @jhass)
* Added `Process.exists?`, `Process#exists?` and `Process#terminated?` (thanks @jhass)
* Added `Process.exec` (thanks @jhass)
* Added `Slice#copy_to`, `Slice#copy_from`, `Slice#move_to` and `Slice#move_from` (thanks @RX14)
* Added `URI#==` and `URI#hash` (thanks @timcraft)
* Added `YAML#parse(IO)`
* Added `Indexable` module that `Array`, `Slice`, `Tuple` and `StaticArray` include
* Added `indent` parameter to `to_pretty_json`
* Added lazy form of `getter` and `property` macros
* Added macro methods to access an ASTNode's location
* Unified String and Char to integer/float conversion API (thanks @jhass)
* [Lots of bug fixes](https://github.com/crystal-lang/crystal/milestone/5?closed=1)

## 0.18.7 (2016-07-03)

* The `compile` command was renamed back to `build`. The `compile` command is deprecated and will be removed in a future version
* Fibers now can be spawned with a name
* ECR macros can now be required with just `require "ecr"`
* [Several bugs fixes and enhancements](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.7+is%3Aclosed)

## 0.18.6 (2016-06-28)

* `T?` is now parsed as `Union(T, Nil)` outside the type grammar
* Added `String#sub` overloads for replacing an index or range with a char or string
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.6+is%3Aclosed)

## 0.18.5 (2016-06-27)

* Added `OpenSSL::SSL::Socket#alpn_protocol`
* Added `IO#copy(src, desc, limit)` (thanks @jreinert)
* Added `TypeNode#instance` macro method
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.5+is%3Aclosed)

## 0.18.4 (2016-06-21)

* Fixed [#2887](https://github.com/crystal-lang/crystal/issues/2887)
* Fix broken specs

## 0.18.3 (2016-06-21)

* `TypeNode`: added `<`, `<=`, `>` and `>=` macro methods
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.3+is%3Aclosed)

## 0.18.2 (2016-06-16)

* Fixed building Crystal from the source tarball

## 0.18.1 (2016-06-16)

* Spec: passing `--profile` shows the slowest 10 specs (thanks @mperham)
* Added `StringLiteral#>` and `StringLiteral#<` in macros
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.1+is%3Aclosed)

## 0.18.0 (2016-06-14)

* **(breaking change)** `IniFile` was renamed to `INI`, and its method `load` renamed to `parse`
* **(breaking change)** `Process.getpgid` was renamed to `Process.pgid`
* **(breaking change)** An `Exception`'s backtrace is now set when it's raised, not when it's created: it's `backtrace` method raises if it's not set, and there's `backtrace?` to get it as a nilable array
* **(breaking change)** `dup` is now correctly implemented in all types. `clone` is not defined by default, but some types in the standard library do. Also check `Object#def_clone`
* **(breaking change)** the `method_missing` macro only accepts a single argument: a `Call` now. The form that accepted 3 arguments was removed.
* **(breaking change)** the `delegate` macro must now be used like `delegate method1, method2, ..., methodN, to: object`
* **(breaking change)** `Hash#each_with_index` and `Hash#each_with_object` now yield a tuple (pair) and an index, because `Hash` is now `Enumerable`. Use `do |(key, value), index|` for this.
* **(breaking change)** `{"foo": 1}` denotes a named tuple literal now, not a hash literal. Use `{"foo" => 1}` instead. This also applies to, for example `HTTP::Headers{...}`
* **(breaking change)** Extra block arguments now give a compile-time error. This means that methods that yield more than once, one time with N arguments and another time with M arguments, with N < M, will always give an error. To fix this, add M - N `nil` fillers on the yield side (this makes it more explicit that `nil` was intended to be a block argument value)
* **(breaking change)** `OpenSSL::SSL::Context` and `OpenSSL::SSL::Socket` can no longer be used directly anymore. Use their respective subclasses `OpenSSL::SSL::Context::Client`,
  with `OpenSSL::SSL::Socket::Client`, `OpenSSL::SSL::Context::Server` with `OpenSSL::SSL::Socket::Server`.
* **(breaking change)** TLS server and client sockets now use sane defaults, including support for hostname verification for client sockets, used by default in `HTTP::Client`.
* **(breaking change)** The `ssl` option was renamed to `tls` in `HTTP::Client`, `HTTP::Server`, `HTTP::WebSocket`, `OAuth::Consumer`, `OAuth::Signature` and `OAuth2::AccessToken`.
* The `dns_timeout` setting in a few classes like `HTTP::Client` and `TCPSocket` is now ignored until a next version supports a non-blocking `getaddrinfo` equivalent
* `OpenSSL::SSL::Socket::Client` supports server name indication now.
* The `build` command was renamed to `compile`. The `build` command is deprecated and will be removed in a future version
* The `--cross-compile` flag no longer takes arguments, use `--target` and `-D`
* Added a `Union` type that represents the type of a union, which can have class methods
* Methods, procs and lib functions that are marked as returning `Void` now return `Nil`
* Methods that are marked as returning `Nil` are not checked for a correct return type, they always return `nil` now
* When `as` fails at runtime it now includes which type couldn't be cast
* Macros can now be used inside `lib` and `enum` declarations
* Macros can now be declared inside enums
* Macro calls can now be used as enum values
* Generic types can now include a splatted type variable. This already existed in the language (`Tuple(*T)`, `Proc(*T)`) but there was no syntax to define such types.
* Class variables are now inherited (only their type, not their value). They are now similar to Ruby class instance variables.
* Splats in `yield` can now be used
* Splat in block arguments can now be used.
* Added block auto-unpacking: if a method yields a tuple and a block specifies more then one block argument, the tuple is unpacked to these arguments
* String literals are now allowed as external method arguments, to match named tuples and named arguments
* `sizeof` and `instance_sizeof` can now be used as generic type arguments (mostly useful combined with `StaticArray`)
* `Hash`, `HTTP::Headers`, `HTTP::Params` and `ENV` now include the `Enumerable` module
* `Proc` is now `Proc(*T, R)`
* `Tuple(*T).new` and `NamedTuple(**T).new` now correctly match the given `T` (#1828)
* `Float64#to_s` now produces an ever more accurate output
* `JSON` parsing now correctly handle floats with many digits
* `JSON.mapping` and `YAML.mapping` now also accept named arguments in addition to a hash literal or named tuple literal
* `Int#chr` now raises if the integer is out of a char's range. The old non-raising behaviour is now in `Int#unsafe_chr`.
* The output of `pp x` is now `x # => ...` instead of `x = ...`
* The output of the `debug()` macro method now tries to format the code (pass `false` to disable this)
* Added `JSON` and `YAML` parsing and mapping for unions
* Added `FileUtils.cp_r` (thanks @Dreauw)
* Added `Tuple.from` and `NamedTuple.from`  (thanks @jhass)
* Added `XML.escape` (thanks @juanedi)
* Added `HTTP::Server::Response#respond_with_error` (thanks @jhass)
* Added `TCPServer#accept?`
* Added optional `base` argument to `Char#digit?` and `Char#hex?` (thanks @mirek)
* Added `flag?` macro method, similar to using `ifdef`. `ifdef` is deprecated and will be removed in a future version.
* Added `YAML::PullParser#read_raw`
* Added `Proc#partial`
* Added `Socket.ip?(str)` to validate IPv4 and IPv6 addresses
* Added `Bytes` as an alias of `Slice(UInt8)`
* Added `RangeLiteral` macro methods: `begin`, `end`, `excludes_end?`, `map` and `to_a`
* Added `ArrayLiteral#[range]` and `ArrayLiteral#[from, to]` in macros (applicable for `TupleLiteral` too)
* Added `Generic` macro methods: `name`, `type_vars`, `named_args`
* Spec: added JUnit formatter output (thanks @juanedi)
* The `tls` option in `HTTP::Client` can now take a `OpenSSL::SSL::Context::Client` in addition to `true`.
* `HTTP::LogHandler` logs exceptions now (thanks @jhass)
* `HTTP::ErrorHandler` does not tell the client which exception occurred by default (can be enabled with a `verbose` flag) (thanks @jhass)
* Several bug fixes

## 0.17.4 (2016-05-26)

* Added string literals without interpolations nor escapes: `%q{...}` and `<<-'HEREDOC'`. Also added `%Q{...}` with the same meaning as `%{...}`.
* A method that uses `@type` inside a macro expression is now automatically detected as being a `macro def`
* `Float64#to_s` now produces a more accurate output
* Added `Crystal::VERSION` and other compiler-metadata constants
* Added `Object.from_json(string_or_io, root)` and a `root` option to `JSON.mapping`
* Added `System.hostname` (thanks @miketheman)
* The `property`, `getter` and `setter` macros now also accept assignments (`property x = 0`)
* The `record` macro now also accepts assignments (`record Point, x = 0, y = 0`)
* Comparison in macros between `MacroId` and `StringLiteral` or `SymbolLiteral` now work as expected (compares the `id` representation)
* Some bug fixes

## 0.17.3 (2016-05-20)

* Fixed: multiple macro runs executions didn't work well (#2624)
* Fixed incorrect formatting of underscore in unpacked block arguments
* Fixed wrong codegen for global variable assignment in type declaration (#2619)
* Fixed initialize default arguments where evaluated at the class scope (#731)
* The type guesser can now infer a block type from `def initialize(&@block)`
* Allow type restriction in double splat argument (similar to restriction in single splat)
* Allow splat restriction in splat argument (useful for `Tuple.new`)
* Allow double splat restriction in double splat argument (useful for `NamedTuple.new`)

## 0.17.2 (2016-05-18)

* Fixed crash when using pointerof of constant

## 0.17.1 (2016-05-18)

* Constants and class vars are no longer initialized before "main". Now their initialization order goes along with "main", similar to how it works in Ruby (much more intuitive)
* Added syntax for unpacking block arguments: `foo { |(x, y)| ... }`
* Added `NamedTupleLiteral#map` and `HashLiteral#map` in macros (thanks @jhass)
* Fixed wrong codgen for tuples/named tuples merge with pass-by-value types
* Formatter: fixed incorrect format for named tuple type

## 0.17.0 (2016-05-17)

* **(breaking change)** Macro defs are now parsed like regular methods. Enclose the body with `{% begin %} .. {% end %}` if you needed that behaviour
* **(breaking change)** A union of two tuples of the same size results in a tuple with the unions of the types in each position. This only affects code that later tested a tuple's type with `is_a?`, for example `tuple.is_a?({Int32, String})`
* **(breaking change)** Method arguments have now a different semantic. This only affects methods that had a splat argument followed by other arguments.
* **(breaking change)** The syntax `{foo: 1, bar: 2}` now denotes a `NamedTuple`, not a `Hash` with symbol as keys. Use `{:foo => 1, :bar => 2}` instead
* The syntax `exp as Type` is now deprecated and will be removed in the next version. Use `crystal tool format` to automatically upgrade your code
* The compiler now gives an error when trying to define a method named `!`, `is_a?`, `responds_to?`, `nil?`, `as` or `as?`
* Added the `NamedTuple` type
* Added double splatting
* Added external argument names
* Macro defs return type is no longer mandatory
* Added `as?`: similar to `as`, but returns `nil` when the type doesn't match
* Added `Number::Primitive` alias
* Added `Tuple#+(Tuple)`
* Added `ArrayLiteral#+(ArrayLiteral)` in macros
* `Crypto::MD5` now allows `Slice(UInt8)` and a block form (thanks @will)
* Added docs for XML (thanks @Hamdiakoguz)
* Many bug fixes

## 0.16.0 (2016-05-05)

* **(breaking change)** Instance, class and global variables types must be told to the compiler, [either explicitly or through a series of syntactic rules](http://crystal-lang.org/docs/syntax_and_semantics/type_inference.html)
* **(breaking change)** Non-abstract structs cannot be inherited anymore (abstract structs can), check the [docs](http://crystal-lang.org/docs/syntax_and_semantics/structs.html) to know why. In many cases you can use modules instead.
* **(breaking change)** Class variables are now initialized at the beginning of the program (before "main"), make sure to read the docs about [class variables](http://crystal-lang.org/docs/syntax_and_semantics/class_variables.html) and [main](http://crystal-lang.org/docs/syntax_and_semantics/the_program.html)
* **(breaking change)** Constants are now initialized at the beginning of the program (before "main"), make sure to read the docs about [constants](http://crystal-lang.org/docs/syntax_and_semantics/constants.html) and [main](http://crystal-lang.org/docs/syntax_and_semantics/the_program.html)
* **(breaking change)** When doing `crystal program.cr arg1 arg2 arg3`, `arg1`, `arg2` and `arg3` are considered arguments to pass to the program (not the compiler). Use `crystal run program.cr arg1 ...` to consider `arg1` a file to include in the compilation.
* **(breaking change)** `Int#**(Int)` now returns an integer, and raises if the argument is negative. Use a float base or exponent for negative exponents to work.
* **(breaking change)** `Slice#to_s` and `StaticArray#to_s` now include their type name in the output
* Support for FreeBSD and musl libc has landed (thanks @ysbaddaden)
* The `.crystal` directory is now created at `$HOME/.cache/crystal` or `$HOME/.crystal` (or others similar), with a fallback to the current directory
* `crystal doc` and `crystal tool hierarchy` are now much faster. Additionally, the hierarchy tool shows types for generic types, and doesn't show instantiations anymore (wasn't very useful)
* `!` now does type filtering (for example you can do `!x || x.bar`, assuming `x` can be `nil` and the non-nil type responds to `bar`)
* Named arguments can now match any argument, even if they don't have a default value. Make sure to read the [docs](http://crystal-lang.org/docs/syntax_and_semantics/default_and_named_arguments.html)
* The `as` operator can now be written as a method: `exp.as(Type)` in addition to `exp as Type`. The old syntax will be removed in a few releases.
* Added `@x : Int32 = 1` syntax (declaration + initialization)
* `new`/`initialize` logic now works more as one would expect
* Added `BigRational` (thanks @will)
* Added `BigFloat` (thanks @Exilor)
* Added `String#insert`
* Added `Time::EpochConverter` and `Time::EpochMillisConverter`
* Added `%s` (unix epoch) directive to `Time::Format`
* `Time` now honours Dayling Saving and `ENV["TZ"]`
* Added `HTTP::Server::Response#cookies` (thanks @jhass)
* Added `Array#bsearch`, `Array#bsearch_index` and `Range#bsearch` (thanks @MakeNowJust)
* Added `Range#reverse_each` iterator (thanks @omninonsense)
* `JSON::Any`: added `as_...?` methods (thanks @DougEverly)
* `JSON::Any` is now `Enumerable`
* `YAML::Any` is now `Enumerable`
* Added `JSON.parse_raw` that returns a `JSON::Type`
* `JSON::PullParser`: added `#read_raw` to read a JSON value as a raw string (useful for delayed parsing). Also added `String::RawConverter` to be used with `JSON.mapping`.
* `JSON` and `YAML`: enums, `BigInt` and `BigFloat` are now serializable
* `ENV`: allow passing `nil` as a value to delete an environment variable
* `Hash`: allow `Array | Tuple` arguments for `#select`, `#select!`, `#reject` and `#reject!`
* `Crypto::Subtle.constant_time_compare` now returns `Bool`, and it can compare two strings in addition to two slices (thanks @skunkworker)
* `HTTP::Server`: reset port zero after listening (thanks @splattael)
* Added `File#each_line` iterator
* Added `Number.slice`, `Number.static_array`, `Slice.[]` and `StaticArray.[]` to easily create slices and static arrays
* Added `Slice#hexdump` (thanks @will)
* Added `Enumerable#product` (thanks @dkhofer)
* Fix: disallow using `out` with `Void*` pointers
* Fixed bug in `XML::Node#namespace_scopes` (thanks @Hamdiakoguz)
* Added docs for `INIFile` (thanks @EvanHahn)
* Lots of bug fixes

## 0.15.0 (2016-03-31)

* **(breaking change)** `!` has now its meaning hardcoded in the language. If you defined it for a type it won't be invoked as a method anymore.
* **(breaking change)** `nil?` has now its meaning hardcoded in the language. If you defined it for a type it won't be invoked as a method anymore.
* **(breaking change)** `typeof` is now disallowed in `alias` declarations
* Added `crystal tool format --check` to check that source code is properly formatted
* `crystal play` (playground) added workbooks support, as well as improvements and stabilizations
* Added `Tempfile.dirname` (thanks @DougEverly)
* Added `Path#resolve` method in macros
* `{{...}}` arguments to a macro call are now expanded before macro invocation (#2392)
* Special variables (`$~` and `$?`) are now accessible after being defined in blocks (#2194)
* Some bugs and regressions fixed

## 0.14.2 (2016-03-22)

* Fixed regression with formatter (#2348)
* Fixed regression with block return types (#2347)
* Fixed regression with openssl (https://github.com/crystal-lang/crystal/commit/78c12caf2366b01f949046e78ad4dab65d0d80d4)

## 0.14.1 (2016-03-21)

* Fixed some regressions in the formatter

## 0.14.0 (2016-03-21)

* **(breaking change)** The syntax of a method argument with a default value and a type restriction is now `def foo(arg : Type = default_value)`. The old `def foo(arg = default_value : Type)` was removed.
* **(breaking change)** `Enumerable#take(n)` and `Iterator#take(n)` were renamed to `first(n)`
* **(breaking change)** `Socket#addr` and `Socket#peeraddr` were renamed to `local_address` and `remote_address` respectively
* **(breaking change)** Removed `Comparable#between?(a, z)`. Use `a <= x <= z` instead
* **(breaking change)** `HTTP::WebSocketHandler` callbacks can now access the `HTTP::Context`. If you had a forwarding method to it you'll need to update it. See #2313.
* New command `crystal play` that opens a playground for you to play in the browser :-) (thanks @bcardiff)
* New command `crystal env` that prints environment information
* `Spec`: you can now run multiple files with specified line numbers, as in `crystal spec file1.cr:10 file2.cr:20 ...`
* Initial support for musl-libc (thanks @ysbaddaden)
* Added `FileUtils.cp` (thanks @Dreauw)
* Added `Array#first(n)` and `Array#last(n)` (thanks @greyblake)
* Added `WebSocket#close` and properly handle disconnections
* Added `UDPSocket#send` and `UDPSocket#receive` (thanks @tatey)
* Added `Char#uppercase?` and `Char#lowercase?` (thanks @MaloJaffre`)
* Added `sync_close` property to `OpenSSL::SSL::Socket`, `Zlib::Inflate` and `Zlib::Deflate`
* Added `XML::Node#encoding` and `XML::Node#version`
* Added `HTTP::Client::Response#success?` (thanks @marceloboeira)
* Added `StaticArray#shuffle!(random)` (thanks @Nesqwik)
* Added `Splat#exp` method in macros
* Added fiber-safe `Mutex`
* All `Int` types (except `BigInt`) can now be used in `JSON` and `YAML` mappings (thanks @marceloboeira)
* Instance variable declarations/initializations now correctly work in generic classes and modules
* Lots of bug fixes

## 0.13.0 (2016-03-07)

* **(breaking change)** `Matrix` was moved to a separate shard: [https://github.com/Exilor/matrix](https://github.com/Exilor/Matrix)
* The syntax of a method argument with a default value and a type restriction is now `def foo(arg : Type = default_value)`. Run `crystal tool format` to automatically upgrade exsiting code to this new syntax. The old `def foo(arg = default_value : Type)` syntax will be removed in a next release.
* Special handling of `case` with a tuple literal. See [#2258](https://github.com/crystal-lang/crystal/pull/2258).
* Keywords can now be used for variable declaration, so `property end : Time` works as expected.
* Comparison of signed vs. unsigned integers now always give a correct result
* Allow declaring instance variables in non-generic module types (`module Moo; @x : Int32; end`)
* Allow initializing instance variables in non-generic module types (`module Moo; @x = 1; end`)
* `Spec`: allow setting multiple output formatters (thanks @marceloboeira)
* `StringScanner`: improved performance
* Added `foo.[0] = 1` and `foo.[0]` as valid syntax, similar to the one in `&.` blocks (thanks @MakeNowJust)
* `CSV`: allow separate and quote characters different than comma and doble quote (thanks @jreinert)
* `YAML`: support merge operator (`<<`) (thanks @jreinert)
* Allow redefining primitive methods like `Int32#+(other : Int32)`
* Allow defining macros with operator names like `[]`
* `Levenshtein`: improved performance (thanks @tcrouch)
* `HTTP::Client`: fixed incorrect parsing of chunked body
* `HTTP::Client`: added a constructor with an `URI` argument (thanks @plukevdh)
* `String`: `sub` and `gsub` now understand backreferences (thanks @bjmllr)
* `Random`: added `Random#rand(Float64)` and `Random#rand(Range(Float, Float))` (thanks @AlexWayfer)
* `HTML`: `HTLM.escape` includes more characters (thanks @Ryuuzakis)
* Added `TypeNode.class` method in macros (thanks @waterlink)
* `run` inside macros now also work with absolute paths (useful when used with `__DIR__`)
* Added docs for `Math` and `StaticArray` (thanks @Zavydiel, @HeleneMyr)
* Many bug fixes and some micro-optimizations

## 0.12.0 (2016-02-16)

* **(breaking change)** When used with a type declaration, the macros `property`, `getter`, `setter`, etc., declare instance variables with those types.
* **(breaking change)** `JSON.mapping` and `YAML.mapping` declare instance variables with the given types.
* **(breaking change)** `YAML.load` was renamed to `YAML.parse`, and it now returns a `YAML::Any`.
* **(breaking change)** `embed_ecr` and `ecr_file` were renamed to `ECR.embed` and `ECR.def_to_s` (the old methods now produce a warning and will be removed in the next release).
* Added encoding support: `IO#set_encoding`, `String#encode`, and `HTTP::Client` charset check.
* Segmentation faults are now trapped and shown in a more friendlier way.
* The `record` macro can now accept type declarations (for example `record Point, x : Int32, y : Int32`)
* Added `Iterator#step` (thanks @jhass)
* `Array#push` and `Array#unshift` can now accept multiple values and add the elements in an efficient way (thanks @arktisklada)
* Added `default` option to `JSON.mapping` (thanks @kostya)
* Added `default` option to `YAML.mapping` (thanks @jreinert)
* Allow doing `case foo; when Foo.class` (and `Foo(T)` and `Foo(T).class`) in case expressions.
* Added `Class#|` so a union type can be expresses as `Int32 | Char` in regular code.
* Added `File.real_path` (thanks @jreinert)
* Added `dns_timeout` for `HTTP::Client` (thanks @kostya)
* Added dynamic width precision to `sprintf` (thanks @gtramontina)
* `Markdown` now supports blockquotes and 1 level of list nesting (thanks @SebastianSzturo)
* `p` now accepts multiple arguments
* Many bug fixes and some optimizations

## 0.11.1 (2016-01-25)
* Fixed #2050, #2054, #2057, #2059, #2064
* Fixed bug: HTTP::Server::Response headers weren't cleared after each request
* Formatter would incorrectly change `property x :: Int32` to `property x = uninitialized Int32`

## 0.11.0 (2016-01-23)

* **(breaking change)** Syntax for type declarations changed from `var :: Type` to `var : Type`. The old syntax is still allowed but will be deprecated in the next version (run `crystal tool format` to automatically fix this)
* **(breaking change)** Syntax for uninitialized variables, which used to be `var :: Type`, is now `var = uninitialized Type`. The old syntax is still allowed but will be deprecated in the next version (run `crystal tool format` to automatically fix this)
* **(breaking change)** `HTTP::Server` refactor to support streaming. Check the [docs](http://crystal-lang.org/api/HTTP/Server.html) of `HTTP::Server` for upgrade instructions
* **(breaking change)** Renamed `HTTP::WebSocketSession` to `HTTP::WebSocket`.
* **(breaking change)** Heredocs now remove indentations according to the indentation of the closing identifier (thanks @rhysd)
* **(breaking change)** Renamed `Enumerable#inject` to `Enumerable#reduce`
* **(breaking change)** `next` and `return` semantic inside captured block has been swapped (#420)
* Fibers context switch is now faster, done with inline assembly. `libpcl` is no longer used
* Allow annotating the type of class and global variables
* Support comments in ECR (thanks @ysbaddaden)
* Security improvements to `HTTP::StaticFileHandler` (thanks @MakeNowJust)
* Moved `seek`, `tell`, `pos` and `pos=` from `File` to `IO::FileDescriptor` (affects `Tempfile`)
* `URI.parse` is now faster (thanks @will)
* Many bug fixes, some really old ones involving issues with order of declaration

## 0.10.2 (2016-01-13)

* Fixed Directory Traversal Vulnerability in HTTP::StaticFileHandler (thanks @MakeNowJust)

## 0.10.1 (2016-01-08)

* Added `Int#popcount` (thanks @rmosolgo)
* Added `@[Naked]` attribute for omitting a method's prelude
* Check that abstract methods are implemented by subtypes
* Some bug fixes

## 0.10.0 (2015-12-23)

* **(breaking change)** `def` arguments must always be enclosed in parentheses
* **(breaking change)** A space is now required before and after def return type restriction
* **(breaking change)** Renamed `Dir.working_dir` to `Dir.current`
* **(breaking change)** Moved `HTML::Builder` to [its own shard](https://github.com/crystal-lang/html_builder)
* **(breaking change)** `String#split` now always keeps all results (never drops trailing empty strings)
* **(breaking change)** Removed `Array#buffer`, `StaticArray#buffer` and `Slice#buffer`. Use `to_unsafe` instead (so unsafe usages are easier to spot)
* **(breaking change)** Removed `String#cstr`. Use `to_unsafe` instead (so unsafe usages are easier to spot)
* Optimized Range#sum (thanks @MakeNowJust)
* Allow forward declarations for lib external vars
* Added `Int#to_s(base)` for `base = 62` (thanks @jhass)
* `JSON.parse` now returns `JSON::Any`, which allows traversal of JSON objects with less casts
* Added `OpenSSL::PKCS5` (thanks @benoist)
* MemoryIO can now be created to read/write from a Slice(UInt8). In this mode MemoryIO can't be exapnded, and can optionally be written. And when creating a MemoryIO from a String, it's non-resizeable and read-only.
* Added `Object#!~` (the opposite of `=~`)
* `at_exit` now receives that exit status code in the block (thanks @MakeNowJust)
* Allow using `Set` in JSON mappings (thanks @benoist)
* Added `File.executable?`, `File.readable?` and `File.writeable?` (thanks @mverzilli)
* `Array#sort_by` and `Array#sort_by!` now use a [Schwartzian transform](https://en.wikipedia.org/wiki/Schwartzian_transform) (thanks @radarek)
* Added `Array#each_permutation`, `Array#each_combination` and `Array#each_repeated_combination` iterators
* Added optional *random* argument to `Array#sample` and `Array#shuffle`
* The `delegate` macro can now delegate multiple methods to an object (thanks @elthariel)
* Added basic YAML generation (thanks @porras)

## 0.9.1 (2015-10-30)

* Docs search now finds nested entries (thanks @adlerhsieh)
* Many corrections and changes to the formatter, for better consistency and less obtrusion.
* Added `OpenSSL::Cipher` and `OpenSSL::Digest` (thanks @benoist)
* Added `Char#+(String)` (thanks @hangyas)
* Added `Hash#key` and `Hash#key?` (thanks @adlerhsieh)
* Added `Time::Span#*` and `Time::Span#/` (thanks @jbaum98)
* Added `Slice#reverse_each` (thanks @omninonsense)
* Added docs for `Random` and `Tempfile` (thanks @adlerhsieh)
* Fixed some bugs.

## 0.9.0 (2015-10-16)

* **(breaking change)** The `CGI` module's funcionality has been moved to `URI` and `HTTP::Params`
* **(breaking change)** `IO#read()` is now `IO#gets_to_end`. Removed `IO#read(count)`, added `IO#skip(count)`
* **(breaking change)** `json_mapping` is now `JSON.mapping`. `yaml_mapping` is now `YAML.mapping`
* **(breaking change)** `StringIO` is now `MemoryIO`
* Added `crystal tool format` that automatically formats your code
* `protected` methods can now be invoked between types inside a same namespace
* Removed `curses`, you can use `https://github.com/jreinert/ncurses-crystal`
* `to_unsafe` and numeric conversions are now also automatically performed in C struct and union fields
* Added `{% begin %} ... {% end %}` as an alternative to `{% if true %} ... {% end %}`
* Added `~!` operator
* Added debug metadata for char, float, bool and enums. Also for classes and structs (experimental)
* `Dir.glob` now works well with recursive patterns like `**` (thanks @pgkos)
* Added `read_timeout` and `connect_timeout` to `HTTP::Client` (thanks @benoist)
* Added `Zlib` (thanks @datanoise and @bcardiff)
* Added `HTTP::DeflateHandler` (thanks @bcardiff)
* Added `ENV#fetch` (thanks @tristil)
* `Hash#new` now accepts an initialize capacity argument
* `HTTP::Request` provides access and mutation of `query`, `path` and `query_params` (thanks @waterlink)
* Added `XML::Node#content=` and `#name=`
* Allow passing handlers and a block to an `HTTP::Server` (thanks @RX14)
* `crystal init` now tries to use your github username if available (thanks @jreinert)
* Added `Hash#select`, `Hash#reject` and their bang variant, and `Hash#each_with_object` (thanks @devdazed)
* Added `Hash#select(*keys)` and `Hash#reject(*keys)` and their bang variant (thanks @sdogruyol)
* Added `Set#-`, `Set#^`, and `Set#subtract` (thanks @js-ojus)
* Allow running specs without colors (thanks @rhysd)
* Added `TypeNode#has_constant?` and `TypeNode#type_vars` in macros (thanks @jreinert)
* Added `String#compare` that allows case insensitive comparisons
* Added `File#truncate` (thanks @porras)
* `CSV` is now a class for iterating rows, optionally with headers access
* Allow setting multiple `before_request` callbacks to an `HTTP::Client`
* Added `Dir.cd(&block)` (thanks @rhysd)
* Added `Class#cast` (thanks @will)
* Fixes and additions to WebSocket, like the possibility of streaming data (thanks @jreinert)
* Added `SemanticVersion` class (thanks @technorama)
* `loop` now yields a counter
* Added `Array#[]=(index, count, value)` and `Array#[]=(range, value)`
* Added argless `sleep`
* `IO#write(slice)` now writes the full slice or raises on error
* Added some docs for ECR, Markdown, Hash, File, Time, Time::Span, Colorize, String, SecureRandom, YAML (thanks @adlerhsieh, @chdorner, @vjdhama, @rmosolgo)
* Many bug fixes

## 0.8.0 (2015-09-19)

* **(breaking change)** Renamed a couple of types: `ChannelClosed` -> `Channel::ClosedError`,
  `UnbufferedChannel` -> `Channel::Unbuffered`, `BufferedChannel` -> `Channel::Buffered`,
  `DayOfWeek` -> `Time::DayOfWeek`, `MonthSpan` -> `Time::MonthSpan`, `TimeSpan` -> `Time::Span`,
  `TimeFormat` -> `Time::Format`, `EmptyEnumerable` -> `Enumerable::EmptyError`, `SocketError` -> `Socket::Error`,
  `MatchData` -> `Regex::MatchData`, `SignedInt` -> `Int::Signed`, `UnsignedInt` -> `Int::Unsigned`,
  `FileDescriptorIO` -> `IO::FileDescriptor`, `BufferedIO` -> `IO::Buffered`, `CharReader` -> `Char::Reader`,
  `PointerAppender` -> `Pointer::Appender`.
* **(breaking change)** All places that raised `DomainError` raise `ArgumentError` now.
* **(breaking change)** Renamed `Type.cast` to `Type.new` (for example, `Int32.new` instead of `Int32.cast`)
* **(breaking change)** Removed all macro instance variables except `@type`
* **(breaking change)** Removed `undef`
* **(breaking change)** Removed `length()` and `count()` methods from collections. The only method for this is now `size`.
* **(breaking change)** Removed the ability to invoke methods on a union class
* Improved debugger support
* `crystal deps` now delegates to [shards](https://github.com/ysbaddaden/shards). Removed `Projecfile` support.
* Automatically convert numeric types when invoking C functions
* Automatically define questions methods for enum members
* Support quotes inside quoted symbols (thanks @wolflee)
* Allow marking `initialize` as private
* Added `method_added` macro hook (thanks @MakeNowJust)
* Added `ArrayLiteral#includes?(obj)` in macros
* Added `ASTNode#symbolize` in macros (thanks @kirbyfan64)
* Added experimental `yaml_mapping`
* Added nilable variants to `Enumerable#max`, `Enumerable#min`, and others (thanks @technorama)
* Added `Iterator#flatten` (thanks @jpellerin)
* Added setting a read timeout to `HTTP::Client` (thanks @benoist)
* Added `Array#delete_at(index, count)` and `Array#delete_at(range)` (thanks @tebakane)
* Added `HTTP::Cookies` (thanks @netfeed)
* Added `Tuple#reverse` (thanks @jhass)
* Added `Number#clamp` (thanks @technorama)
* Added serveral socket options (thanks @technorama)
* Added `WebSocket.open` (thanks @kumpelblase2)
* Added `Enum.flags` macro
* Added support for sending chunked content in HTTP server (thanks @bcardiff)
* Added `future`, `lazy` and `delay` concurrency methods (thanks @technorama)
* `fork` now returns a `Process` (thanks @technorama)
* Documented `Set`, and added a couple of methods (thanks @will)
* Nicer formatting in `Benchmark.ips`, and interactive mode (thanks @will)
* The `-f` format output is now honored in compiler errors (thanks @kirbyfan64)
* Fixed an ambiguity with the `crystal build` command (thanks @MakeNowJust)
* Cast exceptions now raise `TypeCastError` instead of `Exception` (thanks @will)
* Many bugs fixes

## 0.7.7 (2015-09-05)

* **(breaking change)** Reimplemented `Process.run` to allow configuring input, output and error, as well as behaving well regarding non-blocking IO (thanks @technorama)
* **(breaking change)** Removed the `alias_method` macro.
* **(breaking change)** Disallow declaring defs, classes and other declarations "dynamically" (for example inside an `if`... this of course didn't work, but incorrectly compiled).
* **(breaking change)** `require` is now only allowed at the top-level, never inside other types or methods.
* **(breaking change)** Removed `Nil#to_i`
* **(breaking change)** Changed API of `Channel#select` toward a thread-safe one.
* **(breaking change)** The two methods that IO must implement are now `read(slice : Slice(UInt8))` and `write(slice : Slice(UInt8))`.
* New beautiful, searchable and more functional API docs. Thanks @rosylilly for the initial design, and @BlaxPirit for some improvements.
* CLI: Moved `browser`, `hierarchy` and `types` to `crystal tool ...`
* Added `crystal tool context` and `crystal tool implementations` for IDEs (thanks @bcardiff!!)
* `Int#>>(amount)` and `Int#<<(amount)` now give zero when `amount` is greater than the number of bits of the integer representation.
* Added `\%` escape sequence inside macros.
* Added aliases for the many C types (thanks @BlaxPirit)
* Added `Iterator#in_groups_of` (thanks @PragTob)
* Added optional `offset` argument to `Hash#each_with_index` (thanks @sergey-kucher)
* Added `Array#combinations`, `Array#each_combination`, `Array#repeated_combinations`, `Array#each_repeated_combination`, `Array#repeated_permutations`, `Array#each_repeated_permutation`, `Array.product` and `Array.each_product` (thanks @kostya)
* Added `Array#rotate` and `Array#rotate!` (thanks @kostya)
* Added `MatchData#pre_match` and `MatchData#post_match` (thanks @bjmllr)
* Added `Array#flatten`
* Added `Range.reverse_each`, along with `Int#pred` and `Char#pred` (thanks @BlaxPirit)
* Added `XML.parse_html` (thanks @ryanworl)
* Added `ENV.keys` and`ENV.values` (thanks @will)
* Added `StaticArray==(other : StaticArray)` (thanks @tatey)
* Added `String#sub` in many variants (thanks @jhass)
* Added `Readline.bind_key`, `Readline.unbind_key`, `Readline.done` and `Readline.done=` (thanks @daphee)
* Added `Hash#all?`, `Hash#any?` and `Hash#inject` (thanks @jreinert)
* Added `File#pos` and `File#pos=`
* Added `Enum.from_value` and `Enum.from_value?`
* Added `Deque` (thanks @BlaxPirit)
* Added lots of methods to `StringScanner`, and documented it, making it usable (thanks @will)
* `StringIO` now quacks like a `File`.
* Allow sending masked data through a `WebSocket`, and sending long data (thanks @kumpelblase2)
* `File.new` now accepts an optional `perm` argument (thanks @technorama)
* `FileDescriptorIO` now has configurable read/write timeouts (thanks @technorama)
* Signal handling is more robust and allows any kind of code (thanks @technorama)
* Correctly handle `WebSocket` close packet (thanks @bebac)
* Correctly implement `seek` and `tell` in buffered IOs (thanks @lbguilherme)
* Allow setting several options on sockets (thanks @technorama)
* Some improvements to `crystal init` for the "app" case (thanks @krisleech)
* `sleep` and IO timeouts can receive `TimeSpan` as arguments (thanks @BlaxPirit)
* Handle `HTTP::Response` without content-length (thanks @lbguilherme)
* Added docs for OptionParser, ENV, Regex, Enumerable, Iterator and some Array methods (thanks @porras, @will, @bjmllr, @PragTob, @decioferreira)
* Lots of bug fixes and small improvements

## 0.7.6 (2015-08-13)

* **(breaking change)** removed support for trailing `while`/`until` ([read this](https://github.com/crystal-lang/crystal/wiki/FAQ#why-trailing-whileuntil-is-not-supported-unlike-ruby))
* **(breaking change)** Renamed `Enumerable#drop` to `Enumerable#skip`
* **(breaking change)** Renamed `Time.at` to `Time.epoch`, and `Time#to_i` and `Time#to_f` to `Time#epoch` and `Time#epoch_f`
* **(breaking change)** `inherited` macro now runs before a class' body
* Renamed `--no-build` flag to `--no-codegen`
* Allow interpolations in heredocs (thanks @jessedoyle)
* Allow hash substitutions in `String#%` and `sprintf` (thanks @zamith)
* Added `SecureRandom.base64`, `SecureRandom.urlsafe_base64` and `SecureRandom.uuid` (thanks @ysbaddaden)
* Added `File.link`, `File.symlink` and `File.symlink?` (thanks @ysbaddaden)
* Added `Enumerable#in_groups_of` (thanks @jalyna)
* Added `Array#zip?` (thanks @yui-knk)
* Added `Array#permutations` and `Array#each_permutation` (thanks @jalyna and @kostya)
* Added `IO#gets(limit : Int)` and `IO#gets(delimiter : Char, limit : Int)`
* Added `Iterator#compact_map`, `Iterator#take_while` and `Iterator#skip_while` (thanks @PragTob)
* Added `StringLiteral#to_i` macro method
* Added `Crypto::Bcrypt` (thanks @akaufmann)
* Added `Time.epoch_ms` and `Time#epoch_ms`
* Added `BitArray#toggle` and `BitArray#invert` (thanks @will)
* Fixed `IO#reopen` swapped semantic (thanks @technorama)
* Many bug fixes and improvements

## 0.7.5 (2015-07-30)

* **(breaking change)** `0` is not a prefix for octal numbers anymore. Use `0o`
* **(breaking change)** Renamed `MissingKey` to `KeyError`
* **(breaking change)** Renamed `IndexOutOfBounds` to `IndexError`
* Fixed all exception-handling related bugs.
* Allow nested and multiline ternary expressions (thanks @daviswahl)
* Allow assigning to `_` (underscore), give error when trying to read from it
* Macros can now also receive the following nodes: `And`, `Or`, `Case`, `RangeLiteral` and `StringInterpolation`. `And` and `Or` have `left` and `right` methods.
* Added `-e` option to `hierarchy` command to filter types by a regex
* Added `-v` as an alias of `--version`
* Added `-h` as an alias of `--help`
* Added `Array#transpose` (thanks @rhysd)
* Added `Benchmark#ips` (thanks @will)
* Added `Hash#merge(&block)` and `Hash#merge!(&block)` (thanks @yui-knk)
* Added `Hash#invert` (thanks @yui-knk)
* Added `Bool#^` (thanks @yui-knk)
* Added `Enumerable#drop`, `Enumerable#drop_while` and `Enumerable#take_while` (thanks @PragTob)
* Added `Enumerable#none?` (thanks @yui-knk)
* Added `Set#subset?`, `Set#superset?` and `Set#intersects?` (thanks @yui-knk)
* Added `Set#new(Enumerable)` (thanks @yui-knk)
* Added `String#succ` (thanks @porras and @Exilor)
* Added `Array#*` (thanks @porras)
* Added `Char#===(Int)` and `Int#===(Char)` (thanks @will)
* Added `StringLiteral#camelcase` and `StringLiteral#underscore` in macros
* Added `Expressions#expressions` in macros
* Added `Cast#obj` and `Cast#to` in macros
* Added `ASTNode#class_name` in macros (thanks @yui-knk)
* Added `Array#push`/`Array#<<` and `Array#unshift` in macros (thanks @ysbaddaden)
* Added `Def#visibility` in macros (thanks @ysbaddaden)
* Added `String#codepoints` and `String#each_codepoint` (thanks @jhass)
* `Char#to_i(base)` now supports bases from 2 to 36
* `Set#|` now correctly accepts a set of a possible different type (thanks @yui-knk)
* Flush `STDERR` on exit (thanks @jbbarth)
* `HTTP::Client` methods accept an optional block, which will yield an `HTTP::Response` with a non-nil `body_io` property to consume the response's IO
* Document `URI`, `UDPSocket` (thanks @davydovanton)
* Improved `URI` class (thanks @will)
* Define `$~` in `String#gsub` and `String#scan`
* Define `$?` in `Process.run`
* Lots of bug fixes and small improvements

## 0.7.4 (2015-06-23)

* Added Float module and remainder (thanks @wmoxam)
* Show elapsed time in HTTP::LogHandler (thanks @zamith for the suggestion)
* Added `0o` as a prefix for octal numbers (thanks @asb)
* Allow spaces before the closing tag of a heredoc (thanks @zamith)
* `String#split(Regex)` now includes captures in the results
* Added `union?`, `union_types` and `type_params` in macro methods
* Improved `MatchData#to_s` to show named groups (thanks @will)
* Optimized Base64 encode/decode (thanks @kostya)
* Added basic docs for spec (thanks @PragTob)
* Added docs for Benchmark (thanks @daneb)
* Added `ARGF`
* Non-matching regex captures now return `nil` instead of an empty string (thanks @will)
* Added `$1?`, `$2?`, etc., as a nilable alternative to `$1`, `$2`, etc.
* Added user, password, fragment and opaque to URI (thanks @will)
* `HTTP::Client.exec` now honors user/password info from URI
* Set default user agent in `HTTP::Client`
* Added `String#chop`
* Fixed `crystal deps` behaviour with empty git repositories (thanks @tkrajcar)
* Optimized `HTTP::Headers` and `HTTP::Request` parsing.
* `FileDescriptorIO` (superclass of `File` and `Socket`) has now buffering capabilities (use `sync=` and `sync?` to turn on/off). That means there's no need to use `BufferedIO` for these classes anymore.
* Allow `pointerof` with class and global variables, and also `foo.@bar` access
* Optimized fibers performance.
* Added inline assembly support.
* The `.crystal` cache dir is now configurable with an ENV variable (thanks @jhass)
* Generic type variables names can now also be a single letter followed by a digit.

## 0.7.3 (2015-06-07)

* Added `Tuple.from_json` and `Tuple.to_json`
* The `method_missing` macro now accepts a 1 argument variant that is a Call node. The 3 arguments variant will be deprecated.
* Flush STDOUT at program exit (fixes `print` not showing any output)
* Added `Time#to_utc` and `Time#to_local` (thanks @datanoise)
* Time comparison is now correct when comparing local vs. utc times
* Support timezone offsets in Time parsing and formatting
* Added `IO#gets(delimiter : String)`
* Added `String#chomp(Char)` and `String#chomp(String)`
* Allow invoking `debug()` inside a macro to see what's being generated.
* `IO#puts` and `IO#print` now receive a splat (thanks @rhysd)
* Added `Process.kill` and `Process.getpgid` (thanks @barachy)
* `Signal` is now an enum. Use it like `Signal::INT.trap { ... }` instead of `Signal.trap(Signal::INT) { ... }`
* Added `CSV.each_row` (both in block and iterator forms)
* Important fixes to non-blocking IO logic.

## 0.7.2 (2015-05-26)

* Improved performance of Regex
* Fixed lexing of octal characters and strings (thanks @rhysd)
* Time.parse can return UTC times (thanks @will)
* Handle dashes in `crystal init` (thanks @niftyn8)
* Generic type varaibles can now only be single letters (T, U, A, B, etc.)
* Support `%x` and `%X` in `sprintf` (thanks @yyyc514)
* Optimized `Int#to_s` (thanks @yyyc514)
* Added `upcase` option to `Int#to_s`, and use downcase by default.
* Improved `String#to_i` and fixed the many variants (`to_i8`, `to_u64`, etc.)
* Added `Time.at` (thanks @jeromegn)
* Added `Int#upto`, `Int#downto`, `Int#to` iterators.
* Added `Iterator#cons` and `Enumerable#each_cons` (thanks @porras)
* Added `Iterator.of`, `Iterator#chain` and `Iterator#tap`.
* Allow top-level `private macro` (similar to top-level `private def`)
* Optimized `BufferedIO` writing performance and memory usage.
* Added `Channel#close`, `Channel#closed?`, `Channel#receive?` and allow them to send/receive nil values (thanks @datanoise).
* Fixed `Process#run` after introducing non-blocking IO (thanks @will)
* `Tuple#map` now returns a `Tuple` (previously it returned an `Array`)
* `Tuple#class` now returns a proper `Class` (previously it returned a `Tuple` of classes)
* Lots of bug fixes.

## 0.7.1 (2015-04-30)

* Fixed [#597](https://github.com/crystal-lang/crystal/issues/597).
* Fixed [#599](https://github.com/crystal-lang/crystal/issues/599).

## 0.7.0 (2015-04-30)

* Crystal has evented IO by default. Added `spawn` and `Channel`.
* Correctly support the X86_64 and X86 ABIs. Now bindings to C APIs that pass and return structs works perfectly fine.
* Added `crystal init` to quickly create a skeleton library or application (thanks @waterlink)
* Added `--emit` flag to the compiler. Now you can easily see the generated LLVM IR, LLVM bitcode, assembly and object files.
* Added `--no-color` flag to suppress color output, useful for editor tools.
* Added macro vars: `%var` and `%var{x, y}` create uniqely named variables inside macros.
* Added [typed splats](https://github.com/crystal-lang/crystal/issues/291).
* Added `Iterator` and many methods that return iterators, like `Array#each`, `Hash#each`, `Int#times`, `Int#step`, `String#each_char`, etc.
* Added `sprintf` and improved `String#%` to support floats and float formatting.
* Added more variants of `String#gsub`.
* Added `Pointer#clear` and use it to clear an `Array`'s values when doing `pop` and other shrinking methods.
* Added `BigInt#to_s(base)`, `BigInt::cast` and bit operators (thanks @Exilor)
* Allow invoking methods on a union class as long as all types in the union have it.
* Allow specifying a def's return type. The compiler checks the return type only for that def for now (not for subclasses overrding the method). The return type appears in the documentation.
* Allow constants and computed constants for a StaticArray length.
* Allow class vars in enums.
* Allow private and protected defs in enums.
* Allow reopening a `lib` and adding more `@[Link]` attributes to it, even allowing duplicated attributes.
* Allow getting a function pointer to a lib fun without specifying its types (i.e. `->LibC.getenv`)
* Allow specifying `ditto` for a doc comment to reuse the previous comment.
* Changed the semantic of `%`: previously it meant `remainder`, not it means `modulo`, similar to Ruby and Python. Added `Int#remainder`.
* `#to_s` and `#inspect` now work for a union class.
* Spec: added global `before_each` and `after_each` hooks, which will simplify the use of mocking libraries like [timecop.cr](https://github.com/waterlink/timecop.cr) and [webmock.cr](https://github.com/manastech/webmock.cr).
* `Range(T)` is now `Range(B, E)` again (much more flexible).
* Improved Regex performance.
* Better XML support.
* Support LLVM 3.6.
* Exception class is now shown on unhandled exceptions
* The following types are now disallowed in generics (for now): Object, Value, Reference, Number, Int and Float.
* Lots of bug fixes, enhancements and optimizations.

## 0.6.1 (2015-03-04)

* The `class` method now works in all cases. You can now compare classes with `==` and ask their `hash` value.
* Block variables can now shadow local variables.
* `Range(B, E)` is now `Range(T)`.
* Added `Number::[]`. Now you can do `Int64[1, 2, 3]` instead of `[1_i64, 2_i64, 3_u64]`.
* Better detection of nilable instance variables, and better error messages too.
* Added `Crypto::Blowfish` (thanks @akaufmann)
* Added `Matrix` (thanks @Exilor)
* Added `CallConvention` attribute for `fun`s.
* Macros: added `constants` so you can inspect a type's constants at compile time.
* Macros: added `methods`, which lists a type's methods (without including supertypes).
* Macros: added `has_attribute?` for enum types, so you can check if an enum has the Flags attribute on it.
* Many more small additions and bug fixes.

## 0.6.0 (2015-02-12)

* Same as 0.5.10

## 0.5.10 (transitional) (2015-02-12)

* **Note**: This release makes core, breaking changes to the language, and doesn't work out of the box with its accompanying standard library. Use 0.6.0 instead.
* Improved error messages related to nilable instance variables.
* The magic variables `$~` and `$?` are now method-local and concurrent-safe.
* `Tuple` is now correctly considered a struct
* `Pointer` is now correctly considered a struct
* Renamed `Function` to `Proc`

## 0.5.9 (2015-02-07)

* `Random` is now a module, with static methods that default to the `Random::MT19937` class.
* Added `Random::ISAAC` engine (thanks @ysbaddaden!)
* Added `String#size` (thanks @zamith!)
* Added `limit` to all `String#split` variants (thanks @jhass!)
* Raising inside a Thread is now rescued and re-raised on join (thanks @jhass!)
* Added `path` option to Projectfile for `crystal deps` (thanks @naps62!)
* Many fixes towards making Crystal work on linux 32 bits.
* Huge refactors, additions and improvements for sockets: Socket, IPSocket, TCPSocket, TCPServer, UDPSocket, UNIXSocket, UNIXServer (thanks @ysbaddaden!)
* Allow regex with empty spaces in various places.
* Added `HTML.escape(String)` (thanks @naps62!)
* Added support for `%w[...]`, `%w{...}`, `%w<...>` as alternatives to `%w(...)`. Same goes for `%i(...)` (thanks @zamith!)
* Added `Enumerable#min_of`, `Enumerable#max_of` and `Enumerable#minmax_of`, `Enumerable#to_h`, `Dir.chdir` and `Number#fdiv` (thanks @jhass!)
* Added `String#match`, `String#[]`, `String#[]?` and `MatchData#[]?  ` related to regexes (thanks @jhass!)
* Allow `T::Bar` when T is a generic type argument.
* Added `subclasses` and `all_subclasses` in macros.
* Now you can invoke `to_s` and `inspect` on C structs and unions, making debugging C bindings much easier!
* Added `#to_f` and `#to_i` to `Time` and `TimeSpan` (thanks @epitron!)
* Added `IO.select` (thanks @jhass!)
* Now you can use `ifdef` inside C structs and unions.
* Added `include` inside C structs, to include other struct fields (useful for composition and avoiding an explicit indirection).
* Added `Char#in_set?`, `String#count`, `String#delete` and `String#squeeze` (thanks @jhass!)
* Added `-D flag` option to the compiler to set compile-time flags to use in `ifdef`.
* More support for forward declarations inside C libs.
* Rewritten some `Function` primitives in Crystal itself, and added methods for obtaining the pointer and closure data, as well as for recreating a function from these.
* Added a `Logger` class (thanks @ysbaddaden!)
* Lots of bugs fixed.

## 0.5.8 (2015-01-16)

* Added `Random` and `Random::MT19937` (Mersenne Twister) classes (thanks @rhysd).
* Docs: removed automatic linking. To link to classes and methods surround with backticks.
* Fixed [#328](https://github.com/crystal-lang/crystal/issues/328): `!=` bug.

## 0.5.7 (2015-01-02)

* Fixed: `doc` command had some hardcoded paths and didn't work
* Added: `private def` at the top-level of a file is only available inside that file

## 0.5.6 (2014-31-12)

* Added a `crystal doc` command to automatically generate documentation for a project using [Markdown](http://daringfireball.net/projects/markdown/) syntax. The style is still ugly but it's quite functional. Now we only need to start documenting things :-)
* Removed the old `@:` attribute syntax.
* Fixed [#311](https://github.com/crystal-lang/crystal/issues/311): Issues with invoking lib functions in other ways (thanks @scidom).
* Fixed [#314](https://github.com/crystal-lang/crystal/issues/314): NoReturn information is not lazy.
* Fixed [#317](https://github.com/crystal-lang/crystal/issues/317): Fixes in UTF-8 encoding/decoding (thanks @yous).
* Fixed [#319](https://github.com/crystal-lang/crystal/issues/319): Unexpected EOF (thanks @Exilor).
* `{{yield}}` inside macros now preserve the yielded node location, leading to much better error messages.
* Added `Float#nan?`, `Float#infinite?` and `Float#finite?`.
* Many other bug fixes and improvements.

## 0.5.5 (2014-12-12)

* Removed `src` and crystal compiler `libs` directory from CRYSTAL_PATH.
* Several bug fixes.

## 0.5.4 (2014-12-04)

* **(breaking change)** `require "foo"` always looks up in `CRYSTAL_PATH`. `require "./foo"` looks up relative to the requiring file.
* **(breaking change)** Renamed `Json` to `JSON`, `Xml` to `XML` and `Yaml` to `YAML` to follow [a convention](https://github.com/crystal-lang/crystal/issues/279).
* **(breaking change)** To use HTTP types do, for example, `require "http/client"` instead of the old `require "net/http"`.
* Added `alias_method` macro (thanks @Exilor and @jtomschroeder).
* Added some `Complex` number methods and many math methods, refactors and specs (thanks @scidom).
* Inheriting generic classes is now possible.
* Creating arrays of generic types (i.e.: `[] of Thread`) is now possible.
* Allow using an alias in a block type (i.e.: `alias F = Int32 ->`, `&block : F`).
* `json_mapping` macro supports a simpler syntax: `json_mapping({key1: Type1, key2: Type2})`.
* Spec: added `be_a(type)` matcher.
* Spec: added `be > ...` and similar matchers for `>=`, `<` and `<=`.
* Added `File::file?` and `File::directory?`.
* CSV parser can parse from String or IO.
* When invoking the compiler like this: `crystal foo.cr -o foo` the `build` command is assumed instead of `run`.
* Added short symbol notation for methods that are operators (i.e. `:+`, `:*`, `:[]`, etc.).
* Added `TimeSpan#ago`, `TimeSpan#from_now`, `MonthSpan#ago` and `MonthSpan#from_now`.

## 0.5.3 (2014-11-06)

* Spec: when a `should` or `should_not` fail, the filename and line number, including the source's line, is included in the error message.
* Spec: added `-l` switch to be able to run a spec defined in a line.
* Added `crystal spec file:line`
* Properties (property, setter, getter) can now be restricted to a type with the syntax `property name :: Type`.
* Enums can be used outside `lib`. They inherit `Enum`, can have methods and can be marked with @[Flags].
* Removed the distinction between `lib` enums and regular enums.
* Fixed: it was incorrectly possible to define `class`, `def`, etc. inside a call block.
* The syntax for specifying the base type of an enum, `enum Name < BaseType` has been deprecated. Use `enum Name : BaseType`.
* Added `Array#<=>` and make it comparable to other arrays.

## 0.5.2 (2014-11-04)

* New command line interface to the compiler (`crystal build ...`, `crystal run ...`, `crystal spec`, etc.). The default is to compiler and run a program.
* `crystal eval` without arguments reads from standard input.
* Added preliminar `crystal deps` command.
* `__FILE__`, `__DIR__` and `__LINE__`, when used as def default arguments, resolve to the caller location (similar to [D](http://dlang.org/traits.html#specialkeywords) and [Swift](https://developer.apple.com/swift/blog/?id=15))
* Allow `as` to determine a type even if the casted value doesn't have a type yet.
* Added `is_a?` in macros. The check is against an [AST node](https://github.com/crystal-lang/crystal/blob/master/src/compiler/crystal/syntax/ast.cr) name. For example `node.is_a?(HashLiteral)`.
* Added `emit_null` property to `json_mapping`.
* Added `converter` property to `json_mapping`.
* Added `pp` in macros.
* Added `to_pretty_json`.
* Added really basic `CSV.parse`.
* Added `Regex.escape`.
* Added `String#scan`.
* Added `-e` switch to spec, to run specs that match a pattern.
* Added `--fail-fast` swtich to spec.
* Added `HTTPClient#basic_auth`.
* Added `DeclareVar`, `Def` and `Arg` macro methods.
* Added `Time` and `TimeSpan` structs. `TimeWithZone` will come later.
* Added `Array#fill` (thanks @Exilor).
* Added `Array#uniq`.
* Optimized `File.read_lines`.
* Allow any expression inside `{% ... %}` so that you can intepret code without outputting the result.
* Allow `\` at the end of a line.
* Allow using `if` and `unless` inside macro expressions.
* Allow marking a `fun/def` as `@[Raises]` (useful when a function can potentially raise from a callback).
* Allow procs are now considered `@[Raises]`.
* `OAuth2::Client` supports getting an access token via authorization code or refresh token.
* Consecutive string literals are automatically concatenated by the parser as long as there is a `\` with a newline between them.
* Many bug fixes.

## 0.5.1 (2014-10-16)

* Added [json_mapping](https://github.com/crystal-lang/crystal/blob/master/spec/std/json/mapping_spec.cr) macro.
* Added [Signal](https://github.com/crystal-lang/crystal/blob/master/src/signal.cr) module.
* Added [Tempfile](https://github.com/crystal-lang/crystal/blob/master/src/tempfile.cr) class.
* Enhanced [HTTP::Client](https://github.com/crystal-lang/crystal/blob/master/src/net/http/client/client.cr).
* Added [OAuth::Consumer](https://github.com/crystal-lang/crystal/blob/master/libs/oauth/consumer.cr).
* Added [OAuth2::Client](https://github.com/crystal-lang/crystal/blob/master/libs/oauth2/client.cr).
* Added [OpenSSL::HMAC](https://github.com/crystal-lang/crystal/blob/master/libs/openssl/hmac.cr).
* Added [SecureRandom](https://github.com/crystal-lang/crystal/blob/master/src/secure_random.cr).
* New syntax for array/hash-like classes. For example: `Set {1, 2, 3}` and `HTTP::Headers {"content-type": "text/plain"}`. These just create the type and use `<<` or `[]=`.
* Optimized Json parsing performance.
* Added a [CSV builder](https://github.com/crystal-lang/crystal/blob/master/src/csv.cr#L13).
* XML reader can [parse from an IO](https://github.com/crystal-lang/crystal/blob/master/src/xml/reader.cr#L10).
* Added `Dir::glob` and `Dir::Entries` (thanks @jhass)
* Allow `ensure` as an expression suffix.
* Fixed [#219](https://github.com/crystal-lang/crystal/issues/219): Proc type is not inferred when passing to library fun and the return type doesn't match.
* Fixed [#224](https://github.com/crystal-lang/crystal/issues/224): Class#new doesn't pass a block.
* Fixed [#225](https://github.com/crystal-lang/crystal/issues/225): ICE when comparing void to something.
* Fixed [#227](https://github.com/crystal-lang/crystal/issues/227): Nested captured block looses scope and crashes compiler.
* Fixed [#228](https://github.com/crystal-lang/crystal/issues/228): Macro expansion doesn't retain symbol escaping as needed.
* Fixed [#229](https://github.com/crystal-lang/crystal/issues/229): Can't change block context if defined within module context.
* Fixed [#230](https://github.com/crystal-lang/crystal/issues/230): Type interference breaks equality operator.
* Fixed [#233](https://github.com/crystal-lang/crystal/issues/233): Incorrect `no block given` message with new.
* Other bug fixes.

## 0.5.0 (2014-09-24)

* String overhaul, and optimizations

## 0.4.5 (2014-09-24)

* Define backtick (`) for command execution.
* Allow string literals as keys in hash literals: `{"foo": "bar"} # :: Hash(String, String)`
* Allow `ifdef` as a suffix.
* Integer division by zero raises a `DivisionByZero` exception.
* Link attributes are now only processed if a lib function is used.
* Removed the `type Name : Type` syntax (use `type Name = Type` instead).
* Removed the `lib Lib("libname"); end` syntax. Use `@[Link]` attribute instead.
* Fixed some `require` issues.
* String representation includes length.
* Upgraded to LLVM 3.5.

## 0.4.4 (2014-09-17)

* Fixed [#193](https://github.com/crystal-lang/crystal/issues/193): allow initializing an enum value with another's one.
* The `record` macro is now variadic, so instead of `record Vec3, [x, y, z]` write `record Vec3, x, y, z`.
* The `def_equals`, `def_hash` and `def_equals_and_hash` macros are now variadic.
* The `property`, `getter` and `setter` macros are now variadic.
* All String methods are now UTF-8 aware.
* `String#length` returns the number of characters, while `String#bytesize` return the number of bytes (previously `length` returned the number of bytes and `bytesize` didn't exist).
* `String#[](index)` now returns a `Char` instead of an `UInt8`, where index is counted in characters. There's also `String#byte_at(index)`.
* Removed the `\x` escape sequence in char and string literals. Use `\u` instead.
* `initialize` methods are now protected.
* Added `IO#gets_to_end`.
* Added backticks (`...`) and `%x(...)` for command execution.
* Added `%r(...)` for regular expression literals.
* Allow interpolations in regular expresion literals.
* Compiling with `--release` sets a `release` flag that you can test with `ifdef`.
* Allow passing splats to C functions
* A C type can now be declared like `type Name = Type` (`type Name : Type` will be deprecated).
* Now a C struct/union type can be created with named arguments.
* New attributes syntax: `@[Attr(...)`] instead of `@:Attr`. The old syntax will be deprecated in a future release.
* New link syntax for C libs: `@[Link("name")]` (uses `name` as `pkg-config name` if available or `-lname` instead), `@[Link(ldflags: "...")]` to pass raw flags to the linker, `@[Link("name", static: true)]` to try to find a static library first, and `@[Link(framework: "AppKit")]` (for Mac OSX).
* Added an `exec` method to execute shell commands. Added the `system` and `backtick` similar to Ruby ones.
* Added `be_truthy` and `be_falsey` spec matchers. Added `Array#zip` without a block. (thanks @mjgpy3)
* Added `getter?` and `property?` macros to create methods that end with `?`.
* Added a `CGI` module.
* The compiler now only depends on `cc` for compiling (removed dependency to `llc`, `opt`, `llvm-dis` and `clang`).
* Added `IO#tty?`.
* Some bug fixes.

## 0.4.3 (2014-08-14)

* Reverted a commit that introduced random crashes.

## 0.4.2 (2014-08-13)

* Fixed [#187](https://github.com/crystal-lang/crystal/issues/185): mixing `yield` and `block.call` crashes the compiler.
* Added `\u` unicode escape sequences inside strings and chars (similar to Ruby). `\x` will be deprecated as it can generate strings with invalid UTF-8 byte sequences.
* Added `String#chars`.
* Fixed: splats weren't working in `initialize`.
* Added the `private` and `protected` visibility modifiers, with the same semantics as Ruby. The difference is that you must place them before a `def` or a macro call.
* Some bug fixes.

## 0.4.1 (2014-08-09)

* Fixed [#185](https://github.com/crystal-lang/crystal/issues/185): `-e` flag stopped working.
* Added a `@length` compile-time variable available inside tuples that allows to do loop unrolling.
* Some bug fixes.

## 0.4.0 (2014-08-08)

* Support splats in macros.
* Support splats in defs and calls.
* Added named arguments.
* Renamed the `make_named_tuple` macro to `record`.
* Added `def_equals`, `def_hash` and `def_equals_and_hash` macros to generate them from a list of fields.
* Added `Slice(T)`, which is a struct having a pointer and a length. Use this in IO for a safe API.
* Some `StaticArray` fixes and enhancements.

## 0.3.5 (2014-07-29)

* **(breaking change)** Removed the special `->` operator for pointers of structs/unions: instead of `foo->bar` use `foo.value.bar`; instead of `foo->bar = 1` use `foo.value.bar = 1`.
* Added `colorize` file that provides methods to easily output bash colors.
* Now you can use modules as generic type arguments (for example, do `x = [] of IO`).
* Added SSL sockets. Now HTTP::Server implements HTTPS.
* Macros have access to constants and types.
* Allow iterating a range in macros with `for`.
* Use cpu cycle counter to initialize random.
* `method_missing` now works in generic types.
* Fixed [#154](https://github.com/crystal-lang/crystal/issues/154): bug, constants are initialized before global variables.
* Fixed [#168](https://github.com/crystal-lang/crystal/issues/168): incorrect type inference of instance variables if not assigned in superclass.
* Fixed [#169](https://github.com/crystal-lang/crystal/issues/169): `responds_to?` wasn't working with generic types.
* Fixed [#171](https://github.com/crystal-lang/crystal/issues/171): ensure blocks are not executed if the rescue block returns from a def.
* Fixed [#175](https://github.com/crystal-lang/crystal/issues/175): invalid code generated when using with/yield with structs.
* Fixed some parser issues and other small issues.
* Allow forward struct/union declarations in libs.
* Added `String#replace(Regex, String)`
* Added a `Box(T)` class, useful for boxing value types to pass them to C as `Void*`.

## 0.3.4 (2014-07-21)

* Fixed [#165](https://github.com/crystal-lang/crystal/issues/165): restrictions with generic types didn't work for hierarchy types.
* Allow using a single underscore in restrictions, useful for matching against an n-tuple or an n-function where you don't care about the types (e.g.: `def foo(x : {_, _})`.
* Added a `generate_hash` macro that generates a `hash` methods based on some AST nodes.
* Added very basic `previous_def`: similar to `super`, but uses the previous definition of a method. Useful to decorate existing methods (similar to `alias_method_chain`). For now the method's type restrictions must match for a previous definition to be found.
* Made the compiler a bit faster
* Added `env` in macros, to fetch an environment value. Returns a StringLiteral if found or NilLiteral if not.
* Make `return 1, 2` be the same as `return {1, 2}`. Same goes with `break` and `next`.
* Added `Pointer#as_enumerable(size : Int)` to create an `Enumerable` from a Pointer with an associated size, with zero overhead. Some methods removed from `Pointer`: `each`, `map`, `to_a`, `index`.
* Added `StaticArray::new`, `StaticArray::new(value)`, `StaticArray::new(&block)`, `StaticArray#shuffle!` and `StaticArray#map!`.
* Faster `Char#to_s(io : IO)`

## 0.3.3 (2014-07-14)

* Allow implicit conversion to C types by defining a `to_unsafe` method. This removed the hardcoded rule for converting a `String` to `UInt8*` and also allows passing an `Array(T)` to an argument expecting `Pointer(T)`.
* Fixed `.is_a?(Class)` not working ([#162](https://github.com/crystal-lang/crystal/issues/162))
* Attributes are now associated to AST nodes in the semantic pass, not during parsing. This allows macros to generate attributes that will be attached to subsequent expressions.
* **(breaking change)** Make ENV#[] raise on missing key, and added ENV#[]?
* **(breaking change)** Macro defs are now written like `macro def name(args) : ReturnType` instead of `def name(args) : ReturnType`, which was a bit confusing.

## 0.3.2 (2014-07-10)

* Integer literals without a suffix are inferred to be Int32, Int64 or UInt64 depending on their value.
* Check that integer literals fit into their types.
* Put back `Int#to_s(radix : Int)` (was renamed to `to_s_in_base` in the previous release) by also specifying a restriction in `Int#to_s(io : IO)`.
* Added `expect_raises` macros in specs

## 0.3.1 (2014-07-09)

* **(breaking change)** Replaced `@name` inside macros with `@class_name`.
* **(breaking change)** Instance variables inside macros now don't have the `@` symbols in their names.

## 0.3.0 (2014-07-08)

* Added `Array#each_index`
* Optimized `String#*` for the case when the string has length one.
* Use `GC.malloc_atomic` for String and String::Buffer (as they don't contain internal pointers.)
* Added a `PointerAppender` struct to easily append to a `Pointer` while counting at the same time (thanks @kostya for the idea).
* Added a `Base64` module (thanks @kostya)
* Allow default arguments in macros
* Allow invoking `new` on a function type. For example: `alias F = Int32 -> Int32; f = F.new { |x| x + 1 }; f.call(2) #=> 3`.
* Allow omitting function argument types when invoking C functions that accept functions as arguments.
* Renamed `@name` to `@class_name` inside macros. `@name` will be deprecated in the next version.
* Added IO#read_fully
* Macro hooks: `inherited`, `included` and `extended`
* `method_missing` macro
* Added `{{ raise ... }}` inside macros to issue a compile error.
* Started JSON serialization and deserialization
* Now `at_exit` handlers are run when you invoke `exit`
* Methods can be marked as abstract
* New convention for `to_s` and `inspect`: you must override them receiving an IO object
* StringBuilder and StringBuffer have been replaced by StringIO

## 0.2.0 (2014-06-24)

* Removed icr (a REPL): it is abandoned for the moment because it was done in a hacky, non-reliable way
* Added very basic `String#underscore` and `String#camelcase`.
* The parser generates string literals out of strings with interpolated string literals. For example, `"#{__DIR__}/foo"` is interpolated at compile time and generates a string literal with the full path, since `__DIR__` is just a (special) string literal.
* **(breaking change)** Now macro nodes are always pasted as is. If you want to generate an id use `{{var.id}}`.

    Previously, a code like this:

    ```ruby
    macro foo(name)
      def {{name}}; end
    end

    foo :hello
    foo "hello"
    foo hello
    ```

    generated this:

    ```ruby
    def hello; end
    def hello; end
    def hello; end
    ```

    With this change, it generates this:

    ```ruby
    def :hello; end
    def "hello"; end
    def hello; end
    ```

    Now, to get an identifier out of a symbol literal, string literal or a name, use id:

    ```ruby
    macro foo(name)
      def {{name.id}}; end
    end
    ```

    Although it's longer to type, the implicit "id" call was sometimes confusing. Explicit is better than implicit.

    Invoking `id` on any other kind of node has no effect on the pasted result.
* Allow escaping curly braces inside macros with `\{`. This allows defining macros that, when expanded, can contain other macro expressions.
* Added a special comment-like pragma to change the lexer's filename, line number and column number.

    ```ruby
    # foo.cr
    a = 1
    #<loc:"bar.cr",12,24>b = 2
    c = 3
    ```

    In the previous example, `b = 2` (and the rest of the file) is considered as being parsed from file `bar.cr` at line 12, column 24.

* Added a special `run` call inside macros. This compiles and executes another Crystal program and pastes its output into the current program.

    As an example, consider this program:

    ```ruby
    # foo.cr
    {{ run("my_program", 1, 2, 3) }}
    ```

    Compiling `foo.cr` will, at compile-time, compile `my_program.cr` and execute it with arguments `1 2 3`. The output of that execution is pasted into `foo.cr` at that location.
* Added ECR (Embedded Crystal) support. This is implemented using the special `run` macro call.

    A small example:

    ```ruby
    # template.ecr
    Hello <%= @msg %>
    ```

    ```ruby
    # foo.cr
    require "ecr/macros"

    class HelloView
      def initialize(@msg)
      end

      # This generates a to_s method with the contents of template.ecr
      ecr_file "template.ecr"
    end

    view = HelloView.new "world!"
    view.to_s #=> "Hello world!"
    ```

    The nice thing about this is that, using the `#<loc...>` pragma for specifying the lexer's location, if you have a syntax/semantic error in the template the error points to the template :-)


## 0.1.0 (2014-06-18)

* First official release
