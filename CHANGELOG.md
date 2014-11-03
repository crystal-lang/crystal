## Next

* New command line interface to the compiler (`crystal build ...`, `crystal run ...`, `crystal spec`, etc.). The default is to compiler and run a program.
* `crystal eval` without arguments reads from standard input.
* `__FILE__`, `__DIR__` and `__LINE__`, when used as def default arguments, resolve to the caller location (similar to [D](http://dlang.org/traits.html#specialkeywords) and [Swift](https://developer.apple.com/swift/blog/?id=15))
* Allow `as` to determine a type even if the casted value doesn't have a type yet.
* Added `is_a?` in macros. The check is against an [AST node](https://github.com/manastech/crystal/blob/master/src/compiler/crystal/syntax/ast.cr) name. For example `node.is_a?(HashLiteral)`.
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

* Added [json_mapping](https://github.com/manastech/crystal/blob/master/spec/std/json/mapping_spec.cr) macro.
* Added [Signal](https://github.com/manastech/crystal/blob/master/src/signal.cr) module.
* Added [Tempfile](https://github.com/manastech/crystal/blob/master/src/tempfile.cr) class.
* Enhanced [HTTP::Client](https://github.com/manastech/crystal/blob/master/src/net/http/client/client.cr).
* Added [OAuth::Consumer](https://github.com/manastech/crystal/blob/master/libs/oauth/consumer.cr).
* Added [OAuth2::Client](https://github.com/manastech/crystal/blob/master/libs/oauth2/client.cr).
* Added [OpenSSL::HMAC](https://github.com/manastech/crystal/blob/master/libs/openssl/hmac.cr).
* Added [SecureRandom](https://github.com/manastech/crystal/blob/master/src/secure_random.cr).
* New syntax for array/hash-like classes. For example: `Set {1, 2, 3}` and `HTTP::Headers {"content-type": "text/plain"}`. These just create the type and use `<<` or `[]=`.
* Optimized Json parsing performance.
* Added a [CSV builder](https://github.com/manastech/crystal/blob/master/src/csv.cr#L13).
* XML reader can [parse from an IO](https://github.com/manastech/crystal/blob/master/src/xml/reader.cr#L10).
* Added `Dir::glob` and `Dir::Entries` (thanks @jhass)
* Allow `ensure` as an expression suffix.
* Fixed [#219](https://github.com/manastech/crystal/issues/219): Proc type is not inferred when passing to library fun and the return type doesn't match.
* Fixed [#224](https://github.com/manastech/crystal/issues/224): Class#new doesn't pass a block.
* Fixed [#225](https://github.com/manastech/crystal/issues/225): ICE when comparing void to something.
* Fixed [#227](https://github.com/manastech/crystal/issues/227): Nested captured block looses scope and crashes compiler.
* Fixed [#228](https://github.com/manastech/crystal/issues/228): Macro expansion doesn't retain symbol escaping as needed.
* Fixed [#229](https://github.com/manastech/crystal/issues/229): Can't change block context if defined within module context.
* Fixed [#230](https://github.com/manastech/crystal/issues/230): Type interference breaks equality operator.
* Fixed [#233](https://github.com/manastech/crystal/issues/233): Incorrect `no block given` message with new.
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

* Fixed [#193](https://github.com/manastech/crystal/issues/193): allow initializing an enum value with another's one.
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

* Fixed [#187](https://github.com/manastech/crystal/issues/185): mixing `yield` and `block.call` crashes the compiler.
* Added `\u` unicode escape sequences inside strings and chars (similar to Ruby). `\x` will be deprecated as it can generate strings with invalid UTF-8 byte sequences.
* Added `String#chars`.
* Fixed: splats weren't working in `initialize`.
* Added the `private` and `protected` visibility modifiers, with the same semantics as Ruby. The difference is that you must place them before a `def` or a macro call.
* Some bug fixes.

## 0.4.1 (2014-08-09)

* Fixed [#185](https://github.com/manastech/crystal/issues/185): `-e` flag stopped working.
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
* Fixed [#154](https://github.com/manastech/crystal/issues/154): bug, constants are initialized before global variables.
* Fixed [#168](https://github.com/manastech/crystal/issues/168): incorrect type inference of instance variables if not assigned in superclass.
* Fixed [#169](https://github.com/manastech/crystal/issues/169): `responds_to?` wasn't working with generic types.
* Fixed [#171](https://github.com/manastech/crystal/issues/171): ensure blocks are not executed if the rescue block returns from a def.
* Fixed [#175](https://github.com/manastech/crystal/issues/175): invalid code generated when using with/yield with structs.
* Fixed some parser issues and other small issues.
* Allow forward struct/union declarations in libs.
* Added `String#replace(Regex, String)`
* Added a `Box(T)` class, useful for boxing value types to pass them to C as `Void*`.

## 0.3.4 (2014-07-21)

* Fixed [#165](https://github.com/manastech/crystal/issues/165): restrictions with generic types didn't work for hierarchy types.
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
* Fixed `.is_a?(Class)` not working ([#162](https://github.com/manastech/crystal/issues/162))
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
