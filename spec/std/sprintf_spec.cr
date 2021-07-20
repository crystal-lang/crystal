require "./spec_helper"
{% unless flag?(:win32) %}
  require "big"
{% end %}

describe "::sprintf" do
  it "works" do
    sprintf("foo", 1).should eq("foo")
    sprintf("Hello %d world", 123).should eq("Hello 123 world")
    sprintf("Hello %d world", [123]).should eq("Hello 123 world")
    sprintf("foo %d bar %s baz %d goo", [1, "hello", 2]).should eq("foo 1 bar hello baz 2 goo")
  end

  it "doesn't format %%" do
    sprintf("%%%d", 1).should eq("%1")
    sprintf("%%*%%", [1, 2, 3]).should eq("%*%")
  end

  context "integers" do
    context "base specifier" do
      it "supports base 2" do
        sprintf("%b", 123).should eq("1111011")
        sprintf("%+b", 123).should eq("+1111011")
        sprintf("% b", 123).should eq(" 1111011")
        sprintf("%-b", 123).should eq("1111011")
        sprintf("%10b", 123).should eq("   1111011")
        sprintf("%-10b", 123).should eq("1111011   ")
      end

      it "supports base 8" do
        sprintf("%o", 123).should eq("173")
        sprintf("%+o", 123).should eq("+173")
        sprintf("% o", 123).should eq(" 173")
        sprintf("%-o", 123).should eq("173")
        sprintf("%6o", 123).should eq("   173")
        sprintf("%-6o", 123).should eq("173   ")
      end

      it "supports base 10" do
        sprintf("%d", 123).should eq("123")
        sprintf("%+d", 123).should eq("+123")
        sprintf("% d", 123).should eq(" 123")
        sprintf("%-d", 123).should eq("123")
        sprintf("%6d", 123).should eq("   123")
        sprintf("%-6d", 123).should eq("123   ")

        sprintf("%i", 123).should eq("123")
        sprintf("%+i", 123).should eq("+123")
        sprintf("% i", 123).should eq(" 123")
        sprintf("%-i", 123).should eq("123")
        sprintf("%6i", 123).should eq("   123")
        sprintf("%-6i", 123).should eq("123   ")
      end

      it "supports base 16" do
        sprintf("%x", 123).should eq("7b")
        sprintf("%+x", 123).should eq("+7b")
        sprintf("% x", 123).should eq(" 7b")
        sprintf("%-x", 123).should eq("7b")
        sprintf("%6x", 123).should eq("    7b")
        sprintf("%-6x", 123).should eq("7b    ")

        sprintf("%X", 123).should eq("7B")
        sprintf("%+X", 123).should eq("+7B")
        sprintf("% X", 123).should eq(" 7B")
        sprintf("%-X", 123).should eq("7B")
        sprintf("%6X", 123).should eq("    7B")
        sprintf("%-6X", 123).should eq("7B    ")

        sprintf("こんに%xちは", 123).should eq("こんに7bちは")
        sprintf("こんに%Xちは", 123).should eq("こんに7Bちは")
      end
    end

    context "width specifier" do
      it "sets the minimum length of the string" do
        sprintf("%20d", 123).should eq("                 123")
        sprintf("%20d", -123).should eq("                -123")
        sprintf("%20d", 0).should eq("                   0")

        sprintf("%4d", 123).should eq(" 123")
        sprintf("%4d", -123).should eq("-123")
        sprintf("%4d", 0).should eq("   0")

        sprintf("%2d", 123).should eq("123")
        sprintf("%2d", -123).should eq("-123")
        sprintf("%2d", 0).should eq(" 0")

        sprintf("%*d", [20, 123]).should eq("                 123")
        sprintf("%*d", [20, -123]).should eq("                -123")
        sprintf("%*d", [20, 0]).should eq("                   0")

        sprintf("%*d", [0, 123]).should eq("123")
        sprintf("%*d", [0, -123]).should eq("-123")
        sprintf("%*d", [0, 0]).should eq("0")
      end

      it "left-justifies on negative width" do
        sprintf("%*d", [-20, 123]).should eq("123                 ")
        sprintf("%*d", [-20, -123]).should eq("-123                ")
        sprintf("%*d", [-20, 0]).should eq("0                   ")

        sprintf("%*d", [-4, 123]).should eq("123 ")
        sprintf("%*d", [-4, -123]).should eq("-123")
        sprintf("%*d", [-4, 0]).should eq("0   ")

        sprintf("%*d", [-2, 123]).should eq("123")
        sprintf("%*d", [-2, -123]).should eq("-123")
        sprintf("%*d", [-2, 0]).should eq("0 ")

        sprintf("%-*d", [-20, 123]).should eq("123                 ")
        sprintf("%-*d", [-20, -123]).should eq("-123                ")
        sprintf("%-*d", [-20, 0]).should eq("0                   ")
      end
    end

    context "precision specifier" do
      it "sets the minimum length of the number part" do
        sprintf("%.12d", 123).should eq("000000000123")
        sprintf("%.12d", -123).should eq("-000000000123")
        sprintf("%.12d", 0).should eq("000000000000")

        sprintf("%.4d", 123).should eq("0123")
        sprintf("%.4d", -123).should eq("-0123")
        sprintf("%.4d", 0).should eq("0000")

        sprintf("%.2d", 123).should eq("123")
        sprintf("%.2d", -123).should eq("-123")
        sprintf("%.2d", 0).should eq("00")

        sprintf("%.0d", 123).should eq("123")
        sprintf("%.0d", -123).should eq("-123")
        sprintf("%.0d", 0).should eq("")
      end

      it "can be used with width" do
        sprintf("%20.12d", 123).should eq("        000000000123")
        sprintf("%20.12d", -123).should eq("       -000000000123")
        sprintf("%20.12d", 0).should eq("        000000000000")

        sprintf("%-20.12d", 123).should eq("000000000123        ")
        sprintf("%-20.12d", -123).should eq("-000000000123       ")
        sprintf("%-20.12d", 0).should eq("000000000000        ")

        sprintf("%8.12d", 123).should eq("000000000123")
        sprintf("%8.12d", -123).should eq("-000000000123")
        sprintf("%8.12d", 0).should eq("000000000000")

        sprintf("%+13.12d", 123).should eq("+000000000123")
        sprintf("%+13.12d", -123).should eq("-000000000123")
        sprintf("%+13.12d", 0).should eq("+000000000000")

        sprintf("%- 20.12d", 123).should eq(" 000000000123       ")
        sprintf("%- 20.12d", -123).should eq("-000000000123       ")
        sprintf("%- 20.12d", 0).should eq(" 000000000000       ")

        sprintf("%*.*d", [20, 12, 123]).should eq("        000000000123")
        sprintf("%*.*d", [20, 12, -123]).should eq("       -000000000123")
        sprintf("%*.*d", [20, 12, 0]).should eq("        000000000000")

        sprintf("%*.*d", [-20, -12, 123]).should eq("123                 ")
        sprintf("%*.*d", [-20, -12, -123]).should eq("-123                ")
        sprintf("%*.*d", [-20, -12, 0]).should eq("0                   ")
      end

      it "is ignored if precision argument is negative" do
        sprintf("%.*d", [-2, 123]).should eq("123")
        sprintf("%.*d", [-2, -123]).should eq("-123")
        sprintf("%.*d", [-2, 0]).should eq("0")

        sprintf("%020.*d", [-2, 123]).should eq("00000000000000000123")
        sprintf("%020.*d", [-2, -123]).should eq("-0000000000000000123")
        sprintf("%020.*d", [-2, 0]).should eq("00000000000000000000")
      end
    end

    context "sharp flag" do
      it "adds a base prefix" do
        sprintf("%#b", 123).should eq("0b1111011")
        sprintf("%#o", 123).should eq("0o173")
        sprintf("%#x", 123).should eq("0x7b")
        sprintf("%#X", 123).should eq("0X7B")

        sprintf("%#b", -123).should eq("-0b1111011")
        sprintf("%#o", -123).should eq("-0o173")
        sprintf("%#x", -123).should eq("-0x7b")
        sprintf("%#X", -123).should eq("-0X7B")
      end

      it "omits the base prefix for 0" do
        sprintf("%#b", 0).should eq("0")
        sprintf("%#o", 0).should eq("0")
        sprintf("%#x", 0).should eq("0")
        sprintf("%#X", 0).should eq("0")
      end
    end

    context "plus flag" do
      it "writes a plus sign for positive integers" do
        sprintf("%+d", 123).should eq("+123")
        sprintf("%+d", -123).should eq("-123")
        sprintf("%+d", 0).should eq("+0")
      end

      it "writes plus sign after left space-padding" do
        sprintf("%+20d", 123).should eq("                +123")
        sprintf("%+20d", -123).should eq("                -123")
        sprintf("%+20d", 0).should eq("                  +0")
      end

      it "writes plus sign before left zero-padding" do
        sprintf("%+020d", 123).should eq("+0000000000000000123")
        sprintf("%+020d", -123).should eq("-0000000000000000123")
        sprintf("%+020d", 0).should eq("+0000000000000000000")
      end
    end

    context "space flag" do
      it "writes a space for positive integers" do
        sprintf("% d", 123).should eq(" 123")
        sprintf("% d", -123).should eq("-123")
        sprintf("% d", 0).should eq(" 0")
      end

      it "writes space before left padding" do
        sprintf("% 20d", 123).should eq("                 123")
        sprintf("% 20d", -123).should eq("                -123")
        sprintf("% 20d", 0).should eq("                   0")

        sprintf("% 020d", 123).should eq(" 0000000000000000123")
        sprintf("% 020d", -123).should eq("-0000000000000000123")
        sprintf("% 020d", 0).should eq(" 0000000000000000000")
      end

      it "is ignored if plus flag is also specified" do
        sprintf("%+ d", 123).should eq("+123")
        sprintf("% +d", 123).should eq("+123")
        sprintf("%+ 20d", 123).should eq("                +123")
        sprintf("% +20d", 123).should eq("                +123")
        sprintf("%+ 020d", 123).should eq("+0000000000000000123")
        sprintf("% +020d", 123).should eq("+0000000000000000123")
      end
    end

    context "zero flag" do
      it "left-pads the result with zeros" do
        sprintf("%020d", 123).should eq("00000000000000000123")
        sprintf("%020d", -123).should eq("-0000000000000000123")
        sprintf("%020d", 0).should eq("00000000000000000000")

        sprintf("%+020d", 123).should eq("+0000000000000000123")
        sprintf("%+020d", -123).should eq("-0000000000000000123")
        sprintf("%+020d", 0).should eq("+0000000000000000000")

        sprintf("% 020d", 123).should eq(" 0000000000000000123")
        sprintf("% 020d", -123).should eq("-0000000000000000123")
        sprintf("% 020d", 0).should eq(" 0000000000000000000")
      end

      it "is ignored if string is right-justified" do
        sprintf("%-020d", 123).should eq("123                 ")
        sprintf("%-020d", -123).should eq("-123                ")
        sprintf("%-020d", 0).should eq("0                   ")

        sprintf("%0-20d", 123).should eq("123                 ")
        sprintf("%0-20d", -123).should eq("-123                ")
        sprintf("%0-20d", 0).should eq("0                   ")

        sprintf("%0*d", [-20, 123]).should eq("123                 ")
        sprintf("%0*d", [-20, -123]).should eq("-123                ")
        sprintf("%0*d", [-20, 0]).should eq("0                   ")

        sprintf("%-0*d", [-20, 123]).should eq("123                 ")
        sprintf("%-0*d", [-20, -123]).should eq("-123                ")
        sprintf("%-0*d", [-20, 0]).should eq("0                   ")
      end

      it "is ignored if precision is specified" do
        sprintf("%020.12d", 123).should eq("        000000000123")
        sprintf("%020.12d", -123).should eq("       -000000000123")
        sprintf("%020.12d", 0).should eq("        000000000000")

        sprintf("%020.*d", [12, 123]).should eq("        000000000123")
        sprintf("%020.*d", [12, -123]).should eq("       -000000000123")
        sprintf("%020.*d", [12, 0]).should eq("        000000000000")

        sprintf("%020.*d", [-12, 123]).should eq("00000000000000000123")
        sprintf("%020.*d", [-12, -123]).should eq("-0000000000000000123")
        sprintf("%020.*d", [-12, 0]).should eq("00000000000000000000")
      end
    end

    context "minus flag" do
      it "left-justifies the string" do
        sprintf("%-d", 123).should eq("123")
        sprintf("%-d", -123).should eq("-123")
        sprintf("%-d", 0).should eq("0")

        sprintf("%-20d", 123).should eq("123                 ")
        sprintf("%-20d", -123).should eq("-123                ")
        sprintf("%-20d", 0).should eq("0                   ")

        sprintf("%-4d", 123).should eq("123 ")
        sprintf("%-4d", -123).should eq("-123")
        sprintf("%-4d", 0).should eq("0   ")

        sprintf("%-2d", 123).should eq("123")
        sprintf("%-2d", -123).should eq("-123")
        sprintf("%-2d", 0).should eq("0 ")
      end

      it "reserves space for the number prefix" do
        sprintf("%-+20d", 123).should eq("+123                ")
        sprintf("%-+20d", -123).should eq("-123                ")
        sprintf("%-+20d", 0).should eq("+0                  ")

        sprintf("%- 20d", 123).should eq(" 123                ")
        sprintf("%- 20d", -123).should eq("-123                ")
        sprintf("%- 20d", 0).should eq(" 0                  ")

        sprintf("%-#20b", 123).should eq("0b1111011           ")
        sprintf("%-#20b", -123).should eq("-0b1111011          ")
        sprintf("%-#20b", 0).should eq("0                   ")
      end
    end

    it "works with Int*::MIN" do
      sprintf("%d", Int8::MIN).should eq("-128")
      sprintf("%d", Int16::MIN).should eq("-32768")
      sprintf("%d", Int32::MIN).should eq("-2147483648")
      sprintf("%d", Int64::MIN).should eq("-9223372036854775808")
    end

    pending_win32 "works with BigInt" do
      sprintf("%d", 123.to_big_i).should eq("123")
      sprintf("%300.250d", 10.to_big_i ** 200).should eq("#{" " * 50}#{"0" * 49}1#{"0" * 200}")
      sprintf("%- #300.250X", 16.to_big_i ** 200 - 1).should eq(" 0X#{"0" * 50}#{"F" * 200}#{" " * 47}")
    end
  end

  pending_win32 describe: "floats" do
    it "works" do
      sprintf("%f", 123).should eq("123.000000")

      sprintf("%g", 123).should eq("123")
      sprintf("%12f", 123.45).should eq("  123.450000")
      sprintf("%-12f", 123.45).should eq("123.450000  ")
      sprintf("% f", 123.45).should eq(" 123.450000")
      sprintf("%+f", 123).should eq("+123.000000")
      sprintf("%012f", 123).should eq("00123.000000")
      sprintf("%.f", 1234.56).should eq("1235")
      sprintf("%.2f", 1234.5678).should eq("1234.57")
      sprintf("%10.2f", 1234.5678).should eq("   1234.57")
      sprintf("%*.2f", [10, 1234.5678]).should eq("   1234.57")
      sprintf("%0*.2f", [10, 1234.5678]).should eq("0001234.57")
      sprintf("%e", 123.45).should eq("1.234500e+02")
      sprintf("%E", 123.45).should eq("1.234500E+02")
      sprintf("%G", 12345678.45).should eq("1.23457E+07")
      sprintf("%a", 12345678.45).should eq("0x1.78c29ce666666p+23")
      sprintf("%A", 12345678.45).should eq("0X1.78C29CE666666P+23")
      sprintf("%100.50g", 123.45).should eq("                                                  123.4500000000000028421709430404007434844970703125")

      sprintf("%.2f", 2.536_f32).should eq("2.54")
      sprintf("%0*.*f", [10, 2, 2.536_f32]).should eq("0000002.54")

      expect_raises(ArgumentError, "Expected dynamic value '*' to be an Int - \"not a number\" (String)") do
        sprintf("%*f", ["not a number", 2.536_f32])
      end

      sprintf("%12.2f %12.2f %6.2f %.2f", {2.0, 3.0, 4.0, 5.0}).should eq("        2.00         3.00   4.00 5.00")

      sprintf("%f", 1e15).should eq("1000000000000000.000000")
    end
  end

  context "strings" do
    it "works" do
      sprintf("%s", 'a').should eq("a")
      sprintf("%-s", 'a').should eq("a")
      sprintf("%20s", 'a').should eq("                   a")
      sprintf("%-20s", 'a').should eq("a                   ")
      sprintf("%*s", [10, 123]).should eq("       123")
      sprintf("%*s", [-10, 123]).should eq("123       ")
      sprintf("%.5s", "foo bar baz").should eq("foo b")
      sprintf("%.*s", [5, "foo bar baz"]).should eq("foo b")
      sprintf("%*.*s", [20, 5, "foo bar baz"]).should eq("               foo b")
      sprintf("%-*.*s", [20, 5, "foo bar baz"]).should eq("foo b               ")
    end

    it "calls to_s on non-strings" do
      span = 1.second
      sprintf("%s", span).should eq(span.to_s)
    end
  end

  context "plain substitution" do
    it "substitutes one placeholder" do
      sprintf("change %{this}", {"this" => "nothing"}).should eq "change nothing"
      sprintf("change %{this}", {this: "nothing"}).should eq "change nothing"
    end

    it "substitutes multiple placeholder" do
      sprintf("change %{this} and %{more}", {"this" => "nothing", "more" => "something"}).should eq "change nothing and something"
      sprintf("change %{this} and %{more}", {this: "nothing", more: "something"}).should eq "change nothing and something"
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
      sprintf("change %<this>.2f", {"this" => 23.456}).should eq "change 23.46"
      sprintf("change %<this>.2f", {this: 23.456}).should eq "change 23.46"
    end
  end
end
