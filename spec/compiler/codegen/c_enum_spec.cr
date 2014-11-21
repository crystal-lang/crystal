require "../../spec_helper"

CodeGenCEnumString = "lib Foo; enum Bar; X, Y, Z = 10, W; end end"

describe "Code gen: c enum" do
  it "codegens enum value" do
    run("#{CodeGenCEnumString}; Foo::Bar::X").to_i.should eq(0)
  end

  it "codegens enum value 2" do
    run("#{CodeGenCEnumString}; Foo::Bar::Y").to_i.should eq(1)
  end

  it "codegens enum value 3" do
    run("#{CodeGenCEnumString}; Foo::Bar::Z").to_i.should eq(10)
  end

  it "codegens enum value 4" do
    run("#{CodeGenCEnumString}; Foo::Bar::W").to_i.should eq(11)
  end

  [
    {"1 + 2", 3},
    {"3 - 2", 1},
    {"3 * 2", 6},
    {"10 / 2", 5},
    {"1 << 3", 8},
    {"100 >> 3", 12},
    {"10 & 3", 2},
    {"10 | 3", 11},
    {"(1 + 2) * 3", 9},
    {"10 % 3", 1},
  ].each do |test_case|
    it "codegens enum with #{test_case[0]} " do
      run("
        lib Foo
          enum Bar
            X = #{test_case[0]}
          end
        end

        Foo::Bar::X
        ").to_i.should eq(test_case[1])
    end
  end

  it "codegens enum that refers to another enum constant" do
    run("
      lib Foo
        enum Bar
          A = 1
          B = A + 1
          C = B + 1
        end
      end

      Foo::Bar::C
      ").to_i.should eq(3)
  end

  it "codegens enum that refers to another constant" do
    run("
      lib Foo
        X = 10
        enum Bar
          A = X
          B = A + 1
          C = B + 1
        end
      end

      Foo::Bar::C
      ").to_i.should eq(12)
  end
end
