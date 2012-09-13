require 'spec_helper'

describe 'Lexer: column numbers' do
  let(:lexer) { Lexer.new "1;  ident; def;\n4" }

  it "stores column numbers" do
    assert_token :INT, 1
    assert_token :';', 2
    assert_token :SPACE, 3
    assert_token :IDENT, 5
    assert_token :';', 10
    assert_token :SPACE, 11
    assert_token :IDENT, 12
    assert_token :';', 15
    assert_token :NEWLINE, 16
    assert_token :INT, 1
  end

  def assert_token(type, column_number)
    token = lexer.next_token
    token.type.should eq(type)
    token.column_number.should eq(column_number)
  end
end
