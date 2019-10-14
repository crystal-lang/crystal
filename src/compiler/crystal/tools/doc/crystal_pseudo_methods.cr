class Crystal::Doc::Generator
  def insert_pseudo_methods
    object = @program.object

    object.add_def declare_pseudo_method("!",
      return_type: Path.new(["Bool"]),
      doc: <<-DOC)
        Returns the boolean negation of `self`.

        ```
        !true   # => false
        !false  # => true
        !nil    # => true
        !1      # => false
        !"foo"  # => false
        ```

        This method is a unary operator and usually written in prefix notation
        (`!foo`) but it can also be written as a regular method call (`foo.!`).
        DOC

    object.add_def declare_pseudo_method("is_a?",
      args: [
        Arg.new("type", restriction: Path.new(["Class"])),
      ],
      return_type: Path.new(["Bool"]),
      doc: <<-DOC)
        Returns `true` if  inherits or includes *type*.
        *type* must be a constant, it cannot be evaluated at runtime.

        ```
        a = 1
        a.class                 # => Int32
        a.is_a?(Int32)          # => true
        a.is_a?(String)         # => false
        a.is_a?(Number)         # => true
        a.is_a?(Int32 | String) # => true
        ```
        DOC

    object.add_def declare_pseudo_method("nil?",
      return_type: Path.new(["Bool"]),
      doc: <<-DOC)
        Returns `true` if `self` is `Nil`.

        ```
        1.nil?   # => false
        nil.nil? # => true
        ```

        This method is equivalent to `is_a?(Nil)`.
        DOC

    object.add_def declare_pseudo_method("as",
      args: [
        Arg.new("type", restriction: Path.new(["Class"])),
      ],
      doc: <<-DOC)
        Returns `self`.

        The type of this expression is restricted to *type* by the compiler.
        *type* must be a constant, it cannot be evaluated at runtime.

        If *type* is not a valid restriction for the expression type, it
        is a compile-time error.
        If *type*  is a valid restriction for the expression, but `self` can't
        be restricted, it raises at runtime.
        *type* may be a wider restriction than the expression type, the resulting
        type is narrowed to the minimal restriction.

        ```
        a = [1, "foo"][0]
        typeof(a)             # => Int32 | String

        typeof(a.as(Int32))   # => Int32
        a.as(Int32)           # => 1

        typeof(a.as(Bool))    # Compile Error: can't cast (Int32 | String) to Bool

        typeof(a.as(String))  # => String
        a.as(String)          # Runtime Error: cast from Int32 to String failed

        typeof(a.as(Int32 | Bool)) # => Int32
        a.as(Int32 | Bool)         # => 1
        ```
        DOC

    object.add_def declare_pseudo_method("as?",
      args: [
        Arg.new("type", restriction: Path.new(["Class"])),
      ],
      doc: <<-DOC)
        Returns `self` or `nil` if can't be restricted to *type*.

        The type of this expression is restricted to *type* by the compiler.
        If *type* is not a valid type restriction for the expression type, then
        it is restricted to `Nil`.
        *type* must be a constant, it cannot be evaluated at runtime.

        ```
        a = [1, "foo"][0]
        typeof(a)              # => Int32 | String

        typeof(a.as?(Int32))   # => Int32 | Nil
        a.as?(Int32)           # => 1

        typeof(a.as?(Bool))    # => Nil
        a.as?(Bool)            # => nil

        typeof(a.as?(String))  # => String | Nil
        a.as?(String)          # nil

        typeof(a.as?(Int32 | Bool)) # => Int32 | Nil
        a.as?(Int32 | Bool)         # => 1
        ```
        DOC

    object.add_def declare_pseudo_method("responds_to?",
      args: [
        Arg.new("name", restriction: Path.new(["Symbol"])),
      ],
      return_type: Path.new(["Bool"]),
      doc: <<-DOC)
        Returns `true` if `self` responds to *name*.

        *name* must be a symbol literal, it cannot be evaluated at runtime.

        ```
        a = 1
        a.responds_to?(:abs)  # => true
        a.responds_to?(:size) # => false
        ```
      DOC
  end

  private def declare_pseudo_method(*args_, doc : String, file = __FILE__, line = __LINE__, end_line = __END_LINE__, **kwargs)
    Def.new(*args_, **kwargs).tap do |d|
      # Need to add locations, otherwise the methods would be skipped in docs
      d.at(Location.new(file, line, 0))
      d.at_end(Location.new(file, end_line, 0))
      d.doc = <<-DOC
        #{doc}

        NOTE: This is a pseudo-method provided directly by the Crystal compiler.
              It cannot be redefined nor overridden.
        DOC
    end
  end
end
