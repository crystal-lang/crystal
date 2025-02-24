require "./spec_helper"
require "../support/number"
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

  if String::Formatter::HAS_RYU_PRINTF
    describe "floats" do
      context "fixed format" do
        it "works" do
          assert_sprintf "%f", 123, "123.000000"

          assert_sprintf "%12f", 123.45, "  123.450000"
          assert_sprintf "%-12f", 123.45, "123.450000  "
          assert_sprintf "% f", 123.45, " 123.450000"
          assert_sprintf "%+f", 123, "+123.000000"
          assert_sprintf "%012f", 123, "00123.000000"
          assert_sprintf "%.f", 1234.56, "1235"
          assert_sprintf "%.2f", 1234.5678, "1234.57"
          assert_sprintf "%10.2f", 1234.5678, "   1234.57"
          assert_sprintf "%*.2f", [10, 1234.5678], "   1234.57"
          assert_sprintf "%*.*f", [10, 2, 1234.5678], "   1234.57"
          assert_sprintf "%.2f", 2.536_f32, "2.54"
          assert_sprintf "%+0*.*f", [10, 2, 2.536_f32], "+000002.54"
          assert_sprintf "%#.0f", 1234.56, "1235."
          assert_sprintf "%#.1f", 1234.56, "1234.6"

          expect_raises(ArgumentError, "Expected dynamic value '*' to be an Int - \"not a number\" (String)") do
            sprintf("%*f", ["not a number", 2.536_f32])
          end

          assert_sprintf "%12.2f %12.2f %6.2f %.2f", [2.0, 3.0, 4.0, 5.0], "        2.00         3.00   4.00 5.00"

          assert_sprintf "%f", 1e15, "1000000000000000.000000"
        end
      end

      context "scientific format" do
        it "works" do
          assert_sprintf "%e", 123.45, "1.234500e+02"
          assert_sprintf "%E", 123.45, "1.234500E+02"

          assert_sprintf "%e", Float64::MAX, "1.797693e+308"
          assert_sprintf "%e", Float64::MIN_POSITIVE, "2.225074e-308"
          assert_sprintf "%e", Float64::MIN_SUBNORMAL, "4.940656e-324"
          assert_sprintf "%e", 0.0, "0.000000e+00"
          assert_sprintf "%e", -0.0, "-0.000000e+00"
          assert_sprintf "%e", -Float64::MIN_SUBNORMAL, "-4.940656e-324"
          assert_sprintf "%e", -Float64::MIN_POSITIVE, "-2.225074e-308"
          assert_sprintf "%e", Float64::MIN, "-1.797693e+308"
        end

        context "width specifier" do
          it "sets the minimum length of the string" do
            assert_sprintf "%20e", 123.45, "        1.234500e+02"
            assert_sprintf "%20e", -123.45, "       -1.234500e+02"
            assert_sprintf "%+20e", 123.45, "       +1.234500e+02"

            assert_sprintf "%13e", 123.45, " 1.234500e+02"
            assert_sprintf "%13e", -123.45, "-1.234500e+02"
            assert_sprintf "%+13e", 123.45, "+1.234500e+02"

            assert_sprintf "%12e", 123.45, "1.234500e+02"
            assert_sprintf "%12e", -123.45, "-1.234500e+02"
            assert_sprintf "%+12e", 123.45, "+1.234500e+02"

            assert_sprintf "%2e", 123.45, "1.234500e+02"
            assert_sprintf "%2e", -123.45, "-1.234500e+02"
            assert_sprintf "%+2e", 123.45, "+1.234500e+02"
          end

          it "left-justifies on negative width" do
            assert_sprintf "%*e", [-20, 123.45], "1.234500e+02        "
          end
        end

        context "precision specifier" do
          it "sets the minimum length of the fractional part" do
            assert_sprintf "%.0e", 2.0, "2e+00"
            assert_sprintf "%.0e", 2.5.prev_float, "2e+00"
            assert_sprintf "%.0e", 2.5, "2e+00"
            assert_sprintf "%.0e", 2.5.next_float, "3e+00"
            assert_sprintf "%.0e", 3.0, "3e+00"
            assert_sprintf "%.0e", 3.5.prev_float, "3e+00"
            assert_sprintf "%.0e", 3.5, "4e+00"
            assert_sprintf "%.0e", 3.5.next_float, "4e+00"
            assert_sprintf "%.0e", 4.0, "4e+00"

            assert_sprintf "%.0e", 9.5, "1e+01"

            assert_sprintf "%.100e", 1.1, "1.1000000000000000888178419700125232338905334472656250000000000000000000000000000000000000000000000000e+00"

            assert_sprintf "%.10000e", 1.0, "1.#{"0" * 10000}e+00"

            assert_sprintf "%.1000e", Float64::MIN_POSITIVE.prev_float,
              "2.2250738585072008890245868760858598876504231122409594654935248025624400092282356951" \
              "787758888037591552642309780950434312085877387158357291821993020294379224223559819827" \
              "501242041788969571311791082261043971979604000454897391938079198936081525613113376149" \
              "842043271751033627391549782731594143828136275113838604094249464942286316695429105080" \
              "201815926642134996606517803095075913058719846423906068637102005108723282784678843631" \
              "944515866135041223479014792369585208321597621066375401613736583044193603714778355306" \
              "682834535634005074073040135602968046375918583163124224521599262546494300836851861719" \
              "422417646455137135420132217031370496583210154654068035397417906022589503023501937519" \
              "773030945763173210852507299305089761582519159720757232455434770912461317493580281734" \
              "466552734375000000000000000000000000000000000000000000000000000000000000000000000000" \
              "000000000000000000000000000000000000000000000000000000000000000000000000000000000000" \
              "000000000000000000000000000000000000000000000000000000000000000000000000000000e-308"
          end

          it "can be used with width" do
            assert_sprintf "%20.13e", 123.45, " 1.2345000000000e+02"
            assert_sprintf "%20.13e", -123.45, "-1.2345000000000e+02"
            assert_sprintf "%20.13e", 0.0, " 0.0000000000000e+00"

            assert_sprintf "%-20.13e", 123.45, "1.2345000000000e+02 "
            assert_sprintf "%-20.13e", -123.45, "-1.2345000000000e+02"
            assert_sprintf "%-20.13e", 0.0, "0.0000000000000e+00 "

            assert_sprintf "%8.13e", 123.45, "1.2345000000000e+02"
            assert_sprintf "%8.13e", -123.45, "-1.2345000000000e+02"
            assert_sprintf "%8.13e", 0.0, "0.0000000000000e+00"
          end

          it "is ignored if precision argument is negative" do
            assert_sprintf "%.*e", [-2, 123.45], "1.234500e+02"
          end
        end

        context "sharp flag" do
          it "prints a decimal point even if no digits follow" do
            assert_sprintf "%#.0e", 1.0, "1.e+00"
            assert_sprintf "%#.0e", 10000.0, "1.e+04"
            assert_sprintf "%#.0e", 1.0e+23, "1.e+23"
            assert_sprintf "%#.0e", 1.0e-100, "1.e-100"
            assert_sprintf "%#.0e", 0.0, "0.e+00"
            assert_sprintf "%#.0e", -0.0, "-0.e+00"
          end
        end

        context "plus flag" do
          it "writes a plus sign for positive values" do
            assert_sprintf "%+e", 123.45, "+1.234500e+02"
            assert_sprintf "%+e", -123.45, "-1.234500e+02"
            assert_sprintf "%+e", 0.0, "+0.000000e+00"
          end

          it "writes plus sign after left space-padding" do
            assert_sprintf "%+20e", 123.45, "       +1.234500e+02"
            assert_sprintf "%+20e", -123.45, "       -1.234500e+02"
            assert_sprintf "%+20e", 0.0, "       +0.000000e+00"
          end

          it "writes plus sign before left zero-padding" do
            assert_sprintf "%+020e", 123.45, "+00000001.234500e+02"
            assert_sprintf "%+020e", -123.45, "-00000001.234500e+02"
            assert_sprintf "%+020e", 0.0, "+00000000.000000e+00"
          end
        end

        context "space flag" do
          it "writes a space for positive values" do
            assert_sprintf "% e", 123.45, " 1.234500e+02"
            assert_sprintf "% e", -123.45, "-1.234500e+02"
            assert_sprintf "% e", 0.0, " 0.000000e+00"
          end

          it "writes space before left space-padding" do
            assert_sprintf "% 20e", 123.45, "        1.234500e+02"
            assert_sprintf "% 20e", -123.45, "       -1.234500e+02"
            assert_sprintf "% 20e", 0.0, "        0.000000e+00"

            assert_sprintf "% 020e", 123.45, " 00000001.234500e+02"
            assert_sprintf "% 020e", -123.45, "-00000001.234500e+02"
            assert_sprintf "% 020e", 0.0, " 00000000.000000e+00"
          end

          it "is ignored if plus flag is also specified" do
            assert_sprintf "% +e", 123.45, "+1.234500e+02"
            assert_sprintf "%+ e", -123.45, "-1.234500e+02"
          end
        end

        context "zero flag" do
          it "left-pads the result with zeros" do
            assert_sprintf "%020e", 123.45, "000000001.234500e+02"
            assert_sprintf "%020e", -123.45, "-00000001.234500e+02"
            assert_sprintf "%020e", 0.0, "000000000.000000e+00"
          end

          it "is ignored if string is left-justified" do
            assert_sprintf "%-020e", 123.45, "1.234500e+02        "
            assert_sprintf "%-020e", -123.45, "-1.234500e+02       "
            assert_sprintf "%-020e", 0.0, "0.000000e+00        "
          end

          it "can be used with precision" do
            assert_sprintf "%020.12e", 123.45, "001.234500000000e+02"
            assert_sprintf "%020.12e", -123.45, "-01.234500000000e+02"
            assert_sprintf "%020.12e", 0.0, "000.000000000000e+00"
          end
        end

        context "minus flag" do
          it "left-justifies the string" do
            assert_sprintf "%-20e", 123.45, "1.234500e+02        "
            assert_sprintf "%-20e", -123.45, "-1.234500e+02       "
            assert_sprintf "%-20e", 0.0, "0.000000e+00        "
          end
        end
      end

      context "general format" do
        it "works" do
          assert_sprintf "%g", 123.45, "123.45"
          assert_sprintf "%G", 123.45, "123.45"

          assert_sprintf "%g", 1.2345e-5, "1.2345e-05"
          assert_sprintf "%G", 1.2345e-5, "1.2345E-05"

          assert_sprintf "%g", 1.2345e+25, "1.2345e+25"
          assert_sprintf "%G", 1.2345e+25, "1.2345E+25"

          assert_sprintf "%g", Float64::MAX, "1.79769e+308"
          assert_sprintf "%g", Float64::MIN_POSITIVE, "2.22507e-308"
          assert_sprintf "%g", Float64::MIN_SUBNORMAL, "4.94066e-324"
          assert_sprintf "%g", 0.0, "0"
          assert_sprintf "%g", -0.0, "-0"
          assert_sprintf "%g", -Float64::MIN_SUBNORMAL, "-4.94066e-324"
          assert_sprintf "%g", -Float64::MIN_POSITIVE, "-2.22507e-308"
          assert_sprintf "%g", Float64::MIN, "-1.79769e+308"
        end

        context "width specifier" do
          it "sets the minimum length of the string" do
            assert_sprintf "%10g", 123.45, "    123.45"
            assert_sprintf "%10g", -123.45, "   -123.45"
            assert_sprintf "%+10g", 123.45, "   +123.45"

            assert_sprintf "%7g", 123.45, " 123.45"
            assert_sprintf "%7g", -123.45, "-123.45"
            assert_sprintf "%+7g", 123.45, "+123.45"

            assert_sprintf "%6g", 123.45, "123.45"
            assert_sprintf "%6g", -123.45, "-123.45"
            assert_sprintf "%+6g", 123.45, "+123.45"

            assert_sprintf "%2g", 123.45, "123.45"
            assert_sprintf "%2g", -123.45, "-123.45"
            assert_sprintf "%+2g", 123.45, "+123.45"
          end

          it "left-justifies on negative width" do
            assert_sprintf "%*g", [-10, 123.45], "123.45    "
          end
        end

        context "precision specifier" do
          it "sets the precision of the value" do
            assert_sprintf "%.0g", 123.45, "1e+02"
            assert_sprintf "%.1g", 123.45, "1e+02"
            assert_sprintf "%.2g", 123.45, "1.2e+02"
            assert_sprintf "%.3g", 123.45, "123"
            assert_sprintf "%.4g", 123.45, "123.5"
            assert_sprintf "%.5g", 123.45, "123.45"
            assert_sprintf "%.6g", 123.45, "123.45"
            assert_sprintf "%.7g", 123.45, "123.45"
            assert_sprintf "%.8g", 123.45, "123.45"

            assert_sprintf "%.1000g", 123.45, "123.4500000000000028421709430404007434844970703125"

            assert_sprintf "%.0g", 1.23e-45, "1e-45"
            assert_sprintf "%.1g", 1.23e-45, "1e-45"
            assert_sprintf "%.2g", 1.23e-45, "1.2e-45"
            assert_sprintf "%.3g", 1.23e-45, "1.23e-45"
            assert_sprintf "%.4g", 1.23e-45, "1.23e-45"
            assert_sprintf "%.5g", 1.23e-45, "1.23e-45"
            assert_sprintf "%.6g", 1.23e-45, "1.23e-45"

            assert_sprintf "%.1000g", 1e-5, "1.0000000000000000818030539140313095458623138256371021270751953125e-05"
          end

          it "can be used with width" do
            assert_sprintf "%10.1g", 123.45, "     1e+02"
            assert_sprintf "%10.2g", 123.45, "   1.2e+02"
            assert_sprintf "%10.3g", 123.45, "       123"
            assert_sprintf "%10.4g", 123.45, "     123.5"
            assert_sprintf "%10.5g", 123.45, "    123.45"
            assert_sprintf "%10.1g", -123.45, "    -1e+02"
            assert_sprintf "%10.2g", -123.45, "  -1.2e+02"
            assert_sprintf "%10.3g", -123.45, "      -123"
            assert_sprintf "%10.4g", -123.45, "    -123.5"
            assert_sprintf "%10.5g", -123.45, "   -123.45"
            assert_sprintf "%10.5g", 0, "         0"

            assert_sprintf "%-10.1g", 123.45, "1e+02     "
            assert_sprintf "%-10.2g", 123.45, "1.2e+02   "
            assert_sprintf "%-10.3g", 123.45, "123       "
            assert_sprintf "%-10.4g", 123.45, "123.5     "
            assert_sprintf "%-10.5g", 123.45, "123.45    "
            assert_sprintf "%-10.1g", -123.45, "-1e+02    "
            assert_sprintf "%-10.2g", -123.45, "-1.2e+02  "
            assert_sprintf "%-10.3g", -123.45, "-123      "
            assert_sprintf "%-10.4g", -123.45, "-123.5    "
            assert_sprintf "%-10.5g", -123.45, "-123.45   "
            assert_sprintf "%-10.5g", 0, "0         "

            assert_sprintf "%3.1g", 123.45, "1e+02"
            assert_sprintf "%3.2g", 123.45, "1.2e+02"
            assert_sprintf "%3.3g", 123.45, "123"
            assert_sprintf "%3.4g", 123.45, "123.5"
            assert_sprintf "%3.5g", 123.45, "123.45"
            assert_sprintf "%3.1g", -123.45, "-1e+02"
            assert_sprintf "%3.2g", -123.45, "-1.2e+02"
            assert_sprintf "%3.3g", -123.45, "-123"
            assert_sprintf "%3.4g", -123.45, "-123.5"
            assert_sprintf "%3.5g", -123.45, "-123.45"

            assert_sprintf "%1000.800g", 123.45, "#{" " * 950}123.4500000000000028421709430404007434844970703125"
          end

          it "is ignored if precision argument is negative" do
            assert_sprintf "%.*g", [-2, 123.45], "123.45"
          end
        end

        context "sharp flag" do
          it "prints decimal point and trailing zeros" do
            assert_sprintf "%#.0g", 12345, "1.e+04"
            assert_sprintf "%#.6g", 12345, "12345.0"
            assert_sprintf "%#.10g", 12345, "12345.00000"
            assert_sprintf "%#.100g", 12345, "12345.#{"0" * 95}"
            assert_sprintf "%#.1000g", 12345, "12345.#{"0" * 995}"

            assert_sprintf "%#.0g", 1e-5, "1.e-05"
            assert_sprintf "%#.6g", 1e-5, "1.00000e-05"
            assert_sprintf "%#.10g", 1e-5, "1.000000000e-05"
            assert_sprintf "%#.100g", 1e-5, "1.0000000000000000818030539140313095458623138256371021270751953125#{"0" * 35}e-05"
            assert_sprintf "%#.1000g", 1e-5, "1.0000000000000000818030539140313095458623138256371021270751953125#{"0" * 935}e-05"

            assert_sprintf "%#15.0g", 12345, "         1.e+04"
            assert_sprintf "%#15.6g", 12345, "        12345.0"
            assert_sprintf "%#15.10g", 12345, "    12345.00000"
          end
        end

        context "plus flag" do
          it "writes a plus sign for positive values" do
            assert_sprintf "%+g", 123.45, "+123.45"
            assert_sprintf "%+g", -123.45, "-123.45"
            assert_sprintf "%+g", 0.0, "+0"
          end

          it "writes plus sign after left space-padding" do
            assert_sprintf "%+10g", 123.45, "   +123.45"
            assert_sprintf "%+10g", -123.45, "   -123.45"
            assert_sprintf "%+10g", 0.0, "        +0"
          end

          it "writes plus sign before left zero-padding" do
            assert_sprintf "%+010g", 123.45, "+000123.45"
            assert_sprintf "%+010g", -123.45, "-000123.45"
            assert_sprintf "%+010g", 0.0, "+000000000"
          end
        end

        context "space flag" do
          it "writes a space for positive values" do
            assert_sprintf "% g", 123.45, " 123.45"
            assert_sprintf "% g", -123.45, "-123.45"
            assert_sprintf "% g", 0.0, " 0"
          end

          it "writes space before left space-padding" do
            assert_sprintf "% 10g", 123.45, "    123.45"
            assert_sprintf "% 10g", -123.45, "   -123.45"
            assert_sprintf "% 10g", 0.0, "         0"

            assert_sprintf "% 010g", 123.45, " 000123.45"
            assert_sprintf "% 010g", -123.45, "-000123.45"
            assert_sprintf "% 010g", 0.0, " 000000000"
          end

          it "is ignored if plus flag is also specified" do
            assert_sprintf "% +g", 123.45, "+123.45"
            assert_sprintf "%+ g", -123.45, "-123.45"
          end
        end

        context "zero flag" do
          it "left-pads the result with zeros" do
            assert_sprintf "%010g", 123.45, "0000123.45"
            assert_sprintf "%010g", -123.45, "-000123.45"
            assert_sprintf "%010g", 0.0, "0000000000"
          end

          it "is ignored if string is left-justified" do
            assert_sprintf "%-010g", 123.45, "123.45    "
            assert_sprintf "%-010g", -123.45, "-123.45   "
            assert_sprintf "%-010g", 0.0, "0         "
          end

          it "can be used with precision" do
            assert_sprintf "%010.2g", 123.45, "0001.2e+02"
            assert_sprintf "%010.2g", -123.45, "-001.2e+02"
            assert_sprintf "%010.2g", 0.0, "0000000000"
          end
        end

        context "minus flag" do
          it "left-justifies the string" do
            assert_sprintf "%-10g", 123.45, "123.45    "
            assert_sprintf "%-10g", -123.45, "-123.45   "
            assert_sprintf "%-10g", 0.0, "0         "

            assert_sprintf "%- 10g", 123.45, " 123.45   "
            assert_sprintf "%- 10g", -123.45, "-123.45   "
            assert_sprintf "%- 10g", 0.0, " 0        "
          end
        end
      end

      context "hex format" do
        it "works" do
          assert_sprintf "%a", 1194684.0, "0x1.23abcp+20"
          assert_sprintf "%A", 1194684.0, "0X1.23ABCP+20"
          assert_sprintf "%a", 12345678.45, "0x1.78c29ce666666p+23"
          assert_sprintf "%A", 12345678.45, "0X1.78C29CE666666P+23"

          assert_sprintf "%a", Float64::MAX, "0x1.fffffffffffffp+1023"
          assert_sprintf "%a", Float64::MIN_POSITIVE, "0x1p-1022"
          assert_sprintf "%a", Float64::MIN_SUBNORMAL, "0x0.0000000000001p-1022"
          assert_sprintf "%a", 0.0, "0x0p+0"
          assert_sprintf "%a", -0.0, "-0x0p+0"
          assert_sprintf "%a", -Float64::MIN_SUBNORMAL, "-0x0.0000000000001p-1022"
          assert_sprintf "%a", -Float64::MIN_POSITIVE, "-0x1p-1022"
          assert_sprintf "%a", Float64::MIN, "-0x1.fffffffffffffp+1023"
        end

        context "width specifier" do
          it "sets the minimum length of the string" do
            assert_sprintf "%20a", hexfloat("0x1p+0"), "              0x1p+0"
            assert_sprintf "%20a", hexfloat("0x1.2p+0"), "            0x1.2p+0"
            assert_sprintf "%20a", hexfloat("0x1.23p+0"), "           0x1.23p+0"
            assert_sprintf "%20a", hexfloat("0x1.234p+0"), "          0x1.234p+0"
            assert_sprintf "%20a", hexfloat("0x1.2345p+0"), "         0x1.2345p+0"
            assert_sprintf "%20a", hexfloat("0x1.23456p+0"), "        0x1.23456p+0"
            assert_sprintf "%20a", hexfloat("0x1.234567p+0"), "       0x1.234567p+0"
            assert_sprintf "%20a", hexfloat("0x1.2345678p+0"), "      0x1.2345678p+0"
            assert_sprintf "%20a", hexfloat("0x1.23456789p+0"), "     0x1.23456789p+0"
            assert_sprintf "%20a", hexfloat("0x1.23456789ap+0"), "    0x1.23456789ap+0"
            assert_sprintf "%20a", hexfloat("0x1.23456789abp+0"), "   0x1.23456789abp+0"
            assert_sprintf "%20a", hexfloat("0x1.23456789abcp+0"), "  0x1.23456789abcp+0"

            assert_sprintf "%20a", hexfloat("-0x1p+0"), "             -0x1p+0"
            assert_sprintf "%20a", hexfloat("-0x1.2p+0"), "           -0x1.2p+0"
            assert_sprintf "%20a", hexfloat("-0x1.23p+0"), "          -0x1.23p+0"
            assert_sprintf "%20a", hexfloat("-0x1.234p+0"), "         -0x1.234p+0"
            assert_sprintf "%20a", hexfloat("-0x1.2345p+0"), "        -0x1.2345p+0"
            assert_sprintf "%20a", hexfloat("-0x1.23456p+0"), "       -0x1.23456p+0"
            assert_sprintf "%20a", hexfloat("-0x1.234567p+0"), "      -0x1.234567p+0"
            assert_sprintf "%20a", hexfloat("-0x1.2345678p+0"), "     -0x1.2345678p+0"
            assert_sprintf "%20a", hexfloat("-0x1.23456789p+0"), "    -0x1.23456789p+0"
            assert_sprintf "%20a", hexfloat("-0x1.23456789ap+0"), "   -0x1.23456789ap+0"
            assert_sprintf "%20a", hexfloat("-0x1.23456789abp+0"), "  -0x1.23456789abp+0"
            assert_sprintf "%20a", hexfloat("-0x1.23456789abcp+0"), " -0x1.23456789abcp+0"

            assert_sprintf "%+20a", 1194684.0, "      +0x1.23abcp+20"

            assert_sprintf "%14a", 1194684.0, " 0x1.23abcp+20"
            assert_sprintf "%14a", -1194684.0, "-0x1.23abcp+20"
            assert_sprintf "%+14a", 1194684.0, "+0x1.23abcp+20"

            assert_sprintf "%13a", 1194684.0, "0x1.23abcp+20"
            assert_sprintf "%13a", -1194684.0, "-0x1.23abcp+20"
            assert_sprintf "%+13a", 1194684.0, "+0x1.23abcp+20"

            assert_sprintf "%2a", 1194684.0, "0x1.23abcp+20"
            assert_sprintf "%2a", -1194684.0, "-0x1.23abcp+20"
            assert_sprintf "%+2a", 1194684.0, "+0x1.23abcp+20"
          end

          it "left-justifies on negative width" do
            assert_sprintf "%*a", [-20, 1194684.0], "0x1.23abcp+20       "
          end
        end

        context "precision specifier" do
          it "sets the minimum length of the fractional part" do
            assert_sprintf "%.0a", 0.0, "0x0p+0"

            assert_sprintf "%.0a", (Float64::MIN_POSITIVE / 2).prev_float, "0x0p-1022"
            assert_sprintf "%.0a", Float64::MIN_POSITIVE / 2, "0x0p-1022"
            assert_sprintf "%.0a", (Float64::MIN_POSITIVE / 2).next_float, "0x1p-1022"
            assert_sprintf "%.0a", Float64::MIN_POSITIVE.prev_float, "0x1p-1022"
            assert_sprintf "%.0a", Float64::MIN_POSITIVE, "0x1p-1022"

            assert_sprintf "%.0a", 0.0625, "0x1p-4"
            assert_sprintf "%.0a", 0.0625.next_float, "0x1p-4"
            assert_sprintf "%.0a", 0.09375.prev_float, "0x1p-4"
            assert_sprintf "%.0a", 0.09375, "0x2p-4"
            assert_sprintf "%.0a", 0.09375.next_float, "0x2p-4"
            assert_sprintf "%.0a", 0.125.prev_float, "0x2p-4"
            assert_sprintf "%.0a", 0.125, "0x1p-3"

            assert_sprintf "%.1a", 2.0, "0x1.0p+1"
            assert_sprintf "%.1a", 2.0.next_float, "0x1.0p+1"
            assert_sprintf "%.1a", 2.0625.prev_float, "0x1.0p+1"
            assert_sprintf "%.1a", 2.0625, "0x1.0p+1"
            assert_sprintf "%.1a", 2.0625.next_float, "0x1.1p+1"
            assert_sprintf "%.1a", 2.125.prev_float, "0x1.1p+1"
            assert_sprintf "%.1a", 2.125, "0x1.1p+1"
            assert_sprintf "%.1a", 2.125.next_float, "0x1.1p+1"
            assert_sprintf "%.1a", 2.1875.prev_float, "0x1.1p+1"
            assert_sprintf "%.1a", 2.1875, "0x1.2p+1"
            assert_sprintf "%.1a", 2.1875.next_float, "0x1.2p+1"
            assert_sprintf "%.1a", 2.25.prev_float, "0x1.2p+1"
            assert_sprintf "%.1a", 2.25, "0x1.2p+1"

            assert_sprintf "%.1a", 60.0, "0x1.ep+5"
            assert_sprintf "%.1a", 60.0.next_float, "0x1.ep+5"
            assert_sprintf "%.1a", 61.0.prev_float, "0x1.ep+5"
            assert_sprintf "%.1a", 61.0, "0x1.ep+5"
            assert_sprintf "%.1a", 61.0.next_float, "0x1.fp+5"
            assert_sprintf "%.1a", 62.0.prev_float, "0x1.fp+5"
            assert_sprintf "%.1a", 62.0, "0x1.fp+5"
            assert_sprintf "%.1a", 62.0.next_float, "0x1.fp+5"
            assert_sprintf "%.1a", 63.0.prev_float, "0x1.fp+5"
            assert_sprintf "%.1a", 63.0, "0x2.0p+5"
            assert_sprintf "%.1a", 63.0.next_float, "0x2.0p+5"
            assert_sprintf "%.1a", 64.0.prev_float, "0x2.0p+5"
            assert_sprintf "%.1a", 64.0, "0x1.0p+6"

            assert_sprintf "%.4a", 65536.0, "0x1.0000p+16"
            assert_sprintf "%.4a", 65536.0.next_float, "0x1.0000p+16"
            assert_sprintf "%.4a", 65536.5.prev_float, "0x1.0000p+16"
            assert_sprintf "%.4a", 65536.5, "0x1.0000p+16"
            assert_sprintf "%.4a", 65536.5.next_float, "0x1.0001p+16"
            assert_sprintf "%.4a", 65537.0.prev_float, "0x1.0001p+16"
            assert_sprintf "%.4a", 65537.0, "0x1.0001p+16"
            assert_sprintf "%.4a", 65537.0.next_float, "0x1.0001p+16"
            assert_sprintf "%.4a", 65537.5.prev_float, "0x1.0001p+16"
            assert_sprintf "%.4a", 65537.5, "0x1.0002p+16"
            assert_sprintf "%.4a", 65537.5.next_float, "0x1.0002p+16"
            assert_sprintf "%.4a", 65538.0.prev_float, "0x1.0002p+16"
            assert_sprintf "%.4a", 65538.0, "0x1.0002p+16"

            assert_sprintf "%.4a", 131070.0, "0x1.fffep+16"
            assert_sprintf "%.4a", 131070.0.next_float, "0x1.fffep+16"
            assert_sprintf "%.4a", 131070.5.prev_float, "0x1.fffep+16"
            assert_sprintf "%.4a", 131070.5, "0x1.fffep+16"
            assert_sprintf "%.4a", 131070.5.next_float, "0x1.ffffp+16"
            assert_sprintf "%.4a", 131071.0.prev_float, "0x1.ffffp+16"
            assert_sprintf "%.4a", 131071.0, "0x1.ffffp+16"
            assert_sprintf "%.4a", 131071.0.next_float, "0x1.ffffp+16"
            assert_sprintf "%.4a", 131071.5.prev_float, "0x1.ffffp+16"
            assert_sprintf "%.4a", 131071.5, "0x2.0000p+16"
            assert_sprintf "%.4a", 131071.5.next_float, "0x2.0000p+16"
            assert_sprintf "%.4a", 131072.0.prev_float, "0x2.0000p+16"
            assert_sprintf "%.4a", 131072.0, "0x1.0000p+17"

            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x01, "0x0.000000000000p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x07, "0x0.000000000000p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x08, "0x0.000000000000p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x09, "0x0.000000000001p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x0f, "0x0.000000000001p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x10, "0x0.000000000001p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x11, "0x0.000000000001p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x17, "0x0.000000000001p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x18, "0x0.000000000002p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x19, "0x0.000000000002p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x1f, "0x0.000000000002p-1022"
            assert_sprintf "%.12a", Float64::MIN_SUBNORMAL * 0x20, "0x0.000000000002p-1022"

            assert_sprintf "%.17a", Float64::MAX, "0x1.fffffffffffff0000p+1023"
            assert_sprintf "%.16a", Float64::MAX, "0x1.fffffffffffff000p+1023"
            assert_sprintf "%.15a", Float64::MAX, "0x1.fffffffffffff00p+1023"
            assert_sprintf "%.14a", Float64::MAX, "0x1.fffffffffffff0p+1023"
            assert_sprintf "%.13a", Float64::MAX, "0x1.fffffffffffffp+1023"
            assert_sprintf "%.12a", Float64::MAX, "0x2.000000000000p+1023"
            assert_sprintf "%.11a", Float64::MAX, "0x2.00000000000p+1023"
            assert_sprintf "%.10a", Float64::MAX, "0x2.0000000000p+1023"
            assert_sprintf "%.9a", Float64::MAX, "0x2.000000000p+1023"
            assert_sprintf "%.8a", Float64::MAX, "0x2.00000000p+1023"
            assert_sprintf "%.7a", Float64::MAX, "0x2.0000000p+1023"
            assert_sprintf "%.6a", Float64::MAX, "0x2.000000p+1023"
            assert_sprintf "%.5a", Float64::MAX, "0x2.00000p+1023"
            assert_sprintf "%.4a", Float64::MAX, "0x2.0000p+1023"
            assert_sprintf "%.3a", Float64::MAX, "0x2.000p+1023"
            assert_sprintf "%.2a", Float64::MAX, "0x2.00p+1023"
            assert_sprintf "%.1a", Float64::MAX, "0x2.0p+1023"
            assert_sprintf "%.0a", Float64::MAX, "0x2p+1023"

            assert_sprintf "%.1000a", 1194684.0, "0x1.23abc#{"0" * 995}p+20"
          end

          it "can be used with width" do
            assert_sprintf "%20.8a", 1194684.0, "    0x1.23abc000p+20"
            assert_sprintf "%20.8a", -1194684.0, "   -0x1.23abc000p+20"
            assert_sprintf "%20.8a", 0.0, "     0x0.00000000p+0"

            assert_sprintf "%-20.8a", 1194684.0, "0x1.23abc000p+20    "
            assert_sprintf "%-20.8a", -1194684.0, "-0x1.23abc000p+20   "
            assert_sprintf "%-20.8a", 0.0, "0x0.00000000p+0     "

            assert_sprintf "%4.8a", 1194684.0, "0x1.23abc000p+20"
            assert_sprintf "%4.8a", -1194684.0, "-0x1.23abc000p+20"
            assert_sprintf "%4.8a", 0.0, "0x0.00000000p+0"
          end

          it "is ignored if precision argument is negative" do
            assert_sprintf "%.*a", [-2, 1194684.0], "0x1.23abcp+20"
          end
        end

        context "sharp flag" do
          it "prints a decimal point even if no digits follow" do
            assert_sprintf "%#a", 1.0, "0x1.p+0"
            assert_sprintf "%#a", Float64::MIN_POSITIVE, "0x1.p-1022"
            assert_sprintf "%#a", 2.0 ** -234, "0x1.p-234"
            assert_sprintf "%#a", 2.0 ** 1021, "0x1.p+1021"
            assert_sprintf "%#a", 0.0, "0x0.p+0"
            assert_sprintf "%#a", -0.0, "-0x0.p+0"

            assert_sprintf "%#.0a", 1.0, "0x1.p+0"
            assert_sprintf "%#.0a", Float64::MIN_POSITIVE, "0x1.p-1022"
            assert_sprintf "%#.0a", 2.0 ** -234, "0x1.p-234"
            assert_sprintf "%#.0a", 2.0 ** 1021, "0x1.p+1021"
            assert_sprintf "%#.0a", 1194684.0, "0x1.p+20"
            assert_sprintf "%#.0a", 0.0, "0x0.p+0"
            assert_sprintf "%#.0a", -0.0, "-0x0.p+0"
          end
        end

        context "plus flag" do
          it "writes a plus sign for positive values" do
            assert_sprintf "%+a", 1194684.0, "+0x1.23abcp+20"
            assert_sprintf "%+a", -1194684.0, "-0x1.23abcp+20"
            assert_sprintf "%+a", 0.0, "+0x0p+0"
          end

          it "writes plus sign after left space-padding" do
            assert_sprintf "%+20a", 1194684.0, "      +0x1.23abcp+20"
            assert_sprintf "%+20a", -1194684.0, "      -0x1.23abcp+20"
            assert_sprintf "%+20a", 0.0, "             +0x0p+0"
          end

          it "writes plus sign before left zero-padding" do
            assert_sprintf "%+020a", 1194684.0, "+0x0000001.23abcp+20"
            assert_sprintf "%+020a", -1194684.0, "-0x0000001.23abcp+20"
            assert_sprintf "%+020a", 0.0, "+0x00000000000000p+0"
          end
        end

        context "space flag" do
          it "writes a space for positive values" do
            assert_sprintf "% a", 1194684.0, " 0x1.23abcp+20"
            assert_sprintf "% a", -1194684.0, "-0x1.23abcp+20"
            assert_sprintf "% a", 0.0, " 0x0p+0"
          end

          it "writes space before left space-padding" do
            assert_sprintf "% 20a", 1194684.0, "       0x1.23abcp+20"
            assert_sprintf "% 20a", -1194684.0, "      -0x1.23abcp+20"
            assert_sprintf "% 20a", 0.0, "              0x0p+0"

            assert_sprintf "% 020a", 1194684.0, " 0x0000001.23abcp+20"
            assert_sprintf "% 020a", -1194684.0, "-0x0000001.23abcp+20"
            assert_sprintf "% 020a", 0.0, " 0x00000000000000p+0"
          end

          it "is ignored if plus flag is also specified" do
            assert_sprintf "% +a", 1194684.0, "+0x1.23abcp+20"
            assert_sprintf "%+ a", -1194684.0, "-0x1.23abcp+20"
          end
        end

        context "zero flag" do
          it "left-pads the result with zeros" do
            assert_sprintf "%020a", 1194684.0, "0x00000001.23abcp+20"
            assert_sprintf "%020a", -1194684.0, "-0x0000001.23abcp+20"
            assert_sprintf "%020a", 0.0, "0x000000000000000p+0"
          end

          it "is ignored if string is left-justified" do
            assert_sprintf "%-020a", 1194684.0, "0x1.23abcp+20       "
            assert_sprintf "%-020a", -1194684.0, "-0x1.23abcp+20      "
            assert_sprintf "%-020a", 0.0, "0x0p+0              "
          end

          it "can be used with precision" do
            assert_sprintf "%020.8a", 1194684.0, "0x00001.23abc000p+20"
            assert_sprintf "%020.8a", -1194684.0, "-0x0001.23abc000p+20"
            assert_sprintf "%020.8a", 0.0, "0x000000.00000000p+0"
          end
        end

        context "minus flag" do
          it "left-justifies the string" do
            assert_sprintf "%-20a", 1194684.0, "0x1.23abcp+20       "
            assert_sprintf "%-20a", -1194684.0, "-0x1.23abcp+20      "
            assert_sprintf "%-20a", 0.0, "0x0p+0              "
          end
        end
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
  else
    pending "floats"
  end

  context "chars" do
    it "works" do
      assert_sprintf "%c", 'a', "a"
      assert_sprintf "%3c", 'R', "  R"
      assert_sprintf "%-3c", 'L', "L  "
      assert_sprintf "%c", '▞', "▞"
      assert_sprintf "%c", 65, "A"
      assert_sprintf "%c", 66_i8, "B"
      assert_sprintf "%c", 67_i16, "C"
      assert_sprintf "%c", 68_i32, "D"
      assert_sprintf "%c", 69_i64, "E"
      assert_sprintf "%c", 97_u8, "a"
      assert_sprintf "%c", 98_u16, "b"
      assert_sprintf "%c", 99_u32, "c"
      assert_sprintf "%c", 100_u64, "d"
      assert_sprintf "%c", 0x259E, "▞"
    end

    it "raises if not a Char or Int" do
      expect_raises(ArgumentError, "Expected a char or integer") { sprintf("%c", "this") }
      expect_raises(ArgumentError, "Expected a char or integer") { sprintf("%c", 17.34) }
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
