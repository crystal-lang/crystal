require 'spec_helper'

describe 'Type inference: primitives' do
  it "types a bool" do
      assert_type('false') { bool }
    end

  it "types an int" do
    assert_type('1') { int32 }
  end

  it "types an i8" do
    assert_type('1_i8') { int8 }
  end

  it "types an i16" do
    assert_type('1_i16') { int16 }
  end

  it "types an i64" do
    assert_type('1_i64') { int64 }
  end

  it "types an u8" do
    assert_type('1_u8') { uint8 }
  end

  it "types an u16" do
    assert_type('1_u16') { uint16 }
  end

  it "types an u32" do
    assert_type('1_u32') { uint32 }
  end

  it "types an u64" do
    assert_type('1_u64') { uint64 }
  end

  it "types a float" do
    assert_type('2.3_f32') { float32 }
  end

  it "types a double" do
    assert_type('2.3') { float64 }
  end

  it "types a double with suffix" do
    assert_type('2.3_f64') { float64 }
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
    assert_type('class Int; def foo; 2.5; end; end; 1.foo') { float64 }
  end

  permutate_primitive_types do |type1, type2, suffix1, suffix2|
    ['+', '-', '*', '/'].each do |op|
      it "types #{type1} #{op} #{type2}", primitives: true do
        assert_type("1#{suffix1} #{op} 2#{suffix2}") { primitive_operation_type(type1, type2) }
      end
    end

    ['==', '>', '>=', '<', '<=', '!='].each do |op|
      it "types #{type1} #{op} #{type2}", primitives: true do
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
    assert_type("'a'.ord") { int32 }
  end

  it "types Int#to_i" do
    assert_type("1.to_i") { int32 }
  end

  it "types Int#to_f" do
    assert_type("1.to_f") { float64 }
  end

  it "types Int#<<" do
    assert_type("1 << 2") { int32 }
  end

  it "types Float#to_i" do
    assert_type("1.5f32.to_i") { int32 }
  end

  it "types Float#to_f" do
    assert_type("1.5f32.to_f") { float64 }
  end

  it "types ARGV" do
    assert_type(%q(require "argv"; ARGV)) { array_of(string) }
  end

  it "reports can't call primitive with args" do
    assert_error "1 + 'a'",
      "no overload matches"
  end

  it "reports can't use instance variables inside a Value" do
    assert_error "class Int32; def foo; @a = 1; end; end; 2.foo",
      "can't use instance variables inside Int"
  end
end
