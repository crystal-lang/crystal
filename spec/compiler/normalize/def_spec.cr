require "../../spec_helper"

module Crystal
  describe "Normalize: def" do
    it "expands a def on request with default arguments" do
      a_def = parse("def foo(x, y = 1, z = 2); x + y + z; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 1)
      expected = parse("def foo(x); y = 1; z = 2; foo(x, y, z); end")
      actual.should eq(expected)
    end

    it "expands a def on request with default arguments (2)" do
      a_def = parse("def foo(x, y = 1, z = 2); x + y + z; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 2)
      expected = parse("def foo(x, y); z = 2; foo(x, y, z); end")
      actual.should eq(expected)
    end

    it "expands a def on request with default arguments that yields" do
      a_def = parse("def foo(x, y = 1, z = 2); yield x + y + z; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 1)
      expected = parse("def foo(x); y = 1; z = 2; yield x + y + z; end")
      actual.should eq(expected)
    end

    it "expands a def on request with default arguments that yields (2)" do
      a_def = parse("def foo(x, y = 1, z = 2); yield x + y + z; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 2)
      expected = parse("def foo(x, y); z = 2; yield x + y + z; end")
      actual.should eq(expected)
    end

    it "expands a def on request with default arguments and type restrictions" do
      a_def = parse("def foo(x, y : Int32 = 1, z : Int64 = 2i64); x + y + z; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 1)
      expected = parse("def foo(x); y = 1; z = 2i64; x + y + z; end").as(Def)

      exps = expected.body.as(Expressions).expressions
      exps[0] = AssignWithRestriction.new(exps[0].as(Assign), Path.new("Int32"))
      exps[1] = AssignWithRestriction.new(exps[1].as(Assign), Path.new("Int64"))

      actual.should eq(expected)
    end

    it "expands a def on request with default arguments and type restrictions (2)" do
      a_def = parse("def foo(x, y : Int32 = 1, z : Int64 = 2i64); x + y + z; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 2)
      expected = parse("def foo(x, y : Int32); z = 2i64; x + y + z; end").as(Def)

      exps = expected.body.as(Expressions).expressions
      exps[0] = AssignWithRestriction.new(exps[0].as(Assign), Path.new("Int64"))

      actual.should eq(expected)
    end

    it "expands with splat" do
      a_def = parse("def foo(*args); args; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 3)
      expected = parse("def foo(__temp_1, __temp_2, __temp_3)\n  args = {__temp_1, __temp_2, __temp_3}\n  args\nend")
      actual.should eq(expected)
    end

    it "expands with splat with one arg before" do
      a_def = parse("def foo(x, *args); args; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 3)
      expected = parse("def foo(x, __temp_1, __temp_2)\n  args = {__temp_1, __temp_2}\n  args\nend")
      actual.should eq(expected)
    end

    it "expands with splat and zero" do
      a_def = parse("def foo(*args); args; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 0)
      actual.to_s.should eq("def foo\n  args = {}\n  args\nend")
    end

    it "expands with splat and default argument" do
      a_def = parse("def foo(x = 1, *args); args; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 0)
      actual.to_s.should eq("def foo\n  x = 1\n  args = {}\n  args\nend")
    end

    it "expands with named argument" do
      a_def = parse("def foo(x = 1, y = 2); x + y; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 0, ["y"])
      actual.to_s.should eq("def foo:y(y)\n  x = 1\n  foo(x, y)\nend")
    end

    it "expands with two named argument" do
      a_def = parse("def foo(x = 1, y = 2); x + y; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 0, ["y", "x"])
      actual.to_s.should eq("def foo:y:x(y, x)\n  foo(x, y)\nend")
    end

    it "expands with two named argument and one not" do
      a_def = parse("def foo(x, y = 2, z = 3); x + y; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 1, ["z"])
      actual.to_s.should eq("def foo:z(x, z)\n  y = 2\n  foo(x, y, z)\nend")
    end

    it "expands with named argument and yield" do
      a_def = parse("def foo(x = 1, y = 2, &); yield x + y; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 0, ["y"])
      actual.to_s.should eq("def foo:y(y, &)\n  x = 1\n  yield x + y\nend")
    end

    # Small optimizations: no need to create a separate def in these cases
    it "expands with one named arg that is the only one (1)" do
      a_def = parse("def foo(x = 1); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0, ["x"])
      other_def.should be(a_def)
    end

    it "expands with one named arg that is the only one (2)" do
      a_def = parse("def foo(x, y = 1); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 1, ["y"])
      other_def.should be(a_def)
    end

    it "expands with more named arg which come in the correct order" do
      a_def = parse("def foo(x, y = 1, z = 2); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 1, ["y", "z"])
      other_def.should be(a_def)
    end

    it "expands with magic constant" do
      a_def = parse("def foo(x, y = __LINE__); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 1)
      other_def.should be(a_def)
    end

    it "expands with magic constant specifying one when all are magic" do
      a_def = parse("def foo(x, file = __FILE__, line = __LINE__); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 2)
      other_def.should be(a_def)
    end

    it "expands with magic constant specifying one when not all are magic" do
      a_def = parse("def foo(x, z = 1, line = __LINE__); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 2)
      other_def.should be(a_def)
    end

    it "expands with magic constant with named arg" do
      a_def = parse("def foo(x, file = __FILE__, line = __LINE__); x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 1, ["line"])
      other_def.to_s.should eq("def foo:line(x, line, file = __FILE__)\n  foo(x, file, line)\nend")
    end

    it "expands with magic constant with named arg with yield" do
      a_def = parse("def foo(x, file = __FILE__, line = __LINE__, &); yield x, file, line; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 1, ["line"])
      other_def.to_s.should eq("def foo:line(x, line, file = __FILE__, &)\n  yield x, file, line\nend")
    end

    it "expands a def with double splat and no args" do
      a_def = parse("def foo(**options); options; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0)
      other_def.to_s.should eq("def foo\n  options = {}\n  options\nend")
    end

    it "expands a def with double splat and two named args" do
      a_def = parse("def foo(**options); options; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0, ["x", "y"])
      other_def.to_s.should eq("def foo:x:y(x __temp_1, y __temp_2)\n  options = {x: __temp_1, y: __temp_2}\n  options\nend")
    end

    it "expands a def with double splat and two named args and regular args" do
      a_def = parse("def foo(y, **options); y + options; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0, ["x", "y", "z"])
      other_def.to_s.should eq("def foo:x:y:z(x __temp_1, y, z __temp_3)\n  options = {x: __temp_1, z: __temp_3}\n  y + options\nend")
    end

    it "expands a def with splat and double splat" do
      a_def = parse("def foo(*args, **options); args + options; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 2, ["x", "y"])
      other_def.to_s.should eq("def foo:x:y(__temp_1, __temp_2, x __temp_3, y __temp_4)\n  args = {__temp_1, __temp_2}\n  options = {x: __temp_3, y: __temp_4}\n  args + options\nend")
    end

    it "expands arg with default value after splat" do
      a_def = parse("def foo(*args, x = 10); args + x; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0)
      other_def.to_s.should eq("def foo\n  x = 10\n  args = {}\n  args + x\nend")
    end

    it "expands default value after splat index" do
      a_def = parse("def foo(x, *y, z = 10); x + y + z; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 3)
      other_def.to_s.should eq("def foo(x, __temp_1, __temp_2)\n  z = 10\n  y = {__temp_1, __temp_2}\n  (x + y) + z\nend")
    end

    it "uses bare *" do
      a_def = parse("def foo(x, *, y); x + y; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 1, ["y"])
      other_def.to_s.should eq("def foo:y(x, y)\n  x + y\nend")
    end

    it "expands a def with external names (1)" do
      a_def = parse("def foo(x y); y; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 0, ["x"])
      actual.should be(a_def)
    end

    it "expands a def with external names (2)" do
      a_def = parse("def foo(x x1, y y1); x1 + y1; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0, ["y", "x"])
      other_def.to_s.should eq("def foo:y:x(y y1, x x1)\n  foo(x1, y1)\nend")
    end

    it "expands a def on request with default arguments (external names)" do
      a_def = parse("def foo(x x1, y y1 = 1, z z1 = 2); x1 + y1 + z1; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 1)
      expected = parse("def foo(x x1); y1 = 1; z1 = 2; foo(x1, y1, z1); end")
      actual.should eq(expected)
    end

    it "expands a def on request with default arguments that yields (external names)" do
      a_def = parse("def foo(x x1, y y1 = 1, z z1 = 2); yield x1 + y1 + z1; end").as(Def)
      actual = a_def.expand_default_arguments(Program.new, 1)
      expected = parse("def foo(x x1); y1 = 1; z1 = 2; yield x1 + y1 + z1; end")
      actual.should eq(expected)
    end

    it "expands a new def with double splat and two named args and regular args" do
      a_def = parse("def new(y, **options); y + options; end").as(Def)
      other_def = a_def.expand_new_default_arguments(Program.new, 0, ["x", "y", "z"])
      other_def.to_s.should eq("def new:x:y:z(x __temp_1, y __temp_2, z __temp_3)\n  _ = allocate\n  _.initialize(x: __temp_1, y: __temp_2, z: __temp_3)\n  if _.responds_to?(:finalize)\n    ::GC.add_finalizer(_)\n  end\n  _\nend")
    end

    it "expands def with reserved external name (#6559)" do
      a_def = parse("def foo(abstract __arg0, **options); @abstract = __arg0; end").as(Def)
      other_def = a_def.expand_default_arguments(Program.new, 0, ["abstract"])
      other_def.to_s.should eq("def foo:abstract(abstract __arg0)\n  options = {}\n  @abstract = __arg0\nend")
    end

    describe "gives correct body location with" do
      {"default arg"                  => "def testing(foo = 5)",
       "default arg with restriction" => "def testing(foo : Int = 5)",
       "splat arg"                    => "def testing(*foo : Array)",
       "block instance var arg"       => "def testing(&@foo : ->)",
      }.each do |(suffix1, definition)|
        {"with body"    => "zzz = 7\n",
         "without body" => "",
        }.each do |(suffix2, body)|
          it "#{suffix1}, #{suffix2}" do
            a_def = parse("#{definition}\n#{body}end").as(Def)
            actual = a_def.expand_default_arguments(Program.new, 1)

            actual.location.should eq Location.new("", line_number: 1, column_number: 1)
            actual.body.location.should eq Location.new("", line_number: 2, column_number: 1)
          end
        end
      end
    end
  end
end
