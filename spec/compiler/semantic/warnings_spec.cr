require "../spec_helper"

describe "Semantic: warnings" do
  describe "deprecated types" do
    it "detects deprecated class methods" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        class Foo
        end

        Foo.new
        CRYSTAL
        "warning in line 5\nWarning: Deprecated Foo."

      assert_warning <<-CRYSTAL,
        @[Deprecated]
        module Foo::Bar
          def self.baz
          end
        end

        Foo::Bar.baz
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo::Bar."
    end

    it "detects deprecated superclass" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        class Foo
        end

        class Bar < Foo
        end
        CRYSTAL
        "warning in line 5\nWarning: Deprecated Foo."
    end

    it "doesn't check superclass when the class is deprecated" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        class Foo
        end

        @[Deprecated]
        class Bar < Foo
        end

        Bar.new
        CRYSTAL
        "warning in line 9\nWarning: Deprecated Bar."
    end

    it "detects deprecated type reference" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        class Foo
        end

        def p(x)
          x
        end

        p Foo
        CRYSTAL
        "warning in line 9\nWarning: Deprecated Foo."
    end

    it "only affects the type not the namespace" do
      assert_no_warning <<-CRYSTAL
        @[Deprecated]
        class Foo
          class Bar
          end
        end

        Foo::Bar.new
        CRYSTAL
    end

    it "doesn't deprecate instance methods (constructors already warn)" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        class Foo
          def do_something
          end
        end

        foo = Foo.new
        foo.do_something
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo."
    end

    it "detects deprecated through alias" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        class Foo
        end

        alias Bar = Foo
        alias Baz = Bar

        Baz.new
        CRYSTAL
        "warning in line 8\nWarning: Deprecated Foo."
    end

    it "detects deprecated constant in generic argument" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        class Foo
        end

        class Bar(T)
        end

        Bar(Foo)
        CRYSTAL
        "warning in line 8\nWarning: Deprecated Foo. Do not use me"
    end

    it "detects deprecated constant in include" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        module Foo
        end

        class Bar
          include Foo
        end

        Bar.new
        CRYSTAL
        "warning in line 6\nWarning: Deprecated Foo. Do not use me"
    end

    it "detects deprecated constant in extend" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        module Foo
        end

        class Bar
          extend Foo
        end
        CRYSTAL
        "warning in line 6\nWarning: Deprecated Foo. Do not use me"
    end
  end

  describe "deprecated alias" do
    it "detects deprecated class method calls" do
      assert_warning <<-CRYSTAL,
        class Foo
        end

        @[Deprecated("Use Foo.")]
        alias Bar = Foo

        Bar.new
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Bar. Use Foo."

      assert_warning <<-CRYSTAL,
        module Foo::Bar
          def self.baz; end
        end

        @[Deprecated("Use Foo::Bar.")]
        alias Bar = Foo::Bar

        Bar.baz
        CRYSTAL
        "warning in line 8\nWarning: Deprecated Bar. Use Foo::Bar."
    end

    it "doesn't deprecate the aliased type" do
      assert_no_warning <<-CRYSTAL
        class Foo
        end

        @[Deprecated("Use Foo.")]
        alias Bar = Foo

        Foo.new
        CRYSTAL
    end
  end

  describe "deprecated annotations" do
    it "detects deprecated annotations" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        annotation Foo; end

        @[Foo]
        def bar; end

        bar
        CRYSTAL
        "warning in line 2\nWarning: Deprecated annotation Foo."
    end

    it "detects deprecated namespaced annotations" do
      assert_warning <<-CRYSTAL,
        module MyNamespace
          @[Deprecated]
          annotation Foo; end
        end

        @[MyNamespace::Foo]
        def bar; end

        bar
        CRYSTAL
        "warning in line 3\nWarning: Deprecated annotation MyNamespace::Foo."
    end
  end

  describe "deprecated methods" do
    it "detects top-level deprecated methods" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        def foo
        end

        foo
        CRYSTAL
        "warning in line 5\nWarning: Deprecated ::foo. Do not use me"
    end

    it "deprecation reason is optional" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        def foo
        end

        foo
        CRYSTAL
        "warning in line 5\nWarning: Deprecated ::foo."
    end

    it "detects deprecated instance methods" do
      assert_warning <<-CRYSTAL,
        class Foo
          @[Deprecated("Do not use me")]
          def m
          end
        end

        Foo.new.m
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo#m. Do not use me"
    end

    it "detects deprecated class methods" do
      assert_warning <<-CRYSTAL,
        class Foo
          @[Deprecated("Do not use me")]
          def self.m
          end
        end

        Foo.m
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated generic instance methods" do
      assert_warning <<-CRYSTAL,
        class Foo(T)
          @[Deprecated("Do not use me")]
          def m
          end
        end

        Foo(Int32).new.m
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo(Int32)#m. Do not use me"
    end

    it "detects deprecated generic class methods" do
      assert_warning <<-CRYSTAL,
        class Foo(T)
          @[Deprecated("Do not use me")]
          def self.m
          end
        end

        Foo(Int32).m
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo(Int32).m. Do not use me"
    end

    it "detects deprecated module methods" do
      assert_warning <<-CRYSTAL,
        module Foo
          @[Deprecated("Do not use me")]
          def self.m
          end
        end

        Foo.m
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated methods with named arguments" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        def foo(*, a)
        end

        foo(a: 2)
        CRYSTAL
        "warning in line 5\nWarning: Deprecated ::foo."
    end

    it "detects deprecated initialize" do
      assert_warning <<-CRYSTAL,
        class Foo
          @[Deprecated]
          def initialize
          end
        end

        Foo.new
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo.new."
    end

    it "detects deprecated initialize with named arguments" do
      assert_warning <<-CRYSTAL,
        class Foo
          @[Deprecated]
          def initialize(*, a)
          end
        end

        Foo.new(a: 2)
        CRYSTAL
        "warning in line 7\nWarning: Deprecated Foo.new:a."
    end

    it "informs warnings once per call site location (a)" do
      warning_failures = warnings_result <<-CRYSTAL
        class Foo
          @[Deprecated("Do not use me")]
          def m
          end

          def b
            m
          end
        end

        Foo.new.b
        Foo.new.b
        CRYSTAL
      warning_failures.size.should eq(1)
    end

    it "informs warnings once per call site location (b)" do
      warning_failures = warnings_result <<-CRYSTAL
        class Foo
          @[Deprecated("Do not use me")]
          def m
          end
        end

        Foo.new.m
        Foo.new.m
        CRYSTAL

      warning_failures.size.should eq(2)
    end

    it "informs warnings once per yield" do
      warning_failures = warnings_result <<-CRYSTAL
        class Foo
          @[Deprecated("Do not use me")]
          def m
          end
        end

        def twice
          yield
          yield
        end

        twice { Foo.new.m }
        CRYSTAL

      warning_failures.size.should eq(1)
    end

    it "informs warnings once per target type" do
      warning_failures = warnings_result <<-CRYSTAL
        class Foo(T)
          @[Deprecated("Do not use me")]
          def m
          end

          def b
            m
          end
        end

        Foo(Int32).new.b
        Foo(Int64).new.b
        CRYSTAL

      warning_failures.size.should eq(2)
    end

    it "ignore deprecation excluded locations" do
      with_tempdir("check_warnings_excludes") do
        Dir.mkdir "lib"

        # NOTE tempfile might be created in symlinked folder
        # which affects how to match current dir /var/folders/...
        # with the real path /private/var/folders/...
        path = File.realpath(".")

        main_filename = File.join(path, "main.cr")
        output_filename = File.join(path, "main")

        File.write main_filename, <<-CRYSTAL
          require "./lib/foo"

          bar
          foo
          CRYSTAL
        File.write File.join(path, "lib", "foo.cr"), <<-CRYSTAL
          @[Deprecated("Do not use me")]
          def foo
          end

          def bar
            foo
          end
          CRYSTAL

        compiler = create_spec_compiler
        compiler.warnings.level = :all
        compiler.warnings.exclude_lib_path = true
        compiler.prelude = "empty"
        compiler.compile Compiler::Source.new(main_filename, File.read(main_filename)), output_filename

        compiler.warnings.infos.size.should eq(1)
      end
    end

    it "ignores nested calls to deprecated methods" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        def foo; bar; end

        @[Deprecated]
        def bar; end

        foo
        CRYSTAL
        "warning in line 7\nWarning: Deprecated ::foo."
    end

    it "errors if invalid argument type" do
      assert_error <<-CRYSTAL,
        @[Deprecated(42)]
        def foo
        end
        CRYSTAL
        "first argument must be a String"
    end

    it "errors if too many arguments" do
      assert_error <<-CRYSTAL,
        @[Deprecated("Do not use me", "extra arg")]
        def foo
        end
        CRYSTAL
        "wrong number of deprecated annotation arguments (given 2, expected 1)"
    end

    it "errors if invalid named arguments" do
      assert_error <<-CRYSTAL,
        @[Deprecated(invalid: "Do not use me")]
        def foo
        end
        CRYSTAL
        "too many named arguments (given 1, expected maximum 0)"
    end
  end

  describe "deprecated method args" do
    describe "defs" do
      it "warns when a deprecated positional argument is passed" do
        assert_warning <<-CRYSTAL,
          def foo(a, @[Deprecated] b, c)
          end

          foo(1, 2, 3)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument b."
      end

      it "warns when a deprecated keyword argument is passed" do
        assert_warning <<-CRYSTAL,
          def foo(x, *, a, @[Deprecated] b)
          end

          foo(0, a: 1, b: 2)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument b."
      end

      it "warns when a deprecated splat argument is passed" do
        assert_warning <<-CRYSTAL,
          def foo(a, @[Deprecated] *args)
          end

          foo(1, 2)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument args."
      end

      it "warns when a deprecated double splat argument is passed" do
        assert_warning <<-CRYSTAL,
          def foo(*, a, @[Deprecated] **opts)
          end

          foo(a: 1, bad: 2)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument opts."
      end

      it "warns when a deprecated default positional argument is passed" do
        assert_warning <<-CRYSTAL,
          def foo(a, @[Deprecated] b = nil, c = nil)
          end

          foo(1, 2)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument b."
      end

      it "warns when a deprecated default keyword argument is passed" do
        assert_warning <<-CRYSTAL,
          def foo(*, a, @[Deprecated] b = nil)
          end

          foo(a: 1, b: 2)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument b."
      end

      it "doesn't warn when a deprecated default positional argument isn't explicitly passed" do
        assert_no_warning <<-CRYSTAL
          def foo(a, @[Deprecated] b = nil, c = nil)
          end

          foo(1)
          foo(1, c: 3)
        CRYSTAL
      end

      it "doesn't warn when a deprecated default keyword argument isn't explicitly passed" do
        assert_no_warning <<-CRYSTAL
          def foo(*, a, @[Deprecated] b = nil)
          end

          foo(a: 1)
        CRYSTAL
      end

      it "warns when a default value calls a method with a deprecated arg" do
        assert_warning <<-CRYSTAL,
          def bar(@[Deprecated] x)
          end

          def foo(a, @[Deprecated] b = bar(a))
          end

          foo(1)
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument x."

        assert_warning <<-CRYSTAL,
          def bar(@[Deprecated] x)
          end

          def foo(a, @[Deprecated] b = bar(a))
          end

          foo(1, 2)
        CRYSTAL
          "warning in line 7\nWarning: Deprecated argument b."
      end

      it "warns when a deprecated arg default value calls a method with a deprecated arg" do
        assert_warning <<-CRYSTAL,
          def bar(@[Deprecated] x)
          end

          def foo(@[Deprecated] b = bar(1))
          end

          foo
        CRYSTAL
          "warning in line 4\nWarning: Deprecated argument x."
      end
    end

    describe "constructors" do
      it "warns when a deprecated positional arg is passed" do
        assert_warning <<-CRYSTAL,
          class Foo
            def initialize(a, @[Deprecated] b, c)
            end
          end

          Foo.new(1, 2, 3)
        CRYSTAL
          "warning in line 6\nWarning: Deprecated argument b."
      end

      it "warns when a deprecated keyword argument is passed" do
        assert_warning <<-CRYSTAL,
          class Foo
            def initialize(x, *, a, @[Deprecated] b)
            end
          end

          Foo.new(0, a: 1, b: 2)
        CRYSTAL
          "warning in line 6\nWarning: Deprecated argument b."
      end

      it "warns when a deprecated splat argument is passed" do
        assert_warning <<-CRYSTAL,
          class Foo
            def initialize(a, @[Deprecated] *args)
            end
          end

          Foo.new(1, 2)
        CRYSTAL
          "warning in line 6\nWarning: Deprecated argument args."
      end

      it "warns when a deprecated double splat argument is passed" do
        assert_warning <<-CRYSTAL,
          class Foo
            def initialize(*, a, @[Deprecated] **opts)
            end
          end

          Foo.new(a: 1, bad: 2)
        CRYSTAL
          "warning in line 6\nWarning: Deprecated argument opts."
      end
    end
  end

  describe "deprecated macros" do
    it "detects top-level deprecated macros" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        macro foo
        end

        foo
        CRYSTAL
        "warning in line 6\nWarning: Deprecated ::foo. Do not use me"
    end

    it "deprecation reason is optional" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        macro foo
        end

        foo
        CRYSTAL
        "warning in line 6\nWarning: Deprecated ::foo."
    end

    it "detects deprecated class macros" do
      assert_warning <<-CRYSTAL,
        class Foo
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
        CRYSTAL
        "warning in line 8\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated generic class macros" do
      assert_warning <<-CRYSTAL,
        class Foo(T)
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
        CRYSTAL
        "warning in line 8\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated module macros" do
      assert_warning <<-CRYSTAL,
        module Foo
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
        CRYSTAL
        "warning in line 8\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated macros with named arguments" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        macro foo(*, a)
        end

        foo(a: 2)
        CRYSTAL
        "warning in line 6\nWarning: Deprecated ::foo."
    end

    it "informs warnings once per call site location (a)" do
      warning_failures = warnings_result <<-CRYSTAL
        class Foo
          @[Deprecated("Do not use me")]
          macro m
          end

          macro b
            Foo.m
          end
        end

        Foo.b
        Foo.b
        CRYSTAL

      warning_failures.size.should eq(1)
    end

    it "informs warnings once per call site location (b)" do
      warning_failures = warnings_result <<-CRYSTAL
        class Foo
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
        Foo.m
        CRYSTAL

      warning_failures.size.should eq(2)
    end

    it "ignore deprecation excluded locations" do
      with_tempdir("check_warnings_excludes") do
        Dir.mkdir_p "lib"

        # NOTE tempfile might be created in symlinked folder
        # which affects how to match current dir /var/folders/...
        # with the real path /private/var/folders/...
        path = File.realpath(".")

        main_filename = File.join(path, "main.cr")
        output_filename = File.join(path, "main")

        File.write main_filename, %(
          require "./lib/foo"

          bar
          foo
        )
        File.write File.join(path, "lib", "foo.cr"), %(
          @[Deprecated("Do not use me")]
          macro foo
          end

          macro bar
            foo
          end
        )

        compiler = create_spec_compiler
        compiler.warnings.level = :all
        compiler.warnings.exclude_lib_path = true
        compiler.prelude = "empty"
        compiler.compile Compiler::Source.new(main_filename, File.read(main_filename)), output_filename

        compiler.warnings.infos.size.should eq(1)
      end
    end

    it "errors if invalid argument type" do
      assert_error <<-CRYSTAL, "first argument must be a String"
        @[Deprecated(42)]
        macro foo
        end
        CRYSTAL
    end

    it "errors if too many arguments" do
      assert_error <<-CRYSTAL, "wrong number of deprecated annotation arguments (given 2, expected 1)"
        @[Deprecated("Do not use me", "extra arg")]
        macro foo
        end
        CRYSTAL
    end

    it "errors if invalid named argument" do
      assert_error <<-CRYSTAL, "too many named arguments (given 1, expected maximum 0)"
        @[Deprecated(invalid: "Do not use me")]
        macro foo
        end
        CRYSTAL
    end
  end

  describe "deprecated constants" do
    it "detects deprecated constants" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        FOO = 1

        FOO
        CRYSTAL
        "warning in line 4\nWarning: Deprecated FOO. Do not use me"
    end

    it "detects deprecated constants inside macros" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        FOO = 1

        {% FOO %}
        CRYSTAL
        "warning in line 4\nWarning: Deprecated FOO. Do not use me"
    end

    it "detects deprecated constants in type declarations (1)" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        FOO = 1

        class Foo(N)
        end

        class Bar < Foo(FOO)
        end
        CRYSTAL
        "warning in line 7\nWarning: Deprecated FOO. Do not use me"
    end

    it "detects deprecated constants in type declarations (2)" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        FOO = 1

        module Foo(N)
        end

        class Bar
          include Foo(FOO)
        end
        CRYSTAL
        "warning in line 8\nWarning: Deprecated FOO. Do not use me"
    end

    it "detects deprecated constants in type declarations (3)" do
      assert_warning <<-CRYSTAL,
        @[Deprecated("Do not use me")]
        FOO = 1

        class Foo(N)
        end

        alias Bar = Foo(FOO)
        CRYSTAL
        "warning in line 7\nWarning: Deprecated FOO. Do not use me"
    end
  end

  describe "abstract def positional parameter name mismatch" do
    it "detects mismatch with single parameter" do
      assert_warning <<-CRYSTAL, "warning in line 6\nWarning: positional parameter 'y' corresponds to parameter 'x' of the overridden method"
        abstract class Foo
          abstract def foo(x)
        end

        class Bar < Foo
          def foo(y); end
        end
        CRYSTAL
    end

    it "detects mismatch within many parameters" do
      assert_warning <<-CRYSTAL, "warning in line 6\nWarning: positional parameter 'e' corresponds to parameter 'c' of the overridden method"
        abstract class Foo
          abstract def foo(a, b, c, d)
        end

        class Bar < Foo
          def foo(a, b, e, d); end
        end
        CRYSTAL
    end

    it "detects multiple mismatches" do
      warnings_result(<<-CRYSTAL).size.should eq(2)
        abstract class Foo
          abstract def foo(src, dst)
        end

        class Bar < Foo
          def foo(dst, src); end
        end
        CRYSTAL
    end

    it "respects external names of positional parameters (1)" do
      assert_warning <<-CRYSTAL, "warning in line 6\nWarning: positional parameter 'a' corresponds to parameter 'b' of the overridden method"
        abstract class Foo
          abstract def foo(b)
        end

        class Bar < Foo
          def foo(a b); end
        end
        CRYSTAL
    end

    it "respects external names of positional parameters (2)" do
      assert_warning <<-CRYSTAL, "warning in line 6\nWarning: positional parameter 'b' corresponds to parameter 'a' of the overridden method"
        abstract class Foo
          abstract def foo(a b)
        end

        class Bar < Foo
          def foo(b); end
        end
        CRYSTAL
    end

    it "doesn't warn if external parameter name matches (1)" do
      warnings_result(<<-CRYSTAL).should be_empty
        abstract class Foo
          abstract def foo(a)
        end

        class Bar < Foo
          def foo(a b); end
        end
        CRYSTAL
    end

    it "doesn't warn if external parameter name matches (2)" do
      warnings_result(<<-CRYSTAL).should be_empty
        abstract class Foo
          abstract def foo(a b)
        end

        class Bar < Foo
          def foo(a c); end
        end
        CRYSTAL
    end

    it "doesn't compare positional parameters to single splat" do
      warnings_result(<<-CRYSTAL).should be_empty
        abstract class Foo
          abstract def foo(x)
        end

        class Bar < Foo
          def foo(*y); end
        end
        CRYSTAL
    end

    it "doesn't compare single splats" do
      warnings_result(<<-CRYSTAL).should be_empty
        abstract class Foo
          abstract def foo(*x)
        end

        class Bar < Foo
          def foo(*y); end
        end
        CRYSTAL
    end

    it "informs warnings once per matching overload (1)" do
      assert_warning <<-CRYSTAL, "warning in line 6\nWarning: positional parameter 'y' corresponds to parameter 'x' of the overridden method"
        abstract class Foo
          abstract def foo(x : Int32)
        end

        class Bar < Foo
          def foo(y : Int32 | Char); end
          def foo(x : Int32 | String); end
        end
        CRYSTAL
    end

    it "informs warnings once per matching overload (2)" do
      warnings_result(<<-CRYSTAL).size.should eq(2)
        abstract class Foo
          abstract def foo(x : Int32)
        end

        class Bar < Foo
          def foo(y : Int32 | Char); end
          def foo(z : Int32 | String); end
        end
        CRYSTAL
    end

    describe "stops warning after implementation with matching parameters is found (#12150)" do
      it "exact match" do
        warnings_result(<<-CRYSTAL).should be_empty
          abstract class Foo
            abstract def foo(x : Int32)
          end

          class Bar < Foo
            def foo(x : Int32); end
            def foo(y : Int32 | String); end
          end
          CRYSTAL
      end

      it "contravariant restrictions" do
        warnings_result(<<-CRYSTAL).should be_empty
          abstract class Foo
            abstract def foo(x : Int32, y : Int32)
          end

          class Bar < Foo
            def foo(x : Int32 | Char, y : Int); end
            def foo(y : Int32 | String, z : Int32); end
          end
          CRYSTAL
      end

      it "different single splats" do
        warnings_result(<<-CRYSTAL).should be_empty
          abstract class Foo
            abstract def foo(x : Int32, *y)
          end

          class Bar < Foo
            def foo(x : Int32, *z); end
            def foo(y : Int32 | String, *z); end
          end
          CRYSTAL
      end

      it "reordered named parameters" do
        warnings_result(<<-CRYSTAL).should be_empty
          abstract class Foo
            abstract def foo(x : Int32, *, y : Int32, z : Int32)
          end

          class Bar < Foo
            def foo(x : Int32, *, z : Int32, y : Int32); end
            def foo(w : Int, *, y : Int32, z : Int32); end
          end
          CRYSTAL
      end
    end

    describe "continues warning if implementation with matching parameters is not found (#12150)" do
      it "not a full implementation" do
        assert_warning <<-CRYSTAL, "warning in line 8\nWarning: positional parameter 'y' corresponds to parameter 'x' of the overridden method"
          abstract class Foo
            abstract def foo(x : Int32 | String)
          end

          class Bar < Foo
            def foo(x : Int32); end
            def foo(x : String); end
            def foo(y : Int32 | String); end
          end
          CRYSTAL
      end

      it "single splat" do
        assert_warning <<-CRYSTAL, "warning in line 7\nWarning: positional parameter 'y' corresponds to parameter 'x' of the overridden method"
          abstract class Foo
            abstract def foo(x : Int32)
          end

          class Bar < Foo
            def foo(x : Int32, *y); end
            def foo(y : Int32 | String); end
          end
          CRYSTAL
      end

      it "double splat" do
        assert_warning <<-CRYSTAL, "warning in line 7\nWarning: positional parameter 'z' corresponds to parameter 'x' of the overridden method"
          abstract class Foo
            abstract def foo(x : Int32, *, y)
          end

          class Bar < Foo
            def foo(x : Int32, **opts); end
            def foo(z : Int32, *, y); end
          end
          CRYSTAL
      end
    end

    it "doesn't warn if current type is abstract (#12266)" do
      warnings_result(<<-CRYSTAL).should be_empty
        class Foo
          def foo(x); end
        end

        abstract class Bar < Foo
          abstract def foo(y)
        end

        abstract class Baz < Bar
        end
        CRYSTAL
    end

    it "doesn't warn if current type is a module (#12266)" do
      warnings_result(<<-CRYSTAL).should be_empty
        module Foo
          def foo(x); end # Warning: positional parameter 'x' corresponds to parameter 'y' of the overridden method Bar#foo(y), which has a different name and may affect named argument passing
        end

        module Bar
          include Foo
          abstract def foo(y)
        end

        module Baz
          include Bar
        end
        CRYSTAL
    end
  end

  it "exposes syntax warnings" do
    assert_warning UInt64::MAX.to_s, "Warning: #{UInt64::MAX} doesn't fit in an Int64, try using the suffix u64 or i128"
  end

  it "exposes syntax warnings after macro interpolation" do
    assert_warning "{% begin %}0x8000_0000_0000_000{{ 0 }}{% end %}", "Warning: 0x8000_0000_0000_0000 doesn't fit in an Int64, try using the suffix u64 or i128"
  end
end
