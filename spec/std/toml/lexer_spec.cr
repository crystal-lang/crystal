require "spec"
require "toml"

def it_lexes_toml(string, expected_type)
  it "lexes #{string}" do
    lexer = Toml::Lexer.new string
    token = lexer.next_token
    token.type.should eq(expected_type)
  end
end

describe "Toml::Lexer" do
  it_lexes_toml "", :EOF
  it_lexes_toml "[", :"["
  it_lexes_toml "]", :"]"
  it_lexes_toml ".", :"."
  it_lexes_toml "=", :"="
  it_lexes_toml ",", :","
end
