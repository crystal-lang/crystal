require "../../support/syntax"

private def t(kind : Crystal::Token::Kind)
  kind
end

private def it_lexes(string, type : Token::Kind, *, slash_is_regex : Bool? = nil)
  it "lexes #{string.inspect}" do
    lexer = Lexer.new string
    unless (v = slash_is_regex).nil?
      lexer.slash_is_regex = v
    end
    token = lexer.next_token
    token.type.should eq(type)
  end
end

private def it_lexes(string, type : Token::Kind, value)
  it "lexes #{string.inspect}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
    token.value.should eq(value)
  end
end

private def it_lexes(string, type : Token::Kind, value, number_kind : NumberKind)
  it "lexes #{string.inspect}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(type)
    token.value.should eq(value)
    token.number_kind.should eq(number_kind)
  end
end

private def it_lexes_many(values, type : Token::Kind)
  values.each do |value|
    it_lexes value, type, value
  end
end

private def it_lexes_keywords(*keywords : Keyword)
  keywords.each do |keyword|
    it_lexes keyword.to_s, :IDENT, keyword
  end
end

private def it_lexes_idents(idents)
  idents.each do |ident|
    it_lexes ident, :IDENT, ident
  end
end

private def it_lexes_i32(values)
  values.each { |value| it_lexes_number :i32, value }
end

private def it_lexes_i64(values)
  values.each { |value| it_lexes_number :i64, value }
end

private def it_lexes_i128(values)
  values.each { |value| it_lexes_number :i128, value }
end

private def it_lexes_u64(values)
  values.each { |value| it_lexes_number :u64, value }
end

private def it_lexes_f32(values)
  values.each { |value| it_lexes_number :f32, value }
end

private def it_lexes_f64(values)
  values.each { |value| it_lexes_number :f64, value }
end

private def it_lexes_number(number_kind : NumberKind, value : Array)
  it_lexes value[0], :NUMBER, value[1], number_kind
end

private def it_lexes_number(number_kind : NumberKind, value : String)
  it_lexes value, :NUMBER, value, number_kind
end

private def it_lexes_char(string, value)
  it "lexes #{string}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).should eq(value)
  end
end

private def it_lexes_string(string, value)
  it "lexes #{string}" do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(t :DELIMITER_START)

    token = lexer.next_string_token(token.delimiter_state)
    token.value.should eq(value)
  end
end

private def it_lexes_operators(ops)
  ops.each do |op|
    it "lexes #{op.inspect}" do
      lexer = Lexer.new op
      lexer.slash_is_regex = false
      token = lexer.next_token
      token.type.operator?.should be_true
      token.type.to_s.should eq(op)
    end
  end
end

private def it_lexes_const(value)
  it_lexes value, :CONST, value
end

private def it_lexes_instance_var(value)
  it_lexes value, :INSTANCE_VAR, value
end

private def it_lexes_class_var(value)
  it_lexes value, :CLASS_VAR, value
end

private def it_lexes_globals(globals)
  it_lexes_many globals, :GLOBAL
end

private def it_lexes_symbols(symbols)
  symbols.each do |symbol|
    value = symbol[1, symbol.size - 1]
    value = value[1, value.size - 2] if value.starts_with?('"')
    it_lexes symbol, :SYMBOL, value
  end
end

private def it_lexes_global_match_data_index(globals)
  globals.each do |global|
    it_lexes global, :GLOBAL_MATCH_DATA_INDEX, global[1, global.size - 1]
  end
end

describe "Lexer" do
  it_lexes "", :EOF
  it_lexes " ", :SPACE
  it_lexes "\t", :SPACE
  it_lexes "\n", :NEWLINE
  it_lexes "\n\n\n", :NEWLINE
  it_lexes "_", :UNDERSCORE
  it_lexes_keywords :def, :if, :else, :elsif, :end, :true, :false, :class, :module, :include,
    :extend, :while, :until, :nil, :do, :yield, :return, :unless, :next, :break,
    :begin, :lib, :fun, :type, :struct, :union, :enum, :macro, :out, :require,
    :case, :when, :select, :then, :of, :abstract, :rescue, :ensure, :alias,
    :pointerof, :sizeof, :instance_sizeof, :offsetof, :as, :typeof, :for, :in,
    :with, :self, :super, :private, :protected, :asm, :uninitialized,
    :annotation, :verbatim, :is_a_question, :as_question, :nil_question, :responds_to_question
  it_lexes_idents ["ident", "something", "with_underscores", "with_1", "foo?", "bar!", "fooBar",
                   "❨╯°□°❩╯︵┻━┻"]
  it_lexes_idents ["def?", "if?", "else?", "elsif?", "end?", "true?", "false?", "class?", "while?",
                   "do?", "yield?", "return?", "unless?", "next?", "break?", "begin?"]
  it_lexes_idents ["def!", "if!", "else!", "elsif!", "end!", "true!", "false!", "class!", "while!",
                   "nil!", "do!", "yield!", "return!", "unless!", "next!", "break!", "begin!"]
  it_lexes_i32 ["1", ["0i32", "0"], ["1hello", "1"], "+1", "-1", "1234", "+1234", "-1234",
                ["1.foo", "1"], ["1_000", "1000"], ["100_000", "100000"]]
  it_lexes_i64 [["1i64", "1"], ["1_i64", "1"], ["1i64hello", "1"], ["+1_i64", "+1"], ["-1_i64", "-1"]]
  it_lexes_i128 [["1i128", "1"], ["1_i128", "1"], ["1i128hello", "1"], ["+1_i128", "+1"], ["-1_i128", "-1"]]
  it_lexes_f32 [["0f32", "0"], ["0_f32", "0"], ["1.0f32", "1.0"], ["1.0f32hello", "1.0"],
                ["+1.0f32", "+1.0"], ["-1.0f32", "-1.0"], ["-0.0f32", "-0.0"], ["1_234.567_890_f32", "1234.567890"]]
  it_lexes_f64 ["1.0", ["1.0hello", "1.0"], "+1.0", "-1.0", ["1_234.567_890", "1234.567890"]]
  it_lexes_f32 [["1e+23_f32", "1e+23"], ["1.2e+23_f32", "1.2e+23"]]
  it_lexes_f64 ["1e23", "1e-23", "1e+23", "1.2e+23", ["1e23f64", "1e23"], ["1.2e+23_f64", "1.2e+23"], "0e40", "2e01", ["2_e2", "2e2"], "1E40"]

  it_lexes_number :i8, ["1i8", "1"]
  it_lexes_number :i8, ["1_i8", "1"]

  it_lexes_number :i16, ["1i16", "1"]
  it_lexes_number :i16, ["1_i16", "1"]

  it_lexes_number :i32, ["1i32", "1"]
  it_lexes_number :i32, ["1_i32", "1"]

  it_lexes_number :i64, ["1i64", "1"]
  it_lexes_number :i64, ["1_i64", "1"]

  it_lexes_number :u8, ["1u8", "1"]
  it_lexes_number :u8, ["1_u8", "1"]

  it_lexes_number :u16, ["1u16", "1"]
  it_lexes_number :u16, ["1_u16", "1"]

  it_lexes_number :u32, ["1u32", "1"]
  it_lexes_number :u32, ["1_u32", "1"]

  it_lexes_number :u64, ["1u64", "1"]
  it_lexes_number :u64, ["1_u64", "1"]

  it_lexes_number :u128, ["1u128", "1"]
  it_lexes_number :u128, ["1_u128", "1"]

  it_lexes_number :f32, ["1f32", "1"]
  it_lexes_number :f32, ["1.0f32", "1.0"]

  it_lexes_number :f64, ["1f64", "1"]
  it_lexes_number :f64, ["1.0f64", "1.0"]

  it_lexes_number :i32, ["0b1010", "10"]
  it_lexes_number :i32, ["+0b1010", "+10"]
  it_lexes_number :i32, ["-0b1010", "-10"]

  it_lexes_number :i32, ["0xFFFF", "65535"]
  it_lexes_number :i32, ["0xabcdef", "11259375"]
  it_lexes_number :i32, ["+0xFFFF", "+65535"]
  it_lexes_number :i32, ["-0xFFFF", "-65535"]

  it_lexes_number :i64, ["0x80000001", "2147483649"]
  it_lexes_number :i64, ["-0x80000001", "-2147483649"]
  it_lexes_number :i64, ["0xFFFFFFFF", "4294967295"]
  it_lexes_number :i64, ["-0xFFFFFFFF", "-4294967295"]

  it_lexes_number :u64, ["0xFFFF_u64", "65535"]

  it_lexes_i32 [["0o123", "83"], ["-0o123", "-83"], ["+0o123", "+83"]]
  it_lexes_f64 [["0.5", "0.5"], ["+0.5", "+0.5"], ["-0.5", "-0.5"]]
  it_lexes_i64 [["0o123_i64", "83"], ["0x1_i64", "1"], ["0b1_i64", "1"]]

  it_lexes_i64 ["2147483648", "-2147483649"]
  it_lexes_i64 [["2147483648.foo", "2147483648"]]
  it_lexes_u64 ["18446744073709551615", "14146167139683460000", "9223372036854775808"]
  it_lexes_number :u64, ["10000000000000000000_u64", "10000000000000000000"]

  it_lexes_i64 [["0x3fffffffffffffff", "4611686018427387903"]]
  it_lexes_i64 [["-0x8000000000000000_i64", "-9223372036854775808"]]
  it_lexes_i64 ["-9223372036854775808", "9223372036854775807"]
  it_lexes_u64 [["0xffffffffffffffff", "18446744073709551615"]]

  it_lexes_number :i32, ["+0", "+0"]
  it_lexes_number :i32, ["-0", "-0"]

  it_lexes_number :i32, ["0", "0"]
  it_lexes_number :i32, ["0_i32", "0"]
  it_lexes_number :i8, ["0i8", "0"]

  it_lexes_i32 [["0🔮", "0"], ["12341234🔮", "12341234"], ["0x3🔮", "3"]]
  assert_syntax_error "0b🔮", "numeric literal without digits"

  it_lexes_char "'a'", 'a'
  it_lexes_char "'\\a'", '\a'
  it_lexes_char "'\\b'", '\b'
  it_lexes_char "'\\n'", '\n'
  it_lexes_char "'\\t'", '\t'
  it_lexes_char "'\\v'", '\v'
  it_lexes_char "'\\f'", '\f'
  it_lexes_char "'\\r'", '\r'
  it_lexes_char "'\\0'", '\0'
  it_lexes_char "'\\0'", '\0'
  it_lexes_char "'\\''", '\''
  it_lexes_char "'\\\\'", '\\'
  assert_syntax_error "'", "unterminated char literal"
  assert_syntax_error "'\\", "unterminated char literal"
  it_lexes_operators ["=", "<", "<=", ">", ">=", "+", "-", "*", "/", "//", "(", ")",
                      "==", "!=", "=~", "!", ",", ".", "..", "...", "&&", "||",
                      "|", "{", "}", "?", ":", "+=", "-=", "*=", "/=", "%=", "//=", "&=",
                      "|=", "^=", "**=", "<<", ">>", "%", "&", "|", "^", "**", "<<=",
                      ">>=", "~", "[]", "[]=", "[", "]", "::", "<=>", "=>", "||=",
                      "&&=", "===", ";", "->", "[]?", "{%", "{{", "%}", "@[", "!~",
                      "&+", "&-", "&*", "&**", "&+=", "&-=", "&*="]
  it_lexes "!@foo", :OP_BANG
  it_lexes "+@foo", :OP_PLUS
  it_lexes "-@foo", :OP_MINUS
  it_lexes "&+@foo", :OP_AMP_PLUS
  it_lexes "&-@foo", :OP_AMP_MINUS
  it_lexes_const "Foo"
  it_lexes_const "ÁrvíztűrőTükörfúrógép"
  it_lexes_const "ǅǈǋǲᾈᾉᾊ"
  it_lexes_instance_var "@foo"
  it_lexes_class_var "@@foo"
  it_lexes_globals ["$foo", "$FOO", "$_foo", "$foo123"]
  it_lexes_symbols [":foo", ":foo!", ":foo?", ":foo=", ":\"foo\"", ":かたな", ":+", ":-", ":*", ":/", "://",
                    ":==", ":<", ":<=", ":>", ":>=", ":!", ":!=", ":=~", ":!~", ":&", ":|",
                    ":^", ":~", ":**", ":>>", ":<<", ":%", ":[]", ":[]?", ":[]=", ":<=>", ":===",
                    ":&+", ":&-", ":&*", ":&**"]

  it_lexes_global_match_data_index ["$1", "$10", "$1?", "$10?", "$23?"]
  assert_syntax_error "$01", %(unexpected token: "1")
  assert_syntax_error "$0?"

  it_lexes "$~", :OP_DOLLAR_TILDE
  it_lexes "$?", :OP_DOLLAR_QUESTION

  assert_syntax_error "128_i8", "128 doesn't fit in an Int8"
  assert_syntax_error "-129_i8", "-129 doesn't fit in an Int8"
  assert_syntax_error "256_u8", "256 doesn't fit in an UInt8"
  assert_syntax_error "-1_u8", "Invalid negative value -1 for UInt8"

  assert_syntax_error "32768_i16", "32768 doesn't fit in an Int16"
  assert_syntax_error "-32769_i16", "-32769 doesn't fit in an Int16"
  assert_syntax_error "65536_u16", "65536 doesn't fit in an UInt16"
  assert_syntax_error "-1_u16", "Invalid negative value -1 for UInt16"

  assert_syntax_error "2147483648_i32", "2147483648 doesn't fit in an Int32"
  assert_syntax_error "-2147483649_i32", "-2147483649 doesn't fit in an Int32"
  assert_syntax_error "4294967296_u32", "4294967296 doesn't fit in an UInt32"
  assert_syntax_error "-1_u32", "Invalid negative value -1 for UInt32"

  assert_syntax_error "9223372036854775808_i64", "9223372036854775808 doesn't fit in an Int64"
  assert_syntax_error "-9223372036854775809_i64", "-9223372036854775809 doesn't fit in an Int64"
  assert_syntax_error "118446744073709551616_u64", "118446744073709551616 doesn't fit in an UInt64"
  assert_syntax_error "18446744073709551616_u64", "18446744073709551616 doesn't fit in an UInt64"
  assert_syntax_error "-1_u64", "Invalid negative value -1 for UInt64"
  assert_syntax_error "-0_u64", "Invalid negative value -0 for UInt64"
  assert_syntax_error "-0u64", "Invalid negative value -0 for UInt64"

  assert_syntax_error "18446744073709551616_i32", "18446744073709551616 doesn't fit in an Int32"
  assert_syntax_error "9999999999999999999_i32", "9999999999999999999 doesn't fit in an Int32"

  assert_syntax_error "-9999999999999999999", "-9999999999999999999 doesn't fit in an Int64, try using the suffix i128"
  assert_syntax_error "-99999999999999999999", "-99999999999999999999 doesn't fit in an Int64, try using the suffix i128"
  assert_syntax_error "-11111111111111111111", "-11111111111111111111 doesn't fit in an Int64, try using the suffix i128"
  assert_syntax_error "-9223372036854775809", "-9223372036854775809 doesn't fit in an Int64, try using the suffix i128"
  assert_syntax_error "118446744073709551616", "118446744073709551616 doesn't fit in an UInt64, try using the suffix i128"
  assert_syntax_error "18446744073709551616", "18446744073709551616 doesn't fit in an UInt64, try using the suffix i128"

  assert_syntax_error "340282366920938463463374607431768211456", "340282366920938463463374607431768211456 doesn't fit in an UInt64"
  assert_syntax_error "-170141183460469231731687303715884105729", "-170141183460469231731687303715884105729 doesn't fit in an Int64"
  assert_syntax_error "-999999999999999999999999999999999999999", "-999999999999999999999999999999999999999 doesn't fit in an Int64"

  assert_syntax_error "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF doesn't fit in an UInt64"
  assert_syntax_error "0o7777777777777777777777777777777777777777777777777", "0o7777777777777777777777777777777777777777777777777 doesn't fit in an UInt64"
  assert_syntax_error "-0o7777777777777777777777777777777777777777777777777", "-0o7777777777777777777777777777777777777777777777777 doesn't fit in an Int64"

  it_lexes_number :i128, ["9223372036854775808_i128", "9223372036854775808"]
  it_lexes_number :i128, ["-9223372036854775809_i128", "-9223372036854775809"]
  it_lexes_number :u128, ["118446744073709551616_u128", "118446744073709551616"]
  it_lexes_number :u128, ["18446744073709551616_u128", "18446744073709551616"]
  it_lexes_number :i128, ["170141183460469231731687303715884105727_i128", "170141183460469231731687303715884105727"]
  it_lexes_number :u128, ["170141183460469231731687303715884105728_u128", "170141183460469231731687303715884105728"]
  it_lexes_number :u128, ["340282366920938463463374607431768211455_u128", "340282366920938463463374607431768211455"]
  it_lexes_number :u128, ["0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128", "340282366920938463463374607431768211455"]
  it_lexes_number :i128, ["-0x80000000000000000000000000000000_i128", "-170141183460469231731687303715884105728"]
  assert_syntax_error "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF doesn't fit in an UInt64, try using the suffix u128"
  assert_syntax_error "-0x80000000000000000000000000000000", "-0x80000000000000000000000000000000 doesn't fit in an Int64, try using the suffix i128"
  assert_syntax_error "-0x80000000000000000000000000000001", "-0x80000000000000000000000000000001 doesn't fit in an Int64"
  assert_syntax_error "-1_u128", "Invalid negative value -1 for UInt128"

  assert_syntax_error "1__1", "consecutive underscores in numbers aren't allowed"
  assert_syntax_error "-3_", "trailing '_' in number"
  assert_syntax_error "0b_10", "unexpected '_' in number"
  assert_syntax_error "10e_10", "unexpected '_' in number"
  assert_syntax_error "1_.1", "unexpected '_' in number"
  assert_syntax_error "-0e_12", "unexpected '_' in number"

  assert_syntax_error "0_12", "octal constants should be prefixed with 0o"
  assert_syntax_error "0123", "octal constants should be prefixed with 0o"
  assert_syntax_error "00", "octal constants should be prefixed with 0o"
  assert_syntax_error "01_i64", "octal constants should be prefixed with 0o"

  assert_syntax_error "0xFF_i8", "0xFF doesn't fit in an Int8"
  assert_syntax_error "0o200_i8", "0o200 doesn't fit in an Int8"
  assert_syntax_error "0b10000000_i8", "0b10000000 doesn't fit in an Int8"

  assert_syntax_error "0b11_f32", "binary float literal is not supported"
  assert_syntax_error "0o73_f64", "octal float literal is not supported"

  # 2**31 - 1
  it_lexes_i32 [["0x7fffffff", "2147483647"], ["0o17777777777", "2147483647"], ["0b1111111111111111111111111111111", "2147483647"]]
  it_lexes_i32 [["0x7fffffff_i32", "2147483647"], ["0o17777777777_i32", "2147483647"], ["0b1111111111111111111111111111111_i32", "2147483647"]]
  # 2**32 - 1
  it_lexes_i64 [["0xffffffff", "4294967295"], ["0o37777777777", "4294967295"], ["0b11111111111111111111111111111111", "4294967295"]]
  # 2**32
  it_lexes_i64 [["0x100000000", "4294967296"], ["0o40000000000", "4294967296"], ["0b100000000000000000000000000000000", "4294967296"]]
  assert_syntax_error "0x100000000i32", "0x100000000 doesn't fit in an Int32"
  assert_syntax_error "0o40000000000i32", "0o40000000000 doesn't fit in an Int32"
  assert_syntax_error "0b100000000000000000000000000000000i32", "0b100000000000000000000000000000000 doesn't fit in an Int32"
  # 2**63 - 1
  it_lexes_i64 [["0x7fffffffffffffff", "9223372036854775807"], ["0o777777777777777777777", "9223372036854775807"], ["0b111111111111111111111111111111111111111111111111111111111111111", "9223372036854775807"]]
  # 2**63
  it_lexes_u64 [["0x8000000000000000", "9223372036854775808"], ["0o1000000000000000000000", "9223372036854775808"], ["0b1000000000000000000000000000000000000000000000000000000000000000", "9223372036854775808"]]
  assert_syntax_error "0x8000000000000000i64", "0x8000000000000000 doesn't fit in an Int64"
  assert_syntax_error "0o1000000000000000000000i64", "0o1000000000000000000000 doesn't fit in an Int64"
  assert_syntax_error "0b1000000000000000000000000000000000000000000000000000000000000000i64", "0b1000000000000000000000000000000000000000000000000000000000000000 doesn't fit in an Int64"
  # 2**64 - 1
  it_lexes_u64 [["0xffff_ffff_ffff_ffff", "18446744073709551615"], ["0o177777_77777777_77777777", "18446744073709551615"], ["0b11111111_11111111_11111111_11111111_11111111_11111111_11111111_11111111", "18446744073709551615"]]
  it_lexes_u64 [["0x00ffffffffffffffff", "18446744073709551615"], ["0o001777777777777777777777", "18446744073709551615"], ["0b001111111111111111111111111111111111111111111111111111111111111111", "18446744073709551615"]]
  # 2**64
  assert_syntax_error "0x10000_0000_0000_0000", "0x10000_0000_0000_0000 doesn't fit in an UInt64, try using the suffix i128"
  it_lexes_number :i128, ["0x10000_0000_0000_0000_i128", "18446744073709551616"]
  assert_syntax_error "0x10000_0000_0000_0000_u64", "0x10000_0000_0000_0000 doesn't fit in an UInt64"
  assert_syntax_error "0xfffffffffffffffff_u64", "0xfffffffffffffffff doesn't fit in an UInt64"
  assert_syntax_error "0o200000_00000000_00000000_u64", "0o200000_00000000_00000000 doesn't fit in an UInt64"
  assert_syntax_error "0o200000_00000000_00000000", "0o200000_00000000_00000000 doesn't fit in an UInt64, try using the suffix i128"
  assert_syntax_error "0b100000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_u64", "0b100000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000 doesn't fit in an UInt64"
  assert_syntax_error "0b100000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000", "0b100000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000 doesn't fit in an UInt64, try using the suffix i128"
  # Very large
  assert_syntax_error "0x1afafafafafafafafafafaf", "0x1afafafafafafafafafafaf doesn't fit in an UInt64, try using the suffix i128"
  assert_syntax_error "0x1afafafafafafafafafafafu64", "0x1afafafafafafafafafafaf doesn't fit in an UInt64"
  assert_syntax_error "0x1afafafafafafafafafafafi32", "0x1afafafafafafafafafafaf doesn't fit in an Int32"
  assert_syntax_error "0o1234567123456712345671234567u64", "0o1234567123456712345671234567 doesn't fit in an UInt64"
  assert_syntax_error "0o1234567123456712345671234567", "0o1234567123456712345671234567 doesn't fit in an UInt64, try using the suffix i128"
  assert_syntax_error "0o12345671234567_12345671234567_i8", "0o12345671234567_12345671234567 doesn't fit in an Int8"
  assert_syntax_error "0b100000000000000000000000000000000000000000000000000000000000000000", "0b100000000000000000000000000000000000000000000000000000000000000000 doesn't fit in an UInt64, try using the suffix i128"
  assert_syntax_error "0b100000000000000000000000000000000000000000000000000000000000000000u64", "0b100000000000000000000000000000000000000000000000000000000000000000 doesn't fit in an UInt64"

  it_lexes_i64 [["0o700000000000000000000", "8070450532247928832"]]
  it_lexes_u64 [["0o1000000000000000000000", "9223372036854775808"]]

  assert_syntax_error "4f33", "invalid float suffix"
  assert_syntax_error "4f65", "invalid float suffix"
  assert_syntax_error "4f22", "invalid float suffix"
  assert_syntax_error "4i33", "invalid int suffix"
  assert_syntax_error "4i65", "invalid int suffix"
  assert_syntax_error "4i22", "invalid int suffix"
  assert_syntax_error "4i3", "invalid int suffix"
  assert_syntax_error "4i12", "invalid int suffix"
  assert_syntax_error "4u33", "invalid uint suffix"
  assert_syntax_error "4u65", "invalid uint suffix"
  assert_syntax_error "4u22", "invalid uint suffix"
  assert_syntax_error "4u3", "invalid uint suffix"
  assert_syntax_error "4u12", "invalid uint suffix"
  # Tests for #8782
  assert_syntax_error "4F32", %(unexpected token: "F32")
  assert_syntax_error "4F64", %(unexpected token: "F64")
  assert_syntax_error "0F32", %(unexpected token: "F32")

  assert_syntax_error "4.0_u32", "Invalid suffix u32 for decimal number"
  assert_syntax_error "2e8i8", "Invalid suffix i8 for decimal number"

  assert_syntax_error ".42", ".1 style number literal is not supported, put 0 before dot"
  assert_syntax_error "-.42", ".1 style number literal is not supported, put 0 before dot"

  assert_syntax_error "2e", "invalid decimal number exponent"
  assert_syntax_error "2e+", "invalid decimal number exponent"
  assert_syntax_error "2ef32", "invalid decimal number exponent"
  assert_syntax_error "2e+@foo", "invalid decimal number exponent"
  assert_syntax_error "2e+e", "invalid decimal number exponent"
  assert_syntax_error "2e+f32", "invalid decimal number exponent"
  assert_syntax_error "2e+-2", "invalid decimal number exponent"
  assert_syntax_error "2e+_2", "unexpected '_' in number"

  # Test for #11671
  it_lexes_i32 [["0b0_1", "1"]]

  it "lexes not instance var" do
    lexer = Lexer.new "!@foo"
    token = lexer.next_token
    token.type.should eq(t :OP_BANG)
    token = lexer.next_token
    token.type.should eq(t :INSTANCE_VAR)
    token.value.should eq("@foo")
  end

  it "lexes space after keyword" do
    lexer = Lexer.new "end 1"
    token = lexer.next_token
    token.type.should eq(t :IDENT)
    token.value.should eq(Keyword::END)
    token = lexer.next_token
    token.type.should eq(t :SPACE)
  end

  it "lexes space after char" do
    lexer = Lexer.new "'a' "
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.should eq('a')
    token = lexer.next_token
    token.type.should eq(t :SPACE)
  end

  it "lexes comment and token" do
    lexer = Lexer.new "# comment\n="
    token = lexer.next_token
    token.type.should eq(t :NEWLINE)
    token = lexer.next_token
    token.type.should eq(t :OP_EQ)
  end

  it "lexes comment at the end" do
    lexer = Lexer.new "# comment"
    token = lexer.next_token
    token.type.should eq(t :EOF)
  end

  it "lexes __LINE__" do
    lexer = Lexer.new "__LINE__"
    token = lexer.next_token
    token.type.should eq(t :MAGIC_LINE)
  end

  it "lexes __FILE__" do
    lexer = Lexer.new "__FILE__"
    lexer.filename = "foo"
    token = lexer.next_token
    token.type.should eq(t :MAGIC_FILE)
  end

  it "lexes __DIR__" do
    lexer = Lexer.new "__DIR__"
    token = lexer.next_token
    token.type.should eq(t :MAGIC_DIR)
  end

  it "lexes dot and ident" do
    lexer = Lexer.new ".read"
    token = lexer.next_token
    token.type.should eq(t :OP_PERIOD)
    token = lexer.next_token
    token.type.should eq(t :IDENT)
    token.value.should eq("read")
    token = lexer.next_token
    token.type.should eq(t :EOF)
  end

  assert_syntax_error "/foo", "Unterminated regular expression"
  assert_syntax_error "/\\", "Unterminated regular expression"
  assert_syntax_error ":\"foo", "unterminated quoted symbol"

  it "lexes utf-8 char" do
    lexer = Lexer.new "'á'"
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).ord.should eq(225)
  end

  it "lexes utf-8 multibyte char" do
    lexer = Lexer.new "'日'"
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).ord.should eq(26085)
  end

  it "doesn't raise if slash r with slash n" do
    lexer = Lexer.new("\r\n1")
    token = lexer.next_token
    token.type.should eq(t :NEWLINE)
    token = lexer.next_token
    token.type.should eq(t :NUMBER)
  end

  it "doesn't raise if many slash r with slash n" do
    lexer = Lexer.new("\r\n\r\n\r\n1")
    token = lexer.next_token
    token.type.should eq(t :NEWLINE)
    token = lexer.next_token
    token.type.should eq(t :NUMBER)
  end

  assert_syntax_error "\r1", "expected '\\n' after '\\r'"

  it "lexes char with unicode codepoint" do
    lexer = Lexer.new "'\\uFEDA'"
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).ord.should eq(0xFEDA)
  end

  it "lexes char with unicode codepoint and curly with zeros" do
    lexer = Lexer.new "'\\u{0}'"
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).ord.should eq(0)
  end

  it "lexes char with unicode codepoint and curly" do
    lexer = Lexer.new "'\\u{A5}'"
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).ord.should eq(0xA5)
  end

  it "lexes char with unicode codepoint and curly with six hex digits" do
    lexer = Lexer.new "'\\u{10FFFF}'"
    token = lexer.next_token
    token.type.should eq(t :CHAR)
    token.value.as(Char).ord.should eq(0x10FFFF)
  end

  it "lexes float then zero (bug)" do
    lexer = Lexer.new "2.5 0"
    lexer.next_token.number_kind.should eq(NumberKind::F64)
    lexer.next_token.type.should eq(t :SPACE)
    token = lexer.next_token
    token.type.should eq(t :NUMBER)
    token.number_kind.should eq(NumberKind::I32)
  end

  it "lexes symbol with quote" do
    lexer = Lexer.new %(:"\\"")
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("\"")
  end

  it "lexes symbol with backslash (#2187)" do
    lexer = Lexer.new %(:"\\\\")
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("\\")
  end

  it "lexes symbol followed by !=" do
    lexer = Lexer.new ":a!=:a"
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("a")
    token = lexer.next_token
    token.type.should eq(t :OP_BANG_EQ)
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("a")
  end

  it "lexes symbol followed by ==" do
    lexer = Lexer.new ":a==:a"
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("a")
    token = lexer.next_token
    token.type.should eq(t :OP_EQ_EQ)
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("a")
  end

  it "lexes symbol followed by ===" do
    lexer = Lexer.new ":a===:a"
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("a")
    token = lexer.next_token
    token.type.should eq(t :OP_EQ_EQ_EQ)
    token = lexer.next_token
    token.type.should eq(t :SYMBOL)
    token.value.should eq("a")
  end

  it "lexes != after identifier (#4815)" do
    lexer = Lexer.new("some_method!=5")
    token = lexer.next_token
    token.type.should eq(t :IDENT)
    token.value.should eq("some_method")
    token = lexer.next_token
    token.type.should eq(t :OP_BANG_EQ)
    token = lexer.next_token
    token.type.should eq(t :NUMBER)
  end

  assert_syntax_error "'\\uFEDZ'", "expected hexadecimal character in unicode escape"
  assert_syntax_error "'\\u{}'", "expected hexadecimal character in unicode escape"
  assert_syntax_error "'\\u{110000}'", "invalid unicode codepoint (too large)"
  assert_syntax_error "'\\uD800'", "invalid unicode codepoint (surrogate half)"
  assert_syntax_error "'\\uDFFF'", "invalid unicode codepoint (surrogate half)"
  assert_syntax_error "'\\u{D800}'", "invalid unicode codepoint (surrogate half)"
  assert_syntax_error "'\\u{DFFF}'", "invalid unicode codepoint (surrogate half)"
  assert_syntax_error ":+1", "unexpected token"

  it "invalid byte sequence" do
    expect_raises(InvalidByteSequenceError, "Unexpected byte 0xff at position 0, malformed UTF-8") do
      parse "\xFF"
    end
    expect_raises(InvalidByteSequenceError, "Unexpected byte 0xff at position 1, malformed UTF-8") do
      parse " \xFF"
    end
  end

  assert_syntax_error "'\\1'", "invalid char escape sequence"

  it_lexes_string %("\\1"), String.new(Bytes[1])
  it_lexes_string %("\\4"), String.new(Bytes[4])
  it_lexes_string %("\\10"), String.new(Bytes[8])
  it_lexes_string %("\\110"), String.new(Bytes[72])
  it_lexes_string %("\\8"), "8"
  assert_syntax_error %("\\400"), "octal value too big"

  it_lexes_string %("\\x12"), String.new(Bytes[0x12])
  it_lexes_string %("\\xFF"), String.new(Bytes[0xFF])
  assert_syntax_error %("\\xz"), "invalid hex escape"
  assert_syntax_error %("\\x1z"), "invalid hex escape"

  assert_syntax_error %("hi\\)

  it "lexes regex after \\n" do
    lexer = Lexer.new("\n/=/")
    lexer.slash_is_regex = true
    token = lexer.next_token
    token.type.should eq(t :NEWLINE)
    token = lexer.next_token
    token.type.should eq(t :DELIMITER_START)
    token.delimiter_state.kind.should eq(Token::DelimiterKind::REGEX)
  end

  it "lexes regex after \\r\\n" do
    lexer = Lexer.new("\r\n/=/")
    lexer.slash_is_regex = true
    token = lexer.next_token
    token.type.should eq(t :NEWLINE)
    token = lexer.next_token
    token.type.should eq(t :DELIMITER_START)
    token.delimiter_state.kind.should eq(Token::DelimiterKind::REGEX)
  end

  it "lexes heredoc start" do
    lexer = Lexer.new("<<-EOS\n")
    lexer.wants_raw = true
    token = lexer.next_token
    token.type.should eq(t :DELIMITER_START)
    token.delimiter_state.kind.should eq(Token::DelimiterKind::HEREDOC)
    token.raw.should eq "<<-EOS"
  end
end
