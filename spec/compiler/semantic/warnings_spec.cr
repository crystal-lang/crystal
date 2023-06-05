require "../spec_helper"

describe "Semantic: warnings" do
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
        "warning in line 5\nWarning: Deprecated top-level foo. Do not use me"
    end

    it "deprecation reason is optional" do
      assert_warning <<-CRYSTAL,
        @[Deprecated]
        def foo
        end

        foo
        CRYSTAL
        "warning in line 5\nWarning: Deprecated top-level foo."
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
        "warning in line 5\nWarning: Deprecated top-level foo:a."
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
      with_tempfile("check_warnings_excludes") do |path|
        FileUtils.mkdir_p File.join(path, "lib")

        # NOTE tempfile might be created in symlinked folder
        # which affects how to match current dir /var/folders/...
        # with the real path /private/var/folders/...
        path = File.real_path(path)

        main_filename = File.join(path, "main.cr")
        output_filename = File.join(path, "main")

        Dir.cd(path) do
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
    end

    it "ignores nested calls to deprecated methods" do
      x = assert_warning <<-CRYSTAL,
        @[Deprecated]
        def foo; bar; end

        @[Deprecated]
        def bar; end

        foo
        CRYSTAL
        "warning in line 7\nWarning: Deprecated top-level foo."
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

  describe "deprecated macros" do
    it "detects top-level deprecated macros" do
      assert_warning %(
        @[Deprecated("Do not use me")]
        macro foo
        end

        foo
      ), "warning in line 6\nWarning: Deprecated top-level foo. Do not use me"
    end

    it "deprecation reason is optional" do
      assert_warning %(
        @[Deprecated]
        macro foo
        end

        foo
      ), "warning in line 6\nWarning: Deprecated top-level foo."
    end

    it "detects deprecated class macros" do
      assert_warning %(
        class Foo
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
      ), "warning in line 8\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated generic class macros" do
      assert_warning %(
        class Foo(T)
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
      ), "warning in line 8\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated module macros" do
      assert_warning %(
        module Foo
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
      ), "warning in line 8\nWarning: Deprecated Foo.m. Do not use me"
    end

    it "detects deprecated macros with named arguments" do
      assert_warning %(
        @[Deprecated]
        macro foo(*, a)
        end

        foo(a: 2)
      ), "warning in line 6\nWarning: Deprecated top-level foo."
    end

    it "informs warnings once per call site location (a)" do
      warning_failures = warnings_result %(
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
      )

      warning_failures.size.should eq(1)
    end

    it "informs warnings once per call site location (b)" do
      warning_failures = warnings_result %(
        class Foo
          @[Deprecated("Do not use me")]
          macro m
          end
        end

        Foo.m
        Foo.m
      )

      warning_failures.size.should eq(2)
    end

    it "ignore deprecation excluded locations" do
      with_tempfile("check_warnings_excludes") do |path|
        FileUtils.mkdir_p File.join(path, "lib")

        # NOTE tempfile might be created in symlinked folder
        # which affects how to match current dir /var/folders/...
        # with the real path /private/var/folders/...
        path = File.real_path(path)

        main_filename = File.join(path, "main.cr")
        output_filename = File.join(path, "main")

        Dir.cd(path) do
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
    end

    it "errors if invalid argument type" do
      assert_error %(
        @[Deprecated(42)]
        macro foo
        end
        ),
        "first argument must be a String"
    end

    it "errors if too many arguments" do
      assert_error %(
        @[Deprecated("Do not use me", "extra arg")]
        macro foo
        end
        ),
        "wrong number of deprecated annotation arguments (given 2, expected 1)"
    end

    it "errors if invalid named argument" do
      assert_error %(
        @[Deprecated(invalid: "Do not use me")]
        macro foo
        end
        ),
        "too many named arguments (given 1, expected maximum 0)"
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
