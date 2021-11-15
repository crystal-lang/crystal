require "./spec_helper"
require "../support/string"
{% unless flag?(:win32) %}
  require "big"
{% end %}

# use same name for `sprintf` and `IO#printf`
private def fprintf(format, *args)
  sprintf(format, *args)
end

private def fprintf(io : IO, format, *args)
  io.printf(format, *args)
end

private def assert_sprintf(format, *args_and_result, file = __FILE__, line = __LINE__)
  args = args_and_result[..-2]
  result = args_and_result[-1]
  assert_prints fprintf(format, *args), result, file: file, line: line
end

describe "::sprintf" do
  it "works" do
    assert_sprintf "foo", 1, "foo"
    assert_sprintf "Hello %d world", 123, "Hello 123 world"
    assert_sprintf "Hello %d world", [123], "Hello 123 world"
    assert_sprintf "foo %d bar %s baz %d goo", [1, "hello", 2], "foo 1 bar hello baz 2 goo"
  end

  it "doesn't format %%" do
    assert_sprintf "%%%d", 1, "%1"
    assert_sprintf "%%*%%", [1, 2, 3], "%*%"
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

      it "is ignored if string is right-justified" do
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

    pending_win32 "works with BigInt" do
      assert_sprintf "%d", 123.to_big_i, "123"
      assert_sprintf "%300.250d", 10.to_big_i ** 200, "#{" " * 50}#{"0" * 49}1#{"0" * 200}"
      assert_sprintf "%- #300.250X", 16.to_big_i ** 200 - 1, " 0X#{"0" * 50}#{"F" * 200}#{" " * 47}"
    end
  end

  pending_win32 describe: "floats" do
    it "works" do
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

      assert_sprintf "%12.2f %12.2f %6.2f %.2f", {2.0, 3.0, 4.0, 5.0}, "        2.00         3.00   4.00 5.00"

      assert_sprintf "%f", 1e15, "1000000000000000.000000"
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

    it "raises on unbalanced curly" do
      expect_raises(ArgumentError, "Malformed name - unmatched parenthesis") { sprintf("change %{this", {"this" => 1}) }
    end
  end

  context "formatted substitution" do
    it "applies formatting to %<...> placeholder" do
      assert_sprintf "change %<this>.2f", {"this" => 23.456}, "change 23.46"
      assert_sprintf "change %<this>.2f", {this: 23.456}, "change 23.46"
    end
  end
end
