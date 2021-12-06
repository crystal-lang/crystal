require "../../spec_helper"

describe "Semantic: hash" do
  it "types hash literal of int" do
    assert_type("require \"prelude\"; {1 => 2, 3 => 4, 5 => 6}") { hash_of(int32, int32) }
  end

  it "types hash literal of union" do
    assert_type("require \"prelude\"; {1 => 2.5, 'a' => \"foo\"}") { hash_of(union_of(int32, char), union_of(float64, string)) }
  end

  it "types empty typed hash literal of int32 => int32" do
    assert_type("require \"prelude\"; {} of Int32 => Int32") { hash_of(int32, int32) }
  end

  it "types non-empty typed hash literal of int" do
    assert_type("require \"prelude\"; {1 => 2, 3 => 4, 5 => 6} of Int32 => Int32") { hash_of(int32, int32) }
  end

  it "types non-empty typed hash literal of int, with autocast" do
    assert_type("require \"prelude\"; {1 => 2, 3 => 4, 5 => 6} of Int8 => Int64") { hash_of(int8, int64) }
  end

  it "types hash literal size correctly" do
    assert_type("require \"prelude\"; {1 => 2}.size") { int32 }
  end

  it "assignment in hash literal works" do
    assert_type("require \"prelude\"; {(a = 1) => (b = 2)}; {a, b}") { tuple_of [int32, int32] }
  end

  it "errors if typed hash literal has incorrect key element type" do
    ex = assert_error <<-CR,
      require "prelude"
      {1 => 'a', "" => 'b'} of Int32 => Char
      CR
      "key element of typed hash literal must be Int32, not String"

    ex.line_number.should eq(2)
    ex.column_number.should eq(12)
  end

  it "errors if typed hash literal has incorrect value element type" do
    ex = assert_error <<-CR,
      require "prelude"
      {'a' => 1, 'b' => ""} of Char => Int32
      CR
      "value element of typed hash literal must be Int32, not String"

    ex.line_number.should eq(2)
    ex.column_number.should eq(19)
  end
end
