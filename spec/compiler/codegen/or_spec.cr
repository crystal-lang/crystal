require "../../spec_helper"

describe "Code gen: or" do
  it "codegens or with bool false and false" do
    run("false || false").to_b.should be_false
  end

  it "codegens or with bool false and true" do
    run("false || true").to_b.should be_true
  end

  it "codegens or with bool true and true" do
    run("true || true").to_b.should be_true
  end

  it "codegens or with bool true and false" do
    run("true || false").to_b.should be_true
  end

  it "codegens or with bool and int 1" do
    run("struct Bool; def to_i!; 0; end; end; (false || 2).to_i!").to_i.should eq(2)
  end

  it "codegens or with bool and int 2" do
    run("struct Bool; def to_i!; 0; end; end; (true || 2).to_i!").to_i.should eq(0)
  end

  it "codegens or with primitive type other than bool" do
    run("1 || 2").to_i.should eq(1)
  end

  it "codegens or with primitive type other than bool with union" do
    run("(1 || 1.5).to_f").to_f64.should eq(1)
  end

  it "codegens or with primitive type other than bool" do
    run("require \"nil\"; (nil || 2).to_i!").to_i.should eq(2)
  end

  it "codegens or with nilable as left node 1" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "nil"
      class Object; def to_i!; -1; end; end
      a = Reference.new
      a = nil
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with nilable as left node 2" do
    run(<<-CRYSTAL).to_i.should eq(-1)
      class Object; def to_i!; -1; end; end
      a = nil
      a = Reference.new
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with non-false union as left node" do
    run(<<-CRYSTAL).to_i.should eq(1)
      a = 1.5
      a = 1
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with nil union as left node 1" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "nil"
      a = nil
      a = 1
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with nil union as left node 2" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "nil"
      a = 1
      a = nil
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 1" do
    run(<<-CRYSTAL).to_i.should eq(1)
      struct Bool; def to_i!; 0; end; end
      a = false
      a = 1
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 2" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct Bool; def to_i!; 0; end; end
      a = 1
      a = false
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 3" do
    run(<<-CRYSTAL).to_i.should eq(0)
      struct Bool; def to_i!; 0; end; end
      a = 1
      a = true
      (a || 2).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 1" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = false
      a = nil
      a = 2
      (a || 3).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 2" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = nil
      a = 2
      a = false
      (a || 3).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 3" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = nil
      a = 2
      a = true
      (a || 3).to_i!
      CRYSTAL
  end

  it "codegens or with bool union as left node 4" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "nil"
      struct Bool; def to_i!; 1; end; end
      a = 2
      a = true
      a = nil
      (a || 3).to_i!
      CRYSTAL
  end
end
