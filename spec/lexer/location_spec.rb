require 'spec_helper'

describe 'Lexer: location' do
  context "line numbers" do
    it "stores line numbers" do
      lexer = Lexer.new "1\n2"
      token = lexer.next_token
      token.type.should eq(:NUMBER)
      token.line_number.should eq(1)

      token = lexer.next_token
      token.type.should eq(:NEWLINE)
      token.line_number.should eq(1)

      token = lexer.next_token
      token.type.should eq(:NUMBER)
      token.line_number.should eq(2)
    end
  end

  context "column numbers" do
    let(:lexer) { Lexer.new "1;  ident; def;\n4" }

    it "stores column numbers" do
      assert_token :NUMBER, 1
      assert_token :';', 2
      assert_token :SPACE, 3
      assert_token :IDENT, 5
      assert_token :';', 10
      assert_token :SPACE, 11
      assert_token :IDENT, 12
      assert_token :';', 15
      assert_token :NEWLINE, 16
      assert_token :NUMBER, 1
    end

    def assert_token(type, column_number)
      token = lexer.next_token
      token.type.should eq(type)
      token.column_number.should eq(column_number)
    end
  end
end
