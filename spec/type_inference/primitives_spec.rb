require 'spec_helper'

describe 'Type inference: primitives' do
  it "types a bool" do
    assert_type('false') { bool }
  end

  it "types an int" do
    assert_type('1') { int }
  end

  it "types a long" do
    assert_type('1L') { long }
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

  it "types a symbol" do
    assert_type(":foo") { symbol }
  end

  it "types Symbol == Symbol" do
    assert_type(":foo == :bar") { bool }
  end

  it "types Symbol != Symbol" do
    assert_type(%q(require "object"; :foo != :bar)) { bool }
  end

  it "types a primitive method" do
    assert_type('class Int; def foo; 2.5; end; end; 1.foo') { float }
  end

  permutate_primitive_types do |type1, type2, suffix1, suffix2|
    ['+', '-', '*', '/'].each do |op|
      it "types #{type1} #{op} #{type2}" do
        assert_type("1#{suffix1} #{op} 2#{suffix2}") { primitive_operation_type(type1, type2) }
      end
    end

    ['==', '>', '>=', '<', '<=', '!='].each do |op|
      it "types #{type1} #{op} #{type2}" do
        assert_type("1#{suffix1} #{op} 2#{suffix2}") { bool }
      end
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

  it "types Int#<<" do
    assert_type("1 << 2") { int }
  end

  it "types Float#to_i" do
    assert_type("1.5.to_i") { int }
  end

  it "types Float#to_f" do
    assert_type("1.5.to_f") { float }
  end

  it "types ARGV" do
    assert_type(%q(require "argv"; ARGV)) { array_of(string) }
  end
end