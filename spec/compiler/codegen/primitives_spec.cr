require "../../spec_helper"

describe "Code gen: primitives" do
  it "codegens bool" do
    expect(run("true").to_b).to be_true
    expect(run("false").to_b).to be_false
  end

  it "codegens int" do
    expect(run("1").to_i).to eq(1)
  end

  it "codegens long" do
    expect(run("1_i64").to_i).to eq(1)
  end

  it "codegens char" do
    expect(run("'a'").to_i).to eq('a'.ord)
  end

  it "codegens f32" do
    expect(run("2.5_f32").to_f32).to eq(2.5_f32)
  end

  it "codegens f64" do
    expect(run("2.5_f64").to_f64).to eq(2.5_f64)
  end

  it "codegens string" do
    expect(run(%("foo")).to_string).to eq("foo")
  end

  it "codegens 1 + 2" do
    expect(run(%(1 + 2)).to_i).to eq(3)
  end

  it "codegens 1 + 2" do
    expect(run(%(1 - 2)).to_i).to eq(-1)
  end

  it "codegens 2 * 3" do
    expect(run(%(2 * 3)).to_i).to eq(6)
  end

  it "codegens 8.unsafe_div 3" do
    expect(run(%(8.unsafe_div 3)).to_i).to eq(2)
  end

  it "codegens 8.unsafe_mod 3" do
    expect(run(%(10.unsafe_mod 3)).to_i).to eq(1)
  end

  it "defined method that calls primitive (bug)" do
    expect(run("
      struct Int64
        def foo
          to_u64
        end
      end

      a = 1_i64
      a.foo.to_i
      ").to_i).to eq(1)
  end

  it "codegens __LINE__" do
    expect(run("

      __LINE__
      ").to_i).to eq(3)
  end

  it "codeges crystal_type_id with union type" do
    expect(run("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.allocate || Bar.allocate
      f.crystal_type_id == Foo.allocate.crystal_type_id
      ").to_b).to be_true
  end

  it "doesn't treat `(1 == 1) == true` as `1 == 1 == true` (#328)" do
    expect(run("(1 == 1) == true").to_b).to be_true
  end

  it "passes issue #328" do
    expect(run("((1 == 1) != (2 == 2))").to_b).to be_false
  end

  pending "codegens pointer of int" do
    expect(run(%(
      ptr = Pointer(Int).malloc(1_u64)
      ptr.value = 1
      ptr.value = 2_u8
      ptr.value = 3_u16
      ptr.value = 4_u32
      (ptr.value + 1).to_i32
      )).to_i).to eq(5)
  end

  pending "sums two numbers out of an [] of Number" do
    expect(run(%(
      p = Pointer(Number).malloc(2_u64)
      p.value = 1
      (p + 1_i64).value = 1.5

      (p.value + (p + 1_i64).value).to_f32
      )).to_f32).to eq(2.5)
  end

  it "codegens crystal_type_id for class" do
    build(%(String.crystal_type_id))
  end
end
