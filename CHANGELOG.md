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
* Added `@[Naked]` attribute for ommiting a method's prelude
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
# `Set#|` now correctly accepts a set of a possible different type (thanks @yui-knk)
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
* Added `--no-color` flag to supress color output, useful for editor tools.
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
* Allow ommiting function argument types when invoking C functions that accept functions as arguments.
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
* Added a special comment-like pragma to change the lexer's filename, line number and colum number.

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
