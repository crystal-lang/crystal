require "../../spec_helper"

describe "Code gen: primitives" do
  it "codegens bool" do
    run("true").to_b.should be_true
    run("false").to_b.should be_false
  end

  it "codegens int" do
    run("1").to_i.should eq(1)
  end

  it "codegens long" do
    run("1_i64").to_i.should eq(1)
  end

  it "codegens char" do
    run("'a'").to_i.should eq('a'.ord)
  end

  it "codegens f32" do
    run("2.5_f32").to_f32.should eq(2.5_f32)
  end

  it "codegens f64" do
    run("2.5_f64").to_f64.should eq(2.5_f64)
  end

  it "codegens string" do
    run(%("foo")).to_string.should eq("foo")
  end

  it "codegens 1 + 2" do
    run(%(1 + 2)).to_i.should eq(3)
  end

  it "codegens 1 + 2" do
    run(%(1 - 2)).to_i.should eq(-1)
  end

  it "codegens 2 * 3" do
    run(%(2 * 3)).to_i.should eq(6)
  end

  it "codegens 8.unsafe_div 3" do
    run(%(8.unsafe_div 3)).to_i.should eq(2)
  end

  it "codegens 8.unsafe_mod 3" do
    run(%(10.unsafe_mod 3)).to_i.should eq(1)
  end

  it "defined method that calls primitive (bug)" do
    run("
      struct Int64
        def foo
          to_u64
        end
      end

      a = 1_i64
      a.foo.to_i
      ").to_i.should eq(1)
  end

  it "codegens __LINE__" do
    run("

      __LINE__
      ").to_i.should eq(3)
  end

  it "codeges crystal_type_id with union type" do
    run("
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.allocate || Bar.allocate
      f.crystal_type_id == Foo.allocate.crystal_type_id
      ").to_b.should be_true
  end

  it "doesn't treat `(1 == 1) == true` as `1 == 1 == true` (#328)" do
    run("(1 == 1) == true").to_b.should be_true
  end

  it "passes issue #328" do
    run("((1 == 1) != (2 == 2))").to_b.should be_false
  end

  it "codegens pointer of int" do
    run(%(
      ptr = Pointer(Int).malloc(1_u64)
      ptr.value = 1
      ptr.value = 2_u8
      ptr.value = 3_u16
      ptr.value = 4_u32
      (ptr.value + 1).to_i32
      )).to_i.should eq(5)
  end

  it "sums two numbers out of an [] of Number" do
    run(%(
      p = Pointer(Number).malloc(2_u64)
      p.value = 1
      (p + 1_i64).value = 1.5

      (p.value + (p + 1_i64).value).to_f32
      )).to_f32.should eq(2.5)
  end

  it "codegens crystal_type_id for class" do
    build(%(String.crystal_type_id))
  end
end
