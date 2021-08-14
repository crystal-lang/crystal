require "../../spec_helper"

describe "Semantic: hash" do
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
