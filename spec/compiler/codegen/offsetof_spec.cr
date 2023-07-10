require "../../spec_helper"

describe "Code gen: offsetof" do
  it "returns offset allowing manual access of first struct field" do
    code = "struct Foo; @x = 42; def x; @x; end; end;
            f = Foo.new
            (pointerof(f).as(Void*) + offsetof(Foo, @x).to_i64()).as(Int32*).value == f.x"

    run(code).to_b.should be_true
  end

  it "returns offset allowing manual access of struct field that isn't first" do
    code = "struct Foo; @x = 1; @y = 42; def x; @x; end; def y; @y; end; end;
            f = Foo.new
            (pointerof(f).as(Void*) + offsetof(Foo, @y).to_i64()).as(Int32*).value == f.y"

    run(code).to_b.should be_true
  end

  it "returns offset allowing manual access of first class field" do
    code = "class Bar; @x = 42; def x; @x; end; end;
            b = Bar.new
            (b.as(Void*) + offsetof(Bar, @x).to_i64()).as(Int32*).value == b.x"

    run(code).to_b.should be_true
  end

  it "returns offset allowing manual access of class field that isn't first" do
    code = "class Bar; @x = 1; @y = 42; def x; @x; end; def y; @y; end; end;
            b = Bar.new
            (b.as(Void*) + offsetof(Bar, @y).to_i64()).as(Int32*).value == b.y"

    run(code).to_b.should be_true
  end

  it "returns offset allowing manual access of tuple items" do
    code = "foo = {1, 2_i8, 3}
            (pointerof(foo).as(Void*) + offsetof({Int32,Int8,Int32}, 2).to_i64).as(Int32*).value == 3"

    run(code).to_b.should be_true
  end

  it "returns offset of extern union" do
    run(<<-CRYSTAL).to_b.should be_true
      @[Extern(union: true)]
      struct Foo
        @x = 1.0_f32
        @y = uninitialized UInt32

        def y
          @y
        end
      end

      f = Foo.new
      (pointerof(f).as(Void*) + offsetof(Foo, @y).to_i64).as(UInt32*).value == f.y
      CRYSTAL
  end

  it "returns offset of `StaticArray#@buffer`" do
    run(<<-CRYSTAL).to_b.should be_true
      x = uninitialized Int32[4]
      pointerof(x.@buffer).value = 12345
      (pointerof(x).as(Void*) + offsetof(Int32[4], @buffer).to_i64).as(Int32*).value == x.@buffer
      CRYSTAL
  end
end
