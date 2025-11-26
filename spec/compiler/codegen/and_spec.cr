require "../../spec_helper"

describe "Code gen: and" do
  it "codegens and with bool false and false" do
    run("false && false", Bool).should be_false
  end

  it "codegens and with bool false and true" do
    run("false && true", Bool).should be_false
  end

  it "codegens and with bool true and true" do
    run("true && true", Bool).should be_true
  end

  it "codegens and with bool true and false" do
    run("true && false", Bool).should be_false
  end

  it "codegens and with bool and int 1" do
    run("struct Bool; def to_i!; 0; end; end; (false && 2).to_i!", Int32).should eq(0)
  end

  it "codegens and with bool and int 2" do
    run("struct Bool; def to_i!; 0; end; end; (true && 2).to_i!", Int32).should eq(2)
  end

  it "codegens and with primitive type other than bool" do
    run("1 && 2", Int32).should eq(2)
  end

  it "codegens and with primitive type other than bool with union" do
    run("(1 && 1.5).to_f", Float64).should eq(1.5)
  end

  it "codegens and with primitive type other than bool" do
    run(<<-CRYSTAL, Int32).should eq(0)
      struct Nil; def to_i!; 0; end; end
      (nil && 2).to_i!
      CRYSTAL
  end

  it "codegens and with nilable as left node 1" do
    run(<<-CRYSTAL, Int32).should eq(0)
      struct Nil; def to_i!; 0; end; end
      class Object; def to_i!; -1; end; end
      a = Reference.new
      a = nil
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with nilable as left node 2" do
    run(<<-CRYSTAL, Int32).should eq(2)
      class Object; def to_i!; -1; end; end
      a = nil
      a = Reference.new
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with non-false union as left node" do
    run(<<-CRYSTAL, Int32).should eq(2)
      a = 1.5
      a = 1
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with nil union as left node 1" do
    run(<<-CRYSTAL, Int32).should eq(2)
      require "nil"
      a = nil
      a = 1
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with nil union as left node 2" do
    run(<<-CRYSTAL, Int32).should eq(0)
      struct Nil; def to_i!; 0; end; end
      a = 1
      a = nil
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 1" do
    run(<<-CRYSTAL, Int32).should eq(2)
      struct Bool; def to_i!; 0; end; end
      a = false
      a = 1
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 2" do
    run(<<-CRYSTAL, Int32).should eq(0)
      struct Bool; def to_i!; 0; end; end
      a = 1
      a = false
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 3" do
    run(<<-CRYSTAL, Int32).should eq(2)
      struct Bool; def to_i!; 0; end; end
      a = 1
      a = true
      (a && 2).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 1" do
    run(<<-CRYSTAL, Int32).should eq(3)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = false
      a = nil
      a = 2
      (a && 3).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 2" do
    run(<<-CRYSTAL, Int32).should eq(1)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = nil
      a = 2
      a = false
      (a && 3).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 3" do
    run(<<-CRYSTAL, Int32).should eq(3)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = nil
      a = 2
      a = true
      (a && 3).to_i!
      CRYSTAL
  end

  it "codegens and with bool union as left node 4" do
    run(<<-CRYSTAL, Int32).should eq(0)
      struct Nil; def to_i!; 0; end; end
      struct Bool; def to_i!; 1; end; end
      a = 2
      a = true
      a = nil
      (a && 3).to_i!
      CRYSTAL
  end

  it "codegens assign in right node, after must be nilable" do
    run(<<-CRYSTAL, Bool).should be_true
      a = 1 == 2 && (b = Reference.new)
      b.nil?
      CRYSTAL
  end

  it "codegens assign in right node, inside if must not be nil" do
    run(<<-CRYSTAL, Int32).should eq(1)
      struct Nil; end
      class Foo; def foo; 1; end; end

      if 1 == 1 && (b = Foo.new)
        b.foo
      else
        0
      end
      CRYSTAL
  end

  it "codegens assign in right node, after if must be nilable" do
    run(<<-CRYSTAL, Bool).should be_true
      if 1 == 2 && (b = Reference.new)
      end
      b.nil?
      CRYSTAL
  end
end
