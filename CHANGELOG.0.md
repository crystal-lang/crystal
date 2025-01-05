# Changelog (pre 1.0)

Newer entries in [CHANGELOG.md](./CHANGELOG.md)

## [0.36.1] - 2021-02-02
[0.36.1]: https://github.com/crystal-lang/crystal/releases/0.36.1

### Standard library

- Fix `Enum.from_value?` for flag enum with non `Int32` base type. ([#10303](https://github.com/crystal-lang/crystal/pull/10303), thanks @straight-shoota)

#### Text

- Don't raise on `String.new` with `null` pointer and bytesize 0. ([#10308](https://github.com/crystal-lang/crystal/pull/10308), thanks @asterite)

#### Collections

- Explicitly return a `Hash` in `Hash#dup` and `Hash#clone` (reverts [#9871](https://github.com/crystal-lang/crystal/pull/9871)). ([#10331](https://github.com/crystal-lang/crystal/pull/10331), thanks @straight-shoota)

#### Serialization

- XML: fix deprecation warning. ([#10335](https://github.com/crystal-lang/crystal/pull/10335), thanks @bcardiff)

#### Runtime

- Eager load DWARF only if `CRYSTAL_LOAD_DWARF=1`. ([#10326](https://github.com/crystal-lang/crystal/pull/10326), thanks @bcardiff)

### Compiler

- **(performance)** Initialize right-away constants in a separate function. ([#10334](https://github.com/crystal-lang/crystal/pull/10334), thanks @asterite)
- Fix incorrect casting between different union types. ([#10333](https://github.com/crystal-lang/crystal/pull/10333), thanks @asterite)
- Fix a formatting error in the "missing argument" error. ([#10325](https://github.com/crystal-lang/crystal/pull/10325), thanks @BlobCodes)
- Fix while condition assignment check for Not. ([#10347](https://github.com/crystal-lang/crystal/pull/10347), thanks @asterite)
- Allow operators and setters-like macros names back. ([#10338](https://github.com/crystal-lang/crystal/pull/10338), thanks @asterite)

#### Language semantics

- Fix type check not considering virtual types. ([#10304](https://github.com/crystal-lang/crystal/pull/10304), thanks @asterite)
- Use path lookup when looking up type for auto-cast match. ([#10318](https://github.com/crystal-lang/crystal/pull/10318), thanks @asterite)

## [0.36.0] - 2021-01-26
[0.36.0]: https://github.com/crystal-lang/crystal/releases/0.36.0

### Language changes

- **(breaking-change)** Reject annotations on ivars defined in base class. ([#9502](https://github.com/crystal-lang/crystal/pull/9502), thanks @waj)
- **(breaking-change)** Make `**` be right associative. ([#9684](https://github.com/crystal-lang/crystal/pull/9684), thanks @asterite)

#### Macros

- **(breaking-change)** Deprecate `TypeNode#has_attribute?` in favor of `#annotation`. ([#9950](https://github.com/crystal-lang/crystal/pull/9950), thanks @HertzDevil)
- Support heredoc literal in macro. ([#9467](https://github.com/crystal-lang/crystal/pull/9467), thanks @MakeNowJust)
- Support `%Q`, `%i`, `%w`, and `%x` literals in macros. ([#9811](https://github.com/crystal-lang/crystal/pull/9811), thanks @toddsundsted)
- Allow executing multi-assignments in macros. ([#9440](https://github.com/crystal-lang/crystal/pull/9440), thanks @MakeNowJust)

### Standard library

- **(breaking-change)** Drop deprecated `CRC32`, `Adler32` top-level. ([#9530](https://github.com/crystal-lang/crystal/pull/9530), thanks @bcardiff)
- **(breaking-change)** Drop deprecated `Flate`, `Gzip`, `Zip`, `Zlib` top-level. ([#9529](https://github.com/crystal-lang/crystal/pull/9529), thanks @bcardiff)
- **(breaking-change)** Drop deprecated `with_color` top-level method. ([#9531](https://github.com/crystal-lang/crystal/pull/9531), thanks @bcardiff)
- **(breaking-change)** Make `SemanticVersion` parsing more strict. ([#9868](https://github.com/crystal-lang/crystal/pull/9868), thanks @hugopl)
- Respect explicitly provided type vars for `Tuple.new` and `NamedTuple.new`. ([#10047](https://github.com/crystal-lang/crystal/pull/10047), thanks @HertzDevil)
- Fix `OptionParser` to handle sub-commands with hyphen. ([#9465](https://github.com/crystal-lang/crystal/pull/9465), thanks @erdnaxeli)
- Fix `OptionParser` to not call handler if value is given to none value handler. ([#9603](https://github.com/crystal-lang/crystal/pull/9603), thanks @MakeNowJust)
- Make `def_equals` compare first by reference. ([#9650](https://github.com/crystal-lang/crystal/pull/9650), thanks @waj)
- Remove unnecessary `def ==(other)` fallbacks. ([#9571](https://github.com/crystal-lang/crystal/pull/9571), thanks @MakeNowJust)
- Fix `OptionParser` indentation of option descriptions. ([#10183](https://github.com/crystal-lang/crystal/pull/10183), thanks @wonderix)
- Add `#hash` to `Log::Metadata`, `Path`, `SemanticVersion`, `Socket::Address`, `URI::Params`, and `UUID`. ([#10119](https://github.com/crystal-lang/crystal/pull/10119), thanks @straight-shoota)
- Refactor several `case` statements with exhaustive `case`/`in`. ([#9656](https://github.com/crystal-lang/crystal/pull/9656), thanks @Sija)
- Remove `Kernel` mentions in docs. ([#9549](https://github.com/crystal-lang/crystal/pull/9549), thanks @toddsundsted)
- Improve docs for `Object#dup`. ([#10053](https://github.com/crystal-lang/crystal/pull/10053), thanks @straight-shoota)
- Fix example codes in multiple places. ([#9818](https://github.com/crystal-lang/crystal/pull/9818), thanks @maiha)
- Fix typos, misspelling and styling. ([#9636](https://github.com/crystal-lang/crystal/pull/9636), [#9638](https://github.com/crystal-lang/crystal/pull/9638), [#9561](https://github.com/crystal-lang/crystal/pull/9561), [#9786](https://github.com/crystal-lang/crystal/pull/9786), [#9840](https://github.com/crystal-lang/crystal/pull/9840), [#9844](https://github.com/crystal-lang/crystal/pull/9844), [#9854](https://github.com/crystal-lang/crystal/pull/9854), [#9869](https://github.com/crystal-lang/crystal/pull/9869), [#10068](https://github.com/crystal-lang/crystal/pull/10068), [#10123](https://github.com/crystal-lang/crystal/pull/10123), [#10102](https://github.com/crystal-lang/crystal/pull/10102), [#10116](https://github.com/crystal-lang/crystal/pull/10116), [#10229](https://github.com/crystal-lang/crystal/pull/10229), [#10252](https://github.com/crystal-lang/crystal/pull/10252), thanks @kubo, @m-o-e, @mgomes, @philipp-classen, @dukeraphaelng, @camreeves, @docelic, @ilmanzo, @Sija, @pxeger, @oprypin)

#### Macros

- Fix documentation for `#[]=` macro methods. ([#10025](https://github.com/crystal-lang/crystal/pull/10025), thanks @HertzDevil)

#### Numeric

- **(breaking-change)** Move `Complex#exp`, `Complex#log`, etc. to `Math.exp`, `Math.log` overloads. ([#9739](https://github.com/crystal-lang/crystal/pull/9739), thanks @cristian-lsdb)
- **(performance)** Use unchecked arithmetics in `Int#times`. ([#9511](https://github.com/crystal-lang/crystal/pull/9511), thanks @waj)
- Check for overflow when extending signed integers to unsigned integers. ([#10000](https://github.com/crystal-lang/crystal/pull/10000), thanks @HertzDevil)
- Fix `sprintf` for zero left padding a negative number. ([#9725](https://github.com/crystal-lang/crystal/pull/9725), thanks @asterite)
- Fix `BigInt#to_64` and `BigInt#hash`. ([#10121](https://github.com/crystal-lang/crystal/pull/10121), thanks @oprypin)
- Fix `BigDecimal#to_s` for numbers between `-1` and `0`. ([#9897](https://github.com/crystal-lang/crystal/pull/9897), thanks @dukeraphaelng)
- Fix `Number#step`. ([#10130](https://github.com/crystal-lang/crystal/pull/10130), [#10295](https://github.com/crystal-lang/crystal/pull/10295), thanks @straight-shoota, @bcardiff)
- Make `Complex` unary plus returns `self`. ([#9719](https://github.com/crystal-lang/crystal/pull/9719), thanks @asterite)
- Improve `Int#lcm` and `Int#gcd`. ([#9999](https://github.com/crystal-lang/crystal/pull/9999), thanks @HertzDevil)
- Add `Math::TAU`. ([#10179](https://github.com/crystal-lang/crystal/pull/10179), thanks @j8r)
- Add wrapped unary negation to unsigned integer types to allow `&- x` expressions. ([#9947](https://github.com/crystal-lang/crystal/pull/9947), thanks @HertzDevil)
- Improve documentation of mathematical functions. ([#9994](https://github.com/crystal-lang/crystal/pull/9994), thanks @HertzDevil)

#### Text

- **(breaking-change)** Fix `String#index` not working well for broken UTF-8 sequences. ([#9713](https://github.com/crystal-lang/crystal/pull/9713), thanks @asterite)
- **(performance)** `String`: Don't materialize `Regex` `match[0]` if not needed. ([#9615](https://github.com/crystal-lang/crystal/pull/9615), thanks @asterite)
- Fix `String#rindex` default offset for matching empty regex correctly. ([#9690](https://github.com/crystal-lang/crystal/pull/9690), thanks @MakeNowJust)
- Add various `String#delete_at` methods. ([#9398](https://github.com/crystal-lang/crystal/pull/9398), thanks @asterite)
- Raise if passing `null` Pointer to `String`. ([#9653](https://github.com/crystal-lang/crystal/pull/9653), thanks @jgaskins)
- Add `Regex#capture_count`. ([#9746](https://github.com/crystal-lang/crystal/pull/9746), thanks @Sija)
- Add `Regex::MatchData#[]` overloading to `Range`. ([#10076](https://github.com/crystal-lang/crystal/pull/10076), thanks @MakeNowJust)
- Fix duplicates in `String` documentation. ([#9987](https://github.com/crystal-lang/crystal/pull/9987), thanks @Nicolab)
- Add docs for substitution to `Kernel.sprintf`. ([#10227](https://github.com/crystal-lang/crystal/pull/10227), thanks @straight-shoota)

#### Collections

- **(breaking-change)** Make `Hash#reject!`, `Hash#select!`, and `Hash#compact!` consistent with `Array` and return `self`. ([#9904](https://github.com/crystal-lang/crystal/pull/9904), thanks @caspiano)
- **(breaking-change)** Deprecate `Hash#delete_if` in favor of `Hash#reject!`, add `Dequeue#reject!` and `Dequeue#select!`. ([#9878](https://github.com/crystal-lang/crystal/pull/9878), thanks @caspiano)
- **(breaking-change)** Change `Set#delete` to return Bool. ([#9590](https://github.com/crystal-lang/crystal/pull/9590), thanks @j8r)
- **(breaking-change)** Drop deprecated `Enumerable#grep`. ([#9711](https://github.com/crystal-lang/crystal/pull/9711), thanks @j8r)
- **(breaking-change)** Remove `Hash#key_index` . ([#10016](https://github.com/crystal-lang/crystal/pull/10016), thanks @asterite)
- **(breaking-change)** Deprecate `StaticArray#[]=(value)` in favor of `StaticArray#fill`. ([#10027](https://github.com/crystal-lang/crystal/pull/10027), thanks @HertzDevil)
- **(breaking-change)** Rename `Set#{sub,super}set?` to `{sub,super}set_of?`. ([#10187](https://github.com/crystal-lang/crystal/pull/10187), thanks @straight-shoota)
- **(performance)** Optimize `Array#shift` and `Array#unshift`. ([#10081](https://github.com/crystal-lang/crystal/pull/10081), thanks @asterite)
- **(performance)** `Array#rotate` optimization for small arrays. ([#8516](https://github.com/crystal-lang/crystal/pull/8516), thanks @wontruefree)
- ~~Fix `Hash#dup` and `Hash#clone` to return correct type for subclasses. ([#9871](https://github.com/crystal-lang/crystal/pull/9871), thanks @vlazar)~~ (Reverted by [#10331](https://github.com/crystal-lang/crystal/pull/10331) in 0.36.1)
- Fix `Iterator#cons_pair` return type. ([#9788](https://github.com/crystal-lang/crystal/pull/9788), thanks @asterite)
- Fix key type restriction of `Hash#merge` block. ([#9495](https://github.com/crystal-lang/crystal/pull/9495), thanks @MakeNowJust)
- Fix `Range#step`. ([#10203](https://github.com/crystal-lang/crystal/pull/10203), thanks @straight-shoota)
- Let `Range#step` delegate to `begin.step` and allow float based ranges to be stepped. ([#10209](https://github.com/crystal-lang/crystal/pull/10209), thanks @straight-shoota)
- Fix `Indexable#join` with `IO`. ([#10152](https://github.com/crystal-lang/crystal/pull/10152), thanks @straight-shoota)
- Fix `Flatten` for value-type iterators. ([#10096](https://github.com/crystal-lang/crystal/pull/10096), thanks @f-fr)
- Fix `Indexable.range_to_index_and_count` to not raise `IndexError`. ([#10191](https://github.com/crystal-lang/crystal/pull/10191), thanks @straight-shoota)
- Handle recursive structures in `def_clone`, `Hash`, `Array`, `Dequeue`. ([#9800](https://github.com/crystal-lang/crystal/pull/9800), thanks @asterite)
- Add `BitArray#dup`. ([#9550](https://github.com/crystal-lang/crystal/pull/9550), thanks @andremedeiros)
- Allow `Iterator#zip` to take multiple `Iterator` arguments. ([#9944](https://github.com/crystal-lang/crystal/pull/9944), thanks @HertzDevil)
- Add `Iterator#with_object(obj, &)`. ([#9956](https://github.com/crystal-lang/crystal/pull/9956), thanks @HertzDevil)
- Always clear unused bits of `BitArray`s. ([#10008](https://github.com/crystal-lang/crystal/pull/10008), thanks @HertzDevil)
- Update `Enumerable#sum(initial, &)` docs. ([#9860](https://github.com/crystal-lang/crystal/pull/9860), thanks @jage)
- Add `Array#unsafe_build`. ([#10092](https://github.com/crystal-lang/crystal/pull/10092), thanks @straight-shoota)
- Add identity methods for `#sum` and `#product`. ([#10151](https://github.com/crystal-lang/crystal/pull/10151), thanks @straight-shoota)
- Move `combinations`, `permutations`, etc., from `Array` to `Indexable`. ([#10235](https://github.com/crystal-lang/crystal/pull/10235), thanks @wonderix)
- Move sampling methods to `Enumerable`. ([#10129](https://github.com/crystal-lang/crystal/pull/10129), thanks @HertzDevil)
- Use `Set#add` in `Set#add` documentation. ([#9441](https://github.com/crystal-lang/crystal/pull/9441), thanks @hugopl)
- Improve `Hash#values_at` docs. ([#9955](https://github.com/crystal-lang/crystal/pull/9955), thanks @j8r)

#### Serialization

- **(breaking-change)** Drop deprecated `JSON.mapping`. ([#9527](https://github.com/crystal-lang/crystal/pull/9527), thanks @bcardiff)
- **(breaking-change)** Drop deprecated `YAML.mapping`. ([#9526](https://github.com/crystal-lang/crystal/pull/9526), thanks @bcardiff)
- Fix flag enum deserialization from `Int64`. ([#10145](https://github.com/crystal-lang/crystal/pull/10145), thanks @straight-shoota)
- Add support for selective JSON and YAML serialization. ([#9567](https://github.com/crystal-lang/crystal/pull/9567), thanks @stakach)
- YAML: correctly serialize `infinity` and `NaN`. ([#9780](https://github.com/crystal-lang/crystal/pull/9780), thanks @asterite)
- YAML: allow using discriminator in contained types. ([#9851](https://github.com/crystal-lang/crystal/pull/9851), thanks @asterite)
- Support more literal types in `JSON::Serializable.use_json_discriminator` macro. ([#9222](https://github.com/crystal-lang/crystal/pull/9222), thanks @voximity)
- Support more literal types in `YAML::Serializable.use_yaml_discriminator` macro. ([#10149](https://github.com/crystal-lang/crystal/pull/10149), thanks @straight-shoota)
- Add `JSON` serialization to big number types. ([#9898](https://github.com/crystal-lang/crystal/pull/9898), [#10054](https://github.com/crystal-lang/crystal/pull/10054), thanks @dukeraphaelng, @Sija)
- Handle namespaced defaults in `JSON::Serializable` and `YAML::Serializable`. ([#9733](https://github.com/crystal-lang/crystal/pull/9733), thanks @jgaskins)
- Standardize YAML error location. ([#9273](https://github.com/crystal-lang/crystal/pull/9273), thanks @straight-shoota)
- Update `YAML::Field(converter)` argument docs. ([#9557](https://github.com/crystal-lang/crystal/pull/9557), thanks @dscottboggs)
- Use `content` instead of `value` when inspect `XML::Attribute`. ([#9592](https://github.com/crystal-lang/crystal/pull/9592), thanks @asterite)
- Let `JSON::PullParser#on_key` yield self and return value. ([#10028](https://github.com/crystal-lang/crystal/pull/10028), thanks @straight-shoota)
- Cleanup `YAML`/`JSON` `Any#dig` methods. ([#9415](https://github.com/crystal-lang/crystal/pull/9415), thanks @j8r)
- Document `JSON::PullParser`. ([#9983](https://github.com/crystal-lang/crystal/pull/9983), thanks @erdnaxeli)
- Clarify Serialization Converter requirements and examples. ([#10202](https://github.com/crystal-lang/crystal/pull/10202), thanks @Daniel-Worrall)

#### Time

- **(breaking-change)** Drop deprecated `Time::Span.new` variants. ([#10051](https://github.com/crystal-lang/crystal/pull/10051), thanks @Sija)
- **(breaking-change)** Deprecate `Time::Span#duration`, use `Time::Span#abs`. ([#10144](https://github.com/crystal-lang/crystal/pull/10144), thanks @straight-shoota)
- Add `%Z` time format directive. ([#10141](https://github.com/crystal-lang/crystal/pull/10141), thanks @straight-shoota)
- Improve handling edge cases for `Time::Location#load`. ([#10140](https://github.com/crystal-lang/crystal/pull/10140), thanks @straight-shoota)
- Enable pending specs. ([#10093](https://github.com/crystal-lang/crystal/pull/10093), thanks @straight-shoota)
- Improve `Time::Span` arithmetic specs. ([#10143](https://github.com/crystal-lang/crystal/pull/10143), thanks @straight-shoota)

#### Files

- **(breaking-change)** Make `File.size` and `FileInfo#size` be `Int64` instead of `UInt64`. ([#10015](https://github.com/crystal-lang/crystal/pull/10015), thanks @asterite)
- **(breaking-change)** Fix `FileUtils.cp_r` when destination is a directory. ([#10180](https://github.com/crystal-lang/crystal/pull/10180), thanks @wonderix)
- Enable large-file support on i386-linux-gnu. ([#9478](https://github.com/crystal-lang/crystal/pull/9478), thanks @kubo)
- Fix glob not following symdir directories. ([#9910](https://github.com/crystal-lang/crystal/pull/9910), thanks @straight-shoota)
- Windows: allow creating symlinks without admin rights. ([#9767](https://github.com/crystal-lang/crystal/pull/9767), thanks @oprypin)
- Windows: allow touching directories. ([#10284](https://github.com/crystal-lang/crystal/pull/10284), thanks @straight-shoota)
- Fix `Dir.glob` when `readdir` doesn't report file type. ([#9877](https://github.com/crystal-lang/crystal/pull/9877), thanks @straight-shoota)
- Add `Path#stem`. ([#10037](https://github.com/crystal-lang/crystal/pull/10037), thanks @straight-shoota)
- Move `File#fsync`, `File#flock_exclusive`, `File#flock_shared`, and `File#flock_unlock` methods to `IO::FileDescriptor`. ([#9794](https://github.com/crystal-lang/crystal/pull/9794), thanks @naqvis)
- Call `IO#flush` on builder finish methods. ([#9321](https://github.com/crystal-lang/crystal/pull/9321), thanks @straight-shoota)
- Support using `Path` in `MIME` and `File::Error` APIs. ([#10034](https://github.com/crystal-lang/crystal/pull/10034), thanks @Blacksmoke16)
- Windows: enable `FileUtils` specs. ([#9902](https://github.com/crystal-lang/crystal/pull/9902), thanks @oprypin)

#### Networking

- **(breaking-change)** Rename `HTTP::Params` to `URI::Params`. ([#10098](https://github.com/crystal-lang/crystal/pull/10098), thanks @straight-shoota)
- **(breaking-change)** Rename `URI#full_path` to `URI#request_target`. ([#10099](https://github.com/crystal-lang/crystal/pull/10099), thanks @straight-shoota)
- **(breaking-change)** `URI::Params#[]=` replaces all values. ([#9605](https://github.com/crystal-lang/crystal/pull/9605), thanks @asterite)
- Fix type of `HTTP::Server::Response#closed?` to `Bool`. ([#9489](https://github.com/crystal-lang/crystal/pull/9489), thanks @straight-shoota)
- Fix `Socket#accept` to obey `read_timeout`. ([#9538](https://github.com/crystal-lang/crystal/pull/9538), thanks @waj)
- Fix `Socket` to allow datagram over unix sockets. ([#9838](https://github.com/crystal-lang/crystal/pull/9838), thanks @bcardiff)
- Fix `HTTP::Headers#==` and `HTTP::Headers#hash`. ([#10186](https://github.com/crystal-lang/crystal/pull/10186), thanks @straight-shoota)
- Make `HTTP::StaticFileHandler` serve pre-gzipped content. ([#9626](https://github.com/crystal-lang/crystal/pull/9626), thanks @waj)
- Delete `Content-Encoding` and `Content-Length` headers after decompression in `HTTP::Client::Response`. ([#5212](https://github.com/crystal-lang/crystal/pull/5212), thanks @maiha)
- Delay setup of `HTTP::CompressHandler` until content is written. ([#9625](https://github.com/crystal-lang/crystal/pull/9625), thanks @waj)
- Allow `HTTP::Client` to work with any IO. ([#9543](https://github.com/crystal-lang/crystal/pull/9543), thanks @waj)
- Make `HTTP::Server` don't override `content-length` if already set. ([#9726](https://github.com/crystal-lang/crystal/pull/9726), thanks @asterite)
- Do not share underlying hash between `URI::Param`s. ([#9641](https://github.com/crystal-lang/crystal/pull/9641), thanks @jgaskins)
- Add `HTTP::Cookie::SameSite::None`. ([#9262](https://github.com/crystal-lang/crystal/pull/9262), thanks @j8r)
- Add `HTTP::Client` logging and basic instrumentation. ([#9756](https://github.com/crystal-lang/crystal/pull/9756), thanks @bcardiff)
- Add `HTTP::Request#hostname`+ utils. ([#10029](https://github.com/crystal-lang/crystal/pull/10029), thanks @straight-shoota)
- Add `URI#authority`. ([#10100](https://github.com/crystal-lang/crystal/pull/10100), thanks @straight-shoota)
- Add `Socket::IPAddress#private?`. ([#9517](https://github.com/crystal-lang/crystal/pull/9517), thanks @jgillich)
- Make `Socket::IpAddress` a bit more type-friendly. ([#9528](https://github.com/crystal-lang/crystal/pull/9528), thanks @asterite)
- Make specs pass in non-IPv6 environments. ([#9438](https://github.com/crystal-lang/crystal/pull/9438), thanks @jhass)
- Make specs pending instead of failing in no multi-cast environments. ([#9566](https://github.com/crystal-lang/crystal/pull/9566), thanks @jhass)
- Remove invalid optimization on `Encoding`. ([#9724](https://github.com/crystal-lang/crystal/pull/9724), thanks @asterite)
- Drop `RemoteAddressType` private alias. ([#9777](https://github.com/crystal-lang/crystal/pull/9777), thanks @bcardiff)
- Add documentation for `HTTP::WebSocket`. ([#9761](https://github.com/crystal-lang/crystal/pull/9761), [#9778](https://github.com/crystal-lang/crystal/pull/9778), thanks @ibraheemdev, @bcardiff)
- Fix `HTTP` docs. ([#9612](https://github.com/crystal-lang/crystal/pull/9612), [#9627](https://github.com/crystal-lang/crystal/pull/9627), [#9717](https://github.com/crystal-lang/crystal/pull/9717), thanks @RX14, @asterite, @3n-k1)
- Fix reference to TCP protocol in docs. ([#9457](https://github.com/crystal-lang/crystal/pull/9457), thanks @dprobinson)

#### Logging

- **(breaking-change)** Drop deprecated `Logger`. ([#9525](https://github.com/crystal-lang/crystal/pull/9525), thanks @bcardiff)
- **(performance)** Add logging dispatcher to defer entry dispatch from current fiber. ([#9432](https://github.com/crystal-lang/crystal/pull/9432), thanks @waj)
- Take timestamp as an argument in `Log::Entry` initializer. ([#9570](https://github.com/crystal-lang/crystal/pull/9570), thanks @Sija)
- Improve docs regarding `Log.setup`. ([#9497](https://github.com/crystal-lang/crystal/pull/9497), [#9559](https://github.com/crystal-lang/crystal/pull/9559), thanks @caspiano, @jjlorenzo)

#### Crypto

- **(security)** Fix `"force-peer"` `verify_mode` setup. ([#9668](https://github.com/crystal-lang/crystal/pull/9668), thanks @PhilAtWysdom)
- **(security)** Force secure renegotiation on server to prevent Secure Client-Initiated Renegotiation vulnerability attack. ([#9815](https://github.com/crystal-lang/crystal/pull/9815), thanks @bcardiff)
- **(breaking-change)** Refactor `Digest` and introduce `Digest::MD5`, `Digest::SHA1`, `Digest::SHA256`, `Digest::SHA512` backed by openssl. ([#9864](https://github.com/crystal-lang/crystal/pull/9864), thanks @bcardiff)
- Fix overflows in MD5 and SHA1. ([#9781](https://github.com/crystal-lang/crystal/pull/9781), thanks @bcardiff)
- Add `OpenSSL::SSL::Context#set_modern_ciphers` and related methods to set ciphers and cipher suites in a more portable fashion. ([#9814](https://github.com/crystal-lang/crystal/pull/9814), [#10298](https://github.com/crystal-lang/crystal/pull/10298), thanks @bcardiff)
- Add `OpenSSL::SSL::Context#security_level`. ([#9831](https://github.com/crystal-lang/crystal/pull/9831), thanks @bcardiff)
- `OpenSSL::digest` add require for `OpenSSL::Error`. ([#10173](https://github.com/crystal-lang/crystal/pull/10173), thanks @wonderix)

#### Concurrency

- **(breaking-change)** Hide Channel internal implementation methods. ([#9564](https://github.com/crystal-lang/crystal/pull/9564), thanks @j8r)
- `Channel#close` returns `true` unless the channel was already closed. ([#9443](https://github.com/crystal-lang/crystal/pull/9443), thanks @waj)
- Support splat expressions inside `spawn` macro. ([#10234](https://github.com/crystal-lang/crystal/pull/10234), thanks @HertzDevil)
- Remove incorrect note about negative timeout not triggering. ([#10131](https://github.com/crystal-lang/crystal/pull/10131), thanks @straight-shoota)

#### System

- Fix `Process.find_executable` to check the found path is executable and add Windows support. ([#9365](https://github.com/crystal-lang/crystal/pull/9365), thanks @oprypin)
- Add `Process.parse_arguments` and fix `CRYSTAL_OPTS` parsing. ([#9518](https://github.com/crystal-lang/crystal/pull/9518), thanks @MakeNowJust)
- Port to NetBSD. ([#9360](https://github.com/crystal-lang/crystal/pull/9360), thanks @niacat)
- Add note about raising `IO::Error` to `Process` methods. ([#9894](https://github.com/crystal-lang/crystal/pull/9894), thanks @straight-shoota)
- Handle errors in `User`/`Group` `from_name?`/`from_id?` as not found. ([#10182](https://github.com/crystal-lang/crystal/pull/10182), thanks @wonderix)
- define the `SC_PAGESIZE` constant on more platforms. ([#9821](https://github.com/crystal-lang/crystal/pull/9821), thanks @carlhoerberg)

#### Runtime

- Fix bug with passing many args then a struct in Win64 C lib ABI. ([#9520](https://github.com/crystal-lang/crystal/pull/9520), thanks @oprypin)
- Fix C ABI for AArch64. ([#9430](https://github.com/crystal-lang/crystal/pull/9430), thanks @jhass)
- Disable LLVM Global Isel. ([#9401](https://github.com/crystal-lang/crystal/pull/9401), [#9562](https://github.com/crystal-lang/crystal/pull/9562), thanks @jhass, @bcardiff)
- Print original exception after failing to raise it. ([#9220](https://github.com/crystal-lang/crystal/pull/9220), thanks @jhass)
- Use Dwarf information on `Exception::CallStack.print_frame` and crash stacktraces. ([#9792](https://github.com/crystal-lang/crystal/pull/9792), [#9852](https://github.com/crystal-lang/crystal/pull/9852), thanks @bcardiff)
- `MachO`: Handle missing `LC_UUID`. ([#9706](https://github.com/crystal-lang/crystal/pull/9706), thanks @bcardiff)
- Allow `WeakRef` to compile with `-Dgc_none`. ([#9806](https://github.com/crystal-lang/crystal/pull/9806), thanks @bcardiff)
- Fix example in `Crystal.main` docs. ([#9736](https://github.com/crystal-lang/crystal/pull/9736), thanks @hugopl)
- Add a C ABI spec for accepting a large struct - failing on Win32, AArch64. ([#9534](https://github.com/crystal-lang/crystal/pull/9534), thanks @oprypin)
- Don't relativize paths outside of current directory in backtrace. ([#10177](https://github.com/crystal-lang/crystal/pull/10177), thanks @Sija)
- Avoid loading DWARF if env var `CRYSTAL_LOAD_DWARF=0`. ([#10261](https://github.com/crystal-lang/crystal/pull/10261), thanks @bcardiff)
- Fix DWARF loading in FreeBSD. ([#10259](https://github.com/crystal-lang/crystal/pull/10259), thanks @bcardiff)
- Print unhandled exceptions from main routine with `#inspect_with_backtrace`. ([#10086](https://github.com/crystal-lang/crystal/pull/10086), thanks @straight-shoota)

#### Spec

- **(breaking-change)** Add support for custom failure messages in expectations. ([#10127](https://github.com/crystal-lang/crystal/pull/10127), [#10289](https://github.com/crystal-lang/crystal/pull/10289), thanks @Fryguy, @straight-shoota)
- Allow absolute file paths in `crystal spec` CLI. ([#9951](https://github.com/crystal-lang/crystal/pull/9951), thanks @KevinSjoberg)
- Allow `--link-flags` to be used. ([#6243](https://github.com/crystal-lang/crystal/pull/6243), thanks @bcardiff)
- Improve duration display in `spec --profile`. ([#10044](https://github.com/crystal-lang/crystal/pull/10044), thanks @straight-shoota)
- Add exception handler in spec `at_exit`. ([#10106](https://github.com/crystal-lang/crystal/pull/10106), thanks @straight-shoota)

### Compiler

- **(performance)** Don't use init check for constants that are declared before read. ([#9801](https://github.com/crystal-lang/crystal/pull/9801), thanks @asterite)
- **(performance)** Don't use init check for class vars initialized before read. ([#9995](https://github.com/crystal-lang/crystal/pull/9995), thanks @asterite)
- **(performance)** Don't use init flag for string constants. ([#9808](https://github.com/crystal-lang/crystal/pull/9808), thanks @asterite)
- Run side effects for class var with constant initializer. ([#10010](https://github.com/crystal-lang/crystal/pull/10010), thanks @asterite)
- Fix `VaList` and disable `va_arg` for AArch64. ([#9422](https://github.com/crystal-lang/crystal/pull/9422), thanks @jhass)
- Fix cache corrupted when compilation is cancelled. ([#9558](https://github.com/crystal-lang/crystal/pull/9558), thanks @waj)
- Consider `select` as an opening keyword in macros. ([#9624](https://github.com/crystal-lang/crystal/pull/9624), thanks @asterite)
- Use function attribute `frame-pointer`. ([#9361](https://github.com/crystal-lang/crystal/pull/9361), thanks @kubo39)
- Make missing `__crystal_raise_overflow` error more clear. ([#9686](https://github.com/crystal-lang/crystal/pull/9686), thanks @3n-k1)
- Forbid calls with both block arg and block. ([#10026](https://github.com/crystal-lang/crystal/pull/10026), thanks @HertzDevil)
- Add method name to frozen type error. ([#10057](https://github.com/crystal-lang/crystal/pull/10057), thanks @straight-shoota)
- Use file lock to avoid clashes between compilations. ([#10050](https://github.com/crystal-lang/crystal/pull/10050), thanks @asterite)
- Add a couple of missing end locations to some nodes. ([#10012](https://github.com/crystal-lang/crystal/pull/10012), thanks @asterite)
- Don't visit enum member expanded by macro twice. ([#10105](https://github.com/crystal-lang/crystal/pull/10105), thanks @asterite)
- Fix crash when matching arguments against splat restriction after positional parameters. ([#10172](https://github.com/crystal-lang/crystal/pull/10172), thanks @HertzDevil)
- Fix parsing of `do end` blocks inside parenthesis. ([#10189](https://github.com/crystal-lang/crystal/pull/10189), [#10207](https://github.com/crystal-lang/crystal/pull/10207), thanks @straight-shoota, @Sija)
- Fix regex parsing after then in `case/when`. ([#10274](https://github.com/crystal-lang/crystal/pull/10274), thanks @asterite)
- Fix error message for non-exhaustive case statements of 3 or more `Bool`/`Enum` values. ([#10194](https://github.com/crystal-lang/crystal/pull/10194), thanks @HertzDevil)
- Forbid reopening generic types with different type var splats. ([#10167](https://github.com/crystal-lang/crystal/pull/10167), thanks @HertzDevil)
- Apply stricter checks to macro names. ([#10069](https://github.com/crystal-lang/crystal/pull/10069), thanks @HertzDevil)
- Reword error message when including/inheriting generic type without type vars. ([#10206](https://github.com/crystal-lang/crystal/pull/10206), thanks @HertzDevil)
- Print a message pointing to the online playground if compiled without it. ([#9622](https://github.com/crystal-lang/crystal/pull/9622), thanks @deiv)
- Handle typedef type restriction against alias type correctly. ([#9490](https://github.com/crystal-lang/crystal/pull/9490), thanks @MakeNowJust)
- Initial support LLVM 11.0 with known issue regarding optimizations [#10220](https://github.com/crystal-lang/crystal/issues/10220). ([#9829](https://github.com/crystal-lang/crystal/pull/9829), [#10293](https://github.com/crystal-lang/crystal/pull/10293), thanks @bcardiff)
- Add support for `--mcpu native`. ([#10264](https://github.com/crystal-lang/crystal/pull/10264), [#10276](https://github.com/crystal-lang/crystal/pull/10276), thanks @BlobCodes, @bcardiff)
- Fix `Process.run` uses in compiler to handle exec failure. ([#9893](https://github.com/crystal-lang/crystal/pull/9893), [#9911](https://github.com/crystal-lang/crystal/pull/9911), [#9913](https://github.com/crystal-lang/crystal/pull/9913), thanks @straight-shoota, @bcardiff, @oprypin)
- Fix `Command#report_warnings` to gracefully handle missing `Compiler#program`. ([#9866](https://github.com/crystal-lang/crystal/pull/9866), thanks @straight-shoota)
- Add `Program#host_compiler`. ([#9920](https://github.com/crystal-lang/crystal/pull/9920), thanks @straight-shoota)
- Add `Crystal::Path#name_size` implementation. ([#9380](https://github.com/crystal-lang/crystal/pull/9380), thanks @straight-shoota)
- Refactor helper methods in `call_error.cr`. ([#9376](https://github.com/crystal-lang/crystal/pull/9376), thanks @straight-shoota)
- Delegate def error location to implementing type. ([#10159](https://github.com/crystal-lang/crystal/pull/10159), thanks @straight-shoota)
- Refactor `Crystal::Exception` to `Crystal::CodeError`. ([#10197](https://github.com/crystal-lang/crystal/pull/10197), thanks @straight-shoota)
- Refactor `check_single_def_error_message`. ([#10196](https://github.com/crystal-lang/crystal/pull/10196), thanks @straight-shoota)
- Code clean-ups. ([#9468](https://github.com/crystal-lang/crystal/pull/9468), thanks @MakeNowJust)
- Refactors for compiler specs. ([#9379](https://github.com/crystal-lang/crystal/pull/9379), thanks @straight-shoota)
- Windows CI: Fix and enable compiler specs. ([#9348](https://github.com/crystal-lang/crystal/pull/9348), [#9560](https://github.com/crystal-lang/crystal/pull/9560), thanks @oprypin)

#### Language semantics

- **(breaking-change)** Handle union restrictions with free vars properly. ([#10267](https://github.com/crystal-lang/crystal/pull/10267), thanks @HertzDevil)
- **(breaking-change)** Disallow keywords as block argument name. ([#9704](https://github.com/crystal-lang/crystal/pull/9704), thanks @asterite)
- **(breaking-change)** Fix `a-b -c` incorrectly parsed as `a - (b - c)`. ([#9652](https://github.com/crystal-lang/crystal/pull/9652), [#9884](https://github.com/crystal-lang/crystal/pull/9884), thanks @asterite, @bcardiff)
- **(breaking-change)** Check abstract def implementations with splats, default values and keyword arguments. ([#9585](https://github.com/crystal-lang/crystal/pull/9585), thanks @waj)
- **(breaking-change)** Make abstract def return type warning an error. ([#9810](https://github.com/crystal-lang/crystal/pull/9810), thanks @bcardiff)
- **(breaking-change)** Error when abstract def implementation adds a type restriction. ([#9634](https://github.com/crystal-lang/crystal/pull/9634), thanks @waj)
- **(breaking-change)** Don't interpret Proc typedefs as aliases. ([#10254](https://github.com/crystal-lang/crystal/pull/10254), thanks @HertzDevil)
- **(breaking-change)** Remove the special logic of union of pointer and `nil`. ([#9872](https://github.com/crystal-lang/crystal/pull/9872), thanks @asterite)
- Check abstract def implementations with double splats. ([#9633](https://github.com/crystal-lang/crystal/pull/9633), thanks @waj)
- Make inherited hook work through generic instances. ([#9701](https://github.com/crystal-lang/crystal/pull/9701), thanks @asterite)
- Attach doc comment to annotation in macro expansion. ([#9630](https://github.com/crystal-lang/crystal/pull/9630), thanks @MakeNowJust)
- Marks else branch of exhaustive case as unreachable, improving resulting type. ([#9659](https://github.com/crystal-lang/crystal/pull/9659), thanks @Sija)
- Make `Pointer(T)#value=` stricter for generic arguments. ([#10224](https://github.com/crystal-lang/crystal/pull/10224), thanks @asterite)
- Extend type filtering of conditional clauses to arbitrary logical connectives. ([#10147](https://github.com/crystal-lang/crystal/pull/10147), thanks @HertzDevil)
- Support NamedTuple instance restrictions in redefinition checks. ([#10245](https://github.com/crystal-lang/crystal/pull/10245), thanks @HertzDevil)
- Respect block arg restriction when given block has a splat parameter. ([#10242](https://github.com/crystal-lang/crystal/pull/10242), thanks @HertzDevil)
- Make overloads without double splat more specialized than overloads with one. ([#10185](https://github.com/crystal-lang/crystal/pull/10185), thanks @HertzDevil)
- Support type splats inside explicit Unions in type restrictions. ([#10174](https://github.com/crystal-lang/crystal/pull/10174), thanks @HertzDevil)
- Fix splats on generic arguments. ([#9859](https://github.com/crystal-lang/crystal/pull/9859), thanks @asterite)
- Correctly compute line number after macro escape. ([#9858](https://github.com/crystal-lang/crystal/pull/9858), thanks @asterite)
- Fix bug for C structs assigned to a type. ([#9743](https://github.com/crystal-lang/crystal/pull/9743), thanks @matthewmcgarvey)
- Promote C variadic args as needed. ([#9747](https://github.com/crystal-lang/crystal/pull/9747), thanks @asterite)
- Fix parsing of `def self./` and `def self.%`. ([#9721](https://github.com/crystal-lang/crystal/pull/9721), thanks @asterite)
- Fix `ASTNode#to_s` for parenthesized expression in block. ([#9629](https://github.com/crystal-lang/crystal/pull/9629), thanks @MakeNowJust)
- Don't form a closure on `typeof(@ivar)`. ([#9723](https://github.com/crystal-lang/crystal/pull/9723), thanks @asterite)
- Add a few missing `expanded.transform self`. ([#9506](https://github.com/crystal-lang/crystal/pull/9506), thanks @asterite)
- Treat `super` as special only if it doesn't have a receiver (i.e.: allow `super` user defined methods). ([#10011](https://github.com/crystal-lang/crystal/pull/10011), thanks @asterite)
- Implement auto-casting in a better way. ([#9501](https://github.com/crystal-lang/crystal/pull/9501), thanks @asterite)
- Try literal type first when autocasting to unions types. ([#9610](https://github.com/crystal-lang/crystal/pull/9610), thanks @asterite)
- Correctly pass named arguments for `previous_def` and `super`. ([#9834](https://github.com/crystal-lang/crystal/pull/9834), thanks @asterite)
- Turn proc pointer into proc literal in some cases to closure needed variables. ([#9824](https://github.com/crystal-lang/crystal/pull/9824), thanks @asterite)
- Fix proc of self causing multi-dispatch. ([#9972](https://github.com/crystal-lang/crystal/pull/9972), thanks @asterite)
- Fixes and improvements to closured variables. ([#9986](https://github.com/crystal-lang/crystal/pull/9986), thanks @asterite)
- Don't merge proc types but allow assigning them if they are compatible. ([#9971](https://github.com/crystal-lang/crystal/pull/9971), thanks @asterite)
- Reset nilable vars inside block method. ([#10091](https://github.com/crystal-lang/crystal/pull/10091), thanks @asterite)
- Reset free vars before attempting each overload match. ([#10271](https://github.com/crystal-lang/crystal/pull/10271), thanks @HertzDevil)
- Let `offsetof` support `Tuples`. ([#10218](https://github.com/crystal-lang/crystal/pull/10218), thanks @hugopl)

### Tools

- Fetch git config correctly. ([#9640](https://github.com/crystal-lang/crystal/pull/9640), thanks @dorianmariefr)

#### Formatter

- Avoid adding a newline after comment before end. ([#9722](https://github.com/crystal-lang/crystal/pull/9722), thanks @asterite)
- Apply string pieces combination even if heredoc has no indent. ([#9475](https://github.com/crystal-lang/crystal/pull/9475), thanks @MakeNowJust)
- Correctly format named arguments like `foo:bar`. ([#9740](https://github.com/crystal-lang/crystal/pull/9740), thanks @asterite)
- Handle comment before do in a separate line. ([#9762](https://github.com/crystal-lang/crystal/pull/9762), thanks @asterite)
- Fix indent for the first comment of `select when`/`else`. ([#10002](https://github.com/crystal-lang/crystal/pull/10002), thanks @MakeNowJust)
- Reduce redundant newlines at end of `begin ... end`. ([#9741](https://github.com/crystal-lang/crystal/pull/9741), thanks @MakeNowJust)
- Let formatter normalize crystal language tag for code blocks in doc comments. ([#10156](https://github.com/crystal-lang/crystal/pull/10156), thanks @straight-shoota)
- Fix indentation of trailing comma in call with a block. ([#10223](https://github.com/crystal-lang/crystal/pull/10223), thanks @MakeNowJust)

#### Doc generator

- Linkification: refactor, fix edge cases and add specs. ([#9817](https://github.com/crystal-lang/crystal/pull/9817), thanks @oprypin)
- Exclude types from docs who are in nodoc namespaces. ([#9819](https://github.com/crystal-lang/crystal/pull/9819), thanks @Blacksmoke16)
- Fix link generation for lib type reference. ([#9931](https://github.com/crystal-lang/crystal/pull/9931), thanks @straight-shoota)
- Correctly render underscores in code blocks. ([#9822](https://github.com/crystal-lang/crystal/pull/9822), thanks @Blacksmoke16)
- Fix some HTML in docs generator. ([#9918](https://github.com/crystal-lang/crystal/pull/9918), thanks @straight-shoota)
- Correctly handle broken source code on syntax highlighting. ([#9416](https://github.com/crystal-lang/crystal/pull/9416), thanks @MakeNowJust)
- Re-introduce canonical URL for docs generator. ([#9917](https://github.com/crystal-lang/crystal/pull/9917), thanks @straight-shoota)
- Expose `"location"` and `"args_html"` in doc JSON. ([#10122](https://github.com/crystal-lang/crystal/pull/10122), [#10200](https://github.com/crystal-lang/crystal/pull/10200), thanks @oprypin)
- Expose `"aliased_html"` in doc JSON, make `"aliased"` field nullable. ([#10117](https://github.com/crystal-lang/crystal/pull/10117), thanks @oprypin)
- Support linking to section headings in same tab. ([#9826](https://github.com/crystal-lang/crystal/pull/9826), thanks @Blacksmoke16)
- Do not highlight `undef` as a keyword, it's not. ([#10216](https://github.com/crystal-lang/crystal/pull/10216), thanks @rhysd)

### Others

- CI improvements and housekeeping. ([#9507](https://github.com/crystal-lang/crystal/pull/9507), [#9513](https://github.com/crystal-lang/crystal/pull/9513), [#9512](https://github.com/crystal-lang/crystal/pull/9512), [#9515](https://github.com/crystal-lang/crystal/pull/9515), [#9514](https://github.com/crystal-lang/crystal/pull/9514), [#9609](https://github.com/crystal-lang/crystal/pull/9609), [#9642](https://github.com/crystal-lang/crystal/pull/9642), [#9758](https://github.com/crystal-lang/crystal/pull/9758), [#9763](https://github.com/crystal-lang/crystal/pull/9763), [#9850](https://github.com/crystal-lang/crystal/pull/9850), [#9906](https://github.com/crystal-lang/crystal/pull/9906), [#9907](https://github.com/crystal-lang/crystal/pull/9907), [#9912](https://github.com/crystal-lang/crystal/pull/9912), [#10078](https://github.com/crystal-lang/crystal/pull/10078), [#10217](https://github.com/crystal-lang/crystal/pull/10217), [#10255](https://github.com/crystal-lang/crystal/pull/10255), thanks @jhass, @bcardiff, @waj, @oprypin, @j8r, @Sija)
- Add timeout to individual specs on multi-threading. ([#9865](https://github.com/crystal-lang/crystal/pull/9865), thanks @bcardiff)
- Initial AArch64 CI. ([#9508](https://github.com/crystal-lang/crystal/pull/9508), [#9582](https://github.com/crystal-lang/crystal/pull/9582), thanks @jhass, @waj)
- Update distribution-scripts and use LLVM 10 on Linux packages. ([#9710](https://github.com/crystal-lang/crystal/pull/9710), thanks @bcardiff)
- Update distribution-scripts and publish nightly packages to bintray. ([#9663](https://github.com/crystal-lang/crystal/pull/9663), thanks @bcardiff)
- Update distribution-scripts to use Shards v0.13.0. ([#10280](https://github.com/crystal-lang/crystal/pull/10280), thanks @bcardiff)
- Initial Nix development environment. Use Nix for OSX CI instead of homebrew. ([#9727](https://github.com/crystal-lang/crystal/pull/9727), [#9776](https://github.com/crystal-lang/crystal/pull/9776), thanks @bcardiff)
- Prevent recursive call in `bin/crystal` wrapper. ([#9505](https://github.com/crystal-lang/crystal/pull/9505), thanks @jhass)
- Allow overriding `CRYSTAL_PATH` in `bin/crystal` wrapper . ([#9632](https://github.com/crystal-lang/crystal/pull/9632), thanks @bcardiff)
- Makefile: support changing the current crystal via env var and argument. ([#9471](https://github.com/crystal-lang/crystal/pull/9471), thanks @bcardiff)
- Makefile: improve supported LLVM versions message. ([#10221](https://github.com/crystal-lang/crystal/pull/10221), [#10269](https://github.com/crystal-lang/crystal/pull/10269), thanks @rdp, @straight-shoota)
- Update CONTRIBUTING.md. ([#9448](https://github.com/crystal-lang/crystal/pull/9448), [#10249](https://github.com/crystal-lang/crystal/pull/10249), [#10250](https://github.com/crystal-lang/crystal/pull/10250), thanks @wontruefree, @sanks64, @straight-shoota)
- Refactor `RedBlackTree` sample to use an enum instead of symbols. ([#10233](https://github.com/crystal-lang/crystal/pull/10233), thanks @Sija)
- Add security policy. ([#9984](https://github.com/crystal-lang/crystal/pull/9984), thanks @straight-shoota)
- Use `name: nightly` in docs-versions.sh for HEAD. ([#9915](https://github.com/crystal-lang/crystal/pull/9915), thanks @straight-shoota)
- Use canonical base url for generating docs. ([#10007](https://github.com/crystal-lang/crystal/pull/10007), thanks @straight-shoota)
- Remove Vagrantfile. ([#10033](https://github.com/crystal-lang/crystal/pull/10033), thanks @straight-shoota)
- Update NOTICE's copyright year to 2021. ([#10166](https://github.com/crystal-lang/crystal/pull/10166), thanks @matiasgarciaisaia)

## [0.35.1] - 2020-06-19
[0.35.1]: https://github.com/crystal-lang/crystal/releases/0.35.1

### Standard library

#### Collections

- Remove `Hash#each` type restriction to allow working with splats. ([#9456](https://github.com/crystal-lang/crystal/pull/9456), thanks @bcardiff)

#### Networking

- Revert `IO#write` changes in 0.35.0 and let it return Nil. ([#9469](https://github.com/crystal-lang/crystal/pull/9469), thanks @bcardiff)
- Avoid leaking logging context in HTTP request handlers. ([#9494](https://github.com/crystal-lang/crystal/pull/9494), thanks @Blacksmoke16)

#### Crypto

- Use less strict cipher compatibility for OpenSSL client context. ([#9459](https://github.com/crystal-lang/crystal/pull/9459), thanks @straight-shoota)
- Fix `Digest::Base` block argument type restrictions. ([#9500](https://github.com/crystal-lang/crystal/pull/9500), thanks @straight-shoota)

#### Logging

- Fix `Log.context.set` docs for hash based data. ([#9470](https://github.com/crystal-lang/crystal/pull/9470), thanks @bcardiff)

### Compiler

- Show warnings even if there are errors. ([#9461](https://github.com/crystal-lang/crystal/pull/9461), thanks @asterite)
- Fix parsing of `{foo: X, typeof: Y}` type. ([#9453](https://github.com/crystal-lang/crystal/pull/9453), thanks @MakeNowJust)
- Fix parsing of proc in hash `of` key type. ([#9458](https://github.com/crystal-lang/crystal/pull/9458), thanks @MakeNowJust)
- Revert debug level information changes in specs to fix 32 bits builds. ([#9466](https://github.com/crystal-lang/crystal/pull/9466), thanks @bcardiff)

### Others

- CI improvements and housekeeping. ([#9455](https://github.com/crystal-lang/crystal/pull/9455), thanks @bcardiff)
- Code formatting. ([#9482](https://github.com/crystal-lang/crystal/pull/9482), thanks @MakeNowJust)

## [0.35.0] - 2020-06-09
[0.35.0]: https://github.com/crystal-lang/crystal/releases/0.35.0

### Language changes

- **(breaking-change)** Let `case when` be non-exhaustive, introduce `case in` as exhaustive. ([#9258](https://github.com/crystal-lang/crystal/pull/9258), [#9045](https://github.com/crystal-lang/crystal/pull/9045), thanks @asterite)
- Allow `->@ivar.foo` and `->@@cvar.foo` expressions. ([#9268](https://github.com/crystal-lang/crystal/pull/9268), thanks @MakeNowJust)

#### Macros

- Allow executing OpAssign (`+=`, `||=`, etc.) inside macros. ([#9409](https://github.com/crystal-lang/crystal/pull/9409), thanks @asterite)

### Standard library

- **(breaking-change)** Refactor to standardize on first argument for methods receiving `IO`. ([#9134](https://github.com/crystal-lang/crystal/pull/9134), [#9289](https://github.com/crystal-lang/crystal/pull/9289), [#9303](https://github.com/crystal-lang/crystal/pull/9303), [#9318](https://github.com/crystal-lang/crystal/pull/9318), thanks @straight-shoota, @bcardiff, @oprypin)
- **(breaking-change)** Cleanup Digest and OpenSSL::Digest. ([#8426](https://github.com/crystal-lang/crystal/pull/8426), thanks @didactic-drunk)
- Fix `Enum#to_s` for private enum. ([#9126](https://github.com/crystal-lang/crystal/pull/9126), thanks @straight-shoota)
- Refactor `Benchmark::IPS::Entry` to use `UInt64` in `bytes_per_op`. ([#9081](https://github.com/crystal-lang/crystal/pull/9081), thanks @jhass)
- Add `Experimental` annotation and doc label. ([#9244](https://github.com/crystal-lang/crystal/pull/9244), thanks @bcardiff)
- Add subcommands to `OptionParser`. ([#9009](https://github.com/crystal-lang/crystal/pull/9009), [#9133](https://github.com/crystal-lang/crystal/pull/9133), thanks @RX14, @Sija)
- Make `NamedTuple#sorted_keys` public. ([#9263](https://github.com/crystal-lang/crystal/pull/9263), thanks @waj)
- Fix example codes in multiple places. ([#9203](https://github.com/crystal-lang/crystal/pull/9203), thanks @maiha)

#### Macros

- **(breaking-change)** Remove top-level `assert_responds_to` macro. ([#9085](https://github.com/crystal-lang/crystal/pull/9085), thanks @bcardiff)
- **(breaking-change)** Drop top-level `parallel` macro. ([#9097](https://github.com/crystal-lang/crystal/pull/9097), thanks @bcardiff)
- Fix lazy property not forwarding annotations. ([#9140](https://github.com/crystal-lang/crystal/pull/9140), thanks @asterite)
- Add `host_flag?` macro method, not affected by cross-compilation. ([#9049](https://github.com/crystal-lang/crystal/pull/9049), thanks @oprypin)
- Add `.each` and `.each_with_index` to various macro types. ([#9120](https://github.com/crystal-lang/crystal/pull/9120), thanks @Blacksmoke16)
- Add `StringLiteral#titleize` macro method. ([#9269](https://github.com/crystal-lang/crystal/pull/9269), thanks @MakeNowJust)
- Add `TypeNode` methods to check what "type" the node is. ([#9270](https://github.com/crystal-lang/crystal/pull/9270), thanks @Blacksmoke16)
- Fix support `TypeNode.name(generic_args: false)` for generic instances. ([#9224](https://github.com/crystal-lang/crystal/pull/9224), thanks @Blacksmoke16)

#### Numeric

- **(breaking-change)** Add `Int#digits`, reverse `BigInt#digits` result. ([#9383](https://github.com/crystal-lang/crystal/pull/9383), thanks @asterite)
- Fix overflow checking for operations with mixed sign. ([#9403](https://github.com/crystal-lang/crystal/pull/9403), thanks @waj)
- Add `BigInt#factorial` using GMP. ([#9132](https://github.com/crystal-lang/crystal/pull/9132), thanks @peheje)

#### Text

- Add `String#titleize`. ([#9204](https://github.com/crystal-lang/crystal/pull/9204), thanks @hugopl)
- Add `Regex#matches?` and `String#matches?`. ([#8989](https://github.com/crystal-lang/crystal/pull/8989), thanks @MakeNowJust)
- Add `IO` overloads to various `String` case methods. ([#9236](https://github.com/crystal-lang/crystal/pull/9236), thanks @Blacksmoke16)
- Improve docs examples regarding `Regex::MatchData`. ([#9010](https://github.com/crystal-lang/crystal/pull/9010), thanks @MakeNowJust)
- Improve docs on `String` methods. ([#8447](https://github.com/crystal-lang/crystal/pull/8447), thanks @jan-zajic)

#### Collections

- **(breaking-change)** Add `Enumerable#first` with fallback block. ([#8999](https://github.com/crystal-lang/crystal/pull/8999), thanks @MakeNowJust)
- Fix `Array#delete_at` bug with negative start index. ([#9399](https://github.com/crystal-lang/crystal/pull/9399), thanks @asterite)
- Fix `Enumerable#{zip,zip?}` when self is an `Iterator`. ([#9330](https://github.com/crystal-lang/crystal/pull/9330), thanks @mneumann)
- Make `Range#each` and `Range#reverse_each` work better with end/begin-less values. ([#9325](https://github.com/crystal-lang/crystal/pull/9325), thanks @asterite)
- Improve docs on `Hash`. ([#8887](https://github.com/crystal-lang/crystal/pull/8887), thanks @rdp)

#### Serialization

- **(breaking-change)** Deprecate `JSON.mapping` and `YAML.mapping`. ([#9272](https://github.com/crystal-lang/crystal/pull/9272), thanks @straight-shoota)
- **(breaking-change)** Make `INI` a module. ([#9408](https://github.com/crystal-lang/crystal/pull/9408), thanks @j8r)
- Fix integration between `record` macro and `JSON::Serializable`/`YAML::Serializable` regarding default values. ([#9063](https://github.com/crystal-lang/crystal/pull/9063), thanks @Blacksmoke16)
- Fix `XML.parse` invalid mem access in multi-thread. ([#9098](https://github.com/crystal-lang/crystal/pull/9098), thanks @bcardiff, @asterite)
- Fix double string escape in `XML::Node#content=`. ([#9300](https://github.com/crystal-lang/crystal/pull/9300), thanks @straight-shoota)
- Improve xpath regarding namespaces. ([#9288](https://github.com/crystal-lang/crystal/pull/9288), thanks @asterite)
- Escape CDATA end sequences. ([#9230](https://github.com/crystal-lang/crystal/pull/9230), thanks @Blacksmoke16)
- Add `JSON` and `YAML` serialization to `Path`. ([#9156](https://github.com/crystal-lang/crystal/pull/9156), thanks @straight-shoota)
- Specify pkg-config name for `libyaml`. ([#9426](https://github.com/crystal-lang/crystal/pull/9426), thanks @jhass)
- Specify pkg-config name for `libxml2`. ([#9436](https://github.com/crystal-lang/crystal/pull/9436), thanks @Blacksmoke16)
- Make YAML specs robust against libyaml 0.2.5. ([#9427](https://github.com/crystal-lang/crystal/pull/9427), thanks @jhass)

#### Time

- **(breaking-change)** Support different number of fraction digits for RFC3339 time format. ([#9283](https://github.com/crystal-lang/crystal/pull/9283), thanks @waj)
- Fix parsing AM/PM hours. ([#9334](https://github.com/crystal-lang/crystal/pull/9334), thanks @straight-shoota)
- Improve `File.utime` precision from second to 100-nanosecond on Windows. ([#9344](https://github.com/crystal-lang/crystal/pull/9344), thanks @kubo)

#### Files

- **(breaking-change)** Move `Flate`, `Gzip`, `Zip`, `Zlib` to `Compress`. ([#8886](https://github.com/crystal-lang/crystal/pull/8886), thanks @bcardiff)
- **(breaking-change)** Cleanup `File` & `FileUtils`. ([#9175](https://github.com/crystal-lang/crystal/pull/9175), thanks @bcardiff)
- Fix realpath on macOS 10.15 (Catalina). ([#9296](https://github.com/crystal-lang/crystal/pull/9296), thanks @waj)
- Fix `File#pos`, `File#seek` and `File#truncate` over 2G on Windows. ([#9015](https://github.com/crystal-lang/crystal/pull/9015), thanks @kubo)
- Fix `File.rename` to overwrite the destination file on Windows, like elsewhere. ([#9038](https://github.com/crystal-lang/crystal/pull/9038), thanks @oprypin)
- Fix `File`'s specs and related exception types on Windows. ([#9037](https://github.com/crystal-lang/crystal/pull/9037), thanks @oprypin)
- Add support for `Path` arguments to multiple methods. ([#9153](https://github.com/crystal-lang/crystal/pull/9153), thanks @straight-shoota)
- Add `Path#each_part` iterator. ([#9138](https://github.com/crystal-lang/crystal/pull/9138), thanks @straight-shoota)
- Add `Path#relative_to`. ([#9169](https://github.com/crystal-lang/crystal/pull/9169), thanks @straight-shoota)
- Add support for `Path` pattern to `Dir.glob`. ([#9420](https://github.com/crystal-lang/crystal/pull/9420), thanks @straight-shoota)
- Implement `File#fsync` on Windows. ([#9257](https://github.com/crystal-lang/crystal/pull/9257), thanks @kubo)
- Refactor `Path` regarding empty and `.`. ([#9137](https://github.com/crystal-lang/crystal/pull/9137), thanks @straight-shoota)

#### Networking

- **(breaking-change)** Make `IO#skip`, `IO#write` returns the number of bytes it skipped/written as `Int64`. ([#9233](https://github.com/crystal-lang/crystal/pull/9233), [#9363](https://github.com/crystal-lang/crystal/pull/9363), thanks @bcardiff)
- **(breaking-change)** Improve error handling and logging in `HTTP::Server`. ([#9115](https://github.com/crystal-lang/crystal/pull/9115), [#9034](https://github.com/crystal-lang/crystal/pull/9034), thanks @waj, @straight-shoota)
- **(breaking-change)** Change `HTTP::Request#remote_address` type to `Socket::Address?`. ([#9210](https://github.com/crystal-lang/crystal/pull/9210), thanks @waj)
- Fix `flush` methods to always flush underlying `IO`. ([#9320](https://github.com/crystal-lang/crystal/pull/9320), thanks @straight-shoota)
- Fix `HTTP::Server` sporadic failure in SSL handshake. ([#9177](https://github.com/crystal-lang/crystal/pull/9177), thanks @waj)
- `WebSocket` shouldn't reply with same close code. ([#9313](https://github.com/crystal-lang/crystal/pull/9313), thanks @waj)
- Ignore response body during `WebSocket` handshake. ([#9418](https://github.com/crystal-lang/crystal/pull/9418), thanks @waj)
- Treat cookies which expire in this instant as expired. ([#9061](https://github.com/crystal-lang/crystal/pull/9061), thanks @RX14)
- Set `sync` or `flush_on_newline` for standard I/O on Windows. ([#9207](https://github.com/crystal-lang/crystal/pull/9207), thanks @kubo)
- Prefer HTTP basic authentication in OAuth2 client. ([#9127](https://github.com/crystal-lang/crystal/pull/9127), thanks @crush-157)
- Defer request upgrade in `HTTP::Server` (aka: WebSockets). ([#9243](https://github.com/crystal-lang/crystal/pull/9243), thanks @waj)
- Improve `URI::Punycode`, `HTTP::WebSocketHandler`, `HTTP::Status` documentation. ([#9068](https://github.com/crystal-lang/crystal/pull/9068), [#9130](https://github.com/crystal-lang/crystal/pull/9130), [#9180](https://github.com/crystal-lang/crystal/pull/9180), thanks @Blacksmoke16, @dscottboggs, @wontruefree)
- Remove `HTTP::Params::Builder#to_s`, use underlying `IO` directly. ([#9319](https://github.com/crystal-lang/crystal/pull/9319), thanks @straight-shoota)
- Fixed some regular failing specs in multi-thread mode. ([#9412](https://github.com/crystal-lang/crystal/pull/9412), thanks @bcardiff)

#### Crypto

- **(security)** Update SSL server secure defaults. ([#9026](https://github.com/crystal-lang/crystal/pull/9026), thanks @straight-shoota)
- Add LibSSL `NO_TLS_V1_3` option. ([#9350](https://github.com/crystal-lang/crystal/pull/9350), thanks @lun-4)

#### Logging

- **(breaking-change)** Rename `Log::Severity::Warning` to `Warn`. Drop `Verbose`. Add `Trace` and `Notice`. ([#9293](https://github.com/crystal-lang/crystal/pull/9293), [#9107](https://github.com/crystal-lang/crystal/pull/9107), [#9316](https://github.com/crystal-lang/crystal/pull/9316), thanks @bcardiff, @paulcsmith)
- **(breaking-change)** Allow local data on entries via `Log::Metadata` and redesign `Log::Context`. ([#9118](https://github.com/crystal-lang/crystal/pull/9118), [#9227](https://github.com/crystal-lang/crystal/pull/9227), [#9150](https://github.com/crystal-lang/crystal/pull/9150), [#9157](https://github.com/crystal-lang/crystal/pull/9157), thanks @bcardiff, @waj)
- **(breaking-change)** Split top-level `Log::Metadata` from `Log::Metadata::Value`, drop immutability via clone, improve performance. ([#9295](https://github.com/crystal-lang/crystal/pull/9295), thanks @bcardiff)
- **(breaking-change)** Rework `Log.setup_from_env` and defaults. ([#9145](https://github.com/crystal-lang/crystal/pull/9145), [#9240](https://github.com/crystal-lang/crystal/pull/9240),  thanks @bcardiff)
- Add `Log.capture` spec helper. ([#9201](https://github.com/crystal-lang/crystal/pull/9201), thanks @bcardiff)
- Redesign `Log::Formatter`. ([#9211](https://github.com/crystal-lang/crystal/pull/9211), thanks @waj)
- Add `to_json` for `Log::Context`. ([#9101](https://github.com/crystal-lang/crystal/pull/9101), thanks @paulcsmith)
- Add `Log::IOBackend#new` with `formatter` named argument. ([#9105](https://github.com/crystal-lang/crystal/pull/9105), [#9434](https://github.com/crystal-lang/crystal/pull/9434), thanks @paulcsmith, @bcardiff)
- Allow `nil` as context raw values. ([#9121](https://github.com/crystal-lang/crystal/pull/9121), thanks @bcardiff)
- Add missing `Log#with_context`. ([#9058](https://github.com/crystal-lang/crystal/pull/9058), thanks @bcardiff)
- Fix types referred in documentation. ([#9117](https://github.com/crystal-lang/crystal/pull/9117), thanks @bcardiff)
- Allow override context within logging calls. ([#9146](https://github.com/crystal-lang/crystal/pull/9146), thanks @bcardiff)
- Check severity before backend. ([#9400](https://github.com/crystal-lang/crystal/pull/9400), thanks @asterite)

#### Concurrency

- **(breaking-change)** Drop `Concurrent::Future` and top-level methods `delay`, `future`, `lazy`. Use [crystal-community/future.cr](https://github.com/crystal-community/future.cr). ([#9093](https://github.com/crystal-lang/crystal/pull/9093), thanks @bcardiff)

#### System

- **(breaking-change)** Deprecate `Process#kill`, use `Process#signal`. ([#9006](https://github.com/crystal-lang/crystal/pull/9006), thanks @oprypin, @jan-zajic)
- `Process` raises `IO::Error` (or subclasses). ([#9340](https://github.com/crystal-lang/crystal/pull/9340), thanks @waj)
- Add `Process.quote` and fix shell usages in the compiler. ([#9043](https://github.com/crystal-lang/crystal/pull/9043), [#9369](https://github.com/crystal-lang/crystal/pull/9369), thanks @oprypin, @bcardiff)
- Implement `Process` support on Windows. ([#9047](https://github.com/crystal-lang/crystal/pull/9047), [#9021](https://github.com/crystal-lang/crystal/pull/9021), [#9122](https://github.com/crystal-lang/crystal/pull/9122), [#9112](https://github.com/crystal-lang/crystal/pull/9112), [#9149](https://github.com/crystal-lang/crystal/pull/9149), [#9310](https://github.com/crystal-lang/crystal/pull/9310), thanks @oprypin, @RX14, @kubo, @jan-zajic)
- Fix compile-time checking of `dup3`/`clock_gettime` methods definition. ([#9407](https://github.com/crystal-lang/crystal/pull/9407), thanks @asterite)
- Use `Int64` as portable `Process.pid` type. ([#9019](https://github.com/crystal-lang/crystal/pull/9019), thanks @oprypin)

#### Runtime

- **(breaking-change)** Deprecate top-level `fork`. ([#9136](https://github.com/crystal-lang/crystal/pull/9136), thanks @bcardiff)
- **(breaking-change)** Move `Debug` to `Crystal` namespace. ([#9176](https://github.com/crystal-lang/crystal/pull/9176), thanks @bcardiff)
- Fix segfaults when static linking with musl. ([#9238](https://github.com/crystal-lang/crystal/pull/9238), thanks @waj)
- Allow calling `at_exit` inside `at_exit`. ([#9388](https://github.com/crystal-lang/crystal/pull/9388), thanks @asterite)
- Rework DWARF loading and fix empty backtraces in musl. ([#9267](https://github.com/crystal-lang/crystal/pull/9267), thanks @waj)
- Add DragonFly(BSD) support. ([#9178](https://github.com/crystal-lang/crystal/pull/9178), thanks @mneumann)
- Add `Crystal::System::Process` to split out system-specific implementations. ([#9035](https://github.com/crystal-lang/crystal/pull/9035), thanks @oprypin)
- Move internal `CallStack` to `Exception::CallStack`. ([#9076](https://github.com/crystal-lang/crystal/pull/9076), thanks @bcardiff)
- Specify pkg-config name for `libevent`. ([#9395](https://github.com/crystal-lang/crystal/pull/9395), thanks @jhass)

#### Spec

- Reference global Spec in `be_a` macro. ([#9066](https://github.com/crystal-lang/crystal/pull/9066), thanks @asterite)
- Add `-h` short flag to spec runner. ([#9164](https://github.com/crystal-lang/crystal/pull/9164), thanks @straight-shoota)
- Fix `crystal spec` file paths on Windows. ([#9234](https://github.com/crystal-lang/crystal/pull/9234), thanks @oprypin)
- Refactor spec hooks. ([#9090](https://github.com/crystal-lang/crystal/pull/9090), thanks @straight-shoota)

### Compiler

- **(breaking-change)** Improve compiler single-file run syntax to make it shebang-friendly `#!`. ([#9171](https://github.com/crystal-lang/crystal/pull/9171), thanks @RX14)
- **(breaking-change)** Use `Process.quote` for `crystal env` output. ([#9428](https://github.com/crystal-lang/crystal/pull/9428), thanks @MakeNowJust)
- **(breaking-change)** Simplify `Link` annotation handling. ([#8972](https://github.com/crystal-lang/crystal/pull/8972), thanks @RX14)
- Fix parsing of `foo:"bar"` inside call or named tuple. ([#9033](https://github.com/crystal-lang/crystal/pull/9033), thanks @asterite)
- Fix parsing of anonymous splat and block arg. ([#9113](https://github.com/crystal-lang/crystal/pull/9113), thanks @MakeNowJust)
- Fix parsing of `unless` inside macro. ([#9024](https://github.com/crystal-lang/crystal/pull/9024), [#9167](https://github.com/crystal-lang/crystal/pull/9167), thanks @MakeNowJust)
- Fix parsing of `\ ` (backslash + space) inside regex literal to ` ` (space). ([#9079](https://github.com/crystal-lang/crystal/pull/9079), thanks @MakeNowJust)
- Fix parsing of ambiguous '+' and '-'. ([#9194](https://github.com/crystal-lang/crystal/pull/9194), thanks @max-codeware)
- Fix parsing of capitalized named argument. ([#9232](https://github.com/crystal-lang/crystal/pull/9232), thanks @asterite)
- Fix parsing of `{[] of Foo, self.foo}` expressions. ([#9329](https://github.com/crystal-lang/crystal/pull/9329), thanks @MakeNowJust)
- Fix cast fun function pointer to Proc. ([#9287](https://github.com/crystal-lang/crystal/pull/9287), thanks @asterite)
- Make compiler warn on deprecated macros. ([#9343](https://github.com/crystal-lang/crystal/pull/9343), thanks @bcardiff)
- Basic support for Win64 C lib ABI. ([#9387](https://github.com/crystal-lang/crystal/pull/9387), thanks @oprypin)
- Make the compiler able to run on Windows and compile itself. ([#9054](https://github.com/crystal-lang/crystal/pull/9054), [#9062](https://github.com/crystal-lang/crystal/pull/9062), [#9095](https://github.com/crystal-lang/crystal/pull/9095), [#9106](https://github.com/crystal-lang/crystal/pull/9106), [#9307](https://github.com/crystal-lang/crystal/pull/9307), thanks @oprypin, @Sija)
- Add docs regarding `CRYSTAL_OPTS`. ([#9018](https://github.com/crystal-lang/crystal/pull/9018), thanks @straight-shoota)
- Remove `Process.run("which")` from compiler. ([#9141](https://github.com/crystal-lang/crystal/pull/9141), thanks @straight-shoota)
- Refactor type parser. ([#9208](https://github.com/crystal-lang/crystal/pull/9208), thanks @MakeNowJust)
- Refactor & clean-up in compiler. ([#8781](https://github.com/crystal-lang/crystal/pull/8781), [#9195](https://github.com/crystal-lang/crystal/pull/9195), thanks @rhysd, @straight-shoota)
- Refactor `CrystalPath::Error`. ([#9359](https://github.com/crystal-lang/crystal/pull/9359), thanks @straight-shoota)
- Refactor and improvements on spec_helper. ([#9367](https://github.com/crystal-lang/crystal/pull/9367), [#9059](https://github.com/crystal-lang/crystal/pull/9059), [#9393](https://github.com/crystal-lang/crystal/pull/9393), [#9351](https://github.com/crystal-lang/crystal/pull/9351), [#9402](https://github.com/crystal-lang/crystal/pull/9402), thanks @straight-shoota, @jhass, @oprypin)
- Split general ABI specs from x86_64-specific ones, run on every platform. ([#9384](https://github.com/crystal-lang/crystal/pull/9384), thanks @oprypin)

#### Language semantics

- Fix `RegexLiteral#to_s` output when first character of literal is whitespace. ([#9017](https://github.com/crystal-lang/crystal/pull/9017), thanks @MakeNowJust)
- Fix autocasting in multidispatch. ([#9004](https://github.com/crystal-lang/crystal/pull/9004), thanks @asterite)
- Fix propagation of annotations into other scopes. ([#9125](https://github.com/crystal-lang/crystal/pull/9125), thanks @asterite)
- Fix yield computation inside macro code. ([#9324](https://github.com/crystal-lang/crystal/pull/9324), thanks @asterite)
- Fix incorrect type generated with `as?` when type is a union. ([#9417](https://github.com/crystal-lang/crystal/pull/9417), [#9435](https://github.com/crystal-lang/crystal/pull/9435), thanks @asterite)
- Don't duplicate instance var in inherited generic type. ([#9433](https://github.com/crystal-lang/crystal/pull/9433), thanks @asterite)
- Ensure `type_vars` works for generic modules. ([#9161](https://github.com/crystal-lang/crystal/pull/9161), thanks @toddsundsted)
- Make autocasting work in default values against unions. ([#9366](https://github.com/crystal-lang/crystal/pull/9366), thanks @asterite)
- Skip no closure check for non-Crystal procs. ([#9248](https://github.com/crystal-lang/crystal/pull/9248), thanks @jhass)

#### Debugger

- Improve debugging support. ([#8538](https://github.com/crystal-lang/crystal/pull/8538), thanks @skuznetsov)
- Move recent additions to `DIBuilder` to `LLVMExt`. ([#9114](https://github.com/crystal-lang/crystal/pull/9114), thanks @bcardiff)

### Tools

#### Formatter

- Fix formatting of regex after some comments. ([#9109](https://github.com/crystal-lang/crystal/pull/9109), thanks @MakeNowJust)
- Fix formatting of `&.!`. ([#9391](https://github.com/crystal-lang/crystal/pull/9391), thanks @MakeNowJust)
- Avoid crash on heredoc with interpolations. ([#9382](https://github.com/crystal-lang/crystal/pull/9382), thanks @MakeNowJust)
- Refactor: code clean-up. ([#9231](https://github.com/crystal-lang/crystal/pull/9231), thanks @MakeNowJust)

#### Doc generator

- Fix links to methods with `String` default values. ([#9200](https://github.com/crystal-lang/crystal/pull/9200), thanks @bcardiff)
- Fix syntax highlighting of heredoc. ([#9396](https://github.com/crystal-lang/crystal/pull/9396), thanks @MakeNowJust)
- Correctly attach docs before annotations to following types. ([#9332](https://github.com/crystal-lang/crystal/pull/9332), thanks @asterite)
- Allow annotations and `:ditto:` in macro. ([#9341](https://github.com/crystal-lang/crystal/pull/9341), thanks @bcardiff)
- Add project name and version to API docs. ([#8792](https://github.com/crystal-lang/crystal/pull/8792), thanks @straight-shoota)
- Add version selector to API docs. ([#9074](https://github.com/crystal-lang/crystal/pull/9074), [#9187](https://github.com/crystal-lang/crystal/pull/9187), [#9250](https://github.com/crystal-lang/crystal/pull/9250), [#9252](https://github.com/crystal-lang/crystal/pull/9252), [#9254](https://github.com/crystal-lang/crystal/pull/9254), thanks @straight-shoota, @bcardiff)
- Show input type path instead of full qualified path on generic. ([#9302](https://github.com/crystal-lang/crystal/pull/9302), thanks @MakeNowJust)
- Remove README link in API docs. ([#9082](https://github.com/crystal-lang/crystal/pull/9082), thanks @straight-shoota)
- Remove special handling for version tags in docs generator. ([#9083](https://github.com/crystal-lang/crystal/pull/9083), thanks @straight-shoota)
- Refactor `is_crystal_repo` based on project name. ([#9070](https://github.com/crystal-lang/crystal/pull/9070), thanks @straight-shoota)
- Refactor `Docs::Generator` source link generation. ([#9119](https://github.com/crystal-lang/crystal/pull/9119), [#9305](https://github.com/crystal-lang/crystal/pull/9305), thanks @straight-shoota)

#### Playground

- Allow building compiler without 'playground', to avoid dependency on sockets. ([#9031](https://github.com/crystal-lang/crystal/pull/9031), thanks @oprypin)
- Add support to jquery version 3. ([#9028](https://github.com/crystal-lang/crystal/pull/9028), thanks @deiv)

### Others

- CI improvements and housekeeping. ([#9012](https://github.com/crystal-lang/crystal/pull/9012), [#9129](https://github.com/crystal-lang/crystal/pull/9129), [#9242](https://github.com/crystal-lang/crystal/pull/9242), [#9370](https://github.com/crystal-lang/crystal/pull/9370), thanks @bcardiff)
- Update to Shards 0.11.1. ([#9446](https://github.com/crystal-lang/crystal/pull/9446), thanks @bcardiff)
- Tidy up Makefile and crystal env output. ([#9423](https://github.com/crystal-lang/crystal/pull/9423), thanks @bcardiff)
- Always include `lib` directory in the `CRYSTAL_PATH`. ([#9315](https://github.com/crystal-lang/crystal/pull/9315), thanks @waj)
- Use `SOURCE_DATE_EPOCH` only to determine compiler date. ([#9088](https://github.com/crystal-lang/crystal/pull/9088), thanks @straight-shoota)
- Win CI: Bootstrap Crystal, build things on Windows, publish the binary. ([#9123](https://github.com/crystal-lang/crystal/pull/9123), [#9155](https://github.com/crystal-lang/crystal/pull/9155), [#9144](https://github.com/crystal-lang/crystal/pull/9144), [#9346](https://github.com/crystal-lang/crystal/pull/9346), thanks @oprypin)
- Regenerate implementation tool sample. ([#9003](https://github.com/crystal-lang/crystal/pull/9003), thanks @nulty)
- Avoid requiring non std-lib spec spec_helper. ([#9294](https://github.com/crystal-lang/crystal/pull/9294), thanks @bcardiff)
- Improve grammar and fix typos. ([#9087](https://github.com/crystal-lang/crystal/pull/9087), [#9212](https://github.com/crystal-lang/crystal/pull/9212), [#9368](https://github.com/crystal-lang/crystal/pull/9368), thanks @MakeNowJust, @j8r)
- Hide internal functions in docs. ([#9410](https://github.com/crystal-lang/crystal/pull/9410), thanks @bcardiff)
- Advertise full `crystal spec` command for running a particular spec. ([#9103](https://github.com/crystal-lang/crystal/pull/9103), thanks @paulcsmith)
- Update README. ([#9225](https://github.com/crystal-lang/crystal/pull/9225), [#9163](https://github.com/crystal-lang/crystal/pull/9163), thanks @danimiba, @straight-shoota)
- Fix LICENSE and add NOTICE file. ([#3903](https://github.com/crystal-lang/crystal/pull/3903), thanks @MakeNowJust)

## [0.34.0] - 2020-04-06
[0.34.0]: https://github.com/crystal-lang/crystal/releases/0.34.0

### Language changes

- **(breaking-change)** Exhaustive `case` expression check added, for now it produces warnings. ([#8424](https://github.com/crystal-lang/crystal/pull/8424), [#8962](https://github.com/crystal-lang/crystal/pull/8962), thanks @asterite, @Sija)
- Let `Proc(T)` be used as a `Proc(Nil)`. ([#8969](https://github.com/crystal-lang/crystal/pull/8969), [#8970](https://github.com/crystal-lang/crystal/pull/8970), thanks @asterite)

### Standard library

- **(breaking-change)** Replace `Errno`, `WinError`, `IO::Timeout` with `RuntimeError`, `IO::TimeoutError`, `IO::Error`, `File::Error`, `Socket::Error`, and subclasses. ([#8885](https://github.com/crystal-lang/crystal/pull/8885), thanks @waj)
- **(breaking-change)** Replace `Logger` module in favor of `Log` module. ([#8847](https://github.com/crystal-lang/crystal/pull/8847), [#8976](https://github.com/crystal-lang/crystal/pull/8976), thanks @bcardiff)
- **(breaking-change)** Move `Adler32` and `CRC32` to `Digest`. ([#8881](https://github.com/crystal-lang/crystal/pull/8881), thanks @bcardiff)
- **(breaking-change)** Remove `DL` module. ([#8882](https://github.com/crystal-lang/crystal/pull/8882), thanks @bcardiff)
- Enable more win32 specs. ([#8683](https://github.com/crystal-lang/crystal/pull/8683), [#8822](https://github.com/crystal-lang/crystal/pull/8822), thanks @straight-shoota)
- Make `SemanticVersion::Prerelease` comparable. ([#8991](https://github.com/crystal-lang/crystal/pull/8991), thanks @MakeNowJust)
- Use `flag?(:i386)` instead of obsolete `flag?(:i686)`. ([#8863](https://github.com/crystal-lang/crystal/pull/8863), thanks @bcardiff)
- Remove Windows workaround using `vsnprintf`. ([#8942](https://github.com/crystal-lang/crystal/pull/8942), thanks @oprypin)
- Fixed docs broken link to ruby's prettyprint source. ([#8915](https://github.com/crystal-lang/crystal/pull/8915), thanks @matthin)
- Update `OptionParser` example to exit on `--help`. ([#8927](https://github.com/crystal-lang/crystal/pull/8927), thanks @vlazar)

#### Numeric

- Fixed `Float32#to_s` corner-case. ([#8838](https://github.com/crystal-lang/crystal/pull/8838), thanks @toddsundsted)
- Fixed make `Big*#to_u` raise on negative values. ([#8826](https://github.com/crystal-lang/crystal/pull/8826), thanks @Sija)
- Fixed `BigDecimal#to_big_i` regression. ([#8790](https://github.com/crystal-lang/crystal/pull/8790), thanks @Sija)
- Add `Complex#round`. ([#8819](https://github.com/crystal-lang/crystal/pull/8819), thanks @miketheman)
- Add `Int#bit_length` and `BigInt#bit_length`. ([#8924](https://github.com/crystal-lang/crystal/pull/8924), [#8931](https://github.com/crystal-lang/crystal/pull/,8931), thanks @asterite)
- Fixed docs of `Int#gcd`. ([#8894](https://github.com/crystal-lang/crystal/pull/8894), thanks @nard-tech)

#### Text

- **(breaking-change)** Deprecate top-level `with_color` in favor of `Colorize.with`. ([#8892](https://github.com/crystal-lang/crystal/pull/8892), [#8958](https://github.com/crystal-lang/crystal/pull/8958), thanks @bcardiff, @oprypin)
- Add overloads for `String#ljust`, `String#rjust` and `String#center` that take an `IO`. ([#8923](https://github.com/crystal-lang/crystal/pull/8923), thanks @asterite)
- Add missing `Regex#hash` and `Regex::MatchData#hash`. ([#8986](https://github.com/crystal-lang/crystal/pull/8986), thanks @MakeNowJust)
- Upgrade Unicode to 13.0.0. ([#8906](https://github.com/crystal-lang/crystal/pull/8906), thanks @Blacksmoke16)
- Revert deprecation of `String#codepoint_at`. ([#8902](https://github.com/crystal-lang/crystal/pull/8902), thanks @vlazar)
- Move `Iconv` to `Crystal` namespace. ([#8890](https://github.com/crystal-lang/crystal/pull/8890), thanks @bcardiff)

#### Collections

- Fixed make `Range#size` raise on an open range. ([#8829](https://github.com/crystal-lang/crystal/pull/8829), thanks @Sija)
- Add `Enumerable#empty?`. ([#8960](https://github.com/crystal-lang/crystal/pull/8960), thanks @Sija)
- **(performance)** Optimized Implementation of `Array#fill` for zero Values. ([#8903](https://github.com/crystal-lang/crystal/pull/8903), thanks @toddsundsted)
- Refactor `Reflect` to an `Enumerable` private definition. ([#8884](https://github.com/crystal-lang/crystal/pull/8884), thanks @bcardiff)

#### Serialization

- **(breaking-change)** Rename `YAML::Builder.new` with block to `YAML::Builder.build`. ([#8896](https://github.com/crystal-lang/crystal/pull/8896), thanks @straight-shoota)
- Add `XML.build_fragment`. ([#8813](https://github.com/crystal-lang/crystal/pull/8813), thanks @straight-shoota)
- Add `CSV#rewind`. ([#8912](https://github.com/crystal-lang/crystal/pull/8912), thanks @asterite)
- Add `Deque#from_json` and `Deque#to_json`. ([#8850](https://github.com/crystal-lang/crystal/pull/8850), thanks @carlhoerberg)
- Call to `IO#flush` on `CSV`, `INI`, `JSON`, `XML`, and `YAML` builders. ([#8876](https://github.com/crystal-lang/crystal/pull/8876), thanks @asterite)
- Add docs to `Object.from_yaml`. ([#8800](https://github.com/crystal-lang/crystal/pull/8800), thanks @wowinter13)

#### Time

- **(breaking-change)** Improve `Time::Span` initialization API with mandatory named arguments. ([#8257](https://github.com/crystal-lang/crystal/pull/8257), [#8857](https://github.com/crystal-lang/crystal/pull/8857), thanks @dnamsons, @bcardiff)
- Add `Time::Span#total_microseconds`. ([#8966](https://github.com/crystal-lang/crystal/pull/8966), thanks @vlazar)

#### Files

- Fixed multi-thread race condition by setting `fd` to `-1` on closed `File`/`Socket`. ([#8873](https://github.com/crystal-lang/crystal/pull/8873), thanks @bcardiff)
- Fixed `File.dirname` with unicode chars. ([#8911](https://github.com/crystal-lang/crystal/pull/8911), thanks @asterite)
- Add `IO::Buffered#flush_on_newline` back and set it to true for non-tty. ([#8935](https://github.com/crystal-lang/crystal/pull/8935), thanks @asterite)
- Forward missing methods of `IO::Hexdump` to underlying `IO`. ([#8908](https://github.com/crystal-lang/crystal/pull/8908), thanks @carlhoerberg)

#### Networking

- **(breaking-change)** Correctly support WebSocket close codes. ([#8975](https://github.com/crystal-lang/crystal/pull/8975), [#8981](https://github.com/crystal-lang/crystal/pull/8981), thanks @RX14, @Sija)
- Make `HTTP::Client` return empty `body_io` if content-length is zero. ([#8503](https://github.com/crystal-lang/crystal/pull/8503), thanks @asterite)
- Fixed `UDP` specs in the case of a local firewall. ([#8817](https://github.com/crystal-lang/crystal/pull/8817), thanks @RX14)
- Fixed `MIME` spec examples to not collide with actual registry. ([#8795](https://github.com/crystal-lang/crystal/pull/8795), thanks @straight-shoota)
- Fixed `UNIXServer`, and `HTTP::WebSocket` specs to ensure server is accepting before closing. ([#8755](https://github.com/crystal-lang/crystal/pull/8755), [#8879](https://github.com/crystal-lang/crystal/pull/8879), thanks @bcardiff)
- Add type annotation to `tls` argument in `HTTP`. ([#8678](https://github.com/crystal-lang/crystal/pull/8678), thanks @j8r)
- Add `Location` to `HTTP::Request` common header names. ([#8992](https://github.com/crystal-lang/crystal/pull/8992), thanks @mamantoha)

#### Concurrency

- Add docs on `Future` regarding exceptions. ([#8860](https://github.com/crystal-lang/crystal/pull/8860), thanks @rdp)
- Disable occasionally failing `Thread` specs on musl. ([#8801](https://github.com/crystal-lang/crystal/pull/8801), thanks @straight-shoota)

#### System

- Fixed typo on `src/signal.cr`. ([#8805](https://github.com/crystal-lang/crystal/pull/8805), thanks @lbguilherme)

#### Runtime

- Fixed exceptions not being inspectable when running binary from PATH. ([#8807](https://github.com/crystal-lang/crystal/pull/8807), thanks @willhbr)
- Move `AtExitHandlers` to `Crystal` namespace. ([#8883](https://github.com/crystal-lang/crystal/pull/8883), thanks @bcardiff)

### Compiler

- **(breaking-change)** Drop `disable_overflow` compiler flag. ([#8772](https://github.com/crystal-lang/crystal/pull/8772), thanks @Sija)
- Fixed url in "can't infer block return type" error message. ([#8869](https://github.com/crystal-lang/crystal/pull/8869), thanks @nilium)
- Fixed typo in math interpreter error message. ([#8941](https://github.com/crystal-lang/crystal/pull/8941), thanks @j8r)
- Use `CRYSTAL_OPTS` environment variable as default compiler options. ([#8900](https://github.com/crystal-lang/crystal/pull/8900), thanks @bcardiff)
- Avoid using the default `--exclude-warnings` value if some is specified. ([#8899](https://github.com/crystal-lang/crystal/pull/8899), thanks @bcardiff)
- Honor `LIBRARY_PATH` as default library path, and allow linking with no explicit `/usr/lib:/usr/local/lib` paths. ([#8948](https://github.com/crystal-lang/crystal/pull/8948), thanks @bcardiff)
- Fix Windows LLVM globals codegen in non-single-module mode. ([#8978](https://github.com/crystal-lang/crystal/pull/8978), thanks @oprypin)
- Add support for LLVM 10. ([#8940](https://github.com/crystal-lang/crystal/pull/8940), thanks @RX14)
- Remove redundant calls to `Object.to_s` in interpolation in compiler's code. ([#8947](https://github.com/crystal-lang/crystal/pull/8947), thanks @veelenga)

#### Language semantics

- Type as `NoReturn` if calling method on abstract class with no concrete subclasses. ([#8870](https://github.com/crystal-lang/crystal/pull/8870), thanks @asterite)

### Tools

- Add `crystal init` name validation. ([#8737](https://github.com/crystal-lang/crystal/pull/8737), thanks @straight-shoota)

#### Doc generator

- Show warnings on docs command. ([#8880](https://github.com/crystal-lang/crystal/pull/8880), thanks @bcardiff)

### Others

- CI improvements and housekeeping. ([#8804](https://github.com/crystal-lang/crystal/pull/8804), [#8811](https://github.com/crystal-lang/crystal/pull/8811), [#8982](https://github.com/crystal-lang/crystal/pull/8982), thanks @bcardiff, @oprypin)
- Update to Shards 0.10.0. ([#8988](https://github.com/crystal-lang/crystal/pull/8988), thanks @bcardiff)
- Fix `pretty_json` sample. ([#8816](https://github.com/crystal-lang/crystal/pull/8816), thanks @asterite)
- Fix typos throughout the codebase. ([#8971](https://github.com/crystal-lang/crystal/pull/8971), thanks @Sija)

## [0.33.0] - 2020-02-14
[0.33.0]: https://github.com/crystal-lang/crystal/releases/0.33.0

### Language changes

- Allow `timeout` in select statements. ([#8506](https://github.com/crystal-lang/crystal/pull/8506), [#8705](https://github.com/crystal-lang/crystal/pull/8705), thanks @bcardiff, @firejox, @vlazar)

#### Macros

- Add `TypeNode#name(generic_args : BoolLiteral)` to return `TypeNode`'s name with or without type vars. ([#8483](https://github.com/crystal-lang/crystal/pull/8483), thanks @Blacksmoke16)

### Standard library

- **(breaking-change)** Remove several previously deprecated methods and modules: `PartialComparable`, `Crypto::Bcrypt::Password#==`, `HTTP::Server::Response#respond_with_error`, `JSON::PullParser::Kind#==`, `Symbol#==(JSON::PullParser::Kind)`, `JSON::Token#type`, `String#at`, `Time.new`, `Time.now`, `Time.utc_now`, `URI.escape`, `URI.unescape`. ([#8646](https://github.com/crystal-lang/crystal/pull/8646), [#8596](https://github.com/crystal-lang/crystal/pull/8596), thanks @bcardiff, @Blacksmoke16)
- Fixed docs wording. ([#8606](https://github.com/crystal-lang/crystal/pull/8606), [#8784](https://github.com/crystal-lang/crystal/pull/8784), thanks @fxn)
- Add `Object#in?`. ([#8720](https://github.com/crystal-lang/crystal/pull/8720), [#8723](https://github.com/crystal-lang/crystal/pull/8723), thanks @Sija)
- Allow to create an enum from a symbol. ([#8634](https://github.com/crystal-lang/crystal/pull/8634), thanks @bew)
- Add `VaList#next` for getting the next element in a variadic argument list. ([#8535](https://github.com/crystal-lang/crystal/pull/8535), [#8688](https://github.com/crystal-lang/crystal/pull/8688), thanks @ffwff, @RX14)
- Refactor `ARGF` implementation. ([#8593](https://github.com/crystal-lang/crystal/pull/8593), thanks @arcage)
- Fixed specs of `Colorize` on dumb terminal. ([#8673](https://github.com/crystal-lang/crystal/pull/8673), thanks @oprypin)
- Fixed some specs on Win32. ([#8670](https://github.com/crystal-lang/crystal/pull/8670), thanks @straight-shoota)

#### Numeric

- Add `BigInt#unsafe_shr`. ([#8763](https://github.com/crystal-lang/crystal/pull/8763), thanks @asterite)
- Refactor `Float#fdiv` to use binary primitive. ([#8662](https://github.com/crystal-lang/crystal/pull/8662), thanks @bcardiff)

#### Text

- Fixed `\u0000` wrongly added on `String#sub(Hash)` replaces last char. ([#8644](https://github.com/crystal-lang/crystal/pull/8644), thanks @mimame)

#### Collections

- Fixed `Enumerable#zip` to work with union types. ([#8621](https://github.com/crystal-lang/crystal/pull/8621), thanks @asterite)
- Fixed docs regarding `Hash`'s `initial_capacity`. ([#8569](https://github.com/crystal-lang/crystal/pull/8569), thanks @r00ster91)

#### Serialization

- Improved JSON deserialization into union types. ([#8689](https://github.com/crystal-lang/crystal/pull/8689), thanks @KimBurgess)
- Fixed expected error message in libxml2 error spec. ([#8699](https://github.com/crystal-lang/crystal/pull/8699), thanks @straight-shoota)
- Fixed `JSON::PullParser` overflow handling. ([#8698](https://github.com/crystal-lang/crystal/pull/8698), thanks @KimBurgess)
- Fixed `JSON::Any#dig?`/`YAML::Any#dig?` on non-structure values. ([#8745](https://github.com/crystal-lang/crystal/pull/8745), thanks @Sija)

#### Time

- Fixed `Time#shift` over date boundaries with zone offset. ([#8742](https://github.com/crystal-lang/crystal/pull/8742), thanks @straight-shoota)

#### Files

- **(breaking-change)** Deprecate `File::Info#owner`, and `File::Info#group`; use `owner_id`, and `group_id`. ([#8007](https://github.com/crystal-lang/crystal/pull/8007), thanks @j8r)
- Fixed `Path.new` receiving `Path` as first argument. ([#8753](https://github.com/crystal-lang/crystal/pull/8753), thanks @straight-shoota)
- Fixed `File.size` and `File.info` to work with `Path` parameters. ([#8625](https://github.com/crystal-lang/crystal/pull/8625), thanks @snluu)
- Fixed `Path` specs when `ENV["HOME"]` is unset. ([#8667](https://github.com/crystal-lang/crystal/pull/8667), thanks @straight-shoota)
- Refactor `Dir.mkdir_p` to use `Path#each_parent` and make it work on Win32. ([#8668](https://github.com/crystal-lang/crystal/pull/8668), thanks @straight-shoota)
- Fixed `IO::MultiWriter` specs to close file before reading/deleting it. ([#8674](https://github.com/crystal-lang/crystal/pull/8674), thanks @oprypin)

#### Networking

- Fixed invalid call to libevent and race conditions on closed `IO` when resuming readable/writable event. ([#8707](https://github.com/crystal-lang/crystal/pull/8707), [#8733](https://github.com/crystal-lang/crystal/pull/8733), thanks @bcardiff)
- Fixed unexpected EOF in terminated SSL connection. ([#8540](https://github.com/crystal-lang/crystal/pull/8540), thanks @rdp)
- Fixed `HTTP::Cookie` to support `Int64` max-age values. ([#8759](https://github.com/crystal-lang/crystal/pull/8759), thanks @asterite)
- Improve error message for `getaddrinfo` failure. ([#8498](https://github.com/crystal-lang/crystal/pull/8498), thanks @rdp)
- Make `IO::SysCall#wait_readable` and `IO::SysCall#wait_writable` public, yet `:nodoc:`. ([#7366](https://github.com/crystal-lang/crystal/pull/7366), thanks @stakach)
- Refactor `StaticFileHandler` to use `Path`. ([#8672](https://github.com/crystal-lang/crystal/pull/8672), thanks @straight-shoota)
- Remove fixed date in spec. ([#8640](https://github.com/crystal-lang/crystal/pull/8640), thanks @bcardiff)
- Remove non-portable error message in `TCPServer` spec. ([#8702](https://github.com/crystal-lang/crystal/pull/8702), thanks @straight-shoota)

#### Crypto

- Add `Crypto::Bcrypt::Password` check for invalid hash value. ([#6467](https://github.com/crystal-lang/crystal/pull/6467), thanks @miketheman)
- Improve documentation for `Random::Secure`. ([#8484](https://github.com/crystal-lang/crystal/pull/8484), thanks @straight-shoota)

#### Concurrency

- Fixed `Future(Nil)` when the block raises. ([#8650](https://github.com/crystal-lang/crystal/pull/8650), thanks @lbguilherme)
- Fixed `IO` closing in multi-thread mode. ([#8733](https://github.com/crystal-lang/crystal/pull/8733), thanks @bcardiff)
- Fixed some regular failing specs in multi-thread mode. ([#8592](https://github.com/crystal-lang/crystal/pull/8592), [#8643](https://github.com/crystal-lang/crystal/pull/8643), [#8724](https://github.com/crystal-lang/crystal/pull/8724), [#8761](https://github.com/crystal-lang/crystal/pull/8761), thanks @bcardiff)
- Add docs to `Fiber`. ([#8739](https://github.com/crystal-lang/crystal/pull/8739), thanks @straight-shoota)

#### System

- Enable `system` module for Win32 in prelude. ([#8661](https://github.com/crystal-lang/crystal/pull/8661), thanks @straight-shoota)
- Handle exceptions raised at `__crystal_sigfault_handler`. ([#8743](https://github.com/crystal-lang/crystal/pull/8743), thanks @waj)

#### Runtime

- Fixed wrongly collected exception object by the GC. Ensure `LibUnwind::Exception` struct is not atomic. ([#8728](https://github.com/crystal-lang/crystal/pull/8728), thanks @waj)
- Fixed reporting of non-statement rows in DWARF backtrace. ([#8499](https://github.com/crystal-lang/crystal/pull/8499), thanks @rdp)
- Add top level exception handler. ([#8735](https://github.com/crystal-lang/crystal/pull/8735), [#8791](https://github.com/crystal-lang/crystal/pull/8791), thanks @waj)
- Try to open stdio in non-blocking mode. ([#8787](https://github.com/crystal-lang/crystal/pull/8787), thanks @waj)
- Allow `Crystal::System.print_error` to use `printf` like format. ([#8786](https://github.com/crystal-lang/crystal/pull/8786), thanks @bcardiff)

#### Spec

- **(breaking-change)** Remove previously deprecated spec method `assert`. ([#8767](https://github.com/crystal-lang/crystal/pull/8767), thanks @Blacksmoke16)
- `Spec::JUnitFormatter` output and options enhancements. ([#8599](https://github.com/crystal-lang/crystal/pull/8599), [#8692](https://github.com/crystal-lang/crystal/pull/8692), thanks @Sija, @bcardiff)

### Compiler

- **(breaking-change)** Drop support for previously deprecated comma separators in enums and other cleanups. ([#8657](https://github.com/crystal-lang/crystal/pull/8657), thanks @bcardiff)
- **(breaking-change)** Drop uppercase F32 and F64 float number suffixes. ([#8782](https://github.com/crystal-lang/crystal/pull/8782), thanks @rhysd)
- Fixed memory corruption issues by using LLVM's `memset` and `memcpy` that matches target machine. ([#8746](https://github.com/crystal-lang/crystal/pull/8746), thanks @bcardiff)
- Fixed ICE when trying to add type inside annotation. ([#8628](https://github.com/crystal-lang/crystal/pull/8628), thanks @asterite)
- Fixed ICE on `typeof` in an unused block. ([#8695](https://github.com/crystal-lang/crystal/pull/8695), thanks @asterite)
- Fixed ICE in case of wrong target triple. ([#8710](https://github.com/crystal-lang/crystal/pull/8710), thanks @Sija)
- Fixed ICE when raising a macro exception with empty message. ([#8654](https://github.com/crystal-lang/crystal/pull/8654), thanks @jan-zajic)
- Fixed parser bug macro with "eenum" in it. ([#8760](https://github.com/crystal-lang/crystal/pull/8760), thanks @asterite)
- Change `CRYSTAL_PATH` to allow shards to override std-lib. ([#8752](https://github.com/crystal-lang/crystal/pull/8752), thanks @bcardiff)

#### Language semantics

- Fixed missing virtualization of `Proc` pointer. ([#8757](https://github.com/crystal-lang/crystal/pull/8757), thanks @asterite)
- Fixed type of vars after `begin`/`rescue` if all `rescue` are unreachable. ([#8758](https://github.com/crystal-lang/crystal/pull/8758), thanks @asterite)
- Fixed visibility propagation to macro expansions in all cases. ([#8762](https://github.com/crystal-lang/crystal/pull/8762), [#8796](https://github.com/crystal-lang/crystal/pull/8796), thanks @asterite)

### Tools

- Update `crystal init` to handle `.`. ([#8681](https://github.com/crystal-lang/crystal/pull/8681), thanks @jethrodaniel)

#### Formatter

- Fixed indent after comment inside indexer. ([#8627](https://github.com/crystal-lang/crystal/pull/8627), thanks @asterite)
- Fixed indent of comments at the end of a proc literal. ([#8778](https://github.com/crystal-lang/crystal/pull/8778), thanks @asterite)
- Fixed crash when formatting comment after macro. ([#8697](https://github.com/crystal-lang/crystal/pull/8697), thanks @asterite)
- Fixed crash when formatting `exp.!`. ([#8768](https://github.com/crystal-lang/crystal/pull/8768), thanks @asterite)
- Removes unnecessary escape sequences. ([#8619](https://github.com/crystal-lang/crystal/pull/8619), thanks @RX14)

#### Doc generator

- **(breaking-change)** Deprecate `ditto` and `nodoc` in favor of `:ditto:` and `:nodoc:`. ([#6362](https://github.com/crystal-lang/crystal/pull/6362), thanks @j8r)
- Skip creation of `docs/` dir when not needed. ([#8718](https://github.com/crystal-lang/crystal/pull/8718), thanks @Sija)

### Others

- CI improvements and housekeeping. ([#8580](https://github.com/crystal-lang/crystal/pull/8580), [#8597](https://github.com/crystal-lang/crystal/pull/8597), [#8679](https://github.com/crystal-lang/crystal/pull/8679), [#8779](https://github.com/crystal-lang/crystal/pull/8779), thanks @bcardiff, @j8r)
- Add Windows CI using GitHub Actions. ([#8676](https://github.com/crystal-lang/crystal/pull/8676), thanks @oprypin)
- Add Alpine CI using CircleCI. ([#7420](https://github.com/crystal-lang/crystal/pull/7420), thanks @straight-shoota)
- Build Alpine Docker images. ([#8708](https://github.com/crystal-lang/crystal/pull/8708), thanks @straight-shoota)
- Allow `Makefile` to use `lld` if present (Linux only). ([#8641](https://github.com/crystal-lang/crystal/pull/8641), thanks @bcardiff)
- Simplify script to determine installed LLVM version. ([#8605](https://github.com/crystal-lang/crystal/pull/8605), thanks @j8r)
- Add CircleCI test summaries. ([#8617](https://github.com/crystal-lang/crystal/pull/8617), thanks @Sija)
- Add helper scripts to identify working std-lib specs on Win32. ([#8664](https://github.com/crystal-lang/crystal/pull/8664), thanks @straight-shoota)

## [0.32.1] - 2019-12-18
[0.32.1]: https://github.com/crystal-lang/crystal/releases/0.32.1

### Standard library

#### Collections

- Fixed docs of `Enumerable#each_cons_pair` and `Iterator#cons_pair`. ([#8585](https://github.com/crystal-lang/crystal/pull/8585), thanks @arcage)

#### Networking

- Fixed `HTTP::WebSocket`'s `on_close` callback is called for all errors. ([#8552](https://github.com/crystal-lang/crystal/pull/8552), thanks @stakach)
- Fixed sporadic failure in specs with OpenSSL 1.1+. ([#8582](https://github.com/crystal-lang/crystal/pull/8582), thanks @rdp)

### Compiler

#### Language semantics

- Combine contiguous string literals before string interpolation. ([#8581](https://github.com/crystal-lang/crystal/pull/8581), thanks @asterite)

## [0.32.0] - 2019-12-11
[0.32.0]: https://github.com/crystal-lang/crystal/releases/0.32.0

### Language changes

- Allow boolean negation to be written also as a regular method call `expr.!`. ([#8445](https://github.com/crystal-lang/crystal/pull/8445), thanks @jan-zajic)

#### Macros

- Add `TypeNode#class_vars` to list class variables of a type in a macro. ([#8405](https://github.com/crystal-lang/crystal/pull/8405), thanks @jan-zajic)
- Add `TypeNode#includers` to get an array of types a module is directly included in. ([#8133](https://github.com/crystal-lang/crystal/pull/8133), thanks @Blacksmoke16)
- Add `ArrayLiteral#map_with_index` and `TupleLiteral#map_with_index`. ([#8049](https://github.com/crystal-lang/crystal/pull/8049), thanks @Blacksmoke16)
- Add docs for `ArrayLiteral#reduce`. ([#8379](https://github.com/crystal-lang/crystal/pull/8379), thanks @jan-zajic)
- Add `lower:` named argument to `StringLiteral#camelcase`. ([#8429](https://github.com/crystal-lang/crystal/pull/8429), thanks @Blacksmoke16)

### Standard library

- **(breaking-change)** Remove `Readline` from std-lib. It's now available as a shard at [crystal-lang/crystal-readline](https://www.github.com/crystal-lang/crystal-readline) ([#8364](https://github.com/crystal-lang/crystal/pull/8364), thanks @ftarulla)
- Move `Number#clamp` to `Comparable#clamp`. ([#8522](https://github.com/crystal-lang/crystal/pull/8522), thanks @wontruefree)
- Allow `abort` without arguments. ([#8214](https://github.com/crystal-lang/crystal/pull/8214), thanks @dbackeus)
- Improve error message for not-nil assertion in getters. ([#8200](https://github.com/crystal-lang/crystal/pull/8200), [#8296](https://github.com/crystal-lang/crystal/pull/8296), thanks @icy-arctic-fox)
- Add `Enum.valid?`. ([#5716](https://github.com/crystal-lang/crystal/pull/5716), thanks @MakeNowJust)
- Disable colored output if `TERM=dumb`. ([#8271](https://github.com/crystal-lang/crystal/pull/8271), thanks @ilanpillemer)
- Documentation improvements. ([#7656](https://github.com/crystal-lang/crystal/pull/7656), [#8337](https://github.com/crystal-lang/crystal/pull/8337), [#8446](https://github.com/crystal-lang/crystal/pull/8446), thanks @r00ster91, @vlazar, @cserb)
- Add docs for pseudo methods. ([#8327](https://github.com/crystal-lang/crystal/pull/8327), [#8491](https://github.com/crystal-lang/crystal/pull/8491), thanks @straight-shoota)
- Code cleanups. ([#8270](https://github.com/crystal-lang/crystal/pull/8270), [#8368](https://github.com/crystal-lang/crystal/pull/8368), [#8404](https://github.com/crystal-lang/crystal/pull/8404), thanks @asterite, @vlazar, @arcage)

#### Numeric

- Fixed `%` and `Int#remainder` edge case of min int value against `-1`. ([#8321](https://github.com/crystal-lang/crystal/pull/8321), thanks @asterite)
- Fixed `Int#gcd` types edge case and improve performance. ([#7996](https://github.com/crystal-lang/crystal/pull/7996), [#8419](https://github.com/crystal-lang/crystal/pull/8419), thanks @yxhuvud, @j8r)
- Add `Int#bits` for accessing bit ranges. ([#8165](https://github.com/crystal-lang/crystal/pull/8165), thanks @stakach)
- Allow `Number#round` with `UInt` argument. ([#8361](https://github.com/crystal-lang/crystal/pull/8361), thanks @igor-alexandrov)

#### Text

- **(breaking-change)** Implement string interpolation as a call to `String.interpolation`. ([#8400](https://github.com/crystal-lang/crystal/pull/8400), thanks @asterite)
- **(breaking-change)** Deprecate `String#codepoint_at`, use `char_at(index).ord`. ([#8475](https://github.com/crystal-lang/crystal/pull/8475), thanks @vlazar)
- Fixed encoding specs for musl iconv. ([#8525](https://github.com/crystal-lang/crystal/pull/8525), thanks @straight-shoota)
- Add `String#presence`. ([#8345](https://github.com/crystal-lang/crystal/pull/8345), [#8508](https://github.com/crystal-lang/crystal/pull/8508), thanks @igor-alexandrov, @Sija)
- Add `String#center`. ([#8557](https://github.com/crystal-lang/crystal/pull/8557), thanks @hutou)
- **(performance)** Refactor `String#to_utf16` optimizing for ascii-only. ([#8526](https://github.com/crystal-lang/crystal/pull/8526), thanks @straight-shoota)
- Add docs in `Levenshtein` module. ([#8386](https://github.com/crystal-lang/crystal/pull/8386), thanks @katafrakt)
- Add docs to `Regex::Options`. ([#8448](https://github.com/crystal-lang/crystal/pull/8448), thanks @jan-zajic)

#### Collections

- **(breaking-change)** Deprecate `Enumerable#grep`, use `Enumerable#select`. ([#8452](https://github.com/crystal-lang/crystal/pull/8452), thanks @j8r)
- Fixed `Enumerable#minmax`, `#min`, `#max` for partially comparable values. ([#8490](https://github.com/crystal-lang/crystal/pull/8490), thanks @TedTran2019)
- Fixed `Hash#rehash`. ([#8450](https://github.com/crystal-lang/crystal/pull/8450), thanks @asterite)
- Fixed `Array` range assignment index out of bounds. ([#8347](https://github.com/crystal-lang/crystal/pull/8347), thanks @asterite)
- Fixed endless ranged support for `String#[]?` and `Array#[]?`. ([#8567](https://github.com/crystal-lang/crystal/pull/8567), thanks @KarthikMAM)
- Add `Hash#compare_by_identity` and `Set#compare_by_identity`. ([#8451](https://github.com/crystal-lang/crystal/pull/8451), thanks @asterite)
- Add `Enumerable#each_cons_pair` and `Iterator#cons_pair` yielding a tuple. ([#8332](https://github.com/crystal-lang/crystal/pull/8332), thanks @straight-shoota)
- Add `offset` argument to all `map_with_index` methods. ([#8264](https://github.com/crystal-lang/crystal/pull/8264), thanks @asterite)
- **(performance)** Optimized version of `Tuple#to_a`. ([#8265](https://github.com/crystal-lang/crystal/pull/8265), thanks @asterite)
- Add docs to `Hash.merge!(other : Hash, &)`. ([#8380](https://github.com/crystal-lang/crystal/pull/8380), thanks @jan-zajic)
- Add docs to `Hash.select`. ([#8391](https://github.com/crystal-lang/crystal/pull/8391), thanks @jan-zajic)
- Add docs and specs to `Enumerable.reduce`. ([#8378](https://github.com/crystal-lang/crystal/pull/8378), thanks @jan-zajic)

#### Serialization

- **(breaking-change)** Make `XML::Reader#expand` raise, introduce `XML::Reader#expand?` for former behavior. ([#8186](https://github.com/crystal-lang/crystal/pull/8186), thanks @Blacksmoke16)
- Allow `JSON.mapping` & `YAML.mapping` converter attribute to be applied to `Array` and `Hash`. ([#8156](https://github.com/crystal-lang/crystal/pull/8156), thanks @rodrigopinto)
- Add `use_json_discriminator` and `use_yaml_discriminator` to choose type based on property value. ([#8406](https://github.com/crystal-lang/crystal/pull/8406), thanks @asterite)
- Remove return type `self` restriction from `Object.from_json` and `Object.from_yaml`. ([#8489](https://github.com/crystal-lang/crystal/pull/8489), thanks @straight-shoota)

#### Files

- **(breaking-change)** Remove expand home (`~`) by default in `File.expand_path` and `Path#expand`, now opt-in argument. ([#7903](https://github.com/crystal-lang/crystal/pull/7903), thanks @didactic-drunk)
- Fixed bugs in `Path` regarding `#dirname`, `#each_part`, `#each_parent`. ([#8415](https://github.com/crystal-lang/crystal/pull/8415), thanks @jan-zajic)
- Fixed `GZip::Reader` and `GZip::Writer` to handle large data sizes. ([#8421](https://github.com/crystal-lang/crystal/pull/8421), thanks @straight-shoota)
- Fixed `File::Info#same_file?` by providing access to 64 bit inode numbers. ([#8355](https://github.com/crystal-lang/crystal/pull/8355), thanks @didactic-drunk)

#### Networking

- Fixed `HTTP::Response#mime_type` returns `nil` on empty `Content-Type` header. ([#8464](https://github.com/crystal-lang/crystal/pull/8464), thanks @Sija)
- Fixed handling of unidirectional SSL servers hang. ([#8481](https://github.com/crystal-lang/crystal/pull/8481), thanks @rdp)
- Add `HTTP::Client#write_timeout`. ([#8507](https://github.com/crystal-lang/crystal/pull/8507), thanks @Sija)
- Updated mime type of `.js` files to `text/javascript` and include `image/webp`. ([#8342](https://github.com/crystal-lang/crystal/pull/8342), thanks @mamantoha)
- Refactor websocket protocol GUID string. ([#8339](https://github.com/crystal-lang/crystal/pull/8339), thanks @vlazar)

#### Crypto

- **(breaking-change)** Enforce single-line results of `OpenSSL::DigestBase#base64digest` via `Base64.strict_encode`. ([#8215](https://github.com/crystal-lang/crystal/pull/8215), thanks @j8r)

#### Concurrency

- Fixed `Channel` successful sent and raise behavior. ([#8284](https://github.com/crystal-lang/crystal/pull/8284), thanks @firejox)
- Fixed `Channel#close` to be thread-safe. ([#8249](https://github.com/crystal-lang/crystal/pull/8249), thanks @firejox)
- Fixed `select` with `receive?` and closed channels. ([#8304](https://github.com/crystal-lang/crystal/pull/8304), thanks @bcardiff)
- Faster `Mutex` implementation and policy checks. ([#8295](https://github.com/crystal-lang/crystal/pull/8295), [#8563](https://github.com/crystal-lang/crystal/pull/8563), thanks @waj, @ysbaddaden)
- **(performance)** Channel internals refactor and optimize. ([#8322](https://github.com/crystal-lang/crystal/pull/8322), [#8497](https://github.com/crystal-lang/crystal/pull/8497), thanks @firejox, @Sija)
- Add docs to `Channel#send` and `Channel#close`. ([#8356](https://github.com/crystal-lang/crystal/pull/8356), thanks @lbarasti)
- Fixed `Thread#gc_thread_handler` for Windows support. ([#8519](https://github.com/crystal-lang/crystal/pull/8519), thanks @straight-shoota)

#### System

- Don't close pipes used for signal handlers in multi-thread mode. ([#8465](https://github.com/crystal-lang/crystal/pull/8465), thanks @waj)
- Fixed thread initialization on OpenBSD. ([#8293](https://github.com/crystal-lang/crystal/pull/8293), thanks @wmoxam)
- Implement fibers for win32. ([#7995](https://github.com/crystal-lang/crystal/pull/7995), [#8513](https://github.com/crystal-lang/crystal/pull/8513), thanks @straight-shoota, @firejox)

#### Runtime

- Fixed fiber initialization on `-Dgc_none -Dpreview_mt`. ([#8280](https://github.com/crystal-lang/crystal/pull/8280), thanks @bcardiff)
- Add GC profiling stats and warning bindings. ([#8281](https://github.com/crystal-lang/crystal/pull/8281), thanks @bcardiff, @benoist)
- Refactor `callstack_spec`. ([#8308](https://github.com/crystal-lang/crystal/pull/8308), [#8395](https://github.com/crystal-lang/crystal/pull/8395), thanks @straight-shoota, @Sija)

#### Spec

- Fixed `--fail-fast` behaviour. ([#8453](https://github.com/crystal-lang/crystal/pull/8453), thanks @asterite)
- Add before, after, and around hooks. ([#8302](https://github.com/crystal-lang/crystal/pull/8302), thanks @asterite)
- Restrict the type returned by `should_not be_nil` and others. ([#8412](https://github.com/crystal-lang/crystal/pull/8412), thanks @asterite)
- Add ability to randomize specs via `--order random|<seed-value>`. ([#8310](https://github.com/crystal-lang/crystal/pull/8310), thanks @Fryguy)
- Add specs for `Spec` filters. ([#8242](https://github.com/crystal-lang/crystal/pull/8242), thanks @Fryguy)
- Add ability to tag specs. ([#8068](https://github.com/crystal-lang/crystal/pull/8068), thanks @Fryguy)

### Compiler

- Fixed musl libc detection (Alpine 3.10 regression bug). ([#8330](https://github.com/crystal-lang/crystal/pull/8330), thanks @straight-shoota)
- Fixed pragmas handling in macros. ([#8256](https://github.com/crystal-lang/crystal/pull/8256), thanks @asterite)
- Fixed parser crash for 'alias Foo?'. ([#8282](https://github.com/crystal-lang/crystal/pull/8282), thanks @oprypin)
- Fixed parser error on newline before closing parenthesis. ([#8320](https://github.com/crystal-lang/crystal/pull/8320), thanks @MakeNowJust)
- Fixed generic subtypes edge cases triggering `no target defs` error. ([#8417](https://github.com/crystal-lang/crystal/pull/8417), thanks @asterite)
- Fixed cleanup of local vars reachable by macros. ([#8529](https://github.com/crystal-lang/crystal/pull/8529), thanks @asterite)
- Add support for LLVM 9. ([#8358](https://github.com/crystal-lang/crystal/pull/8358), thanks @RX14)
- Add `--mcmodel` option to compiler. ([#8363](https://github.com/crystal-lang/crystal/pull/8363), thanks @ffwff)
- Disallow `instance_sizeof` on union. ([#8399](https://github.com/crystal-lang/crystal/pull/8399), thanks @asterite)
- Add mention to `crystal <command> --help` in help. ([#3628](https://github.com/crystal-lang/crystal/pull/3628), thanks @rdp)
- Improve error message when a filename is misspelled. ([#8500](https://github.com/crystal-lang/crystal/pull/8500), thanks @rdp)
- Show full path of locally compiled Crystal. ([#8486](https://github.com/crystal-lang/crystal/pull/8486), thanks @rdp)
- Code cleanups. ([#8460](https://github.com/crystal-lang/crystal/pull/8460), thanks @veelenga)

#### Language semantics

- Fixed method lookup priority when type alias of union is used. ([#8258](https://github.com/crystal-lang/crystal/pull/8258), thanks @asterite)
- Fixed visibility modifiers in virtual types. ([#8562](https://github.com/crystal-lang/crystal/pull/8562), thanks @asterite)
- Fixed `sizeof(Bool)`. ([#8273](https://github.com/crystal-lang/crystal/pull/8273), thanks @asterite)

### Tools

#### Formatter

- Fixed indent in arguments. ([#8315](https://github.com/crystal-lang/crystal/pull/8315), thanks @MakeNowJust)
- Fixed crash related to parenthesis on generic types. ([#8501](https://github.com/crystal-lang/crystal/pull/8501), thanks @asterite)

#### Doc generator

- Fixed underscore type restriction in doc generator. ([#8331](https://github.com/crystal-lang/crystal/pull/8331), thanks @straight-shoota)
- Correctly attach docs through multiple macro invocations. ([#8502](https://github.com/crystal-lang/crystal/pull/8502), thanks @asterite)
- Allow constants to use `:ditto:`. ([#8389](https://github.com/crystal-lang/crystal/pull/8389), thanks @Blacksmoke16)
- Add sitemap generator. ([#8348](https://github.com/crystal-lang/crystal/pull/8348), thanks @straight-shoota)
- Add documentation for pseudo-methods: `!`, `as`, `nil?`, etc.. ([#8327](https://github.com/crystal-lang/crystal/pull/8327), [#8371](https://github.com/crystal-lang/crystal/pull/8371), thanks @straight-shoota)
- Add clickable anchor icon next to headings. ([#8344](https://github.com/crystal-lang/crystal/pull/8344), thanks @Blacksmoke16)
- Use `&` instead of `&block` for signature of yielding method. ([#8394](https://github.com/crystal-lang/crystal/pull/8394), thanks @j8r)

#### Playground

- Do not collapse whitespaces in playground sidebar. ([#8528](https://github.com/crystal-lang/crystal/pull/8528), thanks @hugopl)

### Others

- CI improvements and housekeeping. ([#8210](https://github.com/crystal-lang/crystal/pull/8210), [#8251](https://github.com/crystal-lang/crystal/pull/8251), [#8283](https://github.com/crystal-lang/crystal/pull/8283), [#8439](https://github.com/crystal-lang/crystal/pull/8439), [#8510](https://github.com/crystal-lang/crystal/pull/8510), thanks @bcardiff)
- Update base docker images to `bionic` and LLVM 8.0. ([#8442](https://github.com/crystal-lang/crystal/pull/8442), thanks @bcardiff)
- Repository clean-up. ([#8312](https://github.com/crystal-lang/crystal/pull/8312), [#8397](https://github.com/crystal-lang/crystal/pull/8397), thanks @bcardiff, @straight-shoota)

## [0.31.1] - 2019-09-30
[0.31.1]: https://github.com/crystal-lang/crystal/releases/0.31.1

### Standard library

#### Numeric

- Fixed overflow in `Random::Secure`. ([#8224](https://github.com/crystal-lang/crystal/pull/8224), thanks @oprypin)

#### Networking

- Workaround `IO::Evented#evented_write` invalid `IndexError` error. ([#8239](https://github.com/crystal-lang/crystal/pull/8239), thanks @bcardiff)

#### Concurrency

- Use bdw-gc upstream patch for green threads support. ([#8225](https://github.com/crystal-lang/crystal/pull/8225), thanks @bcardiff)
- Refactor `Channel` to use records instead of tuples. ([#8227](https://github.com/crystal-lang/crystal/pull/8227), thanks @asterite)

#### Spec

- Add `before_suite` and `after_suite` hooks. ([#8238](https://github.com/crystal-lang/crystal/pull/8238), thanks @asterite)

### Compiler

- Fix debug location information when emitting main code from module. ([#8234](https://github.com/crystal-lang/crystal/pull/8234), thanks @asterite)

#### Language semantics

- Use virtual type for `uninitialized`. ([#8221](https://github.com/crystal-lang/crystal/pull/8221), thanks @asterite)

## [0.31.0] - 2019-09-23
[0.31.0]: https://github.com/crystal-lang/crystal/releases/0.31.0

### Language changes

- Allow non-captured block args with type restriction using `& : T -> U`. ([#8117](https://github.com/crystal-lang/crystal/pull/8117), thanks @asterite)

#### Macros

- Ensure `@type` is devirtualized inside macros. ([#8149](https://github.com/crystal-lang/crystal/pull/8149), thanks @asterite)

### Standard library

- **(breaking-change)** Remove `Markdown` from the std-lib. ([#8115](https://github.com/crystal-lang/crystal/pull/8115), thanks @asterite)
- **(breaking-change)** Deprecate `OptionParser#parse!`, use `OptionParser#parse`. ([#8041](https://github.com/crystal-lang/crystal/pull/8041), thanks @didactic-drunk)
- Fix example codes in multiple places. ([#8194](https://github.com/crystal-lang/crystal/pull/8194), thanks @maiha)

#### Numeric

- **(breaking-change)** Enable overflow by default. ([#8170](https://github.com/crystal-lang/crystal/pull/8170), thanks @bcardiff)
- **(breaking-change)** Make `/` the arithmetic division for all types. ([#8120](https://github.com/crystal-lang/crystal/pull/8120), thanks @bcardiff)
- Add `BigDecimal#**` and `BigRational#**` (pow operator). ([#7860](https://github.com/crystal-lang/crystal/pull/7860), thanks @jwbuiter)
- Avoid overflow exception in `Number#round(digits, base)`. ([#8204](https://github.com/crystal-lang/crystal/pull/8204), thanks @bcardiff)
- Refactor `Int#divisible_by?` for clarity. ([#8045](https://github.com/crystal-lang/crystal/pull/8045), thanks @yxhuvud)

#### Text

- **(performance)** Minor `String#lchop?` ASCII-only optimization. ([#8052](https://github.com/crystal-lang/crystal/pull/8052), thanks @r00ster91)

#### Collections

- **(performance)** Array optimizations for small number of elements. ([#8048](https://github.com/crystal-lang/crystal/pull/8048), thanks @asterite)
- **(performance)** Optimize `Array#*`. ([#8087](https://github.com/crystal-lang/crystal/pull/8087), thanks @asterite)
- **(performance)** Hash now uses an open addressing algorithm. ([#8017](https://github.com/crystal-lang/crystal/pull/8017), [#8182](https://github.com/crystal-lang/crystal/pull/8182), thanks @asterite)
- **(performance)** Optimize `Hash#to_a`, `Hash#keys` and `Hash#values`. ([#8042](https://github.com/crystal-lang/crystal/pull/8042), thanks @asterite)
- **(performance)** Add `Hash#put` and optimize `Set#add?`. ([#8116](https://github.com/crystal-lang/crystal/pull/8116), thanks @asterite)
- Fixed `Slice#==` for some generic instantiations, add `Slice#<=>`. ([#8074](https://github.com/crystal-lang/crystal/pull/8074), thanks @asterite)
- Add docs on idempotence and methods involving eager evaluation in `Iterator`. ([#8053](https://github.com/crystal-lang/crystal/pull/8053), thanks @KimBurgess)
- Add `Set#+`. ([#8121](https://github.com/crystal-lang/crystal/pull/8121), thanks @sam0x17)
- Refactor `Hash` to use integer division instead of float division. ([#8104](https://github.com/crystal-lang/crystal/pull/8104), thanks @asterite)

#### Serialization

- **(breaking-change)** Rename `XML::Type` to `XML::Node::Type`, introduce `XML::Reader::Type`. ([#8134](https://github.com/crystal-lang/crystal/pull/8134), thanks @asterite)
- Fixed JSON and YAML parsing of `NamedTuple` with nilable fields. ([#8109](https://github.com/crystal-lang/crystal/pull/8109), thanks @asterite)
- Fixed YAML to emit unicode characters as such. ([#8132](https://github.com/crystal-lang/crystal/pull/8132), thanks @asterite)
- Fixed INI generation of empty sections. ([#8106](https://github.com/crystal-lang/crystal/pull/8106), thanks @j8r)

#### Files

- **(performance)** Optimize `Path#join` by precomputing capacity if possible. ([#8078](https://github.com/crystal-lang/crystal/pull/8078), thanks @asterite)
- **(performance)** Optimize `Path#join` for the case of joining one single part. ([#8082](https://github.com/crystal-lang/crystal/pull/8082), thanks @asterite)
- **(performance)** Optimize `Dir.glob`. ([#8081](https://github.com/crystal-lang/crystal/pull/8081), thanks @asterite)
- Fixed `File.basename` off-by-one corner-case. ([#8119](https://github.com/crystal-lang/crystal/pull/8119), thanks @ysbaddaden)
- Fixed unneeded evaluation of `Path.home` on `Path.expand`. ([#8128](https://github.com/crystal-lang/crystal/pull/8128), thanks @asterite)
- Fixed `Zip::Writer` STORED compression. ([#8142](https://github.com/crystal-lang/crystal/pull/8142), thanks @asterite)
- Fixed missing check on `ARGF` if read_count is zero. ([#8177](https://github.com/crystal-lang/crystal/pull/8177), thanks @Blacksmoke16)

#### Networking

- **(breaking-change)** Replace `HTTP::Server::Response#respond_with_error` with `#respond_with_status`. ([#6988](https://github.com/crystal-lang/crystal/pull/6988), thanks @straight-shoota)
- **(breaking-change)** Handle too long URIs and too large header fields in `HTTP::Request.from_io` and remove `HTTP::Request::BadRequest`. ([#8013](https://github.com/crystal-lang/crystal/pull/8013), thanks @straight-shoota)
- Fixed memory leak from `SSL_new` if `ssl_accept` fails. ([#8088](https://github.com/crystal-lang/crystal/pull/8088), thanks @rdp)
- Fixed WebSocket ipv6 hostname connection. ([#8066](https://github.com/crystal-lang/crystal/pull/8066), thanks @MrSorcus)
- Add `URI#query_params` method. ([#8090](https://github.com/crystal-lang/crystal/pull/8090), thanks @rodrigopinto)
- Add `URI#resolve` and `URI#relativize`. ([#7716](https://github.com/crystal-lang/crystal/pull/7716), thanks @straight-shoota)
- Add `#clear`, `#delete`, and `#size` methods to `HTTP::Cookies`. ([#8107](https://github.com/crystal-lang/crystal/pull/8107), thanks @sam0x17)
- Refactor `http/server_spec`. ([#8056](https://github.com/crystal-lang/crystal/pull/8056), thanks @straight-shoota)
- Refactor UDP specs to use random port. ([#8139](https://github.com/crystal-lang/crystal/pull/8139), thanks @waj)

#### Concurrency

- Multithreading. ([#8112](https://github.com/crystal-lang/crystal/pull/8112), thanks @waj)
- Delay releasing of fiber stack in multi-thread mode. ([#8138](https://github.com/crystal-lang/crystal/pull/8138), thanks @waj)
- Make `Crystal::Scheduler.init_workers` block until workers are ready. ([#8145](https://github.com/crystal-lang/crystal/pull/8145), thanks @bcardiff)
- Make `Crystal::ThreadLocalValue` thread-safe. ([#8168](https://github.com/crystal-lang/crystal/pull/8168), thanks @waj)
- Let `exec_recursive` use a thread-local data structure. ([#8146](https://github.com/crystal-lang/crystal/pull/8146), thanks @asterite)
- Add explicit return types for some channel methods. ([#8161](https://github.com/crystal-lang/crystal/pull/8161), thanks @Blacksmoke16)
- Remove the dedicated fiber to run the event loop. ([#8173](https://github.com/crystal-lang/crystal/pull/8173), thanks @waj)
- Fix corruption of thread linked list. ([#8196](https://github.com/crystal-lang/crystal/pull/8196), thanks @waj)
- Workaround compile on win32 until fibers is implemented. ([#8195](https://github.com/crystal-lang/crystal/pull/8195), thanks @straight-shoota)

#### System

- Increase precision of `Process.times`. ([#8097](https://github.com/crystal-lang/crystal/pull/8097), thanks @jgaskins)

#### Spec

- **(breaking-change)** Add support for `focus`. ([#8125](https://github.com/crystal-lang/crystal/pull/8125), [#8178](https://github.com/crystal-lang/crystal/pull/8178), [#8208](https://github.com/crystal-lang/crystal/pull/8208), thanks @asterite, @straight-shoota, @bcardiff)

### Compiler

- Fixed ICE on declarations inside fun. ([#8076](https://github.com/crystal-lang/crystal/pull/8076), thanks @asterite)
- Fixed missing `name_location` of some calls. ([#8192](https://github.com/crystal-lang/crystal/pull/8192), thanks @asterite)
- Activate compiler warnings by default. ([#8171](https://github.com/crystal-lang/crystal/pull/8171), thanks @bcardiff)
- Improve return type mismatch error. ([#8203](https://github.com/crystal-lang/crystal/pull/8203), thanks @asterite)
- Improve `for` expression error. ([#7641](https://github.com/crystal-lang/crystal/pull/7641), thanks @r00ster91)

#### Language semantics

- Fixed abstract def check regarding generic ancestor lookup. ([#8098](https://github.com/crystal-lang/crystal/pull/8098), thanks @asterite)
- Fixed missing virtualization of type arguments in `Proc` types. ([#8159](https://github.com/crystal-lang/crystal/pull/8159), thanks @asterite)
- Fixed incorrect typing after exception handler. ([#8037](https://github.com/crystal-lang/crystal/pull/8037), thanks @asterite)
- Fixed behaviour when a yield node can't be typed. ([#8101](https://github.com/crystal-lang/crystal/pull/8101), thanks @asterite)
- Fixed `offsetof` on reference types. ([#8137](https://github.com/crystal-lang/crystal/pull/8137), thanks @mcr431)
- Allow rescue var to be closured. ([#8143](https://github.com/crystal-lang/crystal/pull/8143), thanks @asterite)
- Refactor class var and constant initialization. ([#8067](https://github.com/crystal-lang/crystal/pull/8067), [#8091](https://github.com/crystal-lang/crystal/pull/8091), thanks @waj)
- Add runtime check for recursive initialization of class variables and constants. ([#8172](https://github.com/crystal-lang/crystal/pull/8172), thanks @waj)

### Tools

#### Doc generator

- Fixed link to constructors of another class. ([#8110](https://github.com/crystal-lang/crystal/pull/8110), thanks @asterite)
- Enable docs from previous def and/or ancestors to be inherited. ([#6989](https://github.com/crystal-lang/crystal/pull/6989), thanks @asterite)

### Others

- Update CI to use 0.30.1. ([#8032](https://github.com/crystal-lang/crystal/pull/8032), thanks @bcardiff)
- Use LLVM 8.0 for Linux official packages. ([#8155](https://github.com/crystal-lang/crystal/pull/8155), thanks @bcardiff, @RX14)
- Update dependencies of the build process. ([#8205](https://github.com/crystal-lang/crystal/pull/8205), thanks @bcardiff)
- Code cleanups. ([#8033](https://github.com/crystal-lang/crystal/pull/8033), thanks @straight-shoota)

## [0.30.1] - 2019-08-12
[0.30.1]: https://github.com/crystal-lang/crystal/releases/0.30.1

### Standard library

#### Numeric

- Fixed `Number#humanize` digits. ([#8027](https://github.com/crystal-lang/crystal/pull/8027), thanks @straight-shoota)

#### Networking

- Fixed TCP socket leaking after failed SSL connect in `HTTP::Client#socket`. ([#8025](https://github.com/crystal-lang/crystal/pull/8025), thanks @straight-shoota)
- Honor normalized header names for HTTP requests. ([#8061](https://github.com/crystal-lang/crystal/pull/8061), thanks @asterite)

#### Concurrency

- Don't resume fibers directly from event loop callbacks (or support for libevent 2.1.11). ([#8058](https://github.com/crystal-lang/crystal/pull/8058), thanks @waj)

### Compiler

- Fixed `sizeof(Nil)` and other empty types. ([#8040](https://github.com/crystal-lang/crystal/pull/8040), thanks @asterite)
- Avoid internal globals of type i128 or u128. (or workaround [a llvm 128 bits bug](https://bugs.llvm.org/show_bug.cgi?id=42932)). ([#8063](https://github.com/crystal-lang/crystal/pull/8063), thanks @bcardiff, @asterite)

#### Language semantics

- Consider abstract method implementation in supertype for abstract method checks. ([#8035](https://github.com/crystal-lang/crystal/pull/8035), thanks @asterite)

### Tools

#### Formatter

- Handle consecutive macro literals when subformatting. ([#8034](https://github.com/crystal-lang/crystal/pull/8034), thanks @asterite)
- Fixed crash when formatting syntax error inside macro. ([#8055](https://github.com/crystal-lang/crystal/pull/8055), thanks @asterite)

### Others

- Use LLVM 6.0.1 for darwin official packages. ([#7994](https://github.com/crystal-lang/crystal/pull/7994), thanks @bcardiff)
- Split std_specs in 32 bits CI. ([#8065](https://github.com/crystal-lang/crystal/pull/8065), thanks @bcardiff)

## [0.30.0] - 2019-08-01
[0.30.0]: https://github.com/crystal-lang/crystal/releases/0.30.0

### Language changes

- **(breaking-change)** Enforce abstract methods return types. ([#7956](https://github.com/crystal-lang/crystal/pull/7956), [#7999](https://github.com/crystal-lang/crystal/pull/7999), [#8010](https://github.com/crystal-lang/crystal/pull/8010), thanks @asterite)
- **(breaking-change)** Don't allow ranges to span across lines. ([#7888](https://github.com/crystal-lang/crystal/pull/7888), thanks @oprypin)

#### Macros

- Add `args`/`named_args` macro methods to `Annotations`. ([#7694](https://github.com/crystal-lang/crystal/pull/7694), thanks @Blacksmoke16)
- Unify `resolve` and `types` macro methods API for `Type` and `Path` for convenience. ([#7970](https://github.com/crystal-lang/crystal/pull/7970), thanks @asterite)

### Standard library

- **(breaking-change)** Remove `UUID#to_slice` in favor of `UUID#bytes` to fix dangling pointer issues. ([#7901](https://github.com/crystal-lang/crystal/pull/7901), thanks @ysbaddaden)
- **(performance)** Improve `Box` of reference types. ([#8016](https://github.com/crystal-lang/crystal/pull/8016), thanks @waj)
- Fixed initial seed of `Random::ISAAC`. ([#7977](https://github.com/crystal-lang/crystal/pull/7977), thanks @asterite)
- Fixed mem intrinsics for aarch64. ([#7983](https://github.com/crystal-lang/crystal/pull/7983), thanks @drujensen)
- Add `Benchmark.memory`. ([#7835](https://github.com/crystal-lang/crystal/pull/7835), thanks @r00ster91)
- Allow setting default capacity for `StringPool`. ([#7899](https://github.com/crystal-lang/crystal/pull/7899), thanks @carlhoerberg)
- Add type restrictions to `INI`. ([#7831](https://github.com/crystal-lang/crystal/pull/7831), thanks @j8r)
- Fixed `Logger` docs. ([#7898](https://github.com/crystal-lang/crystal/pull/7898), thanks @dprobinson)
- Fix example codes in multiple places. ([#8003](https://github.com/crystal-lang/crystal/pull/8003), thanks @maiha)

#### Numeric

- Fixed incorrect `Int#%` overflow. ([#7980](https://github.com/crystal-lang/crystal/pull/7980), thanks @asterite)
- Fixed inconsistency between `Float#to_s` and `BigFloat#to_s`, always show `.0` for whole numbers. ([#7982](https://github.com/crystal-lang/crystal/pull/7982), thanks @Lasvad)

#### Text

- Fixed unicode alternate ranges generation. ([#7924](https://github.com/crystal-lang/crystal/pull/7924), thanks @asterite)

#### Collections

- Add `Enumerable#tally`. ([#7921](https://github.com/crystal-lang/crystal/pull/7921), thanks @kachick)
- Add `Enumerable#reduce?` overload with not initial value. ([#7941](https://github.com/crystal-lang/crystal/pull/7941), thanks @miketheman)
- Fix specs of `Enumerable#min_by?`. ([#7919](https://github.com/crystal-lang/crystal/pull/7919), thanks @kachick)

#### Serialization

- **(breaking-change)** JSON: use enums instead of symbols. ([#7966](https://github.com/crystal-lang/crystal/pull/7966), thanks @asterite)
- Fixed YAML deserialization of String in a union type. ([#7938](https://github.com/crystal-lang/crystal/pull/7938), thanks @asterite)
- Validate element names in `XML::Builder`. ([#7965](https://github.com/crystal-lang/crystal/pull/7965), thanks @Blacksmoke16)
- Allow numeric keys in JSON (ie: `Hash(Int32, String).from_json`). ([#7944](https://github.com/crystal-lang/crystal/pull/7944), thanks @asterite)
- Add `alias`/`merge` methods to `YAML::Builder` and `YAML::Nodes::Builder`. ([#7949](https://github.com/crystal-lang/crystal/pull/7949), thanks @Blacksmoke16)

#### Files

- Adds `File.readlink` to match `File.symlink`. ([#7858](https://github.com/crystal-lang/crystal/pull/7858), thanks @didactic-drunk)

#### Networking

- **(breaking-change)** Improve URL encoding. `URI.escape` and `URI.unescape` are renamed to `URI.encode_www_form` and `URI.decode_www_form`. Add `URI.encode` and `URI.decode`. ([#7997](https://github.com/crystal-lang/crystal/pull/7997), [#8021](https://github.com/crystal-lang/crystal/pull/8021), thanks @straight-shoota, @bcardiff)
- **(performance)** HTTP protocol parsing optimizations. ([#8002](https://github.com/crystal-lang/crystal/pull/8002), [#8009](https://github.com/crystal-lang/crystal/pull/8009), thanks @asterite)
- Fixed `HTTP::Server` response double-close. ([#7908](https://github.com/crystal-lang/crystal/pull/7908), thanks @asterite)
- Enforce `HTTP::Client` host argument is just a host. ([#7958](https://github.com/crystal-lang/crystal/pull/7958), thanks @asterite)
- Allow `HTTP::Params.encode` to encode an arrays of values for a key. ([#7862](https://github.com/crystal-lang/crystal/pull/7862), thanks @rodrigopinto)
- Forward `read_timeout`/`write_timeout` in ssl socket to underlaying socket. ([#7820](https://github.com/crystal-lang/crystal/pull/7820), thanks @carlhoerberg)
- Natively support [Same-site Cookies](https://tools.ietf.org/html/draft-west-first-party-cookies-07#section-4.1.1). ([#7864](https://github.com/crystal-lang/crystal/pull/7864), thanks @Blacksmoke16)
- Allow setting buffer size for `IO::Buffered`. ([#7930](https://github.com/crystal-lang/crystal/pull/7930), thanks @carlhoerberg)

#### Crypto

- Require openssl algorithm in pkcs5. ([#7985](https://github.com/crystal-lang/crystal/pull/7985), thanks @will)
- Fixed cipher expectation in `OpenSSL::SSL::Socket` spec. ([#7871](https://github.com/crystal-lang/crystal/pull/7871), thanks @j8r)

#### Concurrency

- Fixed `sysconf` call on OpenBSD. ([#7879](https://github.com/crystal-lang/crystal/pull/7879), thanks @jcs)

#### System

- Introduce `System::User` and `System::Group`. ([#7725](https://github.com/crystal-lang/crystal/pull/7725), thanks @woodruffw, @chris-huxtable)
- Add docs for `Process::Status.exit_status` (#7873). ([#8014](https://github.com/crystal-lang/crystal/pull/8014), thanks @UlisseMini)

### Compiler

- Fixed codegen of `pointer.as(Nil)`. ([#8019](https://github.com/crystal-lang/crystal/pull/8019), thanks @asterite)
- Fixed edge cases in parser and stringifier. ([#7886](https://github.com/crystal-lang/crystal/pull/7886), thanks @oprypin)
- Fixed `concrete_types` for virtual metaclass and modules. ([#7951](https://github.com/crystal-lang/crystal/pull/7951), thanks @bcardiff)
- Fixed incorrect `remove_indirection` in `TypeDefType`. ([#7971](https://github.com/crystal-lang/crystal/pull/7971), thanks @bcardiff)
- Fixed missing `CRYSTAL_SPEC_COMPILER_FLAGS` usage in some more specs. ([774768](https://github.com/crystal-lang/crystal/commit/77476800836eb47c8d783e2259bf21c2992f2041), thanks @bcardiff)
- Revamp compile error formatting & output. ([#7748](https://github.com/crystal-lang/crystal/pull/7748), thanks @martimatix)
- Add support for LLVM 8. ([#7987](https://github.com/crystal-lang/crystal/pull/7987), thanks @bcardiff)
- Add support for LLVM 7. ([#7986](https://github.com/crystal-lang/crystal/pull/7986), thanks @bcardiff, @waj, @foutrelis, @wmoxam)
- Add debug log helper function for codegen. ([#7935](https://github.com/crystal-lang/crystal/pull/7935), [#7937](https://github.com/crystal-lang/crystal/pull/7937), thanks @bcardiff)
- Refactor codegen of unions. ([#7940](https://github.com/crystal-lang/crystal/pull/7940), thanks @bcardiff)
- Move `LLVMId` from `CodeGenVisitor` to `Program`. ([#7973](https://github.com/crystal-lang/crystal/pull/7973), thanks @bcardiff)
- Minor additions and refactors on for LLVM codegen. ([#7972](https://github.com/crystal-lang/crystal/pull/7972), thanks @bcardiff)
- Add `bin/check-compiler-flag` helper script. Add `make clean_cache`. ([da3892](https://github.com/crystal-lang/crystal/commit/da38927f3a00f1e6e5ea86b96ca669533f0aa438), thanks @bcardiff)

#### Language semantics

- Fixed generic metaclass argument expansion. ([#7916](https://github.com/crystal-lang/crystal/pull/7916), thanks @asterite)
- Fixed top-level private const not being scoped. ([#7907](https://github.com/crystal-lang/crystal/pull/7907), thanks @asterite)
- Fixed enum overflow when declaring members. ([#7881](https://github.com/crystal-lang/crystal/pull/7881), thanks @asterite)
- Fixed annotation lookup on generic types. ([#7891](https://github.com/crystal-lang/crystal/pull/7891), thanks @asterite)

### Tools

#### Formatter

- Format top-level inline macros. ([#7889](https://github.com/crystal-lang/crystal/pull/7889), [#7992](https://github.com/crystal-lang/crystal/pull/7992), thanks @asterite)

#### Doc generator

- Allow rendering tags on methods without any docs. ([#7952](https://github.com/crystal-lang/crystal/pull/7952), thanks @Blacksmoke16)

### Others

- Update CI to use 0.29.0. ([#7863](https://github.com/crystal-lang/crystal/pull/7863), thanks @bcardiff)
- Automated snap publishing. ([#7893](https://github.com/crystal-lang/crystal/pull/7893), thanks @bcardiff)
- ~~Use LLVM 6.0.1 for darwin official packages.~~ ([#7994](https://github.com/crystal-lang/crystal/pull/7994), thanks @bcardiff)

## [0.29.0] - 2019-06-05
[0.29.0]: https://github.com/crystal-lang/crystal/releases/0.29.0

### Standard library

- Fix example codes in multiple places. ([#7718](https://github.com/crystal-lang/crystal/pull/7718), thanks @maiha)

#### Macros

- Fix inheritance support of `record` macro. ([#7811](https://github.com/crystal-lang/crystal/pull/7811), thanks @asterite)
- Omit quotes in `puts` macro output. ([#7734](https://github.com/crystal-lang/crystal/pull/7734), thanks @asterite)

#### Numeric

- **(performance)** Optimize `String#to_u` methods for the case of a negative number. ([#7446](https://github.com/crystal-lang/crystal/pull/7446), thanks @r00ster91)

#### Text

- **(breaking-change)** Deprecate `String#at`, use `String#char_at`. ([#7633](https://github.com/crystal-lang/crystal/pull/7633), thanks @j8r)
- **(breaking-change)** Change `String#to_i` to parse octals with prefix `0o` (but not `0` by default). ([#7691](https://github.com/crystal-lang/crystal/pull/7691), thanks @icy-arctic-fox)
- **(breaking-change)** Restrict some `String#to_i` arguments to be `Bool`. ([#7436](https://github.com/crystal-lang/crystal/pull/7436), thanks @j8r)
- Add `downcase` option to `String#camelcase`. ([#7717](https://github.com/crystal-lang/crystal/pull/7717), thanks @wontruefree)
- Add support for unicode 12.0.0. ([#7721](https://github.com/crystal-lang/crystal/pull/7721), thanks @Blacksmoke16)
- Fix `Unicode` not showing up in the API docs. ([#7720](https://github.com/crystal-lang/crystal/pull/7720), thanks @r00ster91)

#### Collections

- **(breaking-change)** Remove `Slice#pointer`. ([#7581](https://github.com/crystal-lang/crystal/pull/7581), thanks @Maroo-b)
- Add sort methods to `Slice`. ([#7597](https://github.com/crystal-lang/crystal/pull/7597), thanks @Maroo-b)
- Add `Slice#[]?`. ([#7701](https://github.com/crystal-lang/crystal/pull/7701), thanks @Sija)
- Improve docs for `Slice#[]`. ([#7780](https://github.com/crystal-lang/crystal/pull/7780), thanks @Sija)

#### Serialization

- YAML: let String handle numbers too. ([#7809](https://github.com/crystal-lang/crystal/pull/7809), thanks @asterite)

#### Time

- Fix time format RFC 3339 to not include offset seconds. ([#7492](https://github.com/crystal-lang/crystal/pull/7492), thanks @straight-shoota)

#### Files

- **(breaking-change)** Rename `File::DEVNULL` to `File::NULL`. ([#7778](https://github.com/crystal-lang/crystal/pull/7778), thanks @r00ster91)
- Fix handling of files starting with `~` in `Path#expand`. ([#7768](https://github.com/crystal-lang/crystal/pull/7768), thanks @byroot)
- Fix `Dir.glob(match_hidden: false)` not hiding hidden files properly. ([#7774](https://github.com/crystal-lang/crystal/pull/7774), thanks @ayazhafiz)

#### Networking

- **(breaking-change)** Let `IO#copy` return `UInt64`. ([#7660](https://github.com/crystal-lang/crystal/pull/7660), thanks @asterite)
- Add support for UDP multicast. ([#7423](https://github.com/crystal-lang/crystal/pull/7423), thanks @stakach)
- Add missing requires to `openssl.cr`. ([#7803](https://github.com/crystal-lang/crystal/pull/7803), thanks @RX14)
- Add `IO::MultiWriter#flush`. ([#7765](https://github.com/crystal-lang/crystal/pull/7765), thanks @mamantoha)
- Add `OpenSSL::SSL::Socket#cipher` and `#tls_version`. ([#7445](https://github.com/crystal-lang/crystal/pull/7445), thanks @carlhoerberg)
- Improve `URI#normalize`. ([#7635](https://github.com/crystal-lang/crystal/pull/7635), thanks @straight-shoota)
- Improve documentation of some `URI` methods. ([#7796](https://github.com/crystal-lang/crystal/pull/7796), thanks @r00ster91)
- Refactor `StaticFileHandler` specs for `Last-Modified` header. ([#7640](https://github.com/crystal-lang/crystal/pull/7640), thanks @straight-shoota)
- Refactor compression usage in handler specs. ([#7819](https://github.com/crystal-lang/crystal/pull/7819), thanks @asterite)

#### Crypto

- **(breaking-change)** Rename `Crypto::Bcrypt::Password#==` to `#verify`. ([#7790](https://github.com/crystal-lang/crystal/pull/7790), thanks @asterite)

#### Concurrency

- Add docs for `Channel`. ([#7673](https://github.com/crystal-lang/crystal/pull/7673), thanks @j8r)

### Compiler

- **(breaking-change)** Fix require relative path resolution. ([#7758](https://github.com/crystal-lang/crystal/pull/7758), thanks @asterite)
- **(breaking-change)** Disallow '!' or '?' at the end of the LHS in an assignment. ([#7582](https://github.com/crystal-lang/crystal/pull/7582), thanks @Maroo-b)
- Allow running compiler_specs with specific flags. ([#7837](https://github.com/crystal-lang/crystal/pull/7837), thanks @bcardiff)
- Fix extend from generic types. ([#7812](https://github.com/crystal-lang/crystal/pull/7812), thanks @asterite)
- Don't virtualize types in `Union(...)` and keep more accurate type information. ([#7815](https://github.com/crystal-lang/crystal/pull/7815), thanks @asterite)
- Do not generate debug metadata for arguments of naked functions. ([#7775](https://github.com/crystal-lang/crystal/pull/7775), thanks @eyusupov)
- Detect deprecation on initialize methods and methods with named args. ([#7724](https://github.com/crystal-lang/crystal/pull/7724), thanks @bcardiff)
- Fix track of AST nodes location. ([#7827](https://github.com/crystal-lang/crystal/pull/7827), thanks @asterite)
- Fix `offsetof` not being usable with macros. ([#7703](https://github.com/crystal-lang/crystal/pull/7703), thanks @malte-v)
- Allow parsing of `call &.@ivar`. ([#7754](https://github.com/crystal-lang/crystal/pull/7754), thanks @asterite)
- Fix `Def#to_s` with `**options` and `&block`. ([#7854](https://github.com/crystal-lang/crystal/pull/7854), thanks @MakeNowJust)
- Check `pointerof` inner expression for errors. ([#7755](https://github.com/crystal-lang/crystal/pull/7755), thanks @asterite)
- Fix some error messages. ([#7833](https://github.com/crystal-lang/crystal/pull/7833), thanks @asterite)
- Improve wording of `pointerof(self)` parser error. ([#7542](https://github.com/crystal-lang/crystal/pull/7542), thanks @r00ster91)
- Fix typo. ([#7828](https://github.com/crystal-lang/crystal/pull/7828), thanks @RX14)

#### Language semantics

- **(breaking-change)** Fix new/initialize lookup regarding modules. ([#7818](https://github.com/crystal-lang/crystal/pull/7818), thanks @asterite)
- **(breaking-change)**  Don't precompute `sizeof` on abstract structs and modules. ([#7801](https://github.com/crystal-lang/crystal/pull/7801), thanks @asterite)
- Consider macro calls in `@ivar` initializer. ([#7750](https://github.com/crystal-lang/crystal/pull/7750), thanks @asterite)
- Give precedence to `T.class` over `Class` in method lookup. ([#7759](https://github.com/crystal-lang/crystal/pull/7759), thanks @asterite)
- Honor enum base type on non-default values. ([#7776](https://github.com/crystal-lang/crystal/pull/7776), thanks @asterite)
- Avoid lookup of private def defined inside macro. ([#7733](https://github.com/crystal-lang/crystal/pull/7733), thanks @asterite)
- Improve type flow of var in `if` with `&&`. ([#7785](https://github.com/crystal-lang/crystal/pull/7785), thanks @asterite)
- Fix handling of `NoReturn` in `if`. ([#7792](https://github.com/crystal-lang/crystal/pull/7792), thanks @asterite)
- Improve edge issues with `while` and `rescue`. ([#7806](https://github.com/crystal-lang/crystal/pull/7806), thanks @asterite)
- Improve error on macro call in proc pointer. ([#7757](https://github.com/crystal-lang/crystal/pull/7757), thanks @asterite)
- Fix error on named args forwarding. ([#7756](https://github.com/crystal-lang/crystal/pull/7756), thanks @asterite)
- Check `NoReturn` type in named args. ([#7761](https://github.com/crystal-lang/crystal/pull/7761), thanks @asterite)
- Fix internal handling of unbound/abstract generic types. ([#7781](https://github.com/crystal-lang/crystal/pull/7781), thanks @asterite)
- Fix wrong cast to unbound generic type. ([#7793](https://github.com/crystal-lang/crystal/pull/7793), thanks @asterite)
- Fix subclass observer to handle edge case call over generic types. ([#7735](https://github.com/crystal-lang/crystal/pull/7735), thanks @asterite)
- Fix edge case of abstract struct with one subclass. ([#7787](https://github.com/crystal-lang/crystal/pull/7787), thanks @asterite)
- Make automatic cast work with `with ... yield`. ([#7746](https://github.com/crystal-lang/crystal/pull/7746), thanks @asterite)

### Tools

- Allow to lookup class and module implementations. ([#7742](https://github.com/crystal-lang/crystal/pull/7742), thanks @MakeNowJust)
- Refactor old duplicated 'def contains_target'. ([#7739](https://github.com/crystal-lang/crystal/pull/7739), thanks @MakeNowJust)

#### Formatter

- Don't produce unnecessary newline before named args following heredoc. ([#7695](https://github.com/crystal-lang/crystal/pull/7695), thanks @MakeNowJust)
- Fix formatting of multiline call arguments. ([#7745](https://github.com/crystal-lang/crystal/pull/7745), thanks @MakeNowJust)
- Fix formatting of annotations with newlines and spaces. ([#7744](https://github.com/crystal-lang/crystal/pull/7744), thanks @MakeNowJust)
- Refactor code to format &.[]. ([#7699](https://github.com/crystal-lang/crystal/pull/7699), thanks @MakeNowJust)

### Others

- CI improvements and housekeeping. ([#7705](https://github.com/crystal-lang/crystal/pull/7705), [#7852](https://github.com/crystal-lang/crystal/pull/7852), thanks @bcardiff)
- Move VERSION inside ./src. ([#7804](https://github.com/crystal-lang/crystal/pull/7804), thanks @bcardiff)

## [0.28.0] - 2019-04-17
[0.28.0]: https://github.com/crystal-lang/crystal/releases/0.28.0

### Language changes

- **(breaking-change)** Enum declaration members can no longer be separated by a space, only by a newline, `;` or `,`, the latter being deprecated and reformatted to a newline. ([#7607](https://github.com/crystal-lang/crystal/pull/7607), [#7618](https://github.com/crystal-lang/crystal/pull/7618), thanks @asterite, and @j8r)
- Add begin-less and end-less ranges: `array[5..]`.  ([#7179](https://github.com/crystal-lang/crystal/pull/7179), thanks @asterite)
- Add `offsetof(Type, @ivar)` expression. ([#7589](https://github.com/crystal-lang/crystal/pull/7589), thanks @malte-v)

#### Macros

- Add `Type#annotations` to list all annotations and not just the last of each kind. ([#7326](https://github.com/crystal-lang/crystal/pull/7326), thanks @Blacksmoke16)
- Add `ArrayLiteral#sort_by` macro method. ([#3947](https://github.com/crystal-lang/crystal/pull/3947), thanks @jreinert)

### Standard library

- **(breaking-change)** Allow creating `None` enum flag with `Enum.from_value`. ([#6516](https://github.com/crystal-lang/crystal/pull/6516), thanks @bew)
- **(breaking-change)** Add deprecation message to `PartialComparable`. Its behaviour has been fully integrated into `Comparable`. ([#7664](https://github.com/crystal-lang/crystal/pull/7664), thanks @straight-shoota)
- **(performance)** Optimize dwarf line numbers decoding. ([#7413](https://github.com/crystal-lang/crystal/pull/7413), thanks @asterite)
- Fix `Signal::CHLD.reset` not clearing previous handler. ([#7409](https://github.com/crystal-lang/crystal/pull/7409), thanks @asterite)
- Add lazy versions of `Object.getter?` and `Object.property?` macros. ([#7322](https://github.com/crystal-lang/crystal/pull/7322), thanks @Sija)
- Allow returning other values than `-1`, `0` and `1` by `Comparable#<=>`. ([#7277](https://github.com/crystal-lang/crystal/pull/7277), thanks @r00ster91)
- Add missing `require` statements to samples in the API docs. ([#7564](https://github.com/crystal-lang/crystal/pull/7564), thanks @Maroo-b)
- Fix example codes in multiple places. ([#7569](https://github.com/crystal-lang/crystal/pull/7569), thanks @maiha)
- Add documentation for `@[Flags]` and `@[Link]` annotations. ([#7665](https://github.com/crystal-lang/crystal/pull/7665), thanks @bcardiff)
- Add documentation for `Bool`. ([#7651](https://github.com/crystal-lang/crystal/pull/7651), thanks @wontruefree)
- Refactor to avoid usage of the thread-local `$errno` GLIBC_PRIVATE symbol. ([#7496](https://github.com/crystal-lang/crystal/pull/7496), thanks @felixvf)
- Refactor to have similar signatures across the stdlib for `#to_s` and `#inspect`. ([#7528](https://github.com/crystal-lang/crystal/pull/7528), thanks @wontruefree)

#### Numeric

- **(breaking-change)** Add deprecation message to `Int#/`. It will return a `Float` in `0.29.0`. Use `Int#//` for integer division. ([#7639](https://github.com/crystal-lang/crystal/pull/7639), thanks @bcardiff)
- Change `Number#inspect` to not show the type suffixes. ([#7525](https://github.com/crystal-lang/crystal/pull/7525), thanks @asterite)
- Add `Int#leading_zeros_count` and `Int#trailing_zeros_count`. ([#7520](https://github.com/crystal-lang/crystal/pull/7520), thanks @Sija)
- Add `Big*#//`, `BigInt#&`-ops and missing `#floor`, `#ceil`, `#trunc`. ([#7638](https://github.com/crystal-lang/crystal/pull/7638), thanks @bcardiff)
- Improve `OverflowError` message. ([#7375](https://github.com/crystal-lang/crystal/pull/7375), thanks @r00ster91)

#### Text

- **(performance)** Optimize `String#compare` in case of ASCII only. ([#7352](https://github.com/crystal-lang/crystal/pull/7352), thanks @r00ster91)
- Add methods for human-readable formatting of numbers: `Number#format`, `Number#humanize`, and `Int#humanize_bytes`. ([#6314](https://github.com/crystal-lang/crystal/pull/6314), thanks @straight-shoota)
- Add `String#rchop?` and `String#lchop?`. ([#7328](https://github.com/crystal-lang/crystal/pull/7328), thanks @j8r)
- Add `options` argument to `String#camelcase` and `String#underscore`. ([#7374](https://github.com/crystal-lang/crystal/pull/7374), thanks @r00ster91)
- Add docs to `Unicode::CaseOptions`. ([#7513](https://github.com/crystal-lang/crystal/pull/7513), thanks @r00ster91)
- Improve specs and docs for `String#each_line` and `IO#each_line`. ([#7419](https://github.com/crystal-lang/crystal/pull/7419), thanks @straight-shoota)

#### Collections

- **(breaking-change)** Let `Array#sort` only use `<=>`, and let `<=>` return `nil` for partial comparability. ([#6611](https://github.com/crystal-lang/crystal/pull/6611), thanks @asterite)
- **(breaking-change)** Drop `Iterator#rewind`. Implement `#cycle` by storing elements in an array. ([#7440](https://github.com/crystal-lang/crystal/pull/7440), thanks @asterite)
- **(performance)** Add `Enumerable#each_cons` support for `Deque` as a reuse buffer. ([#7233](https://github.com/crystal-lang/crystal/pull/7233), thanks @yxhuvud)
- **(performance)** Change `Range#bsearch` `/ 2` to `>> 1` for faster performance. ([#7531](https://github.com/crystal-lang/crystal/pull/7531), thanks @Fryguy)
- Fix `Slice#clone` for non-primitive types and deep copy. ([#7591](https://github.com/crystal-lang/crystal/pull/7591), thanks @straight-shoota)
- Move `Indexable#zip` and `Indexable#zip?` to `Enumerable` and make it work with any number of `Indexable` or `Iterable` or `Iterator`. ([#7453](https://github.com/crystal-lang/crystal/pull/7453), thanks @asterite)
- Add `Slice#[](Range)`. ([#7439](https://github.com/crystal-lang/crystal/pull/7439), thanks @asterite)
- Add nillable range fetching `#[]?(Range)` to `Array` and `String`. ([#7338](https://github.com/crystal-lang/crystal/pull/7338), thanks @j8r)
- Add `Set#add?`. ([#7495](https://github.com/crystal-lang/crystal/pull/7495), thanks @Sija)
- Improve documentation of `Hash` regarding ordering of items. ([#7594](https://github.com/crystal-lang/crystal/pull/7594), thanks @straight-shoota)

#### Serialization

- **(breaking-change)** Change return type of `YAML#libyaml_version` to `SemanticVersion`. ([#7555](https://github.com/crystal-lang/crystal/pull/7555), thanks @asterite)
- Fix support for libxml2 2.9.9. ([#7477](https://github.com/crystal-lang/crystal/pull/7477), thanks @asterite)
- Fix support for libyaml 0.2.2. ([#7555](https://github.com/crystal-lang/crystal/pull/7555), thanks @asterite)
- Add `BigDecimal.from_yaml`. ([#7398](https://github.com/crystal-lang/crystal/pull/7398), thanks @Sija)

#### Time

- **(breaking-change)** Rename `Time` constructors. Deprecate `Time.now` to encourage usage  `Time.utc` or `Time.local` ([#5346](https://github.com/crystal-lang/crystal/pull/5346), [#7586](https://github.com/crystal-lang/crystal/pull/7586), thanks @straight-shoota)
- **(breaking-change)** Rename `Time#add_span` to `Time#shift` for changing a time instance by calendar units and handle other units. ([#6598](https://github.com/crystal-lang/crystal/pull/6598), thanks @straight-shoota)
- **(breaking-change)** Change `Time#date` to return a `Tuple` of `{year, month, day}`. Use `Time#at_beginning_of_day` if a `Time` instance is wanted. ([#5822](https://github.com/crystal-lang/crystal/pull/5822), thanks @straight-shoota)
- Fix Windows monotonic time bug. ([#7377](https://github.com/crystal-lang/crystal/pull/7377), thanks @domgetter)
- Refactor `Time` methods. ([#6581](https://github.com/crystal-lang/crystal/pull/6581), thanks @straight-shoota)

#### Files

- **(breaking-change)** Remove `IO#flush_on_newline` and only `sync` on `STDOUT`/`STDIN`/`STDERR` when they are TTY devices. ([#7470](https://github.com/crystal-lang/crystal/pull/7470), thanks @asterite)
- Add `Path` type. ([#5635](https://github.com/crystal-lang/crystal/pull/5635), thanks @straight-shoota)

#### Networking

- **(breaking-change)** Move `HTTP::Multipart` to `MIME::Multipart`. ([#7085](https://github.com/crystal-lang/crystal/pull/7085), thanks @m1lt0n)
- **(breaking-change)** Stop parsing JSON in OAuth2 errors. ([#7467](https://github.com/crystal-lang/crystal/pull/7467), thanks @asterite)
- **(breaking-change)** Fix `RequestProcessor` connection reuse logic. ([#7055](https://github.com/crystal-lang/crystal/pull/7055), thanks @straight-shoota)
- **(breaking-change)** Replace `HTTP.default_status_message_for(Int)` with `HTTP::Status.new(Int).description`. ([#7247](https://github.com/crystal-lang/crystal/pull/7247), thanks @dwightwatson)
- **(breaking-change)** Fix issues in `URI` implementation. `URI#opaque` method is merged into `URI#path`, which no longer returns `Nil`. `#parse`/`#to_s` normalization and default port handling has changed. ([#6323](https://github.com/crystal-lang/crystal/pull/6323), thanks @straight-shoota)
- Fix write buffering in OpenSSL sockets. ([#7460](https://github.com/crystal-lang/crystal/pull/7460), thanks @carlhoerberg)
- Fix leaks in `HTTP::Server` `#bind_*` and specs. ([#7197](https://github.com/crystal-lang/crystal/pull/7197), thanks @straight-shoota)
- Add `HTTP::Request#remote_address`. ([#7610](https://github.com/crystal-lang/crystal/pull/7610), thanks @asterite)
- Add `HTTP::Status` and `Response#status`. ([#7247](https://github.com/crystal-lang/crystal/pull/7247), [#7682](https://github.com/crystal-lang/crystal/pull/7682), thanks @dwightwatson, and @bcardiff)
- Add support for OAuth 2.0 resource owner password credentials grant type. ([#7424](https://github.com/crystal-lang/crystal/pull/7424), thanks @Blacksmoke16)
- Add support for IIS date format in cookies. ([#7405](https://github.com/crystal-lang/crystal/pull/7405), thanks @Sija)
- Allow calls to `IO::Syscall#wait_readable` and `IO::Syscall#wait_writable`. ([#7366](https://github.com/crystal-lang/crystal/pull/7366), thanks @stakach)

- Fix spec of `HTTP::Client` to not write server response after timeout. ([#7402](https://github.com/crystal-lang/crystal/pull/7402), thanks @asterite)
- Fix spec of `TCP::Server` for musl. ([#7484](https://github.com/crystal-lang/crystal/pull/7484), thanks @straight-shoota)

#### Crypto

- **(breaking-change)** Use `OpenSSL::Algorithm` instead of symbols for `digest`/`hexdigest`. Expose LibCrypt's `PKCS5_PBKDF2_HMAC`. ([#7264](https://github.com/crystal-lang/crystal/pull/7264), thanks @mniak)

#### Concurrency

- Add multi-threading ready GC when compiling with `-D preview_mt`. ([#7546](https://github.com/crystal-lang/crystal/pull/7546), thanks @bcardiff, @waj, and @ysbaddaden)
- Ship patched bdw-gc for multi-threading support. ([#7622](https://github.com/crystal-lang/crystal/pull/7622), thanks @bcardiff, and @ysbaddaden)
- Refactor to extract `Fiber::StackPool` from `Fiber`. ([#7417](https://github.com/crystal-lang/crystal/pull/7417), thanks @ysbaddaden)
- Refactor `IO::Syscall` as `IO::Evented`. ([#7505](https://github.com/crystal-lang/crystal/pull/7505), thanks @ysbaddaden)

#### System

- Add command and args to `execvp` error message. ([#7511](https://github.com/crystal-lang/crystal/pull/7511), thanks @straight-shoota)
- Refactor signals handling in a separate fiber. ([#7469](https://github.com/crystal-lang/crystal/pull/7469), thanks @asterite)

#### Spec

- Improve how running specs are cancelled upon `CTRL+C`. ([#7426](https://github.com/crystal-lang/crystal/pull/7426), thanks @asterite)
- Allow `pending` and `it` to accept constants. ([#7646](https://github.com/crystal-lang/crystal/pull/7646), thanks @straight-shoota)

### Compiler

- **(performance)** Avoid fork and spawn when `--threads=1`. ([#7397](https://github.com/crystal-lang/crystal/pull/7397), thanks @asterite)
- Fix exception type thrown on missing require. ([#7386](https://github.com/crystal-lang/crystal/pull/7386), thanks @asterite)
- Fix ICE when assigning a constant inside a multi-assign. ([#7468](https://github.com/crystal-lang/crystal/pull/7468), thanks @asterite)
- Fix parsing and behaviour of `->foo.[]` and other operators . ([#7334](https://github.com/crystal-lang/crystal/pull/7334), thanks @asterite)
- Fix parsing bug in `asm` with 3 colons and a variable. ([#7627](https://github.com/crystal-lang/crystal/pull/7627), thanks @r00ster91)
- Opt-in detection of calls to `@[Deprecated]` methods. ([#7596](https://github.com/crystal-lang/crystal/pull/7596), [#7626](https://github.com/crystal-lang/crystal/pull/7626), [#7661](https://github.com/crystal-lang/crystal/pull/7661), thanks @bcardiff)
- Add `CRYSTAL_LIBRARY_PATH` for lookup static libraries. ([#7562](https://github.com/crystal-lang/crystal/pull/7562), thanks @bcardiff)
- Improve error messages by adding the scope (and `with ... yield` scope, if any) on undefined method error. ([#7384](https://github.com/crystal-lang/crystal/pull/7384), thanks @asterite)
- Suggest `next` when trying to break from captured block . ([#7406](https://github.com/crystal-lang/crystal/pull/7406), thanks @r00ster91)
- Add detection of linux environment in compiler config. ([#7479](https://github.com/crystal-lang/crystal/pull/7479), thanks @straight-shoota)
- Pending leftovers to support `//` and `&`-ops in multiple places. ([#7628](https://github.com/crystal-lang/crystal/pull/7628), thanks @bcardiff)
- Refactor `Crystal::Config.version` to use `read_file` macro. ([#7081](https://github.com/crystal-lang/crystal/pull/7081), thanks @Sija)
- Rewrite macro spec without executing a shell command. ([#6962](https://github.com/crystal-lang/crystal/pull/6962), thanks @asterite)
- Fix typo in internals. ([#7592](https://github.com/crystal-lang/crystal/pull/7592), thanks @toshokan)

#### Language semantics

- Fix issues with `as`, `as?` and unions and empty types. ([#7475](https://github.com/crystal-lang/crystal/pull/7475), thanks @asterite)
- Fix method lookup when restrictions of instantiated and non-instantiated generic types are used. ([#7537](https://github.com/crystal-lang/crystal/pull/7537), thanks @bew)
- Fix method lookup when free vars and explicit types are used. ([#7536](https://github.com/crystal-lang/crystal/pull/7536), [#7580](https://github.com/crystal-lang/crystal/pull/7580), thanks @bew)
- When declaring a `protected initialize`, define a protected `new`. ([#7510](https://github.com/crystal-lang/crystal/pull/7510), thanks @asterite)
- Fix named args type matching. ([#7529](https://github.com/crystal-lang/crystal/pull/7529), thanks @asterite)
- Merge procs with the same arguments type and `Nil | T` return type to `Nil` return type. ([#7527](https://github.com/crystal-lang/crystal/pull/7527), thanks @asterite)
- Fix passing recursive alias to proc. ([#7568](https://github.com/crystal-lang/crystal/pull/7568), thanks @asterite)

### Tools

- Suggest the user to run the formatter in `travis.yml`. ([#7138](https://github.com/crystal-lang/crystal/pull/7138), thanks @KCErb)

#### Formatter

- Fix formatting of `1\n.as(Int32)`. ([#7347](https://github.com/crystal-lang/crystal/pull/7347), thanks @asterite)
- Fix formatting of nested array elements. ([#7450](https://github.com/crystal-lang/crystal/pull/7450), thanks @MakeNowJust)
- Fix formatting of comments and enums. ([#7605](https://github.com/crystal-lang/crystal/pull/7605), thanks @asterite)
- Fix CLI handling of absolute paths input. ([#7560](https://github.com/crystal-lang/crystal/pull/7560), thanks @RX14)

#### Doc generator

- Don't include private constants. ([#7575](https://github.com/crystal-lang/crystal/pull/7575), thanks @r00ster91)
- Include Crystal built-in constants. ([#7623](https://github.com/crystal-lang/crystal/pull/7623), thanks @bcardiff)
- Add compile-time flag to docs generator. ([#6668](https://github.com/crystal-lang/crystal/pull/6668), [#7438](https://github.com/crystal-lang/crystal/pull/7438), thanks @straight-shoota)
- Display deprecated label when `@[Deprecated]` is used. ([#7653](https://github.com/crystal-lang/crystal/pull/7653), thanks @bcardiff)

#### Playground

- Change the font-weight used for better readability. ([#7552](https://github.com/crystal-lang/crystal/pull/7552), thanks @Maroo-b)

### Others

- CI improvements and housekeeping. ([#7359](https://github.com/crystal-lang/crystal/pull/7359), [#7381](https://github.com/crystal-lang/crystal/pull/7381), [#7388](https://github.com/crystal-lang/crystal/pull/7388), [#7387](https://github.com/crystal-lang/crystal/pull/7387), [#7390](https://github.com/crystal-lang/crystal/pull/7390), [#7622](https://github.com/crystal-lang/crystal/pull/7622), thanks @bcardiff)
- Smoke test linux 64 bits package using docker image recent build. ([#7389](https://github.com/crystal-lang/crystal/pull/7389), thanks @bcardiff)
- Mention git pre-commit hook in `CONTRIBUTING.md`. ([#7617](https://github.com/crystal-lang/crystal/pull/7617), thanks @straight-shoota)
- Fix misspellings throughout the codebase. ([#7361](https://github.com/crystal-lang/crystal/pull/7361), thanks @Sija)
- Use chars instead of strings throughout the codebase. ([#6237](https://github.com/crystal-lang/crystal/pull/6237), thanks @r00ster91)
- Fix GC finalization warning in `Thread` specs. ([#7403](https://github.com/crystal-lang/crystal/pull/7403), thanks @asterite)
- Remove generated docs from linux packages. ([#7519](https://github.com/crystal-lang/crystal/issues/7519), thanks @straight-shoota)

## [0.27.2] - 2019-02-05
[0.27.2]: https://github.com/crystal-lang/crystal/releases/0.27.2

### Standard library

- Fixed integer overflow in main thread stack base detection. ([#7373](https://github.com/crystal-lang/crystal/pull/7373), thanks @ysbaddaden)

#### Networking

- Fixes TLS exception during shutdown. ([#7372](https://github.com/crystal-lang/crystal/pull/7372), thanks @bcardiff)
- Fixed `HTTP::Client` support exception on missing Content-Type. ([#7371](https://github.com/crystal-lang/crystal/pull/7371), thanks @bew)

## [0.27.1] - 2019-01-30
[0.27.1]: https://github.com/crystal-lang/crystal/releases/0.27.1

### Language changes

- Allow trailing commas inside tuple types. ([#7182](https://github.com/crystal-lang/crystal/pull/7182), thanks @asterite)

### Standard library

- **(performance)** Optimize generating `UUID` from `String`. ([#7030](https://github.com/crystal-lang/crystal/pull/7030), thanks @jgaskins)
- **(performance)** Improve `SemanticVersion` operations. ([#7234](https://github.com/crystal-lang/crystal/pull/7234), thanks @j8r)
- Fixed markdown inline code parsing. ([#7090](https://github.com/crystal-lang/crystal/pull/7090), thanks @MakeNowJust)
- Fixed inappropriate uses of `Time.now`. ([#7155](https://github.com/crystal-lang/crystal/pull/7155), thanks @straight-shoota)
- Make `Nil#not_nil!` raise `NilAssertionError`. ([#7330](https://github.com/crystal-lang/crystal/pull/7330), thanks @r00ster91)
- Add SemanticVersion to API docs. ([#7003](https://github.com/crystal-lang/crystal/pull/7003), thanks @Blacksmoke16)
- Add docs to discourage the use of `Bool#to_unsafe` other than for C bindings. ([#7320](https://github.com/crystal-lang/crystal/pull/7320), thanks @oprypin)
- Refactor `#to_s` to be independent of the `name` method. ([#7295](https://github.com/crystal-lang/crystal/pull/7295), thanks @asterite)

#### Macros

- Fixed docs of `ArrayLiteral#unshift`. ([#7127](https://github.com/crystal-lang/crystal/pull/7127), thanks @Blacksmoke16)
- Fixed `Annotation#[]` to accept `String` and `Symbol` as keys. ([#7153](https://github.com/crystal-lang/crystal/pull/7153), thanks @MakeNowJust)
- Fixed `NamedTupleLiteral#[]` to raise a compile error for invalid key type. ([#7158](https://github.com/crystal-lang/crystal/pull/7158), thanks @MakeNowJust)
- Fixed `getter`/`property` macros to work properly with `Bool` types. ([#7313](https://github.com/crystal-lang/crystal/pull/7313), thanks @Sija)
- Add `read_file` macro method. ([#6967](https://github.com/crystal-lang/crystal/pull/6967), [#7094](https://github.com/crystal-lang/crystal/pull/7094), thanks @Sija, @woodruffw)
- Add `StringLiteral#count`. ([#7239](https://github.com/crystal-lang/crystal/pull/7239), thanks @Blacksmoke16)

#### Numeric

- Fixed scale issues when dividing `BigDecimal`. ([#7218](https://github.com/crystal-lang/crystal/pull/7218), thanks @Sija)
- Allow underscores in the `String` passed to `Big*` constructors. ([#7107](https://github.com/crystal-lang/crystal/pull/7107), thanks @Sija)
- Add conversion methods and docs to `Complex`. ([#5440](https://github.com/crystal-lang/crystal/pull/5440), thanks @Sija)
- Add specs for `Int128`, `UInt128`. ([#7173](https://github.com/crystal-lang/crystal/pull/7173), thanks @bcardiff)
- Add unsafe number ops `value.to_X!`/`T.new!`/`Int#&**`. ([#7226](https://github.com/crystal-lang/crystal/pull/7226), thanks @bcardiff)
- Add overflow detection with preview opt-in. ([#7206](https://github.com/crystal-lang/crystal/pull/7206), thanks @bcardiff)

#### Text

- Fixed `ECR` location error reported. ([#7137](https://github.com/crystal-lang/crystal/pull/7137), thanks @MakeNowJust)
- Add docs to ECR. ([#7121](https://github.com/crystal-lang/crystal/pull/7121), thanks @KCErb)
- Refactor `String#to_i` to avoid future overflow. ([#7172](https://github.com/crystal-lang/crystal/pull/7172), thanks @bcardiff)

#### Collections

- Fixed docs example in `Hash#from`. ([#7210](https://github.com/crystal-lang/crystal/pull/7210), thanks @r00ster91)
- Fixed docs links of `Enumerable#chunks` and `Iterator#chunk`. ([#6941](https://github.com/crystal-lang/crystal/pull/6941), thanks @r00ster91)
- Remove implicit null skip from `Hash` to `JSON` serialization. ([#7053](https://github.com/crystal-lang/crystal/pull/7053), thanks @MakeNowJust)
- Add `Iterator#slice_after`. ([#7146](https://github.com/crystal-lang/crystal/pull/7146), thanks @asterite)
- Add `Iterator#slice_before`. ([#7152](https://github.com/crystal-lang/crystal/pull/7152), thanks @asterite)
- Add `Iteratory#slice_when` and `Iterator#chunk_while`. ([#7159](https://github.com/crystal-lang/crystal/pull/7159), thanks @asterite)
- Add `Enumerable#to_h(&block)`. ([#7150](https://github.com/crystal-lang/crystal/pull/7150), thanks @Sija)
- Add `Enumerable#one?`. ([#7166](https://github.com/crystal-lang/crystal/pull/7166), thanks @asterite)
- Add several `Enumerable`, `Iterator` and `Array` overloads that accept a pattern. ([#7174](https://github.com/crystal-lang/crystal/pull/7174), thanks @asterite)
- Add docs to hash constructors. ([#6923](https://github.com/crystal-lang/crystal/pull/6923), thanks @KCErb)

#### Serialization

- Add conversion between JSON and YAML. ([#7232](https://github.com/crystal-lang/crystal/pull/7232), thanks @straight-shoota)
- Standardize `#as_T`/`#as_T?` methods between `JSON::Any`/`YAML::Any`. ([#6556](https://github.com/crystal-lang/crystal/pull/6556), thanks @j8r)
- Add `Set#from_yaml`. ([#6310](https://github.com/crystal-lang/crystal/pull/6310), thanks @kostya)

#### Time

- Fixed `Time::Span` initializer and `sleep` for big seconds. ([#7221](https://github.com/crystal-lang/crystal/pull/7221), thanks @asterite)
- Fixed docs to show proper use of parse. ([#7035](https://github.com/crystal-lang/crystal/pull/7035), thanks @jwoertink)
- Add missing `Float#weeks` method similar to `Int#weeks`. ([#7165](https://github.com/crystal-lang/crystal/pull/7165), thanks @vlazar)

#### Files

- Fix `mkstemps` support on aarch64. ([#7300](https://github.com/crystal-lang/crystal/pull/7300), thanks @silmanduin66)
- Validate LibC error codes in specs involving Errno errors. ([#7087](https://github.com/crystal-lang/crystal/pull/7087), thanks @straight-shoota)
- Add microsecond precision to `System::File.utime` (Unix). ([#7156](https://github.com/crystal-lang/crystal/pull/7156), thanks @straight-shoota)
- Add missing tempfile cleanup in specs. ([#7250](https://github.com/crystal-lang/crystal/pull/7250), thanks @bcardiff)
- Add docs for file open modes. ([#6664](https://github.com/crystal-lang/crystal/pull/6664), thanks @r00ster91)

#### Networking

- Fixed `HTTP::Client` edge case of exception during in TLS initialization. ([#7123](https://github.com/crystal-lang/crystal/pull/7123), thanks @asterite)
- Fixed `OpenSSL::SSL::Error.new` to not raise `Errno`. ([#7068](https://github.com/crystal-lang/crystal/pull/7068), thanks @straight-shoota)
- Fixed `URI` encoding in `StaticFileHandler::DirectoryListing`. ([#7072](https://github.com/crystal-lang/crystal/pull/7072), thanks @Sija)
- Add MIME registry. ([#5765](https://github.com/crystal-lang/crystal/pull/5765), [#7079](https://github.com/crystal-lang/crystal/pull/7079), [#7080](https://github.com/crystal-lang/crystal/pull/7080), thanks @straight-shoota, @Sija)
- Add `MIME::MediaType` for parsing mime media types. ([#7077](https://github.com/crystal-lang/crystal/pull/7077), thanks @straight-shoota)
- Add support for 100-continue in `HTTP::Server::Response`. ([#6912](https://github.com/crystal-lang/crystal/pull/6912), thanks @jreinert)
- Add support for creating sockets from raw file descriptors. ([#6894](https://github.com/crystal-lang/crystal/pull/6894), thanks @myfreeweb)
- Add SNI support for OpenSSL. ([#7291](https://github.com/crystal-lang/crystal/pull/7291), thanks @bararchy)
- Improve `HTTP::Server` docs. ([#7251](https://github.com/crystal-lang/crystal/pull/7251), thanks @straight-shoota)
- Refactor `OpenSSL` specs to reduce chances of failing. ([#7202](https://github.com/crystal-lang/crystal/pull/7202), thanks @bcardiff)

#### Crypto

- Add `OpenSSL::Cipher#authenticated?` to see if the cipher supports aead. ([#7223](https://github.com/crystal-lang/crystal/pull/7223), thanks @danielwestendorf)

#### System

- Fixed inline ASM when compiling for ARM. ([#7041](https://github.com/crystal-lang/crystal/pull/7041), thanks @omarroth)
- Implement `Crystal::System` for Win32. ([#6972](https://github.com/crystal-lang/crystal/pull/6972), thanks @markrjr)
- Add `Errno#errno_message` getter. ([#6702](https://github.com/crystal-lang/crystal/pull/6702), thanks @r00ster91)

#### Spec

- Detect nesting `it` and `pending` at run-time. ([#7297](https://github.com/crystal-lang/crystal/pull/7297), thanks @MakeNowJust)

### Compiler

- Fixed how `LLVM::Type.const_int` emit `Int128` literals. ([#7135](https://github.com/crystal-lang/crystal/pull/7135), thanks @bcardiff)
- Fixed ICE related to named tuples. ([#7163](https://github.com/crystal-lang/crystal/pull/7163), thanks @asterite)
- Fixed automatic casting for private top-level methods. ([#7310](https://github.com/crystal-lang/crystal/pull/7310), thanks @asterite)
- Give proper error if defining initialize inside enum, allow `Enum.new`. ([#7266](https://github.com/crystal-lang/crystal/pull/7266), thanks @asterite)
- Give proper error when trying to access instance variable of union type. ([#7194](https://github.com/crystal-lang/crystal/pull/7194), thanks @asterite)
- Give proper error when trying to instantiate Module. ([#6735](https://github.com/crystal-lang/crystal/pull/6735), thanks @r00ster91)
- Give proper error related to named arguments. ([#7288](https://github.com/crystal-lang/crystal/pull/7288), thanks @asterite)
- Parse required comma between block args. ([#7343](https://github.com/crystal-lang/crystal/pull/7343), thanks @asterite)
- Improve inference in recursion that involves blocks. ([#7161](https://github.com/crystal-lang/crystal/pull/7161), thanks @asterite)
- Add locations to all expanded macro arguments. ([#7008](https://github.com/crystal-lang/crystal/pull/7008), thanks @MakeNowJust)
- Turn a not compiler specific error while requiring into ICE. ([#7208](https://github.com/crystal-lang/crystal/pull/7208), thanks @MakeNowJust)
- Remove old `nil?` error on pointer types. ([#7180](https://github.com/crystal-lang/crystal/pull/7180), thanks @asterite)
- Improve too big tuple and named tuple error message. ([#7131](https://github.com/crystal-lang/crystal/pull/7131), thanks @r00ster91)
- Workaround buggy offset debug info values. ([#7335](https://github.com/crystal-lang/crystal/pull/7335), thanks @bcardiff)
- Refactor extract helper methods to emit `Float32`, `Float64` values. ([#7134](https://github.com/crystal-lang/crystal/pull/7134), thanks @bcardiff)
- Refactor filename resolution logic out of `interpret_run`. ([#7051](https://github.com/crystal-lang/crystal/pull/7051), thanks @Sija)
- Refactor internals regarding overflow. ([#7262](https://github.com/crystal-lang/crystal/pull/7262), thanks @bcardiff)
- Refactor `Crystal::Codegen::Target` and consolidate triple handling. ([#7282](https://github.com/crystal-lang/crystal/pull/7282), [#7317](https://github.com/crystal-lang/crystal/pull/7317), thanks @RX14, @bcardiff)

### Tools

- Update README template. ([#7118](https://github.com/crystal-lang/crystal/pull/7118), thanks @mamantoha)
- Capitalise Crystal in CLI output. ([#7224](https://github.com/crystal-lang/crystal/pull/7224), thanks @dwightwatson)

#### Formatter

- Fixed formatting of multiline literal elements. ([#7048](https://github.com/crystal-lang/crystal/pull/7048), thanks @MakeNowJust)
- Fixed formatting of heredoc with interpolations. ([#7184](https://github.com/crystal-lang/crystal/pull/7184), thanks @MakeNowJust)
- Fixed prevent conflict between nested tuple types and macro expressions. ([#7097](https://github.com/crystal-lang/crystal/pull/7097), thanks @MakeNowJust)
- Fixed format when `typeof` appears inside generic type. ([#7176](https://github.com/crystal-lang/crystal/pull/7176), thanks @asterite)
- Fixed format of newline after `&.foo` in call. ([#7240](https://github.com/crystal-lang/crystal/pull/7240), thanks @MakeNowJust)
- Honor same behaviour for single or multiple file arguments. ([#7144](https://github.com/crystal-lang/crystal/pull/7144), thanks @straight-shoota)
- Refactor remove quotes from overflow symbols in formatter spec. ([#6968](https://github.com/crystal-lang/crystal/pull/6968), thanks @r00ster91)
- Major rework of `crystal tool format` command. ([#7257](https://github.com/crystal-lang/crystal/pull/7257), thanks @MakeNowJust)

#### Doc generator

- **(security)** Prevent XSS via args. ([#7056](https://github.com/crystal-lang/crystal/pull/7056), thanks @MakeNowJust)
- Fixed generation of toplevel. ([#7063](https://github.com/crystal-lang/crystal/pull/7063), thanks @MakeNowJust)
- Fixed display of double splat and block arg. ([#7029](https://github.com/crystal-lang/crystal/pull/7029), [#7031](https://github.com/crystal-lang/crystal/pull/7031), thanks @MakeNowJust)
- Fixed keep trailing spaces in macros. ([#7099](https://github.com/crystal-lang/crystal/pull/7099), thanks @MakeNowJust)
- Fixed avoid showing subtypes of aliased type. ([#7124](https://github.com/crystal-lang/crystal/pull/7124), thanks @asterite)
- Fixed style of methods when hovering. ([#7022](https://github.com/crystal-lang/crystal/pull/7022), thanks @r00ster91)
- Fixed duplicate `source_link` field. ([#7033](https://github.com/crystal-lang/crystal/pull/7033), thanks @bcardiff)
- Fixed missing keywords in `Doc::Highlighter`. ([#7054](https://github.com/crystal-lang/crystal/pull/7054), thanks @MakeNowJust)
- Add `--format` option to docs command. ([#6982](https://github.com/crystal-lang/crystal/pull/6982), thanks @mniak)

### Others

- CI improvements and housekeeping. ([#7018](https://github.com/crystal-lang/crystal/pull/7018), [#7043](https://github.com/crystal-lang/crystal/pull/7043), [#7133](https://github.com/crystal-lang/crystal/pull/7133), [#7139](https://github.com/crystal-lang/crystal/pull/7139), [#7230](https://github.com/crystal-lang/crystal/pull/7230), [#7227](https://github.com/crystal-lang/crystal/pull/7227), [#7263](https://github.com/crystal-lang/crystal/pull/7263), thanks @bcardiff)
- CI split formatting check. ([#7228](https://github.com/crystal-lang/crystal/pull/7228), thanks @bcardiff)
- Depend on standard variable to let the user define the build date. ([#7186](https://github.com/crystal-lang/crystal/pull/7186), thanks @eli-schwartz)
- Reorganize community section in README, add forum. ([#7235](https://github.com/crystal-lang/crystal/pull/7235), thanks @straight-shoota)
- Fixed docs grammar and typos. ([#7034](https://github.com/crystal-lang/crystal/pull/7034), [#7242](https://github.com/crystal-lang/crystal/pull/7242), [#7331](https://github.com/crystal-lang/crystal/pull/7331), thanks @r00ster91, @girng)
- Improve samples. ([#6454](https://github.com/crystal-lang/crystal/pull/6454), thanks @r00ster91)
- Fixed 0.27.0 CHANGELOG. ([#7024](https://github.com/crystal-lang/crystal/pull/7024), thanks @arcage)
- Update ISSUE_TEMPLATE to include forum. ([#7301](https://github.com/crystal-lang/crystal/pull/7301), thanks @straight-shoota)
- Update LICENSE's copyright year. ([#7246](https://github.com/crystal-lang/crystal/pull/7246), thanks @matiasgarciaisaia)

## [0.27.0] - 2018-11-01
[0.27.0]: https://github.com/crystal-lang/crystal/releases/0.27.0

### Language changes

- **(breaking-change)** Disallow comma after newline in argument list. ([#6514](https://github.com/crystal-lang/crystal/pull/6514), thanks @asterite)

#### Macros

- Add `Generic#resolve` and `Generic#resolve?` macro methods. ([#6617](https://github.com/crystal-lang/crystal/pull/6617), thanks @asterite)

### Standard library

- Fixed `v1`, `v2`, `v3`, `v4`, `v5` methods of `UUID`. ([#6952](https://github.com/crystal-lang/crystal/pull/6952), thanks @r00ster91)
- Fixed multiple docs typos and phrasing in multiple places. ([#6778](https://github.com/crystal-lang/crystal/pull/6778), [#6963](https://github.com/crystal-lang/crystal/pull/6963), thanks @r00ster91)
- Fixes `Pointer`/`UInt` subtraction. ([#6994](https://github.com/crystal-lang/crystal/pull/6994), thanks @damaxwell)
- Add stack overflow detection. ([#6928](https://github.com/crystal-lang/crystal/pull/6928), [#6995](https://github.com/crystal-lang/crystal/pull/6995), thanks @damaxwell)
- Add caller file and line to `Nil#not_nil!`. ([#6712](https://github.com/crystal-lang/crystal/pull/6712), thanks @yeeunmariakim)
- Restrict `Enum#parse`/`Enum#parse?` to `String` arguments. ([#6654](https://github.com/crystal-lang/crystal/pull/6654), thanks @vladfaust)
- Refactor and unify printing exceptions from within fibers. ([#6594](https://github.com/crystal-lang/crystal/pull/6594), thanks @Sija)
- Improve docs on properties generated by `property?`. ([#6682](https://github.com/crystal-lang/crystal/pull/6682), thanks @epergo)
- Add docs to top level namespace constants. ([#6971](https://github.com/crystal-lang/crystal/pull/6971), thanks @r00ster91)

#### Macros

- Fix typos in `StringLiteral#gsub` and `#tr` errors. ([#6925](https://github.com/crystal-lang/crystal/pull/6925), thanks @r00ster91)

#### Numeric

- **(breaking-change)** Disallow `rand` with zero value. ([#6686](https://github.com/crystal-lang/crystal/pull/6686), thanks @oprypin)
- **(breaking-change)** Let `==` and `!=` compare the values instead of bits when dealing with signed vs unsigned integers. ([#6689](https://github.com/crystal-lang/crystal/pull/6689), thanks @asterite)
- Fixed `Int#downto` with unsigned int. ([#6678](https://github.com/crystal-lang/crystal/pull/6678), thanks @gmarcais)
- Add wrapping arithmetics operators `&+` `&-` `&*`. ([#6890](https://github.com/crystal-lang/crystal/pull/6890), thanks @bcardiff)
- Add floor divisions operator `Int#//` and `Float#//`. ([#6891](https://github.com/crystal-lang/crystal/pull/6891), thanks @bcardiff)
- Add random support for `BigInt`. ([#6687](https://github.com/crystal-lang/crystal/pull/6687), thanks @oprypin)
- Add docs related to `Float::Printer::*`. ([#5438](https://github.com/crystal-lang/crystal/pull/5438), thanks @Sija)

#### Text

- Add `String::Builder#chomp!` returns self. ([#6583](https://github.com/crystal-lang/crystal/pull/6583), thanks @Sija)
- Add `:default` to colorize and document `ColorRGB`, `Color256`. ([#6427](https://github.com/crystal-lang/crystal/pull/6427), thanks @r00ster91)
- Add `String::Formatter` support for `c` flag and improve docs. ([#6758](https://github.com/crystal-lang/crystal/pull/6758), thanks @r00ster91)

#### Collections

- **(breaking-change)** Replace `Indexable#at` with `#fetch`. Remove `Hash#fetch(key)` as alias of `Hash#[]`. ([#6296](https://github.com/crystal-lang/crystal/pull/6296), thanks @AlexWayfer)
- Add `Hash/Indexable#dig/dig?`. ([#6719](https://github.com/crystal-lang/crystal/pull/6719), thanks @Sija)
- Add `Iterator.chain` to chain array of iterators. ([#6570](https://github.com/crystal-lang/crystal/pull/6570), thanks @xqyww123)
- Add `NamedTuple#to_h` over empty tuples. ([#6628](https://github.com/crystal-lang/crystal/pull/6628), thanks @icyleaf)
- Optimize `Indexable#join` when all elements are strings. ([#6635](https://github.com/crystal-lang/crystal/pull/6635), thanks @asterite)
- Optimize `Array#skip`. ([#6946](https://github.com/crystal-lang/crystal/pull/6946), thanks @asterite)

#### Serialization

- Fixed `YAML::Schema::FailSafe.parse` and `parse_all`. ([#6790](https://github.com/crystal-lang/crystal/pull/6790), thanks @r00ster91)
- Fixed order of `xmlns` and prefix in `XML::Builder#namespace`. ([#6743](https://github.com/crystal-lang/crystal/pull/6743), thanks @yeeunmariakim)
- Fixed `CSV.build` quoting of `Char` and `Symbol`. ([#6904](https://github.com/crystal-lang/crystal/pull/6904), thanks @maiha)
- Fixed docs for `JSON::Serializable`. ([#6950](https://github.com/crystal-lang/crystal/pull/6950), thanks @Heaven31415)
- Add `XML::Attributes#delete`. ([#6910](https://github.com/crystal-lang/crystal/pull/6910), thanks @joenas)
- Add ability to quote values always in `CSV.build`. ([#6723](https://github.com/crystal-lang/crystal/pull/6723), thanks @maiha)
- Refactor how empty properties are handled in `JSON::Serializable` and `YAML::Serializable`. ([#6539](https://github.com/crystal-lang/crystal/pull/6539), thanks @r00ster91)

#### Time

- **(breaking-change)** Rename `Time#epoch` to `Time#to_unix`. Also `#epoch_ms` to `#to_unix_ms`, and `#epoch_f` to `#to_unix_f`. ([#6662](https://github.com/crystal-lang/crystal/pull/6662), thanks @straight-shoota)
- Fixed spec for `Time::Location.load_local` with `TZ=nil`. ([#6740](https://github.com/crystal-lang/crystal/pull/6740), thanks @straight-shoota)
- Add support for ISO calendar week to `Time`. ([#6681](https://github.com/crystal-lang/crystal/pull/6681), thanks @straight-shoota)
- Add `Time::Format` support for `%G`, `%g`, `%V`. ([#6681](https://github.com/crystal-lang/crystal/pull/6681), thanks @straight-shoota)
- Add `Time::Location` loader support for Windows. ([#6363](https://github.com/crystal-lang/crystal/pull/6363), thanks @straight-shoota)
- Add `Time#to_local_in` to change time zone while keeping wall clock. ([#6572](https://github.com/crystal-lang/crystal/pull/6572), thanks @straight-shoota)
- Add `Time::UNIX_EPOCH` and drop private `UNIX_SECONDS` constant. ([#6908](https://github.com/crystal-lang/crystal/pull/6908), thanks @j8r)
- Change `Time::DayOfWeek` to ISO ordinal numbering based on `Monday = 1`. ([#6555](https://github.com/crystal-lang/crystal/pull/6555), thanks @straight-shoota)
- Refactor time specs. ([#6574](https://github.com/crystal-lang/crystal/pull/6574), thanks @straight-shoota)
- Add docs for singular method aliases, add `Int#microsecond` alias. ([#6297](https://github.com/crystal-lang/crystal/pull/6297), thanks @Sija)

#### Files

- **(breaking-change)** Remove `Tempfile`. Use `File.tempfile` or `File.tempname`. ([#6485](https://github.com/crystal-lang/crystal/pull/6485), thanks @straight-shoota)
- Fixed missing closed status check of FDs when creating a subprocess. ([#6641](https://github.com/crystal-lang/crystal/pull/6641), thanks @Timbus)
- Fixed `ChecksumReader.write` error message. ([#6889](https://github.com/crystal-lang/crystal/pull/6889), thanks @r00ster91)
- Add `File#delete`, `Dir#tempdir` and improve `File` docs. ([#6485](https://github.com/crystal-lang/crystal/pull/6485), thanks @straight-shoota)
- Add `File#fsync` to flush all data written into the file to the disk device. ([#6793](https://github.com/crystal-lang/crystal/pull/6793), thanks @carlhoerberg)
- Add `DEVNULL` to docs. ([#6642](https://github.com/crystal-lang/crystal/pull/6642), thanks @r00ster91)
- Improve checks for FreeBSD version due to breaking API changes. ([#6629](https://github.com/crystal-lang/crystal/pull/6629), thanks @myfreeweb)
- Improve performance of `Zlib::Reader`, `Gzip::Reader` and `Flate::Reader` by including `IO::Buffered`. ([#6916](https://github.com/crystal-lang/crystal/pull/6916), thanks @asterite)
- Refactor `Crystal::System::FileDescriptor` to use `@fd` ivar directly. ([#6703](https://github.com/crystal-lang/crystal/pull/6703), thanks @straight-shoota)
- Refactor `{Zlib,Gzip,Flate}::Reader#unbuffered_rewind` to use `check_open`. ([#6958](https://github.com/crystal-lang/crystal/pull/6958), thanks @Sija)

#### Networking

- **(breaking-change)** Remove deprecated alias `HTTP::Server#bind_ssl`. Use `HTTP::Server#bind_tls`. ([#6699](https://github.com/crystal-lang/crystal/pull/6699), thanks @straight-shoota)
- Add `Socket::Address#pretty_print` and `#inspect`. ([#6704](https://github.com/crystal-lang/crystal/pull/6704), thanks @straight-shoota)
- Add `Socket::IPAddress` loopback, unspecified and broadcast methods/constants. ([#6710](https://github.com/crystal-lang/crystal/pull/6710), thanks @straight-shoota)
- Fixed `Socket#reuse_port?` if `SO_REUSEPORT` is not supported. ([#6706](https://github.com/crystal-lang/crystal/pull/6706), thanks @straight-shoota)
- Fixed `TCPServer` handling of `reuse_port`. ([#6940](https://github.com/crystal-lang/crystal/pull/6940), thanks @RX14)
- Add docs to demonstrate parameters for `HTTP::Client`. ([#5145](https://github.com/crystal-lang/crystal/pull/5145), thanks @HCLarsen)
- Add docs examples to `Socket::Server#accept`. ([#6705](https://github.com/crystal-lang/crystal/pull/6705), thanks @straight-shoota)
- Refactor `socket_spec.cr` into separate files. ([#6700](https://github.com/crystal-lang/crystal/pull/6700), thanks @straight-shoota)
- Refactor specs of `HTTP::Client` to remove inheritance for test server. ([#6909](https://github.com/crystal-lang/crystal/pull/6909), thanks @straight-shoota)
- Improve specs for `HTTP::Server#close`. ([#5958](https://github.com/crystal-lang/crystal/pull/5958), thanks @straight-shoota)
- Improve specs for socket. ([#6711](https://github.com/crystal-lang/crystal/pull/6711), thanks @straight-shoota)

#### Crypto

- Fixed OpenSSL bindings to work with LibreSSL. ([#6917](https://github.com/crystal-lang/crystal/pull/6917), thanks @LVMBDV)
- Add support for OpenSSL 1.1.1. ([#6738](https://github.com/crystal-lang/crystal/pull/6738), thanks @ysbaddaden)

#### Concurrency

- Improve POSIX threads integration regarding locking, error and resource management. ([#6944](https://github.com/crystal-lang/crystal/pull/6944), thanks @ysbaddaden)
- Remove unintended public methods from `Channel`. ([#6714](https://github.com/crystal-lang/crystal/pull/6714), thanks @asterite)
- Refactor `Fiber`/`Scheduler` to isolate responsibilities. ([#6897](https://github.com/crystal-lang/crystal/pull/6897), thanks @ysbaddaden)
- Refactor specs that relied on `Fiber.yield` behavior. ([#6953](https://github.com/crystal-lang/crystal/pull/6953), thanks @ysbaddaden)

#### System

- Fixed fork and signal child handlers. ([#6426](https://github.com/crystal-lang/crystal/pull/6426), thanks @ysbaddaden)
- Use blocking `IO` on a TTY if it can't be reopened. ([#6660](https://github.com/crystal-lang/crystal/pull/6660), thanks @Timbus)
- Refactor `Process` in preparation for Windows support. ([#6744](https://github.com/crystal-lang/crystal/pull/6744), thanks @RX14)

#### Spec

- Allow `pending` to be used without blocks. ([#6732](https://github.com/crystal-lang/crystal/pull/6732), thanks @tswicegood)
- Add `be_empty` expectation. ([#6614](https://github.com/crystal-lang/crystal/pull/6614), thanks @mamantoha)
- Add specs for expectation methods. ([#6512](https://github.com/crystal-lang/crystal/pull/6512), thanks @rodrigopinto)

### Compiler

- Fixed don't "ambiguous match" if there's an exact match. ([#6618](https://github.com/crystal-lang/crystal/pull/6618), thanks @asterite)
- Fixed allow annotations inside enums. ([#6713](https://github.com/crystal-lang/crystal/pull/6713), thanks @asterite)
- Fixed `super` inside macros will honor arguments. ([#6638](https://github.com/crystal-lang/crystal/pull/6638), thanks @asterite)
- Fixed guessed ivar type from splat arguments. ([#6648](https://github.com/crystal-lang/crystal/pull/6648), thanks @MakeNowJust)
- Fixed `ASTNode#to_s` of non-unary operator call without argument. ([#6538](https://github.com/crystal-lang/crystal/pull/6538), thanks @MakeNowJust)
- Fixed `ASTNode#to_s` for multiline macro expression. ([#6666](https://github.com/crystal-lang/crystal/pull/6666), thanks @MakeNowJust)
- Fixed `ASTNode#to_s` for `{% verbatim do %} ... {% end %}`. ([#6665](https://github.com/crystal-lang/crystal/pull/6665), thanks @MakeNowJust)
- Fixed empty case statement normalization. ([#6915](https://github.com/crystal-lang/crystal/pull/6915), thanks @straight-shoota)
- Fixed codegen of tuple elements with unreachable elements. ([#6659](https://github.com/crystal-lang/crystal/pull/6659), thanks @MakeNowJust)
- Fixed parsing of `//` corner cases. ([#6927](https://github.com/crystal-lang/crystal/pull/6927), thanks @bcardiff)
- Fixed recursive block expansion check for non `ProcNotation` restriction. ([#6932](https://github.com/crystal-lang/crystal/pull/6932), thanks @MakeNowJust)
- Fixed corner case of expressions not typed on main phase but typed on cleanup phase. ([#6720](https://github.com/crystal-lang/crystal/pull/6720), thanks @MakeNowJust)
- Improve error traces regarding `return`, `next` and `break`. ([#6633](https://github.com/crystal-lang/crystal/pull/6633), thanks @asterite)
- Add resolve generics typenodes in macros. ([#6617](https://github.com/crystal-lang/crystal/pull/6617), thanks @asterite)
- Add support for multiple output values in inline asm. ([#6680](https://github.com/crystal-lang/crystal/pull/6680), thanks @RX14)
- Improve parsing of `asm` operands. ([#6688](https://github.com/crystal-lang/crystal/pull/6688), thanks @RX14)
- Refactor rescue block codegen for Windows. ([#6649](https://github.com/crystal-lang/crystal/pull/6649), thanks @RX14)

### Tools

- Improve installation section in README template. ([#6914](https://github.com/crystal-lang/crystal/pull/6914), [#6942](https://github.com/crystal-lang/crystal/pull/6942), thanks @r00ster91)
- Improve contributors section in README template. ([#7005](https://github.com/crystal-lang/crystal/pull/7005), thanks @r00ster91)

#### Formatter

- Fixed formatting of `{% verbatim do %} ... {% end %}` outside macro. ([#6667](https://github.com/crystal-lang/crystal/pull/6667), thanks @MakeNowJust)
- Fixed formatting of `//` corner cases. ([#6927](https://github.com/crystal-lang/crystal/pull/6927), thanks @bcardiff)
- Improve formatting of `asm` operands. ([#6688](https://github.com/crystal-lang/crystal/pull/6688), thanks @RX14)

#### Doc generator

- Add support for comments after `:nodoc:` marker. ([#6627](https://github.com/crystal-lang/crystal/pull/6627), thanks @Sija)
- Fixed browser performance issue with blur filter. ([#6764](https://github.com/crystal-lang/crystal/pull/6764), thanks @girng)
- Accessibility improvement in search field. ([#6926](https://github.com/crystal-lang/crystal/pull/6926), thanks @jodylecompte)

### Others

- CI improvements and housekeeping. ([#6658](https://github.com/crystal-lang/crystal/pull/6658), [#6739](https://github.com/crystal-lang/crystal/pull/6739), [#6930](https://github.com/crystal-lang/crystal/pull/6930), thanks @bcardiff, @RX14)
- Add `VERSION` file and support for specifying the build commit. ([#6966](https://github.com/crystal-lang/crystal/pull/6966), thanks @bcardiff)
- Add support for specifying the build date. ([#6788](https://github.com/crystal-lang/crystal/pull/6788), thanks @peterhoeg)
- Update Contributing section in `README.md`. ([#6911](https://github.com/crystal-lang/crystal/pull/6911), thanks @r00ster91)

## [0.26.1] - 2018-08-27
[0.26.1]: https://github.com/crystal-lang/crystal/releases/0.26.1

### Language changes

- **(breaking-change)** Make `self` to be eager evaluated when including modules. ([#6557](https://github.com/crystal-lang/crystal/pull/6557), thanks @bcardiff)

#### Macros

- Add `accepts_block?` macro method to `Def`. ([#6604](https://github.com/crystal-lang/crystal/pull/6604), thanks @willhbr)

### Standard library

#### Macros

- Fixed `Object#def_hash` can receive symbols. ([#6531](https://github.com/crystal-lang/crystal/pull/6531), thanks @Sija)

#### Collections

- Add `Hash#transform_keys` and `Hash#transform_values`. ([#4385](https://github.com/crystal-lang/crystal/pull/4385), thanks @deepj)

#### Serialization

- Fixed `JSON::Serializable` and `YAML::Serializable` clashing with custom initializers. ([#6458](https://github.com/crystal-lang/crystal/pull/6458), thanks @kostya)

#### Time

- Fixed docs for `Time::Format`. ([#6578](https://github.com/crystal-lang/crystal/pull/6578), thanks @straight-shoota)

#### Files

- Fixed zlib handling of buffer error. ([#6610](https://github.com/crystal-lang/crystal/pull/6610), thanks @asterite)

#### Networking

- **(deprecate)** `HTTP::Server#bind_ssl` in favor of `HTTP::Server#bind_tls`. ([#6551](https://github.com/crystal-lang/crystal/pull/6551), thanks @bcardiff)
- Add tls scheme to `HTTP::Server#bind`. ([#6533](https://github.com/crystal-lang/crystal/pull/6533), thanks @straight-shoota)
- Fixed `HTTP::Server` crash with self-signed certificate. ([#6590](https://github.com/crystal-lang/crystal/pull/6590), thanks @bcardiff)
- Refactor `HTTP::Server` specs to use free ports. ([#6530](https://github.com/crystal-lang/crystal/pull/6530), thanks @straight-shoota)

#### System

- Improve `STDIN`/`STDOUT`/`STDERR` handling to avoid breaking other programs. ([#6518](https://github.com/crystal-lang/crystal/pull/6518), thanks @Timbus)

#### Spec

- Fixed `DotFormatter` to flush after every spec. ([#6562](https://github.com/crystal-lang/crystal/pull/6562), thanks @asterite)
- Add support for Windows. ([#6497](https://github.com/crystal-lang/crystal/pull/6497), thanks @RX14)

### Compiler

- Fixed evaluate yield expressions in macros. ([#6587](https://github.com/crystal-lang/crystal/pull/6587), thanks @asterite)
- Fixed presence check of named argument via external name. ([#6560](https://github.com/crystal-lang/crystal/pull/6560), thanks @asterite)
- Fixed parser error on `break when`. ([#6509](https://github.com/crystal-lang/crystal/pull/6509), thanks @asterite)
- Fixed `~` methods are now able to be called as `foo.~`. ([#6541](https://github.com/crystal-lang/crystal/pull/6541), thanks @MakeNowJust)
- Fixed parsing newline after macro control expression. ([#6607](https://github.com/crystal-lang/crystal/pull/6607), thanks @asterite)
- Refactor use enum instead of hardcoded string values for emit kinds. ([#6515](https://github.com/crystal-lang/crystal/pull/6515), thanks @bew)

### Tools

#### Formatter

- Fixed formatting of newline before `&.method` in call. ([#6535](https://github.com/crystal-lang/crystal/pull/6535), thanks @MakeNowJust)
- Fixed formatting of empty heredoc. ([#6567](https://github.com/crystal-lang/crystal/pull/6567), thanks @MakeNowJust)
- Fixed formatting of string literal in interpolation. ([#6568](https://github.com/crystal-lang/crystal/pull/6568), thanks @MakeNowJust)
- Fixed formatting of comments in case when. ([#6595](https://github.com/crystal-lang/crystal/pull/6595), thanks @asterite)

#### Doc generator

- Add Menlo font family and fix ordering. ([#6602](https://github.com/crystal-lang/crystal/pull/6602), thanks @slice)

#### Playground

- Fixed internal link. ([#6596](https://github.com/crystal-lang/crystal/pull/6596), thanks @omarroth)

### Others

- CI improvements and housekeeping. ([#6550](https://github.com/crystal-lang/crystal/pull/6550), [#6612](https://github.com/crystal-lang/crystal/pull/6612), thanks @bcardiff)
- Add `pkg-config` as Linux package dependency. ([distribution-scripts#16](https://github.com/crystal-lang/distribution-scripts/pull/16), thanks @bcardiff)

## [0.26.0] - 2018-08-09
[0.26.0]: https://github.com/crystal-lang/crystal/releases/0.26.0

### Language changes

- **(breaking-change)** Revert do not collapse unions for sibling types. ([#6351](https://github.com/crystal-lang/crystal/pull/6351), thanks @asterite)
- **(breaking-change)** Constant lookup context in macro is now lexical. ([#5354](https://github.com/crystal-lang/crystal/pull/5354), thanks @MakeNowJust)
- **(breaking-change)** Evaluate instance var initializers at the metaclass level (ie: disallow using `self`). ([#6414](https://github.com/crystal-lang/crystal/pull/6414), thanks @asterite)
- **(breaking-change)** Add `//` operator parsing. NB: No behaviour is assigned to this operator yet. ([#6470](https://github.com/crystal-lang/crystal/pull/6470), thanks @bcardiff)
- Add `&+` `&-` `&*` `&**` operators parsing. NB: No behaviour is assigned to these operators yet. ([#6329](https://github.com/crystal-lang/crystal/pull/6329), thanks @bcardiff)
- Add support for empty `case` without `when`. ([#6367](https://github.com/crystal-lang/crystal/pull/6367), thanks @straight-shoota)

#### Macros

- Add `pp!` and `p!` macro methods. ([#6374](https://github.com/crystal-lang/crystal/pull/6374), [#6476](https://github.com/crystal-lang/crystal/pull/6476), thanks @straight-shoota)

### Standard library

- Fix docs for `Pointer`. ([#6494](https://github.com/crystal-lang/crystal/pull/6494), thanks @fxn)
- Fix docs of `UUID` enums. ([#6496](https://github.com/crystal-lang/crystal/pull/6496), thanks @r00ster91)

#### Numeric

- Fixed `Random#rand(Range(Float, Float))` to return `Float`. ([#6445](https://github.com/crystal-lang/crystal/pull/6445), thanks @straight-shoota)
- Add docs of big module overloads. ([#6336](https://github.com/crystal-lang/crystal/pull/6336), thanks @laginha87)

#### Text

- **(breaking-change)** `String#from_utf16(pointer : Pointer(UInt16))` returns now `{String, Pointer(UInt16)}`. ([#6333](https://github.com/crystal-lang/crystal/pull/6333), thanks @straight-shoota)
- Add support for unicode 11.0.0. ([#6505](https://github.com/crystal-lang/crystal/pull/6505), thanks @asterite)
- Add an optional argument to `String#check_no_null_byte` to customize error message. ([#6333](https://github.com/crystal-lang/crystal/pull/6333), thanks @straight-shoota)
- Add `ECR.render` for rendering directly as `String`. ([#6371](https://github.com/crystal-lang/crystal/pull/6371), thanks @straight-shoota)
- Fix docs for `Char` ([#6487](https://github.com/crystal-lang/crystal/pull/6487), thanks @r00ster91)

#### Collections

- Add docs for `StaticArray`. ([#6404](https://github.com/crystal-lang/crystal/pull/6404), [#6488](https://github.com/crystal-lang/crystal/pull/6488), thanks @straight-shoota, @r00ster91, @hinrik)
- Refactor `Array#concat`. ([#6493](https://github.com/crystal-lang/crystal/pull/6493), thanks @fxn)

#### Serialization

- **(breaking-change)** Add a maximum nesting level to prevent stack overflow on `YAML::Builder` and `JSON::Builder`. ([#6322](https://github.com/crystal-lang/crystal/pull/6322), thanks @asterite)
- Fixed compatibility for libyaml 0.2.1 regarding document end marker `...`. ([#6287](https://github.com/crystal-lang/crystal/pull/6287), thanks @straight-shoota)
- Add methods and options for pull parsing or hybrid parsing to `XML::Reader`. ([#5740](https://github.com/crystal-lang/crystal/pull/5740), [#6332](https://github.com/crystal-lang/crystal/pull/6332), thanks @felixbuenemann)
- Fixed docs for `JSON::Any`, `JSON::Serialization` and `YAML::Serialization`. ([#6460](https://github.com/crystal-lang/crystal/pull/6460), [#6491](https://github.com/crystal-lang/crystal/pull/6491), thanks @delef, @bmulvihill)


#### Time

- **(breaking-change)** Make location a required argument for `Time.parse`. ([#6369](https://github.com/crystal-lang/crystal/pull/6369), thanks @straight-shoota)
- Add `Time.parse!`, `Time.parse_utc`, `Time.parse_local`. ([#6369](https://github.com/crystal-lang/crystal/pull/6369), thanks @straight-shoota)
- Fix docs comment missing ([#6387](https://github.com/crystal-lang/crystal/pull/6387), thanks @faustinoaq)

#### Files

- **(breaking-change)** Remove `File.each_line` method that returns an iterator. Use `IO#each_line`. ([#6301](https://github.com/crystal-lang/crystal/pull/6301), thanks @asterite)
- Fixed `File.join` when path separator is a component argument. ([#6328](https://github.com/crystal-lang/crystal/pull/6328), thanks @icyleaf)
- Fixed `Dir.glob` can now list broken symlinks. ([#6466](https://github.com/crystal-lang/crystal/pull/6466), thanks @straight-shoota)
- Add `File` and `Dir` support for Windows. ([#5623](https://github.com/crystal-lang/crystal/pull/5623), thanks @RX14)

#### Networking

- **(breaking-change)** Drop `HTTP::Server#tls` in favor of `HTTP::Server#bind_ssl`. ([#5960](https://github.com/crystal-lang/crystal/pull/5960), thanks @straight-shoota)
- **(breaking-change)** Rename alias `HTTP::Handler::Proc` to `HTTP::Handler::HandlerProc`. ([#6453](https://github.com/crystal-lang/crystal/pull/6453), thanks @jwoertink)
- Fixed `Socket#accept?` base implementation. ([#6277](https://github.com/crystal-lang/crystal/pull/6277), thanks @ysbaddaden)
- Fixed performance issue due to unbuffered `IO` read. `IO#sync` only affect writes, introduce `IO#read_buffering?`. ([#6304](https://github.com/crystal-lang/crystal/pull/6304), [#6474](https://github.com/crystal-lang/crystal/pull/6474), thanks @asterite, @bcardiff)
- Fixed handling of closed state in `HTTP::Server::Response`. ([#6477](https://github.com/crystal-lang/crystal/pull/6477), thanks @straight-shoota)
- Fixed change encoding name comparison to be case insensitive for UTF-8. ([#6355](https://github.com/crystal-lang/crystal/pull/6355), thanks @asterite)
- Fixed support for quoted charset value in HTTP. ([#6354](https://github.com/crystal-lang/crystal/pull/6354), thanks @asterite)
- Fixed docs regarding udp example on `Socket::Addrinfo`. ([#6388](https://github.com/crystal-lang/crystal/pull/6388), thanks @faustinoaq)
- Fixed `HTTP::Client` will set `connection: close` header on one-shot requests. ([#6410](https://github.com/crystal-lang/crystal/pull/6410), thanks @asterite)
- Fixed `OpenSSL::Digest` for multibyte strings. ([#6471](https://github.com/crystal-lang/crystal/pull/6471), thanks @RX14)
- Fixed missing `Host` header when using `HTTP::Client#exec`. ([#6481](https://github.com/crystal-lang/crystal/pull/6481), thanks @straight-shoota)
- Add `HTTP::Server#bind(URI|String)` that infers protocol from scheme. ([#6500](https://github.com/crystal-lang/crystal/pull/6500), thanks @straight-shoota)
- Add `HTTP::Params.new` and `HTTP::Params#empty?`. ([#6241](https://github.com/crystal-lang/crystal/pull/6241), thanks @icyleaf)
- Add support for multiple Etags in `If-None-Match` header for `HTTP::Request` and `HTTP::StaticFileHandler`. ([#6219](https://github.com/crystal-lang/crystal/pull/6219), thanks @straight-shoota)
- Add IDNs normalization to punycode in `OpenSSL::SSL::Socket`. ([#6306](https://github.com/crystal-lang/crystal/pull/6306), thanks @paulkass)
- Add `application/wasm` to the default MIME types of `HTTP::StaticFileHandler`. ([#6377](https://github.com/crystal-lang/crystal/pull/6377), thanks @MakeNowJust)
- Add `URI#absolute?` and `URI#relative?`. ([#6311](https://github.com/crystal-lang/crystal/pull/6311), thanks @mamantoha)

#### Crypto

- Fixed `Crypto::Bcrypt::Password#==` was hiding `Reference#==(other)`. ([#6356](https://github.com/crystal-lang/crystal/pull/6356), thanks @straight-shoota)

#### Concurrency

- Fixed `Atomic#swap` with reference types. ([#6428](https://github.com/crystal-lang/crystal/pull/6428), thanks @Exilor)

#### System

- Fixed raise `Errno` if `Process.new` fails to exec. ([#6501](https://github.com/crystal-lang/crystal/pull/6501), thanks @straight-shoota, @lbguilherme)
- Add support for `WinError` UTF-16 string messages. ([#6442](https://github.com/crystal-lang/crystal/pull/6442), thanks @straight-shoota)
- Refactor platform specifics from `ENV` to `Crystal::System::Env` and implement for Windows. ([#6333](https://github.com/crystal-lang/crystal/pull/6333), [#6499](https://github.com/crystal-lang/crystal/pull/6499), thanks @straight-shoota)

#### Spec

- Add [TAP](https://testanything.org/) formatter to spec suite. ([#6286](https://github.com/crystal-lang/crystal/pull/6286), thanks @straight-shoota)

### Compiler

- Fixed named arguments expansion from double splat clash with local variable names. ([#6378](https://github.com/crystal-lang/crystal/pull/6378), thanks @asterite)
- Fixed auto assigned ivars arguments expansions when clash with keywords. ([#6379](https://github.com/crystal-lang/crystal/pull/6379), thanks @asterite)
- Fixed resulting type of union of tuple metaclasses. ([#6342](https://github.com/crystal-lang/crystal/pull/6342), thanks @asterite)
- Fixed ICE when using unbound type parameter inside generic type. ([#6292](https://github.com/crystal-lang/crystal/pull/6292), thanks @asterite)
- Fixed ICE when using unions of metaclasses. ([#6307](https://github.com/crystal-lang/crystal/pull/6307), thanks @asterite)
- Fixed ICE related to literal type guessing and generic types hierarchy. ([#6341](https://github.com/crystal-lang/crystal/pull/6341), thanks @asterite)
- Fixed ICE related to `not` and inlinable values. ([#6452](https://github.com/crystal-lang/crystal/pull/6452), thanks @asterite)
- Fixed rebind variables type in while condition after analyzing its body. ([#6295](https://github.com/crystal-lang/crystal/pull/6295), thanks @asterite)
- Fixed corner cases regarding automatic casts and method instantiation. ([#6284](https://github.com/crystal-lang/crystal/pull/6284), thanks @asterite)
- Fixed parsing of `\A` (and others) inside `%r{...}` inside macros. ([#6282](https://github.com/crystal-lang/crystal/pull/6282), thanks @asterite)
- Fixed parsing of of named tuple inside generic type arguments. ([#6413](https://github.com/crystal-lang/crystal/pull/6413), thanks @asterite)
- Fixed disallow cast from module class to virtual metaclass. ([#6320](https://github.com/crystal-lang/crystal/pull/6320), thanks @asterite)
- Fixed disallow `return` inside a constant's value. ([#6347](https://github.com/crystal-lang/crystal/pull/6347), thanks @asterite)
- Fixed debug info for closured self. ([#6346](https://github.com/crystal-lang/crystal/pull/6346), thanks @asterite)
- Fixed parsing error of newline before closing macro. ([#6382](https://github.com/crystal-lang/crystal/pull/6382), thanks @asterite)
- Fixed missing error if constant has `NoReturn` type. ([#6411](https://github.com/crystal-lang/crystal/pull/6411), thanks @asterite)
- Fixed give proper error when doing sizeof uninstantiated generic type. ([#6418](https://github.com/crystal-lang/crystal/pull/6418), thanks @asterite)
- Fixed private aliases at top-level are now considered private. ([#6432](https://github.com/crystal-lang/crystal/pull/6432), thanks @asterite)
- Fixed setters with multiple arguments as now disallowed. ([#6324](https://github.com/crystal-lang/crystal/pull/6324), thanks @maxfierke)
- Fixed type var that resolves to number in restriction didn't work. ([#6504](https://github.com/crystal-lang/crystal/pull/6504), thanks @asterite)
- Add support for class variables in generic classes. ([#6348](https://github.com/crystal-lang/crystal/pull/6348), thanks @asterite)
- Add support for exception handling in Windows (SEH). ([#6419](https://github.com/crystal-lang/crystal/pull/6419), thanks @RX14)
- Refactor codegen of binary operators. ([#6330](https://github.com/crystal-lang/crystal/pull/6330), thanks @bcardiff)
- Refactor use `JSON::Serializable` instead of `JSON.mapping`. ([#6308](https://github.com/crystal-lang/crystal/pull/6308), thanks @kostya)
- Refactor `Crystal::Call#check_visibility` and extract type methods. ([#6484](https://github.com/crystal-lang/crystal/pull/6484), thanks @asterite, @bcardiff)
- Change how metaclasses are shown. Use `Foo.class` instead of `Foo:Class`. ([#6439](https://github.com/crystal-lang/crystal/pull/6439), thanks @RX14)

### Tools

- Flatten project structure created by `crystal init`. ([#6317](https://github.com/crystal-lang/crystal/pull/6317), thanks @straight-shoota)

#### Formatter

- Fixed formatting of `{ {1}.foo, ...}` like expressions. ([#6300](https://github.com/crystal-lang/crystal/pull/6300), thanks @asterite)
- Fixed formatting of `when` with numbers. Use right alignment only if all are number literals. ([#6392](https://github.com/crystal-lang/crystal/pull/6392), thanks @MakeNowJust)
- Fixed formatting of comment in case's else. ([#6393](https://github.com/crystal-lang/crystal/pull/6393), thanks @MakeNowJust)
- Fixed code fence when language is not crystal will not be formatted. ([#6424](https://github.com/crystal-lang/crystal/pull/6424), thanks @asterite)

#### Doc generator

- Add line numbers at link when there are duplicated filenames in "Defined in:" section. ([#6280](https://github.com/crystal-lang/crystal/pull/6280), [#6489](https://github.com/crystal-lang/crystal/pull/6489), thanks @r00ster91)
- Fix docs navigator not scrolling into open type on page load. ([#6420](https://github.com/crystal-lang/crystal/pull/6420), thanks @soanvig)

### Others

- Fixed `system_spec` does no longer emit errors messages on BSD platforms. ([#6289](https://github.com/crystal-lang/crystal/pull/6289), thanks @jcs)
- Fixed compilation issue when running spec against compiler and std together. ([#6312](https://github.com/crystal-lang/crystal/pull/6312), thanks @straight-shoota)
- Add support for LLVM 6.0. ([#6381](https://github.com/crystal-lang/crystal/pull/6381), [#6380](https://github.com/crystal-lang/crystal/pull/6380), [#6383](https://github.com/crystal-lang/crystal/pull/6383), thanks @felixbuenemann)
- CI improvements and housekeeping. ([#6313](https://github.com/crystal-lang/crystal/pull/6313), [#6337](https://github.com/crystal-lang/crystal/pull/6337), [#6407](https://github.com/crystal-lang/crystal/pull/6407), [#6408](https://github.com/crystal-lang/crystal/pull/6408), [#6315](https://github.com/crystal-lang/crystal/pull/6315), thanks @bcardiff, @MakeNowJust, @r00ster91, @maiha)

## [0.25.1] - 2018-06-27
[0.25.1]: https://github.com/crystal-lang/crystal/releases/0.25.1

### Standard library

#### Macros
- Fixed `Object.delegate` is now able to be used with `[]=` methods. ([#6178](https://github.com/crystal-lang/crystal/pull/6178), thanks @straight-shoota)
- Fixed `p!` `pp!` are now able to be used with tuples. ([#6244](https://github.com/crystal-lang/crystal/pull/6244), thanks @bcardiff)
- Add `#copy_with` method to structs generated by `record` macro. ([#5736](https://github.com/crystal-lang/crystal/pull/5736), thanks @chris-baynes)
- Add docs for `ArrayLiteral#push` and `#unshift`. ([#6232](https://github.com/crystal-lang/crystal/pull/6232), thanks @MakeNowJust)

#### Collections
- Add docs for `Indexable#zip` and `#zip?` methods. ([#5734](https://github.com/crystal-lang/crystal/pull/5734), thanks @rodrigopinto)

#### Serialization
- Add `#dup` and `#clone` for `JSON::Any` and `YAML::Any`. ([6266](https://github.com/crystal-lang/crystal/pull/6266), thanks @asterite)
- Add docs example of nesting mappings to `YAML.builder`. ([#6097](https://github.com/crystal-lang/crystal/pull/6097), thanks @kalinon)

#### Time
- Fixed docs regarding formatting and parsing `Time`. ([#6208](https://github.com/crystal-lang/crystal/pull/6208), [#6214](https://github.com/crystal-lang/crystal/pull/6214), thanks @r00ster91 and @straight-shoota)
- Fixed `Time` internals for future Windows support. ([#6181](https://github.com/crystal-lang/crystal/pull/6181), thanks @RX14)
- Add `Time::Span#microseconds`, `Int#microseconds` and `Float#microseconds`. ([#6272](https://github.com/crystal-lang/crystal/pull/6272), thanks @asterite)
- Add specs. ([#6174](https://github.com/crystal-lang/crystal/pull/6174), thanks @straight-shoota)

#### Files
- Fixed `File.extname` edge case. ([#6234](https://github.com/crystal-lang/crystal/pull/6234), thanks @bcardiff)
- Fixed `FileInfo#flags` return value. ([#6248](https://github.com/crystal-lang/crystal/pull/6248), thanks @fgimian)

#### Networking
- Fixed `IO#write(slice : Bytes)` won't write information if slice is empty. ([#6269](https://github.com/crystal-lang/crystal/pull/6269), thanks @asterite)
- Fixed docs regarding `HTTP::Server#bind_tcp` method. ([#6179](https://github.com/crystal-lang/crystal/pull/6179), [#6233](https://github.com/crystal-lang/crystal/pull/6233), thanks @straight-shoota and @MakeNowJust)
- Add Etag support in `HTTP::StaticFileHandler`. ([#6145](https://github.com/crystal-lang/crystal/pull/6145), thanks @emq)

#### Misc
- Fixed `mmap` usage on OpenBSD 6.3+. ([#6250](https://github.com/crystal-lang/crystal/pull/6250), thanks @jcs)
- Fixed `big/big_int`, `big/big_float`, etc are now able to be included directly. ([#6267](https://github.com/crystal-lang/crystal/pull/6267), thanks @asterite)
- Refactor dependency in `Crystal::Hasher` to avoid load order issues. ([#6184](https://github.com/crystal-lang/crystal/pull/6184), thanks @ysbaddaden)

### Compiler
- Fixed a leakage of unbounded generic type variable and show error. ([#6128](https://github.com/crystal-lang/crystal/pull/6128), thanks @asterite)
- Fixed error message when lookup of library fails and lib's name contains non-alpha chars. ([#6187](https://github.com/crystal-lang/crystal/pull/6187), thanks @oprypin)
- Fixed integer kind deduction for very large negative numbers. ([#6182](https://github.com/crystal-lang/crystal/pull/6182), thanks @rGradeStd)
- Refactor specs tempfiles and data files usage in favor of portability ([#5951](https://github.com/crystal-lang/crystal/pull/5951), thanks @straight-shoota)
- Improve formatting and information in some compiler error messages. ([#6261](https://github.com/crystal-lang/crystal/pull/6261), thanks @RX14)

### Tools

#### Formatter
- Fixed crash when semicolon after block paren were present. ([#6192](https://github.com/crystal-lang/crystal/pull/6192), thanks @MakeNowJust)
- Fixed invalid code produced when heredoc and comma were present. ([#6222](https://github.com/crystal-lang/crystal/pull/6222), thanks @straight-shoota and @MakeNowJust)
- Fixed crash when one-liner `begin`/`rescue` were present. ([#6274](https://github.com/crystal-lang/crystal/pull/6274), thanks @asterite)

#### Doc generator
- Fixed JSON export that prevent jumping to constant. ([#6218](https://github.com/crystal-lang/crystal/pull/6218), thanks @straight-shoota)
- Fixed crash when virtual types were reached. ([#6246](https://github.com/crystal-lang/crystal/pull/6246), thanks @bcardiff)

### Misc

- CI improvements and housekeeping. ([#6193](https://github.com/crystal-lang/crystal/pull/6193), [#6211](https://github.com/crystal-lang/crystal/pull/6211), [#6209](https://github.com/crystal-lang/crystal/pull/6209), [#6221](https://github.com/crystal-lang/crystal/pull/6221), [#6260](https://github.com/crystal-lang/crystal/pull/6260), thanks @bcardiff, @kostya and @r00ster91)
- Update man page. ([#6259](https://github.com/crystal-lang/crystal/pull/6259), thanks @docelic)

## [0.25.0] - 2018-06-11
[0.25.0]: https://github.com/crystal-lang/crystal/releases/0.25.0

### New features and breaking changes
- **(breaking-change)** Time zones has been added to `Time`. ([#5324](https://github.com/crystal-lang/crystal/pull/5324), [#5819](https://github.com/crystal-lang/crystal/pull/5819), thanks @straight-shoota)
- **(breaking-change)** Drop `HTTP.rfc1123_date` in favor of `HTTP.format_time` and add time format implementations for ISO-8601, RFC-3339, and RFC-2822. ([#5123](https://github.com/crystal-lang/crystal/pull/5123), thanks @straight-shoota)
- **(breaking-change)** `crystal deps` is removed, use `shards`. ([#5544](https://github.com/crystal-lang/crystal/pull/5544), thanks @asterite)
- **(breaking-change)** `Hash#key` was renamed as `Hash#key_for`. ([#5444](https://github.com/crystal-lang/crystal/pull/5444), thanks @marksiemers)
- **(breaking-change)** `JSON::Any` and `YAML::Any` have been re-implemented solving some inconsistencies and avoiding the usage of recursive aliases (`JSON::Type` and `YAML::Type` have been removed). ([#5183](https://github.com/crystal-lang/crystal/pull/5183), thanks @asterite)
- **(breaking-change)** Multiple heredocs can be used as arguments and methods can be invoked writing them in the initial delimiter, also empty heredocs are now supported. ([#5578](https://github.com/crystal-lang/crystal/pull/5578), [#5602](https://github.com/crystal-lang/crystal/pull/5602), [#6048](https://github.com/crystal-lang/crystal/pull/6048), thanks @asterite and @MakeNowJust)
- **(breaking-change)** Refactor signal handlers and avoid closing pipe at exit. ([#5730](https://github.com/crystal-lang/crystal/pull/5730), thanks @ysbaddaden)
- **(breaking-change)** Improve behaviour of `File.join` with empty path component. ([#5915](https://github.com/crystal-lang/crystal/pull/5915), thanks @straight-shoota)
- **(breaking-change)** Drop `Colorize#push` in favor of `Colorize#surround` and allow nested calls across the stack. ([#4196](https://github.com/crystal-lang/crystal/pull/4196), thanks @MakeNowJust)
- **(breaking-change)** `File.stat` was renamed to `File.info` and a more portable API was implemented. ([#5584](https://github.com/crystal-lang/crystal/pull/5584), [#6161](https://github.com/crystal-lang/crystal/pull/6161), thanks @RX14 and @bcardiff)
- **(breaking-change)** Refactor `HTTP::Server` to bind to multiple addresses. ([#5776](https://github.com/crystal-lang/crystal/pull/5776), [#5959](https://github.com/crystal-lang/crystal/pull/5959), thanks @straight-shoota)
- **(breaking-change)** Remove block argument from `loop`. ([#6026](https://github.com/crystal-lang/crystal/pull/6026), thanks @asterite)
- **(breaking-change)** Do not collapse unions for sibling types. ([#6024](https://github.com/crystal-lang/crystal/pull/6024), thanks @asterite)
- **(breaking-change)** Disallow `typeof` in type restrictions. ([#5192](https://github.com/crystal-lang/crystal/pull/5192), thanks @asterite)
- **(breaking-change)** Perform unbuffered read when `IO::Buffered#sync = true`. ([#5849](https://github.com/crystal-lang/crystal/pull/5849), thanks @RX14)
- **(breaking-change)** Drop `when _` support. ([#6150](https://github.com/crystal-lang/crystal/pull/6150), thanks @MakeNowJust)
- **(breaking-change)** The `DivisionByZero` exception was renamed to `DivisionByZeroError`. ([#5395](https://github.com/crystal-lang/crystal/pull/5395), thanks @sdogruyol)
- A bootstrap Windows port has been added to the standard library. It's not usable for real programs yet. ([#5339](https://github.com/crystal-lang/crystal/pull/5339), [#5484](https://github.com/crystal-lang/crystal/pull/5484), [#5448](https://github.com/crystal-lang/crystal/pull/5448), thanks @RX14)
- Add automatic casts on literals arguments for numbers and enums. ([#6074](https://github.com/crystal-lang/crystal/pull/6074), thanks @asterite)
- Add user defined annotations. ([#6063](https://github.com/crystal-lang/crystal/pull/6063), [#6084](https://github.com/crystal-lang/crystal/pull/6084), [#6106](https://github.com/crystal-lang/crystal/pull/6106), thanks @asterite)
- Add macro verbatim blocks to avoid nested macros. ([#6108](https://github.com/crystal-lang/crystal/pull/6108), thanks @asterite)
- Allow namespaced expressions to define constants eg: `Foo::Bar = 1`. ([#5883](https://github.com/crystal-lang/crystal/pull/5883), thanks @bew)
- Allow trailing `=` in symbol literals. ([#5969](https://github.com/crystal-lang/crystal/pull/5969), thanks @straight-shoota)
- Allow redefining `None` to `0` for `@[Flags]` enum. ([#6160](https://github.com/crystal-lang/crystal/pull/6160), thanks @bew)
- Suggest possible solutions to failing requires. ([#5487](https://github.com/crystal-lang/crystal/pull/5487), thanks @RX14)
- Allow pointers of external C library global variables. ([#4845](https://github.com/crystal-lang/crystal/pull/4845), thanks @larubujo)
- Decouple pretty-printing (`pp`) and showing the expression (`!`): `p`, `pp`, `p!`, `pp!`. ([#6044](https://github.com/crystal-lang/crystal/pull/6044), thanks @asterite)
- Add ivars default value reflection in macros. ([#5974](https://github.com/crystal-lang/crystal/pull/5974), thanks @asterite)
- Add argless overload to `Number#round` to rounds to the nearest whole number. ([#5397](https://github.com/crystal-lang/crystal/pull/5397), thanks @Sija)
- Add `Int#bits_set?` to easily check that certain bits are set. ([#5619](https://github.com/crystal-lang/crystal/pull/5619), thanks @RX14)
- Add `Float32` and `Float64` constants. ([#4787](https://github.com/crystal-lang/crystal/pull/4787), thanks @konovod)
- Add allocated bytes per operation in `Benchmark.ips`. ([#5522](https://github.com/crystal-lang/crystal/pull/5522), thanks @asterite)
- Add `String#to_utf16` and `String.from_utf16`. ([#5541](https://github.com/crystal-lang/crystal/pull/5541), [#5579](https://github.com/crystal-lang/crystal/pull/5579), [#5583](https://github.com/crystal-lang/crystal/pull/5583) thanks @asterite, @RX14 and @straight-shoota)
- Add `String#starts_with?(re: Regex)`. ([#5485](https://github.com/crystal-lang/crystal/pull/5485), thanks @MakeNowJust)
- Add `Regex.needs_escape?`. ([#5962](https://github.com/crystal-lang/crystal/pull/5962), thanks @Sija)
- Add `Hash#last_key` and `Hash#last_value`. ([#5760](https://github.com/crystal-lang/crystal/pull/5760), thanks @j8r)
- Add no-copy iteration to `Indexable`. ([#4584](https://github.com/crystal-lang/crystal/pull/4584), thanks @cjgajard)
- Add `Time#at_{beginning,end}_of_second` ([#6167](https://github.com/crystal-lang/crystal/pull/6167), thanks @straight-shoota)
- Add `IO::Stapled` to combine two unidirectional `IO`s into a single bidirectional one. ([#6017](https://github.com/crystal-lang/crystal/pull/6017), thanks @straight-shoota)
- Add context to errors in `JSON.mapping` generated code. ([#5932](https://github.com/crystal-lang/crystal/pull/5932), thanks @straight-shoota)
- Add `JSON::Serializable` and `YAML::Serializable` attribute powered mappings. ([#6082](https://github.com/crystal-lang/crystal/pull/6082), thanks @kostya)
- Add `mode` param to `File.write`. ([#5754](https://github.com/crystal-lang/crystal/pull/5754), thanks @woodruffw)
- Add Punycode/IDNA support and integrate with DNS lookup. ([#2543](https://github.com/crystal-lang/crystal/pull/2543), thanks @MakeNowJust)
- Add `HTTP::Client#options` method. ([#5824](https://github.com/crystal-lang/crystal/pull/5824), thanks @mamantoha)
- Add support for `Last-Modified` and other cache improvements to `HTTP::StaticFileHandler`. ([#2470](https://github.com/crystal-lang/crystal/pull/2470), [#5607](https://github.com/crystal-lang/crystal/pull/5607), thanks @bebac and @straight-shoota)
- Add operations and improvements related to `BigDecimal` and `BigFloat`. ([#5437](https://github.com/crystal-lang/crystal/pull/5437), [#5390](https://github.com/crystal-lang/crystal/pull/5390), [#5589](https://github.com/crystal-lang/crystal/pull/5589), [#5582](https://github.com/crystal-lang/crystal/pull/5582), [#5638](https://github.com/crystal-lang/crystal/pull/5638), [#5675](https://github.com/crystal-lang/crystal/pull/5675), thanks @Sija and @mjago)
- Add `BigDecimal` and `UUID` JSON support. ([#5525](https://github.com/crystal-lang/crystal/pull/5525), [#5551](https://github.com/crystal-lang/crystal/pull/5551), thanks @lukeasrodgers and @lachlan)
- Add missing `UUID#inspect`. ([#5574](https://github.com/crystal-lang/crystal/pull/5574), thanks @ngsankha)
- Add `Logger` configuration in initializer. ([#5618](https://github.com/crystal-lang/crystal/pull/5618), thanks @Sija)
- Add custom separators in `CSV.build`. ([#5998](https://github.com/crystal-lang/crystal/pull/5998), [#6008](https://github.com/crystal-lang/crystal/pull/6008) thanks @Sija)
- Add `INI.build` to emit `INI` files. ([#5298](https://github.com/crystal-lang/crystal/pull/5298), thanks @j8r)
- Add `Process.chroot`. ([#5577](https://github.com/crystal-lang/crystal/pull/5577), thanks @chris-huxtable)
- Add `Tempfile.tempname` to create likely nonexisting filenames. ([#5360](https://github.com/crystal-lang/crystal/pull/5360), thanks @woodruffw)
- Add `FileUtils#ln`, `ln_s`, and `ln_sf`. ([#5421](https://github.com/crystal-lang/crystal/pull/5421), thanks @woodruffw)
- Add support 8bit and true color to `Colorize`. ([#5902](https://github.com/crystal-lang/crystal/pull/5902), thanks @MakeNowJust)
- Add comparison operators between classes. ([#5645](https://github.com/crystal-lang/crystal/pull/5645), thanks @asterite)
- Add exception cause in backtrace. ([#5833](https://github.com/crystal-lang/crystal/pull/5833), thanks @RX14)
- Add unhandled exception as argument in `at_exit`. ([#5906](https://github.com/crystal-lang/crystal/pull/5906), thanks @MakeNowJust)
- Add support to target aarch64-linux-musl. ([#5861](https://github.com/crystal-lang/crystal/pull/5861), thanks @jirutka)
- Add `#clear` method to `ArrayLiteral`/`HashLiteral` for macros. ([#5265](https://github.com/crystal-lang/crystal/pull/5265), thanks @Sija)
- Add `Bool#to_unsafe` for C bindings. ([#5465](https://github.com/crystal-lang/crystal/pull/5465), thanks @woodruffw)
- Spec: Add expectations `starts_with`, `ends_with`. ([#5881](https://github.com/crystal-lang/crystal/pull/5881), thanks @kostya)
- Formatter: Add `--include` and `--exclude` options to restrict directories. ([#4635](https://github.com/crystal-lang/crystal/pull/4635), thanks @straight-shoota)
- Documentation generator: improved navigation, searching, rendering and SEO. ([#5229](https://github.com/crystal-lang/crystal/pull/5229), [#5795](https://github.com/crystal-lang/crystal/pull/5795), [#5990](https://github.com/crystal-lang/crystal/pull/5990), [#5657](https://github.com/crystal-lang/crystal/pull/5657), [#6073](https://github.com/crystal-lang/crystal/pull/6073), thanks @straight-shoota, @Sija and @j8r)
- Playground: Add button in playground to run formatter. ([#3652](https://github.com/crystal-lang/crystal/pull/3652), thanks @samueleaton)

### Standard library bugs fixed
- Fixed `String#sub` handling of negative indexes. ([#5491](https://github.com/crystal-lang/crystal/pull/5491), thanks @MakeNowJust)
- Fixed `String#gsub` in non-ascii strings. ([#5350](https://github.com/crystal-lang/crystal/pull/5350), thanks @straight-shoota)
- Fixed `String#dump` for UTF-8 characters higher than `\uFFFF`. ([#5668](https://github.com/crystal-lang/crystal/pull/5668), thanks @straight-shoota)
- Fixed `String#tr` edge case optimization bug. ([#5913](https://github.com/crystal-lang/crystal/pull/5913), thanks @MakeNowJust)
- Fixed `String#rindex` when called with `Regex`. ([#5594](https://github.com/crystal-lang/crystal/pull/5594), thanks @straight-shoota)
- Fixed `Time::Span` precision loss and boundary check. ([#5563](https://github.com/crystal-lang/crystal/pull/5563), [#5786](https://github.com/crystal-lang/crystal/pull/5786), thanks @petoem and @straight-shoota)
- `Array#sample` was fixed to use the provided random number generator (instead of the default) in all cases. ([#5419](https://github.com/crystal-lang/crystal/pull/5419), thanks @c910335)
- Add short-circuit logic in `Deque#rotate!` for singleton and empty queues. ([#5399](https://github.com/crystal-lang/crystal/pull/5399), thanks @willcosgrove)
- `Slice#reverse!` was optimised to be up to 43% faster. ([#5401](https://github.com/crystal-lang/crystal/pull/5401), thanks @larubujo)
- Fixed `Regex#inspect` when escaping was needed. ([#5841](https://github.com/crystal-lang/crystal/pull/5841), thanks @MakeNowJust)
- Fixed `JSON.mapping` now generates type restriction on getters. ([#5935](https://github.com/crystal-lang/crystal/pull/5935), thanks @Daniel-Worrall)
- Fixed `JSON.mapping` documentation regarding unions. ([#5483](https://github.com/crystal-lang/crystal/pull/5483), thanks @RX14)
- Fixed `JSON.mapping` and `YAML.mapping` to allow `properties` property. ([#5180](https://github.com/crystal-lang/crystal/pull/5180), [#5352](https://github.com/crystal-lang/crystal/pull/5352), thanks @maxpowa and @Sija)
- Fixed `YAML` int and float parsing. ([#5699](https://github.com/crystal-lang/crystal/pull/5699), [#5774](https://github.com/crystal-lang/crystal/pull/5774), thanks @straight-shoota)
- Fixed WebSocket handshake validation. ([#5327](https://github.com/crystal-lang/crystal/pull/5327), [#6027](https://github.com/crystal-lang/crystal/pull/6027) thanks @straight-shoota)
- Fixed `HTTP::Client` is able to use ipv6 addresses. ([#6147](https://github.com/crystal-lang/crystal/pull/6147), thanks @bcardiff)
- Fixed handling some invalid responses in `HTTP::Client`. ([#5630](https://github.com/crystal-lang/crystal/pull/5630), thanks @straight-shoota)
- Fixed `HTTP::ChunkedContent` will raise on unterminated content. ([#5928](https://github.com/crystal-lang/crystal/pull/5928), [#5943](https://github.com/crystal-lang/crystal/pull/5943), thanks @straight-shoota)
- `URI#to_s` now handles default ports for lots of schemes. ([#5233](https://github.com/crystal-lang/crystal/pull/5233), thanks @lachlan)
- `HTTP::Cookies` is able to deal with spaces in cookies. ([#5408](https://github.com/crystal-lang/crystal/pull/5408), thanks @bararchy)
- Fixed MIME type of SVG images in `HTTP::StaticFileHandler`. ([#5605](https://github.com/crystal-lang/crystal/pull/5605), thanks @damianham)
- Fixed URI encoding in `StaticFileHandler#redirect_to`. ([#5628](https://github.com/crystal-lang/crystal/pull/5628), thanks @straight-shoota)
- Fixed `before_request` callbacks to be executed right before writing the request in `HTTP::Client`. ([#5626](https://github.com/crystal-lang/crystal/pull/5626), thanks @asterite)
- `Dir.glob` was re-implemented with performance improvements and edge cases fixed. ([#5179](https://github.com/crystal-lang/crystal/pull/5179), thanks @straight-shoota)
- Fixed `File.extname` edge case for '.' in path with no extension. ([#5790](https://github.com/crystal-lang/crystal/pull/5790), thanks @codyjb)
- Some ECDHE curves were incorrectly disabled in `OpenSSL` clients, this has been fixed. ([#5494](https://github.com/crystal-lang/crystal/pull/5494), thanks @jhass)
- Fixed allow bcrypt passwords up to 71 bytes. ([#5356](https://github.com/crystal-lang/crystal/pull/5356), thanks @ysbaddaden)
- Unhandled exceptions occurring inside `Process.fork` now print their backtrace correctly. ([#5431](https://github.com/crystal-lang/crystal/pull/5431), thanks @RX14)
- Fixed `Zip` no longer modifies deflate signature. ([#5376](https://github.com/crystal-lang/crystal/pull/5376), thanks @luislavena)
- Fixed `INI` parser edge cases and performance improvements. ([#5442](https://github.com/crystal-lang/crystal/pull/5442), [#5718](https://github.com/crystal-lang/crystal/pull/5718) thanks @woodruffw, @j8r)
- Fixed initialization of `LibXML`. ([#5587](https://github.com/crystal-lang/crystal/pull/5587), thanks @lbguilherme)
- Some finalizers were missing for example when the object where cloned. ([#5367](https://github.com/crystal-lang/crystal/pull/5367), thanks @alexbatalov)
- Fixed sigfault handler initialization regarding `sa_mask`. ([#5677](https://github.com/crystal-lang/crystal/pull/5677) thanks @ysbaddaden)
- Fixed missing reference symbol in ARM. ([#5640](https://github.com/crystal-lang/crystal/pull/5640), thanks @blankoworld)
- Fixed detect LLVM 5.0 by `llvm-config-5.0` command. ([#5531](https://github.com/crystal-lang/crystal/pull/5531), thanks @Vexatos)
- Restore STDIN|OUT|ERR blocking state on exit. ([#5802](https://github.com/crystal-lang/crystal/pull/5802), thanks @bew)
- Fixed multiple `at_exit` handlers chaining. ([#5413](https://github.com/crystal-lang/crystal/pull/5413), thanks @bew)
- Fixed senders were not notified when channels were closed. ([#5880](https://github.com/crystal-lang/crystal/pull/5880), thanks @carlhoerberg)
- Fixed forward unhandled exception to caller in `parallel` macro. ([#5726](https://github.com/crystal-lang/crystal/pull/5726), thanks @lipanski)
- Fixed Markdown parsing of code fences appearing on the same line. ([#5606](https://github.com/crystal-lang/crystal/pull/5606), thanks @oprypin)
- Fixed OpenSSL bindings to recognize LibreSSL. ([#5676](https://github.com/crystal-lang/crystal/pull/5676), [#6062](https://github.com/crystal-lang/crystal/pull/6062), [#5949](https://github.com/crystal-lang/crystal/pull/5949), [#5973](https://github.com/crystal-lang/crystal/pull/5973) thanks @LVMBDV and @RX14)
- Fixed path value in to `UNIXSocket` created by `UNIXServer`. ([#5869](https://github.com/crystal-lang/crystal/pull/5869), thanks @straight-shoota)
- Fixed `Object.delegate` over setters. ([#5964](https://github.com/crystal-lang/crystal/pull/5964), thanks @straight-shoota)
- Fixed `pp` will now use the same width on every line. ([#5978](https://github.com/crystal-lang/crystal/pull/5978), thanks @MakeNowJust)
- Fixes missing stdarg.cr for i686-linux-musl. ([#6120](https://github.com/crystal-lang/crystal/pull/6120), thanks @bcardiff)
- Spec: Fixed junit spec formatter to emit the correct XML. ([#5463](https://github.com/crystal-lang/crystal/pull/5463), thanks @hanneskaeufler)

### Compiler bugs fixed
- Fixed enum generated values when a member has value 0. ([#5954](https://github.com/crystal-lang/crystal/pull/5954), thanks @bew)
- Fixed compiler issue when previous compilation was interrupted. ([#5585](https://github.com/crystal-lang/crystal/pull/5585), thanks @asterite)
- Fixed compiler error with an empty `ensure` block. ([#5396](https://github.com/crystal-lang/crystal/pull/5396), thanks @MakeNowJust)
- Fixed parsing regex in default arguments. ([#5481](https://github.com/crystal-lang/crystal/pull/5481), thanks @MakeNowJust)
- Fixed parsing error of regex literal after open parenthesis. ([#5453](https://github.com/crystal-lang/crystal/pull/5453), thanks @MakeNowJust)
- Fixed parsing of empty array with blank. ([#6107](https://github.com/crystal-lang/crystal/pull/6107), thanks @asterite)
- Static libraries are now found correctly when using the `--static` compiler flag. ([#5385](https://github.com/crystal-lang/crystal/pull/5385), thanks @jreinert)
- Improve error messages for unterminated literals. ([#5409](https://github.com/crystal-lang/crystal/pull/5409), thanks @straight-shoota)
- Fixed `ProcNotation` and `ProcLiteral` introspection in macros. ([#5206](https://github.com/crystal-lang/crystal/pull/5206), thanks @javanut13)
- Cross compilation honors `--emit` and avoid generating `bc_flags` in current directory. ([#5521](https://github.com/crystal-lang/crystal/pull/5521), thanks @asterite)
- Fixed compiler error with integer constants as generic arguments. ([#5532](https://github.com/crystal-lang/crystal/pull/5532), thanks @asterite)
- Fixed compiler error with self as base class. ([#5534](https://github.com/crystal-lang/crystal/pull/5534), thanks @asterite)
- Fixed macro expansion when mutating the argument. ([#5247](https://github.com/crystal-lang/crystal/pull/5247), thanks @MakeNowJust)
- Fixed macro expansion edge cases. ([#5680](https://github.com/crystal-lang/crystal/pull/5680), [#5842](https://github.com/crystal-lang/crystal/pull/5842), [#6163](https://github.com/crystal-lang/crystal/pull/6163), thanks @asterite, @MakeNowJust and @splattael)
- Fixed macro overload on named args. ([#5808](https://github.com/crystal-lang/crystal/pull/5808), thanks @bew)
- Fixed macro numeric types used in interpreter. ([#5972](https://github.com/crystal-lang/crystal/pull/5972), thanks @straight-shoota)
- Fixed missing debug locations in several places. ([#5597](https://github.com/crystal-lang/crystal/pull/5597), thanks @asterite)
- Fixed missing information in AST nodes needed for macro expansion. ([#5454](https://github.com/crystal-lang/crystal/pull/5454), thanks @MakeNowJust)
- Fixed multiline error messages in emitted by `ASTNode#raise` macro method. ([#5670](https://github.com/crystal-lang/crystal/pull/5670), thanks @asterite)
- Fixed nested delimiters and escaped whitespace in string/symbol array literals. ([#5667](https://github.com/crystal-lang/crystal/pull/5667), thanks @straight-shoota)
- Fixed custom array/hash-like literals in nested modules. ([#5685](https://github.com/crystal-lang/crystal/pull/5685), thanks @asterite)
- Fixed usage of static array in C externs. ([#5690](https://github.com/crystal-lang/crystal/pull/5690), thanks @asterite)
- Fixed `spawn` over expression with receivers. ([#5781](https://github.com/crystal-lang/crystal/pull/5781), thanks @straight-shoota)
- Fixed prevent heredoc inside interpolation. ([#5648](https://github.com/crystal-lang/crystal/pull/5648), thanks @MakeNowJust)
- Fixed parsing error when a newline follows block arg. ([#5737](https://github.com/crystal-lang/crystal/pull/5737), thanks @bew)
- Fixed parsing error when macro argument is followed by a newline. ([#6046](https://github.com/crystal-lang/crystal/pull/6046), thanks @asterite)
- Fixed compiler error messages wording. ([#5887](https://github.com/crystal-lang/crystal/pull/5887), thanks @r00ster91)
- Fixed recursion issues in `method_added` macro hook. ([#5159](https://github.com/crystal-lang/crystal/pull/5159), thanks @MakeNowJust)
- Fixed avoid using type of updated argument for type inference. ([#5166](https://github.com/crystal-lang/crystal/pull/5166), thanks @MakeNowJust)
- Fixed parsing error message on unbalanced end brace in macros. ([#5420](https://github.com/crystal-lang/crystal/pull/5420), thanks @MakeNowJust)
- Fixed parsing error message on keywords are used as arguments. ([#5930](https://github.com/crystal-lang/crystal/pull/5930), [#6052](https://github.com/crystal-lang/crystal/pull/6052), thanks @MakeNowJust and @esse)
- Fixed parsing error message on missing comma for named tuples. ([#5981](https://github.com/crystal-lang/crystal/pull/5981), thanks @MakeNowJust)
- Fixed missing handling of `cond` node in visitor. ([#6032](https://github.com/crystal-lang/crystal/pull/6032), thanks @veelenga)
- Fixed cli when `--threads` has invalid value. ([#6039](https://github.com/crystal-lang/crystal/pull/6039), thanks @r00ster91)
- Fixed private methods can now be called with explicit `self` receiver. ([#6075](https://github.com/crystal-lang/crystal/pull/6075), thanks @MakeNowJust)
- Fixed missing some missing rules of initializer in initializers macro methods. ([#6077](https://github.com/crystal-lang/crystal/pull/6077), thanks @asterite)
- Fixed regression bug related to unreachable code. ([#6045](https://github.com/crystal-lang/crystal/pull/6045), thanks @asterite)

### Tools bugs fixed
- Several `crystal init` and template improvements. ([#5475](https://github.com/crystal-lang/crystal/pull/5475), [#5355](https://github.com/crystal-lang/crystal/pull/5355), [#4691](https://github.com/crystal-lang/crystal/pull/4691), [#5788](https://github.com/crystal-lang/crystal/pull/5788), [#5644](https://github.com/crystal-lang/crystal/pull/5644), [#6031](https://github.com/crystal-lang/crystal/pull/6031) thanks @woodruffw, @faustinoaq, @bew, @kostya and @MakeNowJust)
- Formatter: improve formatting of method call arguments with trailing comments. ([#5492](https://github.com/crystal-lang/crystal/pull/5492), thanks @MakeNowJust)
- Formatter: fix formatting of multiline statements. ([#5234](https://github.com/crystal-lang/crystal/pull/5234), [#5901](https://github.com/crystal-lang/crystal/pull/5901), [#6013](https://github.com/crystal-lang/crystal/pull/6013) thanks @MakeNowJust)
- Formatter: fix formatting of multi assignment. ([#5452](https://github.com/crystal-lang/crystal/pull/5452), thanks @MakeNowJust)
- Formatter: fix formatting of backslash ending statements. ([#5194](https://github.com/crystal-lang/crystal/pull/5194), thanks @asterite)
- Formatter: fix formatting of `.[]` methods. ([#5424](https://github.com/crystal-lang/crystal/pull/5424), thanks @MakeNowJust)
- Formatter: fix formatting of statements with comments. ([#5655](https://github.com/crystal-lang/crystal/pull/5655), [#5893](https://github.com/crystal-lang/crystal/pull/5893), [#5909](https://github.com/crystal-lang/crystal/pull/5909), thanks @MakeNowJust)
- Formatter: fix formatting of nested `begin`/`end`. ([#5922](https://github.com/crystal-lang/crystal/pull/5922), thanks @MakeNowJust)
- Formatter: fix formatting of trailing comma with block calls. ([#5855](https://github.com/crystal-lang/crystal/pull/5855), thanks @MakeNowJust)
- Formatter: fix formatting of ending expression after heredoc. ([#6127](https://github.com/crystal-lang/crystal/pull/6127), thanks @asterite)
- Documentation generator: references to nested types in markdown are now correctly parsed. ([#5308](https://github.com/crystal-lang/crystal/pull/5308), thanks @straight-shoota)
- Documentation generator: fix leftovers regarding default old `doc` directory. ([#5406](https://github.com/crystal-lang/crystal/pull/5406), thanks @GloverDonovan)
- Documentation generator: avoid failing on non git directory. ([#3700](https://github.com/crystal-lang/crystal/pull/3700), thanks @MakeNowJust)
- `Crystal::Doc::Highlighter` has specs now ([#5368](https://github.com/crystal-lang/crystal/pull/5368), thanks @MakeNowJust)
- Playground: can now be run with HTTPS. ([#5527](https://github.com/crystal-lang/crystal/pull/5527), thanks @opiation)
- Playground: Pretty-print objects in inspector. ([#4601](https://github.com/crystal-lang/crystal/pull/4601), thanks @jgaskins)

### Misc
- The platform-specific parts of `File` and `IO::FileDescriptor` were moved to `Crystal::System`, as part of preparation for the Windows port. ([#5333](https://github.com/crystal-lang/crystal/pull/5333), [#5553](https://github.com/crystal-lang/crystal/pull/5553), [#5622](https://github.com/crystal-lang/crystal/pull/5622) thanks @RX14)
- The platform-specific parts of `Dir` were moved to `Crystal::System`, as part of preparation for the Windows port. ([#5447](https://github.com/crystal-lang/crystal/pull/5447), thanks @RX14)
- Incremental contributions regarding Windows support. ([#5422](https://github.com/crystal-lang/crystal/pull/5422), [#5524](https://github.com/crystal-lang/crystal/pull/5524), [#5533](https://github.com/crystal-lang/crystal/pull/5533), [#5538](https://github.com/crystal-lang/crystal/pull/5538), [#5539](https://github.com/crystal-lang/crystal/pull/5539), [#5580](https://github.com/crystal-lang/crystal/pull/5580), [#5947](https://github.com/crystal-lang/crystal/pull/5947) thanks @RX14 and @straight-shoota)
- The build on OpenBSD was fixed. ([#5387](https://github.com/crystal-lang/crystal/pull/5387), thanks @wmoxam)
- Add support for FreeBSD 12 (64-bit inodes). ([#5199](https://github.com/crystal-lang/crystal/pull/5199), thanks @myfreeweb)
- Scripts and makefiles now depend on `sh` instead of `bash` for greater portability. ([#5468](https://github.com/crystal-lang/crystal/pull/5468), thanks @j8r)
- Honor `LDFLAGS` and `EXTRA_FLAGS` in `Makefile`. ([#5423](https://github.com/crystal-lang/crystal/pull/5423), [#5860](https://github.com/crystal-lang/crystal/pull/5860), thanks @trofi, @jirutka)
- Improve message on link failure. ([#5486](https://github.com/crystal-lang/crystal/pull/5486), [#5603](https://github.com/crystal-lang/crystal/pull/5603), thanks @RX14 and @waj)
- Improve `String#to_json` when chars don't need escaping. ([#5456](https://github.com/crystal-lang/crystal/pull/5456), thanks @larubujo)
- Improve `Time#add_span` when arguments are zero. ([#5787](https://github.com/crystal-lang/crystal/pull/5787), thanks @straight-shoota)
- Improve `String#pretty_print` to output by splitting newline. ([#5750](https://github.com/crystal-lang/crystal/pull/5750), thanks @MakeNowJust)
- Add `\a` escape sequence. ([#5864](https://github.com/crystal-lang/crystal/pull/5864), thanks @r00ster91)
- Several miscellaneous minor code cleanups and refactors. ([#5499](https://github.com/crystal-lang/crystal/pull/5499), [#5502](https://github.com/crystal-lang/crystal/pull/5502), [#5507](https://github.com/crystal-lang/crystal/pull/5507), [#5516](https://github.com/crystal-lang/crystal/pull/5516), [#4915](https://github.com/crystal-lang/crystal/pull/4915), [#5526](https://github.com/crystal-lang/crystal/pull/5526), [#5529](https://github.com/crystal-lang/crystal/pull/5529), [#5535](https://github.com/crystal-lang/crystal/pull/5535), [#5537](https://github.com/crystal-lang/crystal/pull/5537), [#5540](https://github.com/crystal-lang/crystal/pull/5540), [#5435](https://github.com/crystal-lang/crystal/pull/5435), [#5520](https://github.com/crystal-lang/crystal/pull/5520), [#5530](https://github.com/crystal-lang/crystal/pull/5530), [#5547](https://github.com/crystal-lang/crystal/pull/5547), [#5543](https://github.com/crystal-lang/crystal/pull/5543), [#5561](https://github.com/crystal-lang/crystal/pull/5561), [#5599](https://github.com/crystal-lang/crystal/pull/5599), [#5493](https://github.com/crystal-lang/crystal/pull/5493), [#5546](https://github.com/crystal-lang/crystal/pull/5546), [#5624](https://github.com/crystal-lang/crystal/pull/5624), [#5701](https://github.com/crystal-lang/crystal/pull/5701), [#5733](https://github.com/crystal-lang/crystal/pull/5733), [#5646](https://github.com/crystal-lang/crystal/pull/5646), [#5729](https://github.com/crystal-lang/crystal/pull/5729), [#5791](https://github.com/crystal-lang/crystal/pull/5791), [#5859](https://github.com/crystal-lang/crystal/pull/5859), [#5882](https://github.com/crystal-lang/crystal/pull/5882), [#5899](https://github.com/crystal-lang/crystal/pull/5899), [#5918](https://github.com/crystal-lang/crystal/pull/5918), [#5896](https://github.com/crystal-lang/crystal/pull/5896), [#5810](https://github.com/crystal-lang/crystal/pull/5810), [#5575](https://github.com/crystal-lang/crystal/pull/5575), [#5785](https://github.com/crystal-lang/crystal/pull/5785), [#5866](https://github.com/crystal-lang/crystal/pull/5866), [#5816](https://github.com/crystal-lang/crystal/pull/5816), [#5945](https://github.com/crystal-lang/crystal/pull/5945), [#5963](https://github.com/crystal-lang/crystal/pull/5963), [#5968](https://github.com/crystal-lang/crystal/pull/5968), [#5977](https://github.com/crystal-lang/crystal/pull/5977), [#6004](https://github.com/crystal-lang/crystal/pull/6004), [#5794](https://github.com/crystal-lang/crystal/pull/5794), [#5858](https://github.com/crystal-lang/crystal/pull/5858), [#6033](https://github.com/crystal-lang/crystal/pull/6033), [#6036](https://github.com/crystal-lang/crystal/pull/6036), [#6079](https://github.com/crystal-lang/crystal/pull/6079), [#6111](https://github.com/crystal-lang/crystal/pull/6111), [#6118](https://github.com/crystal-lang/crystal/pull/6118), [#6141](https://github.com/crystal-lang/crystal/pull/6141), [#6142](https://github.com/crystal-lang/crystal/pull/6142), [#5380](https://github.com/crystal-lang/crystal/pull/5380), [#6071](https://github.com/crystal-lang/crystal/pull/6071), thanks @chastell, @lachlan, @bew, @RX14, @sdogruyol, @MakeNowJust, @Sija, @noriyotcp, @asterite, @splattael, @straight-shoota, @r00ster91, @jirutka, @paulcsmith, @rab, @esse, @carlhoerberg, @chris-huxtable, @luislavena)
- Several documentation fixes and additions. ([#5425](https://github.com/crystal-lang/crystal/pull/5425), [#5682](https://github.com/crystal-lang/crystal/pull/5682), [#5779](https://github.com/crystal-lang/crystal/pull/5779), [#5576](https://github.com/crystal-lang/crystal/pull/5576), [#5806](https://github.com/crystal-lang/crystal/pull/5806), [#5817](https://github.com/crystal-lang/crystal/pull/5817), [#5873](https://github.com/crystal-lang/crystal/pull/5873), [#5878](https://github.com/crystal-lang/crystal/pull/5878), [#5637](https://github.com/crystal-lang/crystal/pull/5637), [#5885](https://github.com/crystal-lang/crystal/pull/5885), [#5884](https://github.com/crystal-lang/crystal/pull/5884), [#5728](https://github.com/crystal-lang/crystal/pull/5728), [#5917](https://github.com/crystal-lang/crystal/pull/5917), [#5912](https://github.com/crystal-lang/crystal/pull/5912), [#5894](https://github.com/crystal-lang/crystal/pull/5894), [#5933](https://github.com/crystal-lang/crystal/pull/5933), [#5809](https://github.com/crystal-lang/crystal/pull/5809), [#5936](https://github.com/crystal-lang/crystal/pull/5936), [#5908](https://github.com/crystal-lang/crystal/pull/5908), [#5851](https://github.com/crystal-lang/crystal/pull/5851), [#5378](https://github.com/crystal-lang/crystal/pull/5378), [#5914](https://github.com/crystal-lang/crystal/pull/5914), [#5967](https://github.com/crystal-lang/crystal/pull/5967), [#5993](https://github.com/crystal-lang/crystal/pull/5993), [#3482](https://github.com/crystal-lang/crystal/pull/3482), [#5946](https://github.com/crystal-lang/crystal/pull/5946), [#6095](https://github.com/crystal-lang/crystal/pull/6095), [#6117](https://github.com/crystal-lang/crystal/pull/6117), [#6131](https://github.com/crystal-lang/crystal/pull/6131), [#6162](https://github.com/crystal-lang/crystal/pull/6162), thanks @MakeNowJust, @straight-shoota, @vendethiel, @bew, @Heaven31415, @marksiemers, @Willamin, @r00ster91, @maiha, @Givralix, @docelic, @CaDs, @esse, @igneus, @masukomi)
- CI housekeeping and including 32 bits automated builds. ([#5796](https://github.com/crystal-lang/crystal/pull/5796), [#5804](https://github.com/crystal-lang/crystal/pull/5804), [#5837](https://github.com/crystal-lang/crystal/pull/5837), [#6015](https://github.com/crystal-lang/crystal/pull/6015), [#6165](https://github.com/crystal-lang/crystal/pull/6165), thanks @bcardiff, @bew and @Sija)
- Sync docs in master to [https://crystal-lang.org/api/master](https://crystal-lang.org/api/master). ([#5941](https://github.com/crystal-lang/crystal/pull/5941), thanks @bcardiff)
- Enable the large heap configuration for libgc. ([#5839](https://github.com/crystal-lang/crystal/pull/5839), thanks @RX14)
- Improve Ctrl-C handling of spec. ([#5719](https://github.com/crystal-lang/crystal/pull/5719), thanks @MakeNowJust)
- Playground: Update to codemirror 5.38.0. ([#6166](https://github.com/crystal-lang/crystal/pull/6166), thanks @bcardiff)

## [0.24.2] - 2018-03-08
[0.24.2]: https://github.com/crystal-lang/crystal/releases/0.24.2

- Fixed an `Index out of bounds` raised during `at_exit` ([#5224](https://github.com/crystal-lang/crystal/issues/5224), [#5565](https://github.com/crystal-lang/crystal/issues/5565), thanks @ysbaddaden)
- Re-add `Dir#each` so it complies with `Enumerable` ([#5458](https://github.com/crystal-lang/crystal/issues/5458), thanks @bcardiff)
- Fixed `SSL::Context` bug verifying certificates ([#5266](https://github.com/crystal-lang/crystal/issues/5266), [#5601](https://github.com/crystal-lang/crystal/issues/5601), thanks @waj)
- Fixed UUID documentation that was missing ([#5478](https://github.com/crystal-lang/crystal/issues/5478), [#5542](https://github.com/crystal-lang/crystal/issues/5542), thanks @asterite)
- Fixed a bug with single expressions in parenthesis ([#5482](https://github.com/crystal-lang/crystal/issues/5482), [#5511](https://github.com/crystal-lang/crystal/issues/5511), [#5513](https://github.com/crystal-lang/crystal/issues/5513), thanks @MakeNowJust)
- Fixed `skip_file` macro docs ([#5488](https://github.com/crystal-lang/crystal/issues/5488), thanks @straight-shoota)
- Fixed CI `build` script's `LIBRARY_PATH` ([#5457](https://github.com/crystal-lang/crystal/issues/5457), [#5461](https://github.com/crystal-lang/crystal/issues/5461), thanks @bcardiff)
- Fixed formatter bug with upper-cased `fun` names ([#5432](https://github.com/crystal-lang/crystal/issues/5432), [#5434](https://github.com/crystal-lang/crystal/issues/5434), thanks @bew)

## [0.24.1] - 2017-12-23
[0.24.1]: https://github.com/crystal-lang/crystal/releases/0.24.1

### New features
- Add ThinLTO support for faster release builds in LLVM 4.0 and above. ([#4367](https://github.com/crystal-lang/crystal/issues/4367), thanks @bcardiff)
- **(breaking-change)** Add `UUID` type. `Random::Secure.uuid` has been replaced with `UUID.random`. ([#4453](https://github.com/crystal-lang/crystal/issues/4453), thanks @wontruefree)
- Add a `BigDecimal` class for arbitrary precision, exact, decimal numbers. ([#4876](https://github.com/crystal-lang/crystal/issues/4876) and [#5255](https://github.com/crystal-lang/crystal/issues/5255), thanks @vegai and @Sija)
- Allow `Set` to work as a case condition, which matches when the case variable is inside the set. ([#5269](https://github.com/crystal-lang/crystal/issues/5269), thanks @MakeNowJust)
- **(breaking-change)** Change `Time::Format` codes to allow more robust options for parsing sub-second precision times. ([#5317](https://github.com/crystal-lang/crystal/issues/5317), thanks @bcardiff)
- Add `Time.utc`, an alias of `Time.new` which shortens creating UTC times. ([#5321](https://github.com/crystal-lang/crystal/issues/5321), thanks @straight-shoota)
- Add custom extension support to `Tempfile`. ([#5264](https://github.com/crystal-lang/crystal/issues/5264), thanks @jreinert)
- Add `reduce` method to `TupleLiteral` and `ArrayLiteral` when using macros. ([#5294](https://github.com/crystal-lang/crystal/issues/5294), thanks @javanut13)
- Export a JSON representation of the documentation in the generated output. ([#4746](https://github.com/crystal-lang/crystal/issues/4746) and [#5228](https://github.com/crystal-lang/crystal/issues/5228), thanks @straight-shoota)
- Make `gc/none` garbage collection compile again and allow it to be enabled using `-Dgc_none` compiler flag. ([#5314](https://github.com/crystal-lang/crystal/issues/5314), thanks @ysbaddaden)

### Standard library bugs fixed
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

### Compiler bugs fixed
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

### Misc
- Fix `Makefile`, CI, and gitignore to use the new documentation path after [#4937](https://github.com/crystal-lang/crystal/issues/4937). ([#5217](https://github.com/crystal-lang/crystal/issues/5217), thanks @straight-shoota)
- Miscellaneous code cleanups. ([#5318](https://github.com/crystal-lang/crystal/issues/5318), [#5341](https://github.com/crystal-lang/crystal/issues/5341) and [#5366](https://github.com/crystal-lang/crystal/issues/5366), thanks @bew and @mig-hub)
- Documentation fixes. ([#5253](https://github.com/crystal-lang/crystal/issues/5253), [#5296](https://github.com/crystal-lang/crystal/issues/5296), [#5300](https://github.com/crystal-lang/crystal/issues/5300) and [#5322](https://github.com/crystal-lang/crystal/issues/5322), thanks @arcage, @icyleaf, @straight-shoota and @bew)
- Fix the in-repository changelog to include 0.24.0. ([#5331](https://github.com/crystal-lang/crystal/pull/5331), thanks @sdogruyol)

## [0.24.0] - 2017-10-30
[0.24.0]: https://github.com/crystal-lang/crystal/releases/0.24.0

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

## [0.23.1] - 2017-07-01
[0.23.1]: https://github.com/crystal-lang/crystal/releases/0.23.1

* Added `Random::PCG32` generator (See [#4536](https://github.com/crystal-lang/crystal/issues/4536), thanks @konovod)
* WebSocket should compare "Upgrade" header value with case insensitive (See [#4617](https://github.com/crystal-lang/crystal/issues/4617), thanks @MakeNowJust)
* Fixed macro lookup from included module (See [#4639](https://github.com/crystal-lang/crystal/issues/4639), thanks @asterite)
* Explained "crystal tool expand" in crystal(1) man page (See [#4643](https://github.com/crystal-lang/crystal/issues/4643), thanks @MakeNowJust)
* Explained how to detect end of file in `IO` (See [#4661](https://github.com/crystal-lang/crystal/issues/4661), thanks @oprypin)

## [0.23.0] - 2017-06-27
[0.23.0]: https://github.com/crystal-lang/crystal/releases/0.23.0

* **(breaking-change)** `Logger#formatter` takes a `Severity` instead of a `String` (See [#4355](https://github.com/crystal-lang/crystal/issues/4355), [#4369](https://github.com/crystal-lang/crystal/issues/4369), thanks @Sija)
* **(breaking-change)** Removed `IO.select` (See [#4392](https://github.com/crystal-lang/crystal/issues/4392), thanks @RX14)
* Added `Crystal::System::Random` namespace (See [#4450](https://github.com/crystal-lang/crystal/issues/4450), thanks @ysbaddaden)
* Added `Path#resolve?` macro method (See [#4370](https://github.com/crystal-lang/crystal/issues/4370), [#4408](https://github.com/crystal-lang/crystal/issues/4408), thanks @RX14)
* Added range methods to `BitArray` (See [#4397](https://github.com/crystal-lang/crystal/issues/4397), [#3968](https://github.com/crystal-lang/crystal/issues/3968), thanks @RX14)
* Added some well-known HTTP Status messages (See [#4419](https://github.com/crystal-lang/crystal/issues/4419), thanks @akzhan)
* Added compiler progress indicator (See [#4182](https://github.com/crystal-lang/crystal/issues/4182), thanks @RX14)
* Added `System.cpu_cores` (See [#4449](https://github.com/crystal-lang/crystal/issues/4449), [#4226](https://github.com/crystal-lang/crystal/issues/4226), thanks @miketheman)
* Added `separator` and `quote_char` to `CSV#each_row` (See [#4448](https://github.com/crystal-lang/crystal/issues/4448), thanks @timsu)
* Added `map_with_index!` to `Pointer`, `Array` and `StaticArray` (See [#4456](https://github.com/crystal-lang/crystal/issues/4456), [#3356](https://github.com/crystal-lang/crystal/issues/3356), [#3354](https://github.com/crystal-lang/crystal/issues/3354), thanks @Nephos)
* Added `headers` parameter to `HTTP::WebSocket` constructors (See [#4227](https://github.com/crystal-lang/crystal/issues/4227), [#4222](https://github.com/crystal-lang/crystal/issues/4222), thanks @adamtrilling)
* Added `unlink` to `XML::Node` (See [#4515](https://github.com/crystal-lang/crystal/issues/4515), [#4331](https://github.com/crystal-lang/crystal/issues/4331), thanks @RX14 and @MrSorcus)
* Added `Math.frexp` (See [#4560](https://github.com/crystal-lang/crystal/issues/4560), thanks @akzhan)
* Added `Regex::MatchData` support for negative indexes (See [#4566](https://github.com/crystal-lang/crystal/issues/4566), thanks @MakeNowJust)
* Added `captures`, `named_captures`, `to_a` and `to_h` to `Regex::MatchData` (See [#3783](https://github.com/crystal-lang/crystal/issues/3783), thanks @MakeNowJust)
* Added `|` as a string delimiter to allow `q|string|` syntax (See [#3467](https://github.com/crystal-lang/crystal/issues/3467), thanks @RX14)
* Added support for Windows linker (See [#4491](https://github.com/crystal-lang/crystal/issues/4491), thanks @RX14)
* Added llvm operand bundle def and catch pad/ret/switch in order to support Windows SEH (See [#4501](https://github.com/crystal-lang/crystal/issues/4501), thanks @bcardiff)
* Added `Float::Printer` based on Grisu3 to speed up float to string conversion (See [#4333](https://github.com/crystal-lang/crystal/issues/4333), thanks @will)
* Added `Object.unsafe_as` to unsafely reinterpret the bytes of an object as being of another `type` (See [#4333](https://github.com/crystal-lang/crystal/issues/4333), thanks @asterite)
* Added `.downcase(Unicode::CaseOptions::Fold)` option which convert strings to casefolded strings for caseless matching (See [#4512](https://github.com/crystal-lang/crystal/issues/4512), thanks @akzhan)
* Added `OpenSSL::DigestIO` to wrap an IO while calculating a digest (See [#4260](https://github.com/crystal-lang/crystal/issues/4260), thanks @spalladino)
* Added `zero?` to numbers and time spans (See [#4026](https://github.com/crystal-lang/crystal/issues/4026), thanks @jellymann)
* Added `TypeNode#has_method?` method (See [#4474](https://github.com/crystal-lang/crystal/issues/4474), thanks @Sija)
* `Regex::MatchData#size` renamed to `#group_size` (See [#4565](https://github.com/crystal-lang/crystal/issues/4565), thanks @MakeNowJust)
* `HTTP::StaticFileHandler` can disable directory listing (See [#4403](https://github.com/crystal-lang/crystal/issues/4403), [#4398](https://github.com/crystal-lang/crystal/issues/4398), thanks @joaodiogocosta)
* `bin/crystal` now uses `/bin/sh` instead of `/bin/bash` (See [#3809](https://github.com/crystal-lang/crystal/issues/3809), [#4410](https://github.com/crystal-lang/crystal/issues/4410), thanks @TheLonelyGhost)
* `crystal init` generates a `.editorconfig` file (See [#4422](https://github.com/crystal-lang/crystal/issues/4422), [#297](https://github.com/crystal-lang/crystal/issues/297), thanks @akzhan)
* `man` page for `crystal` command (See [#2989](https://github.com/crystal-lang/crystal/issues/2989), [#1291](https://github.com/crystal-lang/crystal/issues/1291), thanks @dread-uo)
* Re-raising an exception doesn't overwrite its callstack (See [#4487](https://github.com/crystal-lang/crystal/issues/4487), [#4482](https://github.com/crystal-lang/crystal/issues/4482), thanks @akzhan)
* MD5 and SHA1 documentation clearly states they are not cryptographically secure anymore (See [#4426](https://github.com/crystal-lang/crystal/issues/4426), thanks @RX14)
* Documentation about constructor methods now rendered separately (See [#4216](https://github.com/crystal-lang/crystal/issues/4216), thanks @Sija)
* Turn `Random::System` into a module (See [#4542](https://github.com/crystal-lang/crystal/issues/4542), thanks @oprypin)
* `Regex::MatchData` pretty printed (See [#4574](https://github.com/crystal-lang/crystal/issues/4574), thanks @MakeNowJust)
* `String.underscore` treats digits as downcase or upcase characters depending previous characters (See [#4280](https://github.com/crystal-lang/crystal/issues/4280), thanks @MakeNowJust)
* Refactor time platform specific implementation (See [#4502](https://github.com/crystal-lang/crystal/issues/4502), thanks @bcardiff)
* Fixed Crystal not reusing .o files across builds (See [#4336](https://github.com/crystal-lang/crystal/issues/4336))
* Fixed `SomeClass.class.is_a?(SomeConst)` causing an "already had enclosing call" exception (See [#4364](https://github.com/crystal-lang/crystal/issues/4364), [#4390](https://github.com/crystal-lang/crystal/issues/4390), thanks @rockwyc992)
* Fixed `HTTP::Params.parse` query string with two `=` gave wrong result (See [#4388](https://github.com/crystal-lang/crystal/issues/4388), [#4389](https://github.com/crystal-lang/crystal/issues/4389), thanks @akiicat)
* Fixed `Class.class.is_a?(Class.class.class.class.class)` 🎉 (See [#4375](https://github.com/crystal-lang/crystal/issues/4375), [#4374](https://github.com/crystal-lang/crystal/issues/4374), thanks @rockwyc992)
* Fixed select hanging when sending before receive (See [#3862](https://github.com/crystal-lang/crystal/issues/3862), [#3899](https://github.com/crystal-lang/crystal/issues/3899), thanks @kostya)
* Fixed "Unknown key in access token json: id_token" error in OAuth2 client (See [#4437](https://github.com/crystal-lang/crystal/issues/4437))
* Fixed macro lookup conflicting with method lookup when including on top level (See [#236](https://github.com/crystal-lang/crystal/issues/236))
* Fixed Vagrant images (See [#4510](https://github.com/crystal-lang/crystal/issues/4510), [#4508](https://github.com/crystal-lang/crystal/issues/4508), thanks @Val)
* Fixed `IO::FileDescriptor#seek` from current position (See [#4558](https://github.com/crystal-lang/crystal/issues/4558), thanks @ysbaddaden)
* Fixed `IO::Memory#gets_to_end` to consume the `IO` (See [#4415](https://github.com/crystal-lang/crystal/issues/4415), thanks @jhass)
* Fixed setting of XML attributes (See [#4562](https://github.com/crystal-lang/crystal/issues/4562), thanks @asterite)
* Fixed "SSL_shutdown: Operation now in progress" error by retrying (See [#3168](https://github.com/crystal-lang/crystal/issues/3168), thanks @akzhan)
* Fixed WebSocket negotiation (See [#4386](https://github.com/crystal-lang/crystal/issues/4386), thanks @RX14)

## [0.22.0] - 2017-04-20
[0.22.0]: https://github.com/crystal-lang/crystal/releases/0.22.0

* **(breaking-change)** Removed `Process.new(pid)` is now private (See [#4197](https://github.com/crystal-lang/crystal/issues/4197))
* **(breaking-change)** IO#peek now returns an empty slice on EOF (See [#4240](https://github.com/crystal-lang/crystal/issues/4240), [#4261](https://github.com/crystal-lang/crystal/issues/4261))
* **(breaking-change)** Rename `WeakRef#target` to `WeakRef#value` (See [#4293](https://github.com/crystal-lang/crystal/issues/4293))
* **(breaking-change)** Rename `HTTP::Params.from_hash` to `HTTP::Params.encode` (See [#4205](https://github.com/crystal-lang/crystal/issues/4205))
* **(breaking-change)** `'\"'` is now invalid, use `'"'` (See [#4309](https://github.com/crystal-lang/crystal/issues/4309))
* Improved backtrace function names are now read from DWARF sections (See [#3958](https://github.com/crystal-lang/crystal/issues/3958), thanks @ysbaddaden)
* Improved sigfaults and exceptions are printed to STDERR (See [#4163](https://github.com/crystal-lang/crystal/issues/4163), thanks @Sija)
* Improved SSL Sockets are now buffered (See [#4248](https://github.com/crystal-lang/crystal/issues/4248))
* Improved type inference on loops (See [#4242](https://github.com/crystal-lang/crystal/issues/4242), [#4243](https://github.com/crystal-lang/crystal/issues/4243))
* Improved `pp` and `p`, the printed value is returned (See [#4285](https://github.com/crystal-lang/crystal/issues/4285), [#4283](https://github.com/crystal-lang/crystal/issues/4283), thanks @MakeNowJust)
* Added support for OpenSSL 1.1.0 (See [#4215](https://github.com/crystal-lang/crystal/issues/4215), [#4230](https://github.com/crystal-lang/crystal/issues/4230), thanks @ysbaddaden)
* Added `SecureRandom#random_bytes(Bytes)` (See [#4191](https://github.com/crystal-lang/crystal/issues/4191), thanks @konovod)
* Added setting and deleting of attributes on `XML::Node` (See [#3902](https://github.com/crystal-lang/crystal/issues/3902), thanks @bmmcginty)
* Added `File.touch` and `FileUtils.touch` methods (See [#4069](https://github.com/crystal-lang/crystal/issues/4069), thanks @Sija)
* Added `#values_at` for `CSV` (See [#4157](https://github.com/crystal-lang/crystal/issues/4157), thanks @need47)
* Added `Time#clone` (See [#4174](https://github.com/crystal-lang/crystal/issues/4174), thanks @Sija)
* Added `ancestors` macro method (See [#3875](https://github.com/crystal-lang/crystal/issues/3875), thanks @david50407)
* Added `skip` macro method ([#4237](https://github.com/crystal-lang/crystal/issues/4237), thanks @mverzilli)
* Added `Colorize.on_tty_only!` for easier toggling (See [#4075](https://github.com/crystal-lang/crystal/issues/4075), [#4271](https://github.com/crystal-lang/crystal/issues/4271), thanks @MakeNowJust)
* Added `WebSocket#on_binary` to receive binary messages (See [#2774](https://github.com/crystal-lang/crystal/issues/2774), thanks @lbguilherme)
* Fixed `Iterator.of` stops iterating when `Iterator.stop` is returned (See [#4208](https://github.com/crystal-lang/crystal/issues/4208))
* Fixed `String#insert` for non-ascii Char (See [#4164](https://github.com/crystal-lang/crystal/issues/4164), thanks @Papierkorb)
* Fixed `File.link` now creates a hard link ([#4116](https://github.com/crystal-lang/crystal/issues/4116), thanks @KCreate)
* Fixed error message for `#to_h` over empty `NamedTuple` (See [#4076](https://github.com/crystal-lang/crystal/issues/4076), thanks @karlseguin)
* Fixed `NamedTuple#to_h` does no longer call to value's `#clone` (See [#4203](https://github.com/crystal-lang/crystal/issues/4203))
* Fixed `Math#gamma` and `Math#lgamma` (See [#4229](https://github.com/crystal-lang/crystal/issues/4229), thanks @KCreate)
* Fixed `TCPSocket` creation for 0 port for Mac OSX (See [#4177](https://github.com/crystal-lang/crystal/issues/4177), thanks @will)
* Fixed repo name extraction from git remote in doc tool (See [#4132](https://github.com/crystal-lang/crystal/issues/4132), thanks @Sija)
* Fixed `self` resolution when including a generic module (See [#3972](https://github.com/crystal-lang/crystal/issues/3972), thanks @MakeNowJust)
* Fixed debug information was missing in some cases (See [#4166](https://github.com/crystal-lang/crystal/issues/4166), [#4202](https://github.com/crystal-lang/crystal/issues/4202), [#4254](https://github.com/crystal-lang/crystal/issues/4254))
* Fixed use generic ARM architecture target triple for all ARM architectures (See [#4167](https://github.com/crystal-lang/crystal/issues/4167), thanks @ysbaddaden)
* Fixed macro run arguments escaping
* Fixed zsh completion (See [#4284](https://github.com/crystal-lang/crystal/issues/4284), thanks @veelenga)
* Fixed honor `--no-color` option in spec (See [#4306](https://github.com/crystal-lang/crystal/issues/4306), thanks @luislavena)
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.22.0)

## [0.21.1] - 2017-03-06
[0.21.1]: https://github.com/crystal-lang/crystal/releases/0.21.1

* Improved lookup of abstract def implementors (see [#4052](https://github.com/crystal-lang/crystal/issues/4052))
* Improved allocation of objects without pointer instance variables using `malloc_atomic` (see [#4081](https://github.com/crystal-lang/crystal/issues/4081))
* Added `crystal --version` reports also the LLVM version (see [#4095](https://github.com/crystal-lang/crystal/issues/4095), thanks @matiasgarciaisaia)
* Fixed instance variables initializers corner cases (see [#3988](https://github.com/crystal-lang/crystal/issues/3988))
* Fixed `crystal play` was broken (see [#4061](https://github.com/crystal-lang/crystal/issues/4061))
* Fixed `Atomic` can be set to `nil` (see [#4062](https://github.com/crystal-lang/crystal/issues/4062))
* Fixed `GZip::Header` extra byte (see [#4068](https://github.com/crystal-lang/crystal/issues/4068), thanks @crisward)
* Fixed `ASTNode#to_s` for `Attribute` (see [#4098](https://github.com/crystal-lang/crystal/issues/4098), thanks @olbat)
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.21.1)

## [0.21.0] - 2017-02-20
[0.21.0]: https://github.com/crystal-lang/crystal/releases/0.21.0

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

## [0.20.5] - 2017-01-20
[0.20.5]: https://github.com/crystal-lang/crystal/releases/0.20.5

* Improved performance in `String#index`, `String#rindex` due to Rabin-Karp algorithm (thanks @MakeNowJust).
* Improved performance in `Crypto::Bcrypt` (see [#3880](https://github.com/crystal-lang/crystal/issues/3880), thanks @ysbaddaden).
* `expect_raises` returns raised exception (thanks @kostya).
* Line numbers debug information is always generated (see [#3831](https://github.com/crystal-lang/crystal/issues/3831), thanks @ysbaddaden).
* Added `Zip::File`, `Zip::Reader` and `Zip::Writer`. Native readers for zip files that delegate compression to existing zlib module.
* Added `Hash#delete` with block (see [#3856](https://github.com/crystal-lang/crystal/issues/3856), thanks @bmulvihill).
* Added `String#[](char : Char)` (see [#3855](https://github.com/crystal-lang/crystal/issues/3855), thanks @Sija).
* Added `crystal tool expand` to expand macro call in a given location (see [#3732](https://github.com/crystal-lang/crystal/issues/3732), thanks @MakeNowJust).
* Fixed `crystal play` is able to show compilation errors again.
* `crystal doc` recognizes `crystal-lang/crystal` in any remote (thanks @MaxLap).
* [Some bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.20.5)

## [0.20.4] - 2017-01-06
[0.20.4]: https://github.com/crystal-lang/crystal/releases/0.20.4

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

### [0.20.3] - 2016-12-23
[0.20.3]: https://github.com/crystal-lang/crystal/releases/0.20.3

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

### [0.20.1] - 2016-12-05
[0.20.1]: https://github.com/crystal-lang/crystal/releases/0.20.1

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

### [0.20.0] - 2016-11-22
[0.20.0]: https://github.com/crystal-lang/crystal/releases/0.20.0

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

### [0.19.4 ] - 2016-10-07
[0.19.4 ]: https://github.com/crystal-lang/crystal/releases/0.19.4

* Added support for OpenBSD (thanks @wmoxam and @ysbaddaden)
* More iconv fixes for FreeBSD (thanks @ysbaddaden)
* Changed how `require` works for the upcoming `shards` release (this is backwards compatible). See https://github.com/crystal-lang/crystal/pull/2788
* Added `Atomic` and exposed all LLVM atomic instructions to Crystal (needed to implemented multiple-thread support)
* Added `Process.executable_path` (thanks @kostya, @whereami and @ysbaddaden)
* Added `HTML.unescape` (thanks @dukex)
* Added `Char#+(Int)` and `Char#-(Int)`
* [A few bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.4)

### [0.19.3 ] - 2016-09-30
[0.19.3 ]: https://github.com/crystal-lang/crystal/releases/0.19.3

* `crystal eval` now accepts some flags like `--stats`, `--release` and `--help`
* Added `File.chown` and `File.chmod` (thanks @ysbaddaden)
* Added `Time::Span.zero` (useful for doing `sum`) (thanks @RX14)
* Added docs to `OAuth` and `OAuth2`
* [Several bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.3)

### [0.19.2 ] - 2016-09-16
[0.19.2 ]: https://github.com/crystal-lang/crystal/releases/0.19.2

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

### [0.19.1 ] - 2016-09-09
[0.19.1 ]: https://github.com/crystal-lang/crystal/releases/0.19.1

* Types (class, module, etc.) can now be marked as `private`.
* Added `WeakRef`  (thanks @bcardiff)
* [Several bug fixes](https://github.com/crystal-lang/crystal/issues?q=is%3Aclosed+milestone%3A0.19.1)

### [0.19.0 ] - 2016-09-02
[0.19.0 ]: https://github.com/crystal-lang/crystal/releases/0.19.0

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

### [0.18.7] - 2016-07-03
[0.18.7]: https://github.com/crystal-lang/crystal/releases/0.18.7

* The `compile` command was renamed back to `build`. The `compile` command is deprecated and will be removed in a future version
* Fibers now can be spawned with a name
* ECR macros can now be required with just `require "ecr"`
* [Several bugs fixes and enhancements](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.7+is%3Aclosed)

### [0.18.6] - 2016-06-28
[0.18.6]: https://github.com/crystal-lang/crystal/releases/0.18.6

* `T?` is now parsed as `Union(T, Nil)` outside the type grammar
* Added `String#sub` overloads for replacing an index or range with a char or string
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.6+is%3Aclosed)

### [0.18.5] - 2016-06-27
[0.18.5]: https://github.com/crystal-lang/crystal/releases/0.18.5

* Added `OpenSSL::SSL::Socket#alpn_protocol`
* Added `IO#copy(src, desc, limit)` (thanks @jreinert)
* Added `TypeNode#instance` macro method
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.5+is%3Aclosed)

### [0.18.4] - 2016-06-21
[0.18.4]: https://github.com/crystal-lang/crystal/releases/0.18.4

* Fixed [#2887](https://github.com/crystal-lang/crystal/issues/2887)
* Fix broken specs

### [0.18.3] - 2016-06-21
[0.18.3]: https://github.com/crystal-lang/crystal/releases/0.18.3

* `TypeNode`: added `<`, `<=`, `>` and `>=` macro methods
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.3+is%3Aclosed)

### [0.18.2] - 2016-06-16
[0.18.2]: https://github.com/crystal-lang/crystal/releases/0.18.2

* Fixed building Crystal from the source tarball

### [0.18.1] - 2016-06-16
[0.18.1]: https://github.com/crystal-lang/crystal/releases/0.18.1

* Spec: passing `--profile` shows the slowest 10 specs (thanks @mperham)
* Added `StringLiteral#>` and `StringLiteral#<` in macros
* [Several bugs fixes](https://github.com/crystal-lang/crystal/issues?q=milestone%3A0.18.1+is%3Aclosed)

### [0.18.0] - 2016-06-14
[0.18.0]: https://github.com/crystal-lang/crystal/releases/0.18.0

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
* `Tuple(*T).new` and `NamedTuple(**T).new` now correctly match the given `T` ([#1828](https://github.com/crystal-lang/crystal/issues/1828))
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

### [0.17.4] - 2016-05-26
[0.17.4]: https://github.com/crystal-lang/crystal/releases/0.17.4

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

### [0.17.3] - 2016-05-20
[0.17.3]: https://github.com/crystal-lang/crystal/releases/0.17.3

* Fixed: multiple macro runs executions didn't work well ([#2624](https://github.com/crystal-lang/crystal/issues/2624))
* Fixed incorrect formatting of underscore in unpacked block arguments
* Fixed wrong codegen for global variable assignment in type declaration ([#2619](https://github.com/crystal-lang/crystal/issues/2619))
* Fixed initialize default arguments where evaluated at the class scope ([#731](https://github.com/crystal-lang/crystal/issues/731))
* The type guesser can now infer a block type from `def initialize(&@block)`
* Allow type restriction in double splat argument (similar to restriction in single splat)
* Allow splat restriction in splat argument (useful for `Tuple.new`)
* Allow double splat restriction in double splat argument (useful for `NamedTuple.new`)

### [0.17.2] - 2016-05-18
[0.17.2]: https://github.com/crystal-lang/crystal/releases/0.17.2

* Fixed crash when using pointerof of constant

### [0.17.1] - 2016-05-18
[0.17.1]: https://github.com/crystal-lang/crystal/releases/0.17.1

* Constants and class vars are no longer initialized before "main". Now their initialization order goes along with "main", similar to how it works in Ruby (much more intuitive)
* Added syntax for unpacking block arguments: `foo { |(x, y)| ... }`
* Added `NamedTupleLiteral#map` and `HashLiteral#map` in macros (thanks @jhass)
* Fixed wrong codgen for tuples/named tuples merge with pass-by-value types
* Formatter: fixed incorrect format for named tuple type

### [0.17.0] - 2016-05-17
[0.17.0]: https://github.com/crystal-lang/crystal/releases/0.17.0

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

### [0.16.0] - 2016-05-05
[0.16.0]: https://github.com/crystal-lang/crystal/releases/0.16.0

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
* `Time` now honours Daylight Saving and `ENV["TZ"]`
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

### [0.15.0] - 2016-03-31
[0.15.0]: https://github.com/crystal-lang/crystal/releases/0.15.0

* **(breaking change)** `!` has now its meaning hardcoded in the language. If you defined it for a type it won't be invoked as a method anymore.
* **(breaking change)** `nil?` has now its meaning hardcoded in the language. If you defined it for a type it won't be invoked as a method anymore.
* **(breaking change)** `typeof` is now disallowed in `alias` declarations
* Added `crystal tool format --check` to check that source code is properly formatted
* `crystal play` (playground) added workbooks support, as well as improvements and stabilizations
* Added `Tempfile.dirname` (thanks @DougEverly)
* Added `Path#resolve` method in macros
* `{{...}}` arguments to a macro call are now expanded before macro invocation ([#2392](https://github.com/crystal-lang/crystal/issues/2392))
* Special variables (`$~` and `$?`) are now accessible after being defined in blocks ([#2194](https://github.com/crystal-lang/crystal/issues/2194))
* Some bugs and regressions fixed

### [0.14.2] - 2016-03-22
[0.14.2]: https://github.com/crystal-lang/crystal/releases/0.14.2

* Fixed regression with formatter ([#2348](https://github.com/crystal-lang/crystal/issues/2348))
* Fixed regression with block return types ([#2347](https://github.com/crystal-lang/crystal/issues/2347))
* Fixed regression with openssl (https://github.com/crystal-lang/crystal/commit/78c12caf2366b01f949046e78ad4dab65d0d80d4)

### [0.14.1] - 2016-03-21
[0.14.1]: https://github.com/crystal-lang/crystal/releases/0.14.1

* Fixed some regressions in the formatter

### [0.14.0] - 2016-03-21
[0.14.0]: https://github.com/crystal-lang/crystal/releases/0.14.0

* **(breaking change)** The syntax of a method argument with a default value and a type restriction is now `def foo(arg : Type = default_value)`. The old `def foo(arg = default_value : Type)` was removed.
* **(breaking change)** `Enumerable#take(n)` and `Iterator#take(n)` were renamed to `first(n)`
* **(breaking change)** `Socket#addr` and `Socket#peeraddr` were renamed to `local_address` and `remote_address` respectively
* **(breaking change)** Removed `Comparable#between?(a, z)`. Use `a <= x <= z` instead
* **(breaking change)** `HTTP::WebSocketHandler` callbacks can now access the `HTTP::Context`. If you had a forwarding method to it you'll need to update it. See [#2313](https://github.com/crystal-lang/crystal/issues/2313).
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

### [0.13.0] - 2016-03-07
[0.13.0]: https://github.com/crystal-lang/crystal/releases/0.13.0

* **(breaking change)** `Matrix` was moved to a separate shard: [https://github.com/Exilor/matrix](https://github.com/Exilor/Matrix)
* The syntax of a method argument with a default value and a type restriction is now `def foo(arg : Type = default_value)`. Run `crystal tool format` to automatically upgrade existing code to this new syntax. The old `def foo(arg = default_value : Type)` syntax will be removed in a next release.
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
* `HTML`: `HTML.escape` includes more characters (thanks @Ryuuzakis)
* Added `TypeNode.class` method in macros (thanks @waterlink)
* `run` inside macros now also work with absolute paths (useful when used with `__DIR__`)
* Added docs for `Math` and `StaticArray` (thanks @Zavydiel, @HeleneMyr)
* Many bug fixes and some micro-optimizations

### [0.12.0] - 2016-02-16
[0.12.0]: https://github.com/crystal-lang/crystal/releases/0.12.0

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

### [0.11.1] - 2016-01-25
[0.11.1]: https://github.com/crystal-lang/crystal/releases/0.11.1
* Fixed [#2050](https://github.com/crystal-lang/crystal/issues/2050), [#2054](https://github.com/crystal-lang/crystal/issues/2054), [#2057](https://github.com/crystal-lang/crystal/issues/2057), [#2059](https://github.com/crystal-lang/crystal/issues/2059), [#2064](https://github.com/crystal-lang/crystal/issues/2064)
* Fixed bug: HTTP::Server::Response headers weren't cleared after each request
* Formatter would incorrectly change `property x :: Int32` to `property x = uninitialized Int32`

### [0.11.0] - 2016-01-23
[0.11.0]: https://github.com/crystal-lang/crystal/releases/0.11.0

* **(breaking change)** Syntax for type declarations changed from `var :: Type` to `var : Type`. The old syntax is still allowed but will be deprecated in the next version (run `crystal tool format` to automatically fix this)
* **(breaking change)** Syntax for uninitialized variables, which used to be `var :: Type`, is now `var = uninitialized Type`. The old syntax is still allowed but will be deprecated in the next version (run `crystal tool format` to automatically fix this)
* **(breaking change)** `HTTP::Server` refactor to support streaming. Check the [docs](http://crystal-lang.org/api/HTTP/Server.html) of `HTTP::Server` for upgrade instructions
* **(breaking change)** Renamed `HTTP::WebSocketSession` to `HTTP::WebSocket`.
* **(breaking change)** Heredocs now remove indentations according to the indentation of the closing identifier (thanks @rhysd)
* **(breaking change)** Renamed `Enumerable#inject` to `Enumerable#reduce`
* **(breaking change)** `next` and `return` semantic inside captured block has been swapped ([#420](https://github.com/crystal-lang/crystal/issues/420))
* Fibers context switch is now faster, done with inline assembly. `libpcl` is no longer used
* Allow annotating the type of class and global variables
* Support comments in ECR (thanks @ysbaddaden)
* Security improvements to `HTTP::StaticFileHandler` (thanks @MakeNowJust)
* Moved `seek`, `tell`, `pos` and `pos=` from `File` to `IO::FileDescriptor` (affects `Tempfile`)
* `URI.parse` is now faster (thanks @will)
* Many bug fixes, some really old ones involving issues with order of declaration

### [0.10.2] - 2016-01-13
[0.10.2]: https://github.com/crystal-lang/crystal/releases/0.10.2

* Fixed Directory Traversal Vulnerability in HTTP::StaticFileHandler (thanks @MakeNowJust)

### [0.10.1] - 2016-01-08
[0.10.1]: https://github.com/crystal-lang/crystal/releases/0.10.1

* Added `Int#popcount` (thanks @rmosolgo)
* Added `@[Naked]` attribute for omitting a method's prelude
* Check that abstract methods are implemented by subtypes
* Some bug fixes

### [0.10.0] - 2015-12-23
[0.10.0]: https://github.com/crystal-lang/crystal/releases/0.10.0

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
* MemoryIO can now be created to read/write from a Slice(UInt8). In this mode MemoryIO can't be expanded, and can optionally be written. And when creating a MemoryIO from a String, it's non-resizeable and read-only.
* Added `Object#!~` (the opposite of `=~`)
* `at_exit` now receives that exit status code in the block (thanks @MakeNowJust)
* Allow using `Set` in JSON mappings (thanks @benoist)
* Added `File.executable?`, `File.readable?` and `File.writeable?` (thanks @mverzilli)
* `Array#sort_by` and `Array#sort_by!` now use a [Schwartzian transform](https://en.wikipedia.org/wiki/Schwartzian_transform) (thanks @radarek)
* Added `Array#each_permutation`, `Array#each_combination` and `Array#each_repeated_combination` iterators
* Added optional *random* argument to `Array#sample` and `Array#shuffle`
* The `delegate` macro can now delegate multiple methods to an object (thanks @elthariel)
* Added basic YAML generation (thanks @porras)

### [0.9.1] - 2015-10-30
[0.9.1]: https://github.com/crystal-lang/crystal/releases/0.9.1

* Docs search now finds nested entries (thanks @adlerhsieh)
* Many corrections and changes to the formatter, for better consistency and less obtrusion.
* Added `OpenSSL::Cipher` and `OpenSSL::Digest` (thanks @benoist)
* Added `Char#+(String)` (thanks @hangyas)
* Added `Hash#key` and `Hash#key?` (thanks @adlerhsieh)
* Added `Time::Span#*` and `Time::Span#/` (thanks @jbaum98)
* Added `Slice#reverse_each` (thanks @omninonsense)
* Added docs for `Random` and `Tempfile` (thanks @adlerhsieh)
* Fixed some bugs.

### [0.9.0] - 2015-10-16
[0.9.0]: https://github.com/crystal-lang/crystal/releases/0.9.0

* **(breaking change)** The `CGI` module's functionality has been moved to `URI` and `HTTP::Params`
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

### [0.8.0] - 2015-09-19
[0.8.0]: https://github.com/crystal-lang/crystal/releases/0.8.0

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
* Added several socket options (thanks @technorama)
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

### [0.7.7] - 2015-09-05
[0.7.7]: https://github.com/crystal-lang/crystal/releases/0.7.7

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

### [0.7.6] - 2015-08-13
[0.7.6]: https://github.com/crystal-lang/crystal/releases/0.7.6

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

### [0.7.5] - 2015-07-30
[0.7.5]: https://github.com/crystal-lang/crystal/releases/0.7.5

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

### [0.7.4] - 2015-06-23
[0.7.4]: https://github.com/crystal-lang/crystal/releases/0.7.4

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

### [0.7.3] - 2015-06-07
[0.7.3]: https://github.com/crystal-lang/crystal/releases/0.7.3

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

### [0.7.2] - 2015-05-26
[0.7.2]: https://github.com/crystal-lang/crystal/releases/0.7.2

* Improved performance of Regex
* Fixed lexing of octal characters and strings (thanks @rhysd)
* Time.parse can return UTC times (thanks @will)
* Handle dashes in `crystal init` (thanks @niftyn8)
* Generic type variables can now only be single letters (T, U, A, B, etc.)
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

### [0.7.1] - 2015-04-30
[0.7.1]: https://github.com/crystal-lang/crystal/releases/0.7.1

* Fixed [#597](https://github.com/crystal-lang/crystal/issues/597).
* Fixed [#599](https://github.com/crystal-lang/crystal/issues/599).

### [0.7.0] - 2015-04-30
[0.7.0]: https://github.com/crystal-lang/crystal/releases/0.7.0

* Crystal has evented IO by default. Added `spawn` and `Channel`.
* Correctly support the X86_64 and X86 ABIs. Now bindings to C APIs that pass and return structs works perfectly fine.
* Added `crystal init` to quickly create a skeleton library or application (thanks @waterlink)
* Added `--emit` flag to the compiler. Now you can easily see the generated LLVM IR, LLVM bitcode, assembly and object files.
* Added `--no-color` flag to suppress color output, useful for editor tools.
* Added macro vars: `%var` and `%var{x, y}` create uniquely named variables inside macros.
* Added [typed splats](https://github.com/crystal-lang/crystal/issues/291).
* Added `Iterator` and many methods that return iterators, like `Array#each`, `Hash#each`, `Int#times`, `Int#step`, `String#each_char`, etc.
* Added `sprintf` and improved `String#%` to support floats and float formatting.
* Added more variants of `String#gsub`.
* Added `Pointer#clear` and use it to clear an `Array`'s values when doing `pop` and other shrinking methods.
* Added `BigInt#to_s(base)`, `BigInt::cast` and bit operators (thanks @Exilor)
* Allow invoking methods on a union class as long as all types in the union have it.
* Allow specifying a def's return type. The compiler checks the return type only for that def for now (not for subclasses overriding the method). The return type appears in the documentation.
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

### [0.6.1] - 2015-03-04
[0.6.1]: https://github.com/crystal-lang/crystal/releases/0.6.1

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

### [0.6.0] - 2015-02-12
[0.6.0]: https://github.com/crystal-lang/crystal/releases/0.6.0

* Same as 0.5.10

### [0.5.10 (transitional)] - 2015-02-12
[0.5.10 (transitional)]: https://github.com/crystal-lang/crystal/releases/0.5.10 (transitional)

* **Note**: This release makes core, breaking changes to the language, and doesn't work out of the box with its accompanying standard library. Use 0.6.0 instead.
* Improved error messages related to nilable instance variables.
* The magic variables `$~` and `$?` are now method-local and concurrent-safe.
* `Tuple` is now correctly considered a struct
* `Pointer` is now correctly considered a struct
* Renamed `Function` to `Proc`

### [0.5.9] - 2015-02-07
[0.5.9]: https://github.com/crystal-lang/crystal/releases/0.5.9

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

### [0.5.8] - 2015-01-16
[0.5.8]: https://github.com/crystal-lang/crystal/releases/0.5.8

* Added `Random` and `Random::MT19937` (Mersenne Twister) classes (thanks @rhysd).
* Docs: removed automatic linking. To link to classes and methods surround with backticks.
* Fixed [#328](https://github.com/crystal-lang/crystal/issues/328): `!=` bug.

### [0.5.7] - 2015-01-02
[0.5.7]: https://github.com/crystal-lang/crystal/releases/0.5.7

* Fixed: `doc` command had some hardcoded paths and didn't work
* Added: `private def` at the top-level of a file is only available inside that file

### [0.5.6] - 2014-31-12
[0.5.6]: https://github.com/crystal-lang/crystal/releases/0.5.6

* Added a `crystal doc` command to automatically generate documentation for a project using [Markdown](http://daringfireball.net/projects/markdown/) syntax. The style is still ugly but it's quite functional. Now we only need to start documenting things :-)
* Removed the old `@:` attribute syntax.
* Fixed [#311](https://github.com/crystal-lang/crystal/issues/311): Issues with invoking lib functions in other ways (thanks @scidom).
* Fixed [#314](https://github.com/crystal-lang/crystal/issues/314): NoReturn information is not lazy.
* Fixed [#317](https://github.com/crystal-lang/crystal/issues/317): Fixes in UTF-8 encoding/decoding (thanks @yous).
* Fixed [#319](https://github.com/crystal-lang/crystal/issues/319): Unexpected EOF (thanks @Exilor).
* `{{yield}}` inside macros now preserve the yielded node location, leading to much better error messages.
* Added `Float#nan?`, `Float#infinite?` and `Float#finite?`.
* Many other bug fixes and improvements.

### [0.5.5] - 2014-12-12
[0.5.5]: https://github.com/crystal-lang/crystal/releases/0.5.5

* Removed `src` and crystal compiler `libs` directory from CRYSTAL_PATH.
* Several bug fixes.

### [0.5.4] - 2014-12-04
[0.5.4]: https://github.com/crystal-lang/crystal/releases/0.5.4

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

### [0.5.3] - 2014-11-06
[0.5.3]: https://github.com/crystal-lang/crystal/releases/0.5.3

* Spec: when a `should` or `should_not` fail, the filename and line number, including the source's line, is included in the error message.
* Spec: added `-l` switch to be able to run a spec defined in a line.
* Added `crystal spec file:line`
* Properties (property, setter, getter) can now be restricted to a type with the syntax `property name :: Type`.
* Enums can be used outside `lib`. They inherit `Enum`, can have methods and can be marked with @[Flags].
* Removed the distinction between `lib` enums and regular enums.
* Fixed: it was incorrectly possible to define `class`, `def`, etc. inside a call block.
* The syntax for specifying the base type of an enum, `enum Name < BaseType` has been deprecated. Use `enum Name : BaseType`.
* Added `Array#<=>` and make it comparable to other arrays.

### [0.5.2] - 2014-11-04
[0.5.2]: https://github.com/crystal-lang/crystal/releases/0.5.2

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
* Added `--fail-fast` switch to spec.
* Added `HTTPClient#basic_auth`.
* Added `DeclareVar`, `Def` and `Arg` macro methods.
* Added `Time` and `TimeSpan` structs. `TimeWithZone` will come later.
* Added `Array#fill` (thanks @Exilor).
* Added `Array#uniq`.
* Optimized `File.read_lines`.
* Allow any expression inside `{% ... %}` so that you can interpret code without outputting the result.
* Allow `\` at the end of a line.
* Allow using `if` and `unless` inside macro expressions.
* Allow marking a `fun/def` as `@[Raises]` (useful when a function can potentially raise from a callback).
* Allow procs are now considered `@[Raises]`.
* `OAuth2::Client` supports getting an access token via authorization code or refresh token.
* Consecutive string literals are automatically concatenated by the parser as long as there is a `\` with a newline between them.
* Many bug fixes.

### [0.5.1] - 2014-10-16
[0.5.1]: https://github.com/crystal-lang/crystal/releases/0.5.1

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

### [0.5.0] - 2014-09-24
[0.5.0]: https://github.com/crystal-lang/crystal/releases/0.5.0

* String overhaul, and optimizations

### [0.4.5] - 2014-09-24
[0.4.5]: https://github.com/crystal-lang/crystal/releases/0.4.5

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

### [0.4.4] - 2014-09-17
[0.4.4]: https://github.com/crystal-lang/crystal/releases/0.4.4

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
* Allow interpolations in regular expression literals.
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

### [0.4.3] - 2014-08-14
[0.4.3]: https://github.com/crystal-lang/crystal/releases/0.4.3

* Reverted a commit that introduced random crashes.

### [0.4.2] - 2014-08-13
[0.4.2]: https://github.com/crystal-lang/crystal/releases/0.4.2

* Fixed [#187](https://github.com/crystal-lang/crystal/issues/185): mixing `yield` and `block.call` crashes the compiler.
* Added `\u` unicode escape sequences inside strings and chars (similar to Ruby). `\x` will be deprecated as it can generate strings with invalid UTF-8 byte sequences.
* Added `String#chars`.
* Fixed: splats weren't working in `initialize`.
* Added the `private` and `protected` visibility modifiers, with the same semantics as Ruby. The difference is that you must place them before a `def` or a macro call.
* Some bug fixes.

### [0.4.1] - 2014-08-09
[0.4.1]: https://github.com/crystal-lang/crystal/releases/0.4.1

* Fixed [#185](https://github.com/crystal-lang/crystal/issues/185): `-e` flag stopped working.
* Added a `@length` compile-time variable available inside tuples that allows to do loop unrolling.
* Some bug fixes.

### [0.4.0] - 2014-08-08
[0.4.0]: https://github.com/crystal-lang/crystal/releases/0.4.0

* Support splats in macros.
* Support splats in defs and calls.
* Added named arguments.
* Renamed the `make_named_tuple` macro to `record`.
* Added `def_equals`, `def_hash` and `def_equals_and_hash` macros to generate them from a list of fields.
* Added `Slice(T)`, which is a struct having a pointer and a length. Use this in IO for a safe API.
* Some `StaticArray` fixes and enhancements.

### [0.3.5] - 2014-07-29
[0.3.5]: https://github.com/crystal-lang/crystal/releases/0.3.5

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

### [0.3.4] - 2014-07-21
[0.3.4]: https://github.com/crystal-lang/crystal/releases/0.3.4

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

### [0.3.3] - 2014-07-14
[0.3.3]: https://github.com/crystal-lang/crystal/releases/0.3.3

* Allow implicit conversion to C types by defining a `to_unsafe` method. This removed the hardcoded rule for converting a `String` to `UInt8*` and also allows passing an `Array(T)` to an argument expecting `Pointer(T)`.
* Fixed `.is_a?(Class)` not working ([#162](https://github.com/crystal-lang/crystal/issues/162))
* Attributes are now associated to AST nodes in the semantic pass, not during parsing. This allows macros to generate attributes that will be attached to subsequent expressions.
* **(breaking change)** Make ENV#[] raise on missing key, and added ENV#[]?
* **(breaking change)** Macro defs are now written like `macro def name(args) : ReturnType` instead of `def name(args) : ReturnType`, which was a bit confusing.

### [0.3.2] - 2014-07-10
[0.3.2]: https://github.com/crystal-lang/crystal/releases/0.3.2

* Integer literals without a suffix are inferred to be Int32, Int64 or UInt64 depending on their value.
* Check that integer literals fit into their types.
* Put back `Int#to_s(radix : Int)` (was renamed to `to_s_in_base` in the previous release) by also specifying a restriction in `Int#to_s(io : IO)`.
* Added `expect_raises` macros in specs

### [0.3.1] - 2014-07-09
[0.3.1]: https://github.com/crystal-lang/crystal/releases/0.3.1

* **(breaking change)** Replaced `@name` inside macros with `@class_name`.
* **(breaking change)** Instance variables inside macros now don't have the `@` symbols in their names.

### [0.3.0] - 2014-07-08
[0.3.0]: https://github.com/crystal-lang/crystal/releases/0.3.0

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

### [0.2.0] - 2014-06-24
[0.2.0]: https://github.com/crystal-lang/crystal/releases/0.2.0

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


### [0.1.0] - 2014-06-18
[0.1.0]: https://github.com/crystal-lang/crystal/releases/0.1.0

* First official release
