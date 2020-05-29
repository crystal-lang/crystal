require "../spec_helper"

describe "Semantic: warnings" do
  it "detects top-level deprecated marcos" do
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
        compiler.warnings = Warnings::All
        compiler.warnings_exclude << Crystal.normalize_path "lib"
        compiler.prelude = "empty"
        result = compiler.compile Compiler::Source.new(main_filename, File.read(main_filename)), output_filename

        result.program.warning_failures.size.should eq(1)
      end
    end
  end

  it "errors if invalid argument type" do
    assert_error %(
      @[Deprecated(42)]
      macro foo
      end
      ),
      "Error: first argument must be a String"
  end

  it "errors if too many arguments" do
    assert_error %(
      @[Deprecated("Do not use me", "extra arg")]
      macro foo
      end
      ),
      "Error: wrong number of deprecated annotation arguments (given 2, expected 1)"
  end

  it "errors if invalid named argument" do
    assert_error %(
      @[Deprecated(invalid: "Do not use me")]
      macro foo
      end
      ),
      "Error: too many named arguments (given 1, expected maximum 0)"
  end
end
