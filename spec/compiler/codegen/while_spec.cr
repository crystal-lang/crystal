require "../../spec_helper"

describe "Codegen: while" do
  it "codegens def with while" do
    run("def foo; while false; 1; end; end; foo")
  end

  it "codegens while with false" do
    run("a = 1; while false; a = 2; end; a").to_i.should eq(1)
  end

  it "codegens while with non-false condition" do
    run("a = 1; while a < 10; a = a + 1; end; a").to_i.should eq(10)
  end

  it "codegens while as modifier" do
    run("a = 1; begin; a += 1; end while false; a").to_i.should eq(2)
  end

  it "break without value" do
    run("a = 0; while a < 10; a += 1; break; end; a").to_i.should eq(1)
  end

  it "conditional break without value" do
    run("a = 0; while a < 10; a += 1; break if a > 5; end; a").to_i.should eq(6)
  end

  it "codegens endless while" do
    build "while true; end"
  end

  it "codegens while with declared var 1" do
    run("
      require \"nil\"
      while 1 == 2
        a = 2
      end
      a.to_i
      ").to_i.should eq(0)
  end

  it "codegens while with declared var 2" do
    run("
      require \"nil\"
      while 1 == 1
        a = 2
        if 1 == 1
          a = 3
          break
        end
      end
      a.to_i
      ").to_i.should eq(3)
  end

  it "codegens while with declared var 3" do
    run("
      require \"nil\"
      while 1 == 1
        a = 1
        if a
          break
        else
          2
        end
      end
      a.to_i
      ").to_i.should eq(1)
  end

  it "skip block with next" do
    run("
      i = 0
      x = 0

      while i < 10
        i += 1
        next if i % 2 == 0
        x += i
      end
      x
    ").to_i.should eq(25)
  end
end
