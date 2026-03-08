require "../../spec_helper"

describe "Codegen: while" do
  it "codegens def with while" do
    run("def foo; while false; 1; end; end; foo")
  end

  it "codegens while with false" do
    run("a = 1; while false; a = 2; end; a").to_i.should eq(1)
  end

  it "codegens while with non-false condition" do
    run("a = 1; while a < 10; a = a &+ 1; end; a").to_i.should eq(10)
  end

  it "break without value" do
    run("a = 0; while a < 10; a &+= 1; break; end; a").to_i.should eq(1)
  end

  it "conditional break without value" do
    run("a = 0; while a < 10; a &+= 1; break if a > 5; end; a").to_i.should eq(6)
  end

  it "break with value" do
    run(<<-CRYSTAL).to_i.should eq(4)
      struct Nil; def to_i!; 0; end; end

      a = 0
      b = while a < 10
        a &+= 1
        break a &+ 3
      end
      b.to_i!
      CRYSTAL
  end

  it "conditional break with value" do
    run(<<-CRYSTAL).to_i.should eq(9)
      struct Nil; def to_i!; 0; end; end

      a = 0
      b = while a < 10
        a &+= 1
        break a &+ 3 if a > 5
      end
      b.to_i!
      CRYSTAL
  end

  it "break with value, condition fails" do
    run(<<-CRYSTAL).to_b.should be_true
      a = while 1 == 2
        break 1
      end
      a.nil?
      CRYSTAL
  end

  it "endless break with value" do
    run(<<-CRYSTAL).to_i.should eq(4)
      a = 0
      while true
        a &+= 1
        break a &+ 3
      end
      CRYSTAL
  end

  it "endless conditional break with value" do
    run(<<-CRYSTAL).to_i.should eq(9)
      a = 0
      while true
        a &+= 1
        break a &+ 3 if a > 5
      end
      CRYSTAL
  end

  it "codegens endless while" do
    codegen "while true; end"
  end

  it "codegens while with declared var 1" do
    run(<<-CRYSTAL).to_i.should eq(0)
      struct Nil; def to_i!; 0; end; end

      while 1 == 2
        a = 2
      end
      a.to_i!
      CRYSTAL
  end

  it "codegens while with declared var 2" do
    run(<<-CRYSTAL).to_i.should eq(3)
      struct Nil; def to_i!; 0; end; end

      while 1 == 1
        a = 2
        if 1 == 1
          a = 3
          break
        end
      end
      a.to_i!
      CRYSTAL
  end

  it "codegens while with declared var 3" do
    run(<<-CRYSTAL).to_i.should eq(1)
      struct Nil; def to_i!; 0; end; end

      while 1 == 1
        a = 1
        if a
          break
        else
          2
        end
      end
      a.to_i!
      CRYSTAL
  end

  it "skip block with next" do
    run(<<-CRYSTAL).to_i.should eq(25)
      i = 0
      x = 0

      while i < 10
        i &+= 1
        next if i.unsafe_mod(2) == 0
        x &+= i
      end
      x
      CRYSTAL
  end

  it "doesn't crash on a = NoReturn" do
    codegen(<<-CRYSTAL)
      lib LibFoo
        fun foo : NoReturn
      end

      while a = LibFoo.foo
        a
      end
      CRYSTAL
  end

  it "doesn't crash on #2767" do
    run(<<-CRYSTAL).to_i.should eq(10)
      lib LibC
        fun exit(Int32) : NoReturn
      end

      x = 'x'
      while 1 == 2
        if true
          x = (LibC.exit(0); 1)
        end
      end
      x
      10
      CRYSTAL
  end

  it "doesn't crash on #2767 (2)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      lib LibC
        fun exit(Int32) : NoReturn
      end

      x = 'x'
      while 1 == 2
        x = LibC.exit(0).as(Int32)
      end
      x
      10
      CRYSTAL
  end

  it "doesn't crash on #2767 (3)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      lib LibC
        fun exit(Int32) : NoReturn
      end

      x = 'x'
      while 1 == 2
        if true
          x = if true
            LibC.exit(0)
          else
            3
          end
        end
      end
      x
      10
      CRYSTAL
  end

  it "doesn't crash on #2767 (4)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      lib LibC
        fun exit(Int32) : NoReturn
      end

      x = 'x'
      while 1 == 2
        if true
          x = (LibC.exit(0); 1)
        end
        y = x
        z = y
        x = z
      end
      x
      10
      CRYSTAL
  end

  it "doesn't crash on while true begin break rescue (#7786)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      while true
        begin
          foo = 1
          break
        rescue
        end
      end
      foo
      CRYSTAL
  end
end
