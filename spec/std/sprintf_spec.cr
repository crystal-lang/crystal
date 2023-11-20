require "./spec_helper"
require "spec/helpers/string"
require "big"

# use same name for `sprintf` and `IO#printf` so that `assert_prints` can be leveraged
private def fprintf(format, *args)
  sprintf(format, *args)
end

private def fprintf(io : IO, format, *args)
  io.printf(format, *args)
end

private def assert_sprintf(format, args, result, *, file = __FILE__, line = __LINE__)
  assert_prints fprintf(format, args), result, file: file, line: line
end

describe "::sprintf" do
  it "works" do
    assert_sprintf "Hello %d world", 123, "Hello 123 world"
    assert_sprintf "Hello %d world", [123], "Hello 123 world"
    assert_sprintf "foo %d bar %s baz %d goo", [1, "hello", 2], "foo 1 bar hello baz 2 goo"
  end

  it "accepts multiple positional arguments" do
    assert_prints fprintf("%d %d %d", 1, 23, 456), "1 23 456"
    assert_prints fprintf("%*.*d,%*s", 10, 6, 123, 10, "foo"), "    000123,       foo"
    assert_prints fprintf("foo"), "foo"
  end

  it "doesn't format %%" do
    assert_sprintf "%%%d", 1, "%1"
    assert_sprintf "%%*%%", [1, 2, 3], "%*%"
  end

  it "doesn't accept modifiers for %%" do
    expect_raises(ArgumentError) { sprintf("%0%") }
    expect_raises(ArgumentError) { sprintf("%+%") }
    expect_raises(ArgumentError) { sprintf("%-%") }
    expect_raises(ArgumentError) { sprintf("% %") }
    expect_raises(ArgumentError) { sprintf("%#%") }
    expect_raises(ArgumentError) { sprintf("%.0%") }
    expect_raises(ArgumentError) { sprintf("%*%", 1) }

    expect_raises(ArgumentError) { sprintf("%<a>0%") }
    expect_raises(ArgumentError) { sprintf("%<a>+%") }
    expect_raises(ArgumentError) { sprintf("%<a>-%") }
    expect_raises(ArgumentError) { sprintf("%<a> %") }
    expect_raises(ArgumentError) { sprintf("%<a>#%") }
    expect_raises(ArgumentError) { sprintf("%<a>.0%") }
    expect_raises(ArgumentError) { sprintf("%<a>*%", 1) }
  end

  context "integers" do
    context "base specifier" do
      it "supports base 2" do
        assert_sprintf "%b", 123, "1111011"
        assert_sprintf "%+b", 123, "+1111011"
        assert_sprintf "% b", 123, " 1111011"
        assert_sprintf "%-b", 123, "1111011"
        assert_sprintf "%10b", 123, "   1111011"
        assert_sprintf "%-10b", 123, "1111011   "
      end

      it "supports base 8" do
        assert_sprintf "%o", 123, "173"
        assert_sprintf "%+o", 123, "+173"
        assert_sprintf "% o", 123, " 173"
        assert_sprintf "%-o", 123, "173"
        assert_sprintf "%6o", 123, "   173"
        assert_sprintf "%-6o", 123, "173   "
      end

      it "supports base 10" do
        assert_sprintf "%d", 123, "123"
        assert_sprintf "%+d", 123, "+123"
        assert_sprintf "% d", 123, " 123"
        assert_sprintf "%-d", 123, "123"
        assert_sprintf "%6d", 123, "   123"
        assert_sprintf "%-6d", 123, "123   "

        assert_sprintf "%i", 123, "123"
        assert_sprintf "%+i", 123, "+123"
        assert_sprintf "% i", 123, " 123"
        assert_sprintf "%-i", 123, "123"
        assert_sprintf "%6i", 123, "   123"
        assert_sprintf "%-6i", 123, "123   "
      end

      it "supports base 16" do
        assert_sprintf "%x", 123, "7b"
        assert_sprintf "%+x", 123, "+7b"
        assert_sprintf "% x", 123, " 7b"
        assert_sprintf "%-x", 123, "7b"
        assert_sprintf "%6x", 123, "    7b"
        assert_sprintf "%-6x", 123, "7b    "

        assert_sprintf "%X", 123, "7B"
        assert_sprintf "%+X", 123, "+7B"
        assert_sprintf "% X", 123, " 7B"
        assert_sprintf "%-X", 123, "7B"
        assert_sprintf "%6X", 123, "    7B"
        assert_sprintf "%-6X", 123, "7B    "

        assert_sprintf "こんに%xちは", 123, "こんに7bちは"
        assert_sprintf "こんに%Xちは", 123, "こんに7Bちは"
      end
    end

    context "width specifier" do
      it "sets the minimum length of the string" do
        assert_sprintf "%20d", 123, "                 123"
        assert_sprintf "%20d", -123, "                -123"
        assert_sprintf "%20d", 0, "                   0"

        assert_sprintf "%4d", 123, " 123"
        assert_sprintf "%4d", -123, "-123"
        assert_sprintf "%4d", 0, "   0"

        assert_sprintf "%2d", 123, "123"
        assert_sprintf "%2d", -123, "-123"
        assert_sprintf "%2d", 0, " 0"

        assert_sprintf "%*d", [20, 123], "                 123"
        assert_sprintf "%*d", [20, -123], "                -123"
        assert_sprintf "%*d", [20, 0], "                   0"

        assert_sprintf "%*d", [0, 123], "123"
        assert_sprintf "%*d", [0, -123], "-123"
        assert_sprintf "%*d", [0, 0], "0"
      end

      it "left-justifies on negative width" do
        assert_sprintf "%*d", [-20, 123], "123                 "
        assert_sprintf "%*d", [-20, -123], "-123                "
        assert_sprintf "%*d", [-20, 0], "0                   "

        assert_sprintf "%*d", [-4, 123], "123 "
        assert_sprintf "%*d", [-4, -123], "-123"
        assert_sprintf "%*d", [-4, 0], "0   "

        assert_sprintf "%*d", [-2, 123], "123"
        assert_sprintf "%*d", [-2, -123], "-123"
        assert_sprintf "%*d", [-2, 0], "0 "

        assert_sprintf "%-*d", [-20, 123], "123                 "
        assert_sprintf "%-*d", [-20, -123], "-123                "
        assert_sprintf "%-*d", [-20, 0], "0                   "
      end
    end

    context "precision specifier" do
      it "sets the minimum length of the number part" do
        assert_sprintf "%.12d", 123, "000000000123"
        assert_sprintf "%.12d", -123, "-000000000123"
        assert_sprintf "%.12d", 0, "000000000000"

        assert_sprintf "%.4d", 123, "0123"
        assert_sprintf "%.4d", -123, "-0123"
        assert_sprintf "%.4d", 0, "0000"

        assert_sprintf "%.2d", 123, "123"
        assert_sprintf "%.2d", -123, "-123"
        assert_sprintf "%.2d", 0, "00"

        assert_sprintf "%.0d", 123, "123"
        assert_sprintf "%.0d", -123, "-123"
        assert_sprintf "%.0d", 0, ""
      end

      it "can be used with width" do
        assert_sprintf "%20.12d", 123, "        000000000123"
        assert_sprintf "%20.12d", -123, "       -000000000123"
        assert_sprintf "%20.12d", 0, "        000000000000"

        assert_sprintf "%-20.12d", 123, "000000000123        "
        assert_sprintf "%-20.12d", -123, "-000000000123       "
        assert_sprintf "%-20.12d", 0, "000000000000        "

        assert_sprintf "%8.12d", 123, "000000000123"
        assert_sprintf "%8.12d", -123, "-000000000123"
        assert_sprintf "%8.12d", 0, "000000000000"

        assert_sprintf "%+13.12d", 123, "+000000000123"
        assert_sprintf "%+13.12d", -123, "-000000000123"
        assert_sprintf "%+13.12d", 0, "+000000000000"

        assert_sprintf "%- 20.12d", 123, " 000000000123       "
        assert_sprintf "%- 20.12d", -123, "-000000000123       "
        assert_sprintf "%- 20.12d", 0, " 000000000000       "

        assert_sprintf "%*.*d", [20, 12, 123], "        000000000123"
        assert_sprintf "%*.*d", [20, 12, -123], "       -000000000123"
        assert_sprintf "%*.*d", [20, 12, 0], "        000000000000"

        assert_sprintf "%*.*d", [-20, -12, 123], "123                 "
        assert_sprintf "%*.*d", [-20, -12, -123], "-123                "
        assert_sprintf "%*.*d", [-20, -12, 0], "0                   "
      end

      it "is ignored if precision argument is negative" do
        assert_sprintf "%.*d", [-2, 123], "123"
        assert_sprintf "%.*d", [-2, -123], "-123"
        assert_sprintf "%.*d", [-2, 0], "0"

        assert_sprintf "%020.*d", [-2, 123], "00000000000000000123"
        assert_sprintf "%020.*d", [-2, -123], "-0000000000000000123"
        assert_sprintf "%020.*d", [-2, 0], "00000000000000000000"
      end
    end

    context "sharp flag" do
      it "adds a base prefix" do
        assert_sprintf "%#b", 123, "0b1111011"
        assert_sprintf "%#o", 123, "0o173"
        assert_sprintf "%#x", 123, "0x7b"
        assert_sprintf "%#X", 123, "0X7B"

        assert_sprintf "%#b", -123, "-0b1111011"
        assert_sprintf "%#o", -123, "-0o173"
        assert_sprintf "%#x", -123, "-0x7b"
        assert_sprintf "%#X", -123, "-0X7B"
      end

      it "omits the base prefix for 0" do
        assert_sprintf "%#b", 0, "0"
        assert_sprintf "%#o", 0, "0"
        assert_sprintf "%#x", 0, "0"
        assert_sprintf "%#X", 0, "0"
      end
    end

    context "plus flag" do
      it "writes a plus sign for positive integers" do
        assert_sprintf "%+d", 123, "+123"
        assert_sprintf "%+d", -123, "-123"
        assert_sprintf "%+d", 0, "+0"
      end

      it "writes plus sign after left space-padding" do
        assert_sprintf "%+20d", 123, "                +123"
        assert_sprintf "%+20d", -123, "                -123"
        assert_sprintf "%+20d", 0, "                  +0"
      end

      it "writes plus sign before left zero-padding" do
        assert_sprintf "%+020d", 123, "+0000000000000000123"
        assert_sprintf "%+020d", -123, "-0000000000000000123"
        assert_sprintf "%+020d", 0, "+0000000000000000000"
      end
    end

    context "space flag" do
      it "writes a space for positive integers" do
        assert_sprintf "% d", 123, " 123"
        assert_sprintf "% d", -123, "-123"
        assert_sprintf "% d", 0, " 0"
      end

      it "writes space before left padding" do
        assert_sprintf "% 20d", 123, "                 123"
        assert_sprintf "% 20d", -123, "                -123"
        assert_sprintf "% 20d", 0, "                   0"

        assert_sprintf "% 020d", 123, " 0000000000000000123"
        assert_sprintf "% 020d", -123, "-0000000000000000123"
        assert_sprintf "% 020d", 0, " 0000000000000000000"
      end

      it "is ignored if plus flag is also specified" do
        assert_sprintf "%+ d", 123, "+123"
        assert_sprintf "% +d", 123, "+123"
        assert_sprintf "%+ 20d", 123, "                +123"
        assert_sprintf "% +20d", 123, "                +123"
        assert_sprintf "%+ 020d", 123, "+0000000000000000123"
        assert_sprintf "% +020d", 123, "+0000000000000000123"
      end
    end

    context "zero flag" do
      it "left-pads the result with zeros" do
        assert_sprintf "%020d", 123, "00000000000000000123"
        assert_sprintf "%020d", -123, "-0000000000000000123"
        assert_sprintf "%020d", 0, "00000000000000000000"

        assert_sprintf "%+020d", 123, "+0000000000000000123"
        assert_sprintf "%+020d", -123, "-0000000000000000123"
        assert_sprintf "%+020d", 0, "+0000000000000000000"

        assert_sprintf "% 020d", 123, " 0000000000000000123"
        assert_sprintf "% 020d", -123, "-0000000000000000123"
        assert_sprintf "% 020d", 0, " 0000000000000000000"
      end

      it "is ignored if string is left-justified" do
        assert_sprintf "%-020d", 123, "123                 "
        assert_sprintf "%-020d", -123, "-123                "
        assert_sprintf "%-020d", 0, "0                   "

        assert_sprintf "%0-20d", 123, "123                 "
        assert_sprintf "%0-20d", -123, "-123                "
        assert_sprintf "%0-20d", 0, "0                   "

        assert_sprintf "%0*d", [-20, 123], "123                 "
        assert_sprintf "%0*d", [-20, -123], "-123                "
        assert_sprintf "%0*d", [-20, 0], "0                   "

        assert_sprintf "%-0*d", [-20, 123], "123                 "
        assert_sprintf "%-0*d", [-20, -123], "-123                "
        assert_sprintf "%-0*d", [-20, 0], "0                   "
      end

      it "is ignored if precision is specified" do
        assert_sprintf "%020.12d", 123, "        000000000123"
        assert_sprintf "%020.12d", -123, "       -000000000123"
        assert_sprintf "%020.12d", 0, "        000000000000"

        assert_sprintf "%020.*d", [12, 123], "        000000000123"
        assert_sprintf "%020.*d", [12, -123], "       -000000000123"
        assert_sprintf "%020.*d", [12, 0], "        000000000000"

        assert_sprintf "%020.*d", [-12, 123], "00000000000000000123"
        assert_sprintf "%020.*d", [-12, -123], "-0000000000000000123"
        assert_sprintf "%020.*d", [-12, 0], "00000000000000000000"
      end
    end

    context "minus flag" do
      it "left-justifies the string" do
        assert_sprintf "%-d", 123, "123"
        assert_sprintf "%-d", -123, "-123"
        assert_sprintf "%-d", 0, "0"

        assert_sprintf "%-20d", 123, "123                 "
        assert_sprintf "%-20d", -123, "-123                "
        assert_sprintf "%-20d", 0, "0                   "

        assert_sprintf "%-4d", 123, "123 "
        assert_sprintf "%-4d", -123, "-123"
        assert_sprintf "%-4d", 0, "0   "

        assert_sprintf "%-2d", 123, "123"
        assert_sprintf "%-2d", -123, "-123"
        assert_sprintf "%-2d", 0, "0 "
      end

      it "reserves space for the number prefix" do
        assert_sprintf "%-+20d", 123, "+123                "
        assert_sprintf "%-+20d", -123, "-123                "
        assert_sprintf "%-+20d", 0, "+0                  "

        assert_sprintf "%- 20d", 123, " 123                "
        assert_sprintf "%- 20d", -123, "-123                "
        assert_sprintf "%- 20d", 0, " 0                  "

        assert_sprintf "%-#20b", 123, "0b1111011           "
        assert_sprintf "%-#20b", -123, "-0b1111011          "
        assert_sprintf "%-#20b", 0, "0                   "
      end
    end

    it "works with Int*::MIN" do
      assert_sprintf "%d", Int8::MIN, "-128"
      assert_sprintf "%d", Int16::MIN, "-32768"
      assert_sprintf "%d", Int32::MIN, "-2147483648"
      assert_sprintf "%d", Int64::MIN, "-9223372036854775808"
    end

    it "works with BigInt" do
      assert_sprintf "%d", 123.to_big_i, "123"
      assert_sprintf "%300.250d", 10.to_big_i ** 200, "#{" " * 50}#{"0" * 49}1#{"0" * 200}"
      assert_sprintf "%- #300.250X", 16.to_big_i ** 200 - 1, " 0X#{"0" * 50}#{"F" * 200}#{" " * 47}"
    end
  end

  it "doesn't stop at null character when doing '%'" do
    assert_sprintf "1\u{0}%i\u{0}3", 2, "1\u00002\u00003"
  end

  describe "floats" do
    pending_win32 "works" do
      assert_sprintf "%f", 123, "123.000000"

      assert_sprintf "%g", 123, "123"
      assert_sprintf "%12f", 123.45, "  123.450000"
      assert_sprintf "%-12f", 123.45, "123.450000  "
      assert_sprintf "% f", 123.45, " 123.450000"
      assert_sprintf "%+f", 123, "+123.000000"
      assert_sprintf "%012f", 123, "00123.000000"
      assert_sprintf "%.f", 1234.56, "1235"
      assert_sprintf "%.2f", 1234.5678, "1234.57"
      assert_sprintf "%10.2f", 1234.5678, "   1234.57"
      assert_sprintf "%*.2f", [10, 1234.5678], "   1234.57"
      assert_sprintf "%0*.2f", [10, 1234.5678], "0001234.57"
      assert_sprintf "%e", 123.45, "1.234500e+02"
      assert_sprintf "%E", 123.45, "1.234500E+02"
      assert_sprintf "%G", 12345678.45, "1.23457E+07"
      assert_sprintf "%a", 12345678.45, "0x1.78c29ce666666p+23"
      assert_sprintf "%A", 12345678.45, "0X1.78C29CE666666P+23"
      assert_sprintf "%100.50g", 123.45, "                                                  123.4500000000000028421709430404007434844970703125"
      assert_sprintf "%#.12g", 12345.0, "12345.0000000"

      assert_sprintf "%.2f", 2.536_f32, "2.54"
      assert_sprintf "%0*.*f", [10, 2, 2.536_f32], "0000002.54"

      expect_raises(ArgumentError, "Expected dynamic value '*' to be an Int - \"not a number\" (String)") do
        sprintf("%*f", ["not a number", 2.536_f32])
      end

      assert_sprintf "%12.2f %12.2f %6.2f %.2f", [2.0, 3.0, 4.0, 5.0], "        2.00         3.00   4.00 5.00"

      assert_sprintf "%f", 1e15, "1000000000000000.000000"
    end

    [Float32, Float64].each do |float|
      it "infinities" do
        pos_inf = float.new(1) / float.new(0)
        neg_inf = float.new(-1) / float.new(0)

        assert_sprintf "%f", pos_inf, "inf"
        assert_sprintf "%a", pos_inf, "inf"
        assert_sprintf "%e", pos_inf, "inf"
        assert_sprintf "%g", pos_inf, "inf"
        assert_sprintf "%A", pos_inf, "INF"
        assert_sprintf "%E", pos_inf, "INF"
        assert_sprintf "%G", pos_inf, "INF"

        assert_sprintf "%f", neg_inf, "-inf"
        assert_sprintf "%G", neg_inf, "-INF"

        assert_sprintf "%2f", pos_inf, "inf"
        assert_sprintf "%4f", pos_inf, " inf"
        assert_sprintf "%6f", pos_inf, "   inf"
        assert_sprintf "%2f", neg_inf, "-inf"
        assert_sprintf "%4f", neg_inf, "-inf"
        assert_sprintf "%6f", neg_inf, "  -inf"

        assert_sprintf "% f", pos_inf, " inf"
        assert_sprintf "% 2f", pos_inf, " inf"
        assert_sprintf "% 4f", pos_inf, " inf"
        assert_sprintf "% 6f", pos_inf, "   inf"
        assert_sprintf "% f", neg_inf, "-inf"
        assert_sprintf "% 2f", neg_inf, "-inf"
        assert_sprintf "% 4f", neg_inf, "-inf"
        assert_sprintf "% 6f", neg_inf, "  -inf"

        assert_sprintf "%+f", pos_inf, "+inf"
        assert_sprintf "%+2f", pos_inf, "+inf"
        assert_sprintf "%+4f", pos_inf, "+inf"
        assert_sprintf "%+6f", pos_inf, "  +inf"
        assert_sprintf "%+f", neg_inf, "-inf"
        assert_sprintf "%+2f", neg_inf, "-inf"
        assert_sprintf "%+4f", neg_inf, "-inf"
        assert_sprintf "%+6f", neg_inf, "  -inf"

        assert_sprintf "%+ f", pos_inf, "+inf"

        assert_sprintf "%-4f", pos_inf, "inf "
        assert_sprintf "%-6f", pos_inf, "inf   "
        assert_sprintf "%-4f", neg_inf, "-inf"
        assert_sprintf "%-6f", neg_inf, "-inf  "

        assert_sprintf "% -4f", pos_inf, " inf"
        assert_sprintf "% -6f", pos_inf, " inf  "
        assert_sprintf "% -4f", neg_inf, "-inf"
        assert_sprintf "% -6f", neg_inf, "-inf  "

        assert_sprintf "%-+4f", pos_inf, "+inf"
        assert_sprintf "%-+6f", pos_inf, "+inf  "
        assert_sprintf "%-+4f", neg_inf, "-inf"
        assert_sprintf "%-+6f", neg_inf, "-inf  "

        assert_sprintf "%-+ 6f", pos_inf, "+inf  "

        assert_sprintf "%06f", pos_inf, "   inf"
        assert_sprintf "%-06f", pos_inf, "inf   "
        assert_sprintf "%06f", neg_inf, "  -inf"
        assert_sprintf "%-06f", neg_inf, "-inf  "

        assert_sprintf "%.1f", pos_inf, "inf"

        assert_sprintf "%#f", pos_inf, "inf"
      end

      it "not-a-numbers" do
        pos_nan = Math.copysign(float.new(0) / float.new(0), 1)
        neg_nan = Math.copysign(float.new(0) / float.new(0), -1)

        assert_sprintf "%f", pos_nan, "nan"
        assert_sprintf "%a", pos_nan, "nan"
        assert_sprintf "%e", pos_nan, "nan"
        assert_sprintf "%g", pos_nan, "nan"
        assert_sprintf "%A", pos_nan, "NAN"
        assert_sprintf "%E", pos_nan, "NAN"
        assert_sprintf "%G", pos_nan, "NAN"

        assert_sprintf "%f", neg_nan, "nan"
        assert_sprintf "%a", neg_nan, "nan"
        assert_sprintf "%e", neg_nan, "nan"
        assert_sprintf "%g", neg_nan, "nan"
        assert_sprintf "%A", neg_nan, "NAN"
        assert_sprintf "%E", neg_nan, "NAN"
        assert_sprintf "%G", neg_nan, "NAN"

        assert_sprintf "%+f", pos_nan, "+nan"
        assert_sprintf "%+f", neg_nan, "+nan"
      end
    end
  end

  context "strings" do
    it "works" do
      assert_sprintf "%s", 'a', "a"
      assert_sprintf "%-s", 'a', "a"
      assert_sprintf "%20s", 'a', "                   a"
      assert_sprintf "%-20s", 'a', "a                   "
      assert_sprintf "%*s", [10, 123], "       123"
      assert_sprintf "%*s", [-10, 123], "123       "
      assert_sprintf "%.5s", "foo bar baz", "foo b"
      assert_sprintf "%.*s", [5, "foo bar baz"], "foo b"
      assert_sprintf "%*.*s", [20, 5, "foo bar baz"], "               foo b"
      assert_sprintf "%-*.*s", [20, 5, "foo bar baz"], "foo b               "
    end

    it "calls to_s on non-strings" do
      span = 1.second
      assert_sprintf "%s", span, span.to_s
    end
  end

  context "plain substitution" do
    it "substitutes one placeholder" do
      assert_sprintf "change %{this}", {"this" => "nothing"}, "change nothing"
      assert_sprintf "change %{this}", {this: "nothing"}, "change nothing"
    end

    it "substitutes multiple placeholder" do
      assert_sprintf "change %{this} and %{more}", {"this" => "nothing", "more" => "something"}, "change nothing and something"
      assert_sprintf "change %{this} and %{more}", {this: "nothing", more: "something"}, "change nothing and something"
    end

    it "throws an error when the key is not found" do
      expect_raises(KeyError) { sprintf("change %{this}", {"that" => "wrong key"}) }
      expect_raises(KeyError) { sprintf("change %{this}", {that: "wrong key"}) }
    end

    it "raises if expecting hash or named tuple but not given" do
      expect_raises(ArgumentError, "One hash or named tuple required") { sprintf("change %{this}", "this") }
    end

    it "doesn't raise if 1-element list of hash or named tuple given" do
      assert_sprintf "change %{this}", [{"this" => "nothing"}], "change nothing"
      assert_sprintf "change %{this}", [{this: "nothing"}], "change nothing"
      assert_sprintf "change %{this}", { {"this" => "nothing"} }, "change nothing"
      assert_sprintf "change %{this}", { {this: "nothing"} }, "change nothing"
    end

    it "raises on unbalanced curly" do
      expect_raises(ArgumentError, "Malformed name - unmatched parenthesis") { sprintf("change %{this", {"this" => 1}) }
    end

    it "doesn't raise on balanced curly with null byte" do
      assert_sprintf "change %{this\u{0}}", {"this\u{0}" => 1}, "change 1"
    end

    it "raises if sequential parameters also given" do
      expect_raises(ArgumentError, "Cannot mix named parameters with sequential ones") { sprintf("%{this}%d", {"this" => 1}) }
    end

    it "raises if numbered parameters also given" do
      expect_raises(ArgumentError, "Cannot mix named parameters with numbered ones") { sprintf("%{this} %1$d", {"this" => 1}) }
    end

    it "doesn't raise if formatted substitution also given" do
      assert_sprintf "%{foo}%<bar>s", {"foo" => "x", "bar" => "y"}, "xy"
    end
  end

  context "formatted substitution" do
    it "applies formatting to %<...> placeholder" do
      assert_sprintf "change %<this>.2f", {"this" => 23.456}, "change 23.46"
      assert_sprintf "change %<this>.2f", {this: 23.456}, "change 23.46"
    end

    it "raises if sequential parameters also given" do
      expect_raises(ArgumentError, "Cannot mix named parameters with sequential ones") { sprintf("%<this>d%d", {"this" => 1}) }
    end

    it "raises if numbered parameters also given" do
      expect_raises(ArgumentError, "Cannot mix named parameters with numbered ones") { sprintf("%<this>1$d", {"this" => 1}) }
      expect_raises(ArgumentError, "Cannot mix named parameters with numbered ones") { sprintf("%<this>*1$d", {"this" => 1}) }
      expect_raises(ArgumentError, "Cannot mix named parameters with numbered ones") { sprintf("%<this>.*1$d", {"this" => 1}) }
      expect_raises(ArgumentError, "Cannot mix named parameters with numbered ones") { sprintf("%<this>d %1$d", {"this" => 1}) }
    end

    it "doesn't raise if plain substitution also given" do
      assert_sprintf "%<foo>s%{bar}", {"foo" => "x", "bar" => "y"}, "xy"
    end
  end

  context "sequential parameters" do
    it "raises if named parameters also given" do
      expect_raises(ArgumentError, "Cannot mix sequential parameters with named ones") { sprintf("%d%{this}", 1) }
      expect_raises(ArgumentError, "Cannot mix sequential parameters with named ones") { sprintf("%d%<this>d", 1) }
    end

    it "raises if numbered parameters also given" do
      expect_raises(ArgumentError, "Cannot mix sequential parameters with numbered ones") { sprintf("%d %1$d", 1) }
    end
  end

  context "numbered parameters" do
    it "gets argument at specified index" do
      assert_sprintf "%2$d %3$x %1$s", ["foo", 123, 0xabc], "123 abc foo"
    end

    it "gets width and precision specifier at specified index" do
      assert_sprintf "%2$*1$d", [5, 123], "  123"
      assert_sprintf "%2$.*1$s", [5, "abcdefghij"], "abcde"
      assert_sprintf "%-3$*1$.*2$s", [10, 5, "abcdefghij"], "abcde     "
    end

    it "raises if index is out of bounds" do
      expect_raises(ArgumentError, "Too few arguments") { sprintf("%1$d") }
      expect_raises(ArgumentError, "Too few arguments") { sprintf("%5$d", 1, 2, 3, 4) }
    end

    it "raises if index is zero" do
      expect_raises(ArgumentError) { sprintf("%0$d") }
      expect_raises(ArgumentError) { sprintf("%1$*0$d", 1) }
      expect_raises(ArgumentError) { sprintf("%1$.*0$d", 1) }
    end

    it "can be used before flags" do
      assert_sprintf "%1$ d", 123, " 123"
      assert_sprintf "%1$+d", 123, "+123"
      assert_sprintf "%1$5d", 123, "  123"
      assert_sprintf "%1$-5d", 123, "123  "
      assert_sprintf "%1$#x", 123, "0x7b"
    end

    it "raises if multiple indices specified" do
      expect_raises(ArgumentError, "Cannot specify parameter number more than once") { sprintf("%1$2$d", 1, 2) }
      expect_raises(ArgumentError, "Cannot specify parameter number more than once") { sprintf("%1$-2$d", 1, 2) }
    end

    it "raises if used as width or precision specifier of a sequential parameter" do
      expect_raises(ArgumentError, "Cannot mix numbered parameters with sequential ones") { sprintf("%*1$d", 1) }
      expect_raises(ArgumentError, "Cannot mix numbered parameters with sequential ones") { sprintf("%.*1$d", 1) }
    end

    it "raises if sequential parameters also given" do
      expect_raises(ArgumentError, "Cannot mix numbered parameters with sequential ones") { sprintf("%1$d %d", 1) }
    end

    it "raises if named parameters also given" do
      expect_raises(ArgumentError, "Cannot mix numbered parameters with named ones") { sprintf("%1$d %{this}", 1) }
      expect_raises(ArgumentError, "Cannot mix numbered parameters with named ones") { sprintf("%1$d %<this>d", 1) }
    end
  end
end
