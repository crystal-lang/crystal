## Next

* Added `Array#each_index`
* Optimized `String#*` for the case when the string has length one.
* Use `GC.malloc_atomic` for String and String::Buffer (as they don't contain internal pointers.)
* Added a `PointerAppender` struct to easily append to a `Pointer` while counting at the same time (thanks @kostya for the idea).
* Added a `Base64` module (thanks @kostya)

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
