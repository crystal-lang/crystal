require "../../spec_helper"

describe "Code gen: and" do
  it "codegens and with bool false and false" do
    expect(run("false && false").to_b).to be_false
  end

  it "codegens and with bool false and true" do
    expect(run("false && true").to_b).to be_false
  end

  it "codegens and with bool true and true" do
    expect(run("true && true").to_b).to be_true
  end

  it "codegens and with bool true and false" do
    expect(run("true && false").to_b).to be_false
  end

  it "codegens and with bool and int 1" do
    expect(run("struct Bool; def to_i; 0; end; end; (false && 2).to_i").to_i).to eq(0)
  end

  it "codegens and with bool and int 2" do
    expect(run("struct Bool; def to_i; 0; end; end; (true && 2).to_i").to_i).to eq(2)
  end

  it "codegens and with primitive type other than bool" do
    expect(run("1 && 2").to_i).to eq(2)
  end

  it "codegens and with primitive type other than bool with union" do
    expect(run("(1 && 1.5).to_f").to_f64).to eq(1.5)
  end

  it "codegens and with primitive type other than bool" do
    expect(run("require \"nil\"; (nil && 2).to_i").to_i).to eq(0)
  end

  it "codegens and with nilable as left node 1" do
    expect(run("
      require \"nil\"
      class Object; def to_i; -1; end; end
      a = Reference.new
      a = nil
      (a && 2).to_i
    ").to_i).to eq(0)
  end

  it "codegens and with nilable as left node 2" do
    expect(run("
      class Object; def to_i; -1; end; end
      a = nil
      a = Reference.new
      (a && 2).to_i
    ").to_i).to eq(2)
  end

  it "codegens and with non-false union as left node" do
    expect(run("
      a = 1.5
      a = 1
      (a && 2).to_i
    ").to_i).to eq(2)
  end

  it "codegens and with nil union as left node 1" do
    expect(run("
      require \"nil\"
      a = nil
      a = 1
      (a && 2).to_i
    ").to_i).to eq(2)
  end

  it "codegens and with nil union as left node 2" do
    expect(run("
      require \"nil\"
      a = 1
      a = nil
      (a && 2).to_i
    ").to_i).to eq(0)
  end

  it "codegens and with bool union as left node 1" do
    expect(run("
      struct Bool; def to_i; 0; end; end
      a = false
      a = 1
      (a && 2).to_i
    ").to_i).to eq(2)
  end

  it "codegens and with bool union as left node 2" do
    expect(run("
      struct Bool; def to_i; 0; end; end
      a = 1
      a = false
      (a && 2).to_i
    ").to_i).to eq(0)
  end

  it "codegens and with bool union as left node 3" do
    expect(run("
      struct Bool; def to_i; 0; end; end
      a = 1
      a = true
      (a && 2).to_i
    ").to_i).to eq(2)
  end

  it "codegens and with bool union as left node 1" do
    expect(run("
      require \"nil\"
      struct Bool; def to_i; 1; end; end
      a = false
      a = nil
      a = 2
      (a && 3).to_i
    ").to_i).to eq(3)
  end

  it "codegens and with bool union as left node 2" do
    expect(run("
      require \"nil\"
      struct Bool; def to_i; 1; end; end
      a = nil
      a = 2
      a = false
      (a && 3).to_i
    ").to_i).to eq(1)
  end

  it "codegens and with bool union as left node 3" do
    expect(run("
      require \"nil\"
      struct Bool; def to_i; 1; end; end
      a = nil
      a = 2
      a = true
      (a && 3).to_i
    ").to_i).to eq(3)
  end

  it "codegens and with bool union as left node 4" do
    expect(run("
      require \"nil\"
      struct Bool; def to_i; 1; end; end
      a = 2
      a = true
      a = nil
      (a && 3).to_i
    ").to_i).to eq(0)
  end

  it "codegens assign in right node, after must be nilable" do
    expect(run("
      struct Nil; def nil?; true; end; end
      class Reference; def nil?; false; end; end

      a = 1 == 2 && (b = Reference.new)
      b.nil?
      ").to_b).to be_true
  end

  it "codegens assign in right node, inside if must not be nil" do
    expect(run("
      struct Nil; end
      class Foo; def foo; 1; end; end

      if 1 == 1 && (b = Foo.new)
        b.foo
      else
        0
      end
      ").to_i).to eq(1)
  end

  it "codegens assign in right node, after if must be nilable" do
    expect(run("
      struct Nil; def nil?; true; end; end
      class Reference; def nil?; false; end; end

      if 1 == 2 && (b = Reference.new)
      end
      b.nil?
      ").to_b).to be_true
  end
end
