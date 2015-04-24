require "../../spec_helper"

describe "Normalize: def" do
  it "expands a def on request with default arguments" do
    a_def = parse("def foo(x, y = 1, z = 2); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(1)
    expected = parse("def foo(x); foo(x, 1, 2); end")
    expect(actual).to eq(expected)
  end

  it "expands a def on request with default arguments (2)" do
    a_def = parse("def foo(x, y = 1, z = 2); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(2)
    expected = parse("def foo(x, y); foo(x, y, 2); end")
    expect(actual).to eq(expected)
  end

  it "expands a def on request with default arguments that yields" do
    a_def = parse("def foo(x, y = 1, z = 2); yield x + y + z; end") as Def
    actual = a_def.expand_default_arguments(1)
    expected = parse("def foo(x); y = 1; z = 2; yield x + y + z; end")
    expect(actual).to eq(expected)
  end

  it "expands a def on request with default arguments that yields (2)" do
    a_def = parse("def foo(x, y = 1, z = 2); yield x + y + z; end") as Def
    actual = a_def.expand_default_arguments(2)
    expected = parse("def foo(x, y); z = 2; yield x + y + z; end")
    expect(actual).to eq(expected)
  end

  it "expands a def on request with default arguments and type restrictions" do
    a_def = parse("def foo(x, y = 1 : Int32, z = 2 : Int64); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(1)
    expected = parse("def foo(x); y = 1; z = 2; x + y + z; end")
    expect(actual).to eq(expected)
  end

  it "expands a def on request with default arguments and type restrictions (2)" do
    a_def = parse("def foo(x, y = 1 : Int32, z = 2 : Int64); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(2)
    expected = parse("def foo(x, y : Int32); z = 2; x + y + z; end")
    expect(actual).to eq(expected)
  end

  it "expands with splat" do
    a_def = parse("def foo(*args); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(_arg0, _arg1, _arg2)\n  args = {_arg0, _arg1, _arg2}\n  args\nend")
    expect(actual).to eq(expected)
  end

  it "expands with splat with one arg before" do
    a_def = parse("def foo(x, *args); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(x, _arg0, _arg1)\n  args = {_arg0, _arg1}\n  args\nend")
    expect(actual).to eq(expected)
  end

  it "expands with splat with one arg after" do
    a_def = parse("def foo(*args, x); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(_arg0, _arg1, x)\n  args = {_arg0, _arg1}\n  args\nend")
    expect(actual).to eq(expected)
  end

  it "expands with splat with one arg before and after" do
    a_def = parse("def foo(x, *args, z); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(x, _arg0, z)\n  args = {_arg0}\n  args\nend")
    expect(actual).to eq(expected)
  end

  it "expands with splat and zero" do
    a_def = parse("def foo(*args); args; end") as Def
    actual = a_def.expand_default_arguments(0)
    expect(actual.to_s).to eq("def foo\n  args = {}\n  args\nend")
  end

  it "expands with splat and default argument" do
    a_def = parse("def foo(x = 1, *args); args; end") as Def
    actual = a_def.expand_default_arguments(0)
    expect(actual.to_s).to eq("def foo\n  x = 1\n  args = {}\n  args\nend")
  end

  it "expands with named argument" do
    a_def = parse("def foo(x = 1, y = 2); x + y; end") as Def
    actual = a_def.expand_default_arguments(0, ["y"])
    expect(actual.to_s).to eq("def foo:y(y)\n  foo(1, y)\nend")
  end

  it "expands with two named argument" do
    a_def = parse("def foo(x = 1, y = 2); x + y; end") as Def
    actual = a_def.expand_default_arguments(0, ["y", "x"])
    expect(actual.to_s).to eq("def foo:y:x(y, x)\n  foo(x, y)\nend")
  end

  it "expands with two named argument and one not" do
    a_def = parse("def foo(x, y = 2, z = 3); x + y; end") as Def
    actual = a_def.expand_default_arguments(1, ["z"])
    expect(actual.to_s).to eq("def foo:z(x, z)\n  foo(x, 2, z)\nend")
  end

  it "expands with named argument and yield" do
    a_def = parse("def foo(x = 1, y = 2); yield x + y; end") as Def
    actual = a_def.expand_default_arguments(0, ["y"])
    expect(actual.to_s).to eq("def foo:y(y)\n  x = 1\n  yield x + y\nend")
  end

  # Small optimizations: no need to create a separate def in these cases
  it "expands with one named arg that is the only one (1)" do
    a_def = parse("def foo(x = 1); x; end") as Def
    other_def = a_def.expand_default_arguments(0, ["x"])
    expect(other_def).to be(a_def)
  end

  it "expands with one named arg that is the only one (2)" do
    a_def = parse("def foo(x, y = 1); x; end") as Def
    other_def = a_def.expand_default_arguments(1, ["y"])
    expect(other_def).to be(a_def)
  end

  it "expands with more named arg which come in the correct order" do
    a_def = parse("def foo(x, y = 1, z = 2); x; end") as Def
    other_def = a_def.expand_default_arguments(1, ["y", "z"])
    expect(other_def).to be(a_def)
  end

  it "expands with magic constant" do
    a_def = parse("def foo(x, y = __LINE__); x; end") as Def
    other_def = a_def.expand_default_arguments(1)
    expect(other_def).to be(a_def)
  end

  it "expands with magic constant specifying one when all are magic" do
    a_def = parse("def foo(x, file = __FILE__, line = __LINE__); x; end") as Def
    other_def = a_def.expand_default_arguments(2)
    expect(other_def).to be(a_def)
  end

  it "expands with magic constant specifying one when not all are magic" do
    a_def = parse("def foo(x, z = 1, line = __LINE__); x; end") as Def
    other_def = a_def.expand_default_arguments(2)
    expect(other_def).to be(a_def)
  end

  it "expands with magic constant with named arg" do
    a_def = parse("def foo(x, file = __FILE__, line = __LINE__); x; end") as Def
    other_def = a_def.expand_default_arguments(1, ["line"])
    expect(other_def.to_s).to eq("def foo:line(x, line, file = __FILE__)\n  foo(x, file, line)\nend")
  end

  it "expands with magic constant with named arg with yield" do
    a_def = parse("def foo(x, file = __FILE__, line = __LINE__); yield x, file, line; end") as Def
    other_def = a_def.expand_default_arguments(1, ["line"])
    expect(other_def.to_s).to eq("def foo:line(x, line, file = __FILE__)\n  yield x, file, line\nend")
  end
end
