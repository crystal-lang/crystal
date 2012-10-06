require 'spec_helper'

describe 'Type inference: primitives' do
  it "types a bool" do
    assert_type('false') { bool }
  end

  it "types an int" do
    assert_type('1') { int }
  end

  it "types a float" do
    assert_type('2.3') { float }
  end

  it "types a char" do
    assert_type("'a'") { char }
  end

  it "types a string" do
    assert_type('"foo"') { string }
  end

  it "types a primitive method" do
    assert_type('class Int; def foo; 2.5; end; end; 1.foo') { float }
  end

  ['+', '-', '*', '/'].each do |op|
    it "types Int #{op} Int" do
      assert_type("1 #{op} 2") { int }
    end

    it "types Int #{op} Float" do
      assert_type("1 #{op} 2.0") { float }
    end

    it "types Float #{op} Int" do
      assert_type("1.0 #{op} 2") { float }
    end

    it "types Float #{op} Float" do
      assert_type("1.0 #{op} 2.0") { float }
    end
  end

  ['==', '>', '>=', '<', '<=', '!='].each do |op|
    it "types Int #{op} Int" do
      assert_type("1 #{op} 2") { bool }
    end

    it "types Int #{op} Float" do
      assert_type("1 #{op} 2.0") { bool }
    end

    it "types Float #{op} Int" do
      assert_type("1.0 #{op} 2") { bool }
    end

    it "types Float #{op} Float" do
      assert_type("1.0 #{op} 2.0") { bool }
    end

    it "types Char #{op} Char" do
      assert_type("'a' #{op} 'b'") { bool }
    end
  end

  it "types !Bool" do
    assert_type("!false") { bool }
  end

  it "types Bool && Bool" do
    assert_type("true && true") { bool }
  end

  it "types Bool || Bool" do
    assert_type("true || true") { bool }
  end

  it "types Int#chr" do
    assert_type("65.chr") { char }
  end

  it "types Char#ord" do
    assert_type("'a'.ord") { int }
  end

  it "types Int#to_i" do
    assert_type("1.to_i") { int }
  end

  it "types Int#to_f" do
    assert_type("1.to_f") { float }
  end

  it "types Float#to_i" do
    assert_type("1.5.to_i") { int }
  end

  it "types Float#to_f" do
    assert_type("1.5.to_f") { float }
  end
end