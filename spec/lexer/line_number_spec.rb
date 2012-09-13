require 'spec_helper'

describe 'Lexer: line numbers' do
  it "stores line numbers" do
    lexer = Lexer.new "1\n2"
    token = lexer.next_token
    token.type.should eq(:INT)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:NEWLINE)
    token.line_number.should eq(1)

    token = lexer.next_token
    token.type.should eq(:INT)
    token.line_number.should eq(2)
  end
end
