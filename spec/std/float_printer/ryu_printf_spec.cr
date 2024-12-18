{% skip_file unless String::Formatter::HAS_RYU_PRINTF %}

# This file contains test cases derived from:
#
# * https://github.com/ulfjack/ryu
# * https://github.com/microsoft/STL/tree/main/tests/std/tests/P0067R5_charconv
#
# The following is their license:
#
#   Copyright 2020-2021 Junekey Jeon
#
#   The contents of this file may be used under the terms of
#   the Apache License v2.0 with LLVM Exceptions.
#
#      (See accompanying file LICENSE-Apache or copy at
#       https://llvm.org/foundation/relicensing/LICENSE.txt)
#
#   Alternatively, the contents of this file may be used under the terms of
#   the Boost Software License, Version 1.0.
#      (See accompanying file LICENSE-Boost or copy at
#       https://www.boost.org/LICENSE_1_0.txt)
#
#   Unless required by applicable law or agreed to in writing, this software
#   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.

require "spec"
require "../../support/number"
require "float/printer/ryu_printf"
require "big"
require "./ryu_printf_test_cases"

struct BigFloat
  def to_s_with_range(*, point_range : Range = -3..15)
    String.build do |io|
      to_s_with_range(io, point_range: point_range)
    end
  end

  def to_s_with_range(io : IO, *, point_range : Range = -3..15) : Nil
    cstr = LibGMP.mpf_get_str(nil, out decimal_exponent, 10, 0, self)
    length = LibC.strlen(cstr)
    buffer = Slice.new(cstr, length)

    # add negative sign
    if buffer[0]? == 45 # '-'
      io << '-'
      buffer = buffer[1..]
      length -= 1
    end

    point = decimal_exponent
    exp = point
    exp_mode = !point_range.includes?(point)
    point = 1 if exp_mode

    # add leading zero
    io << '0' if point < 1

    # add integer part digits
    if decimal_exponent > 0 && !exp_mode
      # whole number but not big enough to be exp form
      io.write_string buffer[0, {decimal_exponent, length}.min]
      buffer = buffer[{decimal_exponent, length}.min...]
      (point - length).times { io << '0' }
    elsif point > 0
      io.write_string buffer[0, point]
      buffer = buffer[point...]
    end

    # skip `.0000...`
    unless buffer.all?(&.=== '0')
      io << '.'

      # add leading zeros after point
      if point < 0
        (-point).times { io << '0' }
      end

      # add fractional part digits
      io.write_string buffer

      # print trailing 0 if whole number or exp notation of power of ten
      if (decimal_exponent >= length && !exp_mode) || ((exp != point || exp_mode) && length == 1)
        io << '0'
      end
    end

    # exp notation
    if exp_mode
      io << 'e'
      io << '+' if exp > 0
      (exp - 1).to_s(io)
    end
  end
end

private def fixed_reference(value, precision)
  if precision == 0
    value.to_big_i.to_s
  else
    BigFloat.new(value, 4096).to_s_with_range(point_range: ..)
  end
end

private def exp_reference(value, precision)
  BigFloat.new(value, 4096).to_s_with_range(point_range: 0...0)
end

private def ieee_parts_to_f64(sign, exponent, mantissa)
  ((sign ? 1_u64 << 63 : 0_u64) | (exponent.to_u64 << 52) | mantissa.to_u64).unsafe_as(Float64)
end

private macro expect_fixed(float, precision, string)
  Float::Printer::RyuPrintf.d2fixed({{ float }}, {{ precision }}).should eq({{ string }})
end

private macro expect_exp(float, precision, string)
  Float::Printer::RyuPrintf.d2exp({{ float }}, {{ precision }}).should eq({{ string }})
end

private macro expect_gen(float, precision, string, *, file = __FILE__, line = __LINE__)
  Float::Printer::RyuPrintf.d2gen({{ float }}, {{ precision }}).should eq({{ string }}), file: {{ file }}, line: {{ line }}
end

describe Float::Printer::RyuPrintf do
  describe ".d2fixed" do
    it "Basic" do
      expect_fixed(
        ieee_parts_to_f64(false, 1234, 99999), 0,
        "3291009114715486435425664845573426149758869524108446525879746560")
    end

    it "Zero" do
      expect_fixed(0.0, 4, "0.0000")
      expect_fixed(0.0, 3, "0.000")
      expect_fixed(0.0, 2, "0.00")
      expect_fixed(0.0, 1, "0.0")
      expect_fixed(0.0, 0, "0")
    end

    it "MinMax" do
      expect_fixed(ieee_parts_to_f64(false, 0, 1), 1074,
        "0.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004940656458412465441765687928682213723650598026143247644255856825006755072702087518652998363616359923797965646954457177309266567103559397963987747960107818781263007131903114045278458171678489821036887186360569987307230500063874091535649843873124733972731696151400317153853980741262385655911710266585566867681870395603106249319452715914924553293054565444011274801297099995419319894090804165633245247571478690147267801593552386115501348035264934720193790268107107491703332226844753335720832431936092382893458368060106011506169809753078342277318329247904982524730776375927247874656084778203734469699533647017972677717585125660551199131504891101451037862738167250955837389733598993664809941164205702637090279242767544565229087538682506419718265533447265625")

      expect_fixed(ieee_parts_to_f64(false, 2046, 0xFFFFFFFFFFFFFu64), 0,
        "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368")
    end

    it "AllPowersOfTen" do
      {% for tc in ALL_POWERS_OF_TEN %}
        expect_fixed({{ tc[0] }}, {{ tc[1] }}, fixed_reference({{ tc[0] }}, {{ tc[1] }}))
      {% end %}
    end

    it "RoundToEven" do
      expect_fixed(0.125, 3, "0.125")
      expect_fixed(0.125, 2, "0.12")
      expect_fixed(0.375, 3, "0.375")
      expect_fixed(0.375, 2, "0.38")
    end

    it "RoundToEvenInteger" do
      expect_fixed(2.5, 1, "2.5")
      expect_fixed(2.5, 0, "2")
      expect_fixed(3.5, 1, "3.5")
      expect_fixed(3.5, 0, "4")
    end

    it "NonRoundToEvenScenarios" do
      expect_fixed(0.748046875, 3, "0.748")
      expect_fixed(0.748046875, 2, "0.75")
      expect_fixed(0.748046875, 1, "0.7") # 0.75 would round to "0.8", but this is smaller

      expect_fixed(0.2509765625, 3, "0.251")
      expect_fixed(0.2509765625, 2, "0.25")
      expect_fixed(0.2509765625, 1, "0.3") # 0.25 would round to "0.2", but this is larger

      expect_fixed(ieee_parts_to_f64(false, 1021, 1), 54, "0.250000000000000055511151231257827021181583404541015625")
      expect_fixed(ieee_parts_to_f64(false, 1021, 1), 3, "0.250")
      expect_fixed(ieee_parts_to_f64(false, 1021, 1), 2, "0.25")
      expect_fixed(ieee_parts_to_f64(false, 1021, 1), 1, "0.3") # 0.25 would round to "0.2", but this is larger (again)
    end

    it "VaryingPrecision" do
      expect_fixed(1729.142857142857, 47, "1729.14285714285711037518922239542007446289062500000")
      expect_fixed(1729.142857142857, 46, "1729.1428571428571103751892223954200744628906250000")
      expect_fixed(1729.142857142857, 45, "1729.142857142857110375189222395420074462890625000")
      expect_fixed(1729.142857142857, 44, "1729.14285714285711037518922239542007446289062500")
      expect_fixed(1729.142857142857, 43, "1729.1428571428571103751892223954200744628906250")
      expect_fixed(1729.142857142857, 42, "1729.142857142857110375189222395420074462890625")
      expect_fixed(1729.142857142857, 41, "1729.14285714285711037518922239542007446289062")
      expect_fixed(1729.142857142857, 40, "1729.1428571428571103751892223954200744628906")
      expect_fixed(1729.142857142857, 39, "1729.142857142857110375189222395420074462891")
      expect_fixed(1729.142857142857, 38, "1729.14285714285711037518922239542007446289")
      expect_fixed(1729.142857142857, 37, "1729.1428571428571103751892223954200744629")
      expect_fixed(1729.142857142857, 36, "1729.142857142857110375189222395420074463")
      expect_fixed(1729.142857142857, 35, "1729.14285714285711037518922239542007446")
      expect_fixed(1729.142857142857, 34, "1729.1428571428571103751892223954200745")
      expect_fixed(1729.142857142857, 33, "1729.142857142857110375189222395420074")
      expect_fixed(1729.142857142857, 32, "1729.14285714285711037518922239542007")
      expect_fixed(1729.142857142857, 31, "1729.1428571428571103751892223954201")
      expect_fixed(1729.142857142857, 30, "1729.142857142857110375189222395420")
      expect_fixed(1729.142857142857, 29, "1729.14285714285711037518922239542")
      expect_fixed(1729.142857142857, 28, "1729.1428571428571103751892223954")
      expect_fixed(1729.142857142857, 27, "1729.142857142857110375189222395")
      expect_fixed(1729.142857142857, 26, "1729.14285714285711037518922240")
      expect_fixed(1729.142857142857, 25, "1729.1428571428571103751892224")
      expect_fixed(1729.142857142857, 24, "1729.142857142857110375189222")
      expect_fixed(1729.142857142857, 23, "1729.14285714285711037518922")
      expect_fixed(1729.142857142857, 22, "1729.1428571428571103751892")
      expect_fixed(1729.142857142857, 21, "1729.142857142857110375189")
      expect_fixed(1729.142857142857, 20, "1729.14285714285711037519")
      expect_fixed(1729.142857142857, 19, "1729.1428571428571103752")
      expect_fixed(1729.142857142857, 18, "1729.142857142857110375")
      expect_fixed(1729.142857142857, 17, "1729.14285714285711038")
      expect_fixed(1729.142857142857, 16, "1729.1428571428571104")
      expect_fixed(1729.142857142857, 15, "1729.142857142857110")
      expect_fixed(1729.142857142857, 14, "1729.14285714285711")
      expect_fixed(1729.142857142857, 13, "1729.1428571428571")
      expect_fixed(1729.142857142857, 12, "1729.142857142857")
      expect_fixed(1729.142857142857, 11, "1729.14285714286")
      expect_fixed(1729.142857142857, 10, "1729.1428571429")
      expect_fixed(1729.142857142857, 9, "1729.142857143")
      expect_fixed(1729.142857142857, 8, "1729.14285714")
      expect_fixed(1729.142857142857, 7, "1729.1428571")
      expect_fixed(1729.142857142857, 6, "1729.142857")
      expect_fixed(1729.142857142857, 5, "1729.14286")
      expect_fixed(1729.142857142857, 4, "1729.1429")
      expect_fixed(1729.142857142857, 3, "1729.143")
      expect_fixed(1729.142857142857, 2, "1729.14")
      expect_fixed(1729.142857142857, 1, "1729.1")
      expect_fixed(1729.142857142857, 0, "1729")
    end

    it "Carrying" do
      expect_fixed(0.0009, 4, "0.0009")
      expect_fixed(0.0009, 3, "0.001")
      expect_fixed(0.0029, 4, "0.0029")
      expect_fixed(0.0029, 3, "0.003")
      expect_fixed(0.0099, 4, "0.0099")
      expect_fixed(0.0099, 3, "0.010")
      expect_fixed(0.0299, 4, "0.0299")
      expect_fixed(0.0299, 3, "0.030")
      expect_fixed(0.0999, 4, "0.0999")
      expect_fixed(0.0999, 3, "0.100")
      expect_fixed(0.2999, 4, "0.2999")
      expect_fixed(0.2999, 3, "0.300")
      expect_fixed(0.9999, 4, "0.9999")
      expect_fixed(0.9999, 3, "1.000")
      expect_fixed(2.9999, 4, "2.9999")
      expect_fixed(2.9999, 3, "3.000")
      expect_fixed(9.9999, 4, "9.9999")
      expect_fixed(9.9999, 3, "10.000")
      expect_fixed(29.9999, 4, "29.9999")
      expect_fixed(29.9999, 3, "30.000")
      expect_fixed(99.9999, 4, "99.9999")
      expect_fixed(99.9999, 3, "100.000")
      expect_fixed(299.9999, 4, "299.9999")
      expect_fixed(299.9999, 3, "300.000")

      expect_fixed(0.09, 2, "0.09")
      expect_fixed(0.09, 1, "0.1")
      expect_fixed(0.29, 2, "0.29")
      expect_fixed(0.29, 1, "0.3")
      expect_fixed(0.99, 2, "0.99")
      expect_fixed(0.99, 1, "1.0")
      expect_fixed(2.99, 2, "2.99")
      expect_fixed(2.99, 1, "3.0")
      expect_fixed(9.99, 2, "9.99")
      expect_fixed(9.99, 1, "10.0")
      expect_fixed(29.99, 2, "29.99")
      expect_fixed(29.99, 1, "30.0")
      expect_fixed(99.99, 2, "99.99")
      expect_fixed(99.99, 1, "100.0")
      expect_fixed(299.99, 2, "299.99")
      expect_fixed(299.99, 1, "300.0")

      expect_fixed(0.9, 1, "0.9")
      expect_fixed(0.9, 0, "1")
      expect_fixed(2.9, 1, "2.9")
      expect_fixed(2.9, 0, "3")
      expect_fixed(9.9, 1, "9.9")
      expect_fixed(9.9, 0, "10")
      expect_fixed(29.9, 1, "29.9")
      expect_fixed(29.9, 0, "30")
      expect_fixed(99.9, 1, "99.9")
      expect_fixed(99.9, 0, "100")
      expect_fixed(299.9, 1, "299.9")
      expect_fixed(299.9, 0, "300")
    end

    it "RoundingResultZero" do
      expect_fixed(0.004, 3, "0.004")
      expect_fixed(0.004, 2, "0.00")
      expect_fixed(0.4, 1, "0.4")
      expect_fixed(0.4, 0, "0")
      expect_fixed(0.5, 1, "0.5")
      expect_fixed(0.5, 0, "0")
    end

    it "AllBinaryExponents" do
      {% for tc in ALL_BINARY_EXPONENTS %}
        expect_fixed({{ tc[0] }}, {{ tc[1] }}, fixed_reference({{ tc[0] }}, {{ tc[1] }}))
      {% end %}
    end

    it "Regression" do
      expect_fixed(7.018232e-82, 6, "0.000000")
    end
  end

  describe ".d2exp" do
    it "Basic" do
      expect_exp(ieee_parts_to_f64(false, 1234, 99999), 62,
        "3.29100911471548643542566484557342614975886952410844652587974656e+63")
    end

    it "Zero" do
      expect_exp(0.0, 4, "0.0000e+0")
      expect_exp(0.0, 3, "0.000e+0")
      expect_exp(0.0, 2, "0.00e+0")
      expect_exp(0.0, 1, "0.0e+0")
      expect_exp(0.0, 0, "0e+0")
    end

    it "MinMax" do
      expect_exp(ieee_parts_to_f64(false, 0, 1), 750,
        "4.940656458412465441765687928682213723650598026143247644255856825006755072702087518652998363616359923797965646954457177309266567103559397963987747960107818781263007131903114045278458171678489821036887186360569987307230500063874091535649843873124733972731696151400317153853980741262385655911710266585566867681870395603106249319452715914924553293054565444011274801297099995419319894090804165633245247571478690147267801593552386115501348035264934720193790268107107491703332226844753335720832431936092382893458368060106011506169809753078342277318329247904982524730776375927247874656084778203734469699533647017972677717585125660551199131504891101451037862738167250955837389733598993664809941164205702637090279242767544565229087538682506419718265533447265625e-324")

      expect_exp(ieee_parts_to_f64(false, 2046, 0xFFFFFFFFFFFFFu64), 308,
        "1.79769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368e+308")
    end

    it "AllPowersOfTen" do
      {% for tc in ALL_POWERS_OF_TEN %}
        expect_exp({{ tc[0] }}, {{ tc[2] }}, exp_reference({{ tc[0] }}, {{ tc[2] }}))
      {% end %}
    end

    it "RoundToEven" do
      expect_exp(0.125, 2, "1.25e-1")
      expect_exp(0.125, 1, "1.2e-1")
      expect_exp(0.375, 2, "3.75e-1")
      expect_exp(0.375, 1, "3.8e-1")
    end

    it "RoundToEvenInteger" do
      expect_exp(2.5, 1, "2.5e+0")
      expect_exp(2.5, 0, "2e+0")
      expect_exp(3.5, 1, "3.5e+0")
      expect_exp(3.5, 0, "4e+0")
    end

    it "NonRoundToEvenScenarios" do
      expect_exp(0.748046875, 2, "7.48e-1")
      expect_exp(0.748046875, 1, "7.5e-1")
      expect_exp(0.748046875, 0, "7e-1") # 0.75 would round to "8e-1", but this is smaller

      expect_exp(0.2509765625, 2, "2.51e-1")
      expect_exp(0.2509765625, 1, "2.5e-1")
      expect_exp(0.2509765625, 0, "3e-1") # 0.25 would round to "2e-1", but this is larger

      expect_exp(ieee_parts_to_f64(false, 1021, 1), 53, "2.50000000000000055511151231257827021181583404541015625e-1")
      expect_exp(ieee_parts_to_f64(false, 1021, 1), 2, "2.50e-1")
      expect_exp(ieee_parts_to_f64(false, 1021, 1), 1, "2.5e-1")
      expect_exp(ieee_parts_to_f64(false, 1021, 1), 0, "3e-1") # 0.25 would round to "2e-1", but this is larger (again)
    end

    it "VaryingPrecision" do
      expect_exp(1729.142857142857, 50, "1.72914285714285711037518922239542007446289062500000e+3")
      expect_exp(1729.142857142857, 49, "1.7291428571428571103751892223954200744628906250000e+3")
      expect_exp(1729.142857142857, 48, "1.729142857142857110375189222395420074462890625000e+3")
      expect_exp(1729.142857142857, 47, "1.72914285714285711037518922239542007446289062500e+3")
      expect_exp(1729.142857142857, 46, "1.7291428571428571103751892223954200744628906250e+3")
      expect_exp(1729.142857142857, 45, "1.729142857142857110375189222395420074462890625e+3")
      expect_exp(1729.142857142857, 44, "1.72914285714285711037518922239542007446289062e+3")
      expect_exp(1729.142857142857, 43, "1.7291428571428571103751892223954200744628906e+3")
      expect_exp(1729.142857142857, 42, "1.729142857142857110375189222395420074462891e+3")
      expect_exp(1729.142857142857, 41, "1.72914285714285711037518922239542007446289e+3")
      expect_exp(1729.142857142857, 40, "1.7291428571428571103751892223954200744629e+3")
      expect_exp(1729.142857142857, 39, "1.729142857142857110375189222395420074463e+3")
      expect_exp(1729.142857142857, 38, "1.72914285714285711037518922239542007446e+3")
      expect_exp(1729.142857142857, 37, "1.7291428571428571103751892223954200745e+3")
      expect_exp(1729.142857142857, 36, "1.729142857142857110375189222395420074e+3")
      expect_exp(1729.142857142857, 35, "1.72914285714285711037518922239542007e+3")
      expect_exp(1729.142857142857, 34, "1.7291428571428571103751892223954201e+3")
      expect_exp(1729.142857142857, 33, "1.729142857142857110375189222395420e+3")
      expect_exp(1729.142857142857, 32, "1.72914285714285711037518922239542e+3")
      expect_exp(1729.142857142857, 31, "1.7291428571428571103751892223954e+3")
      expect_exp(1729.142857142857, 30, "1.729142857142857110375189222395e+3")
      expect_exp(1729.142857142857, 29, "1.72914285714285711037518922240e+3")
      expect_exp(1729.142857142857, 28, "1.7291428571428571103751892224e+3")
      expect_exp(1729.142857142857, 27, "1.729142857142857110375189222e+3")
      expect_exp(1729.142857142857, 26, "1.72914285714285711037518922e+3")
      expect_exp(1729.142857142857, 25, "1.7291428571428571103751892e+3")
      expect_exp(1729.142857142857, 24, "1.729142857142857110375189e+3")
      expect_exp(1729.142857142857, 23, "1.72914285714285711037519e+3")
      expect_exp(1729.142857142857, 22, "1.7291428571428571103752e+3")
      expect_exp(1729.142857142857, 21, "1.729142857142857110375e+3")
      expect_exp(1729.142857142857, 20, "1.72914285714285711038e+3")
      expect_exp(1729.142857142857, 19, "1.7291428571428571104e+3")
      expect_exp(1729.142857142857, 18, "1.729142857142857110e+3")
      expect_exp(1729.142857142857, 17, "1.72914285714285711e+3")
      expect_exp(1729.142857142857, 16, "1.7291428571428571e+3")
      expect_exp(1729.142857142857, 15, "1.729142857142857e+3")
      expect_exp(1729.142857142857, 14, "1.72914285714286e+3")
      expect_exp(1729.142857142857, 13, "1.7291428571429e+3")
      expect_exp(1729.142857142857, 12, "1.729142857143e+3")
      expect_exp(1729.142857142857, 11, "1.72914285714e+3")
      expect_exp(1729.142857142857, 10, "1.7291428571e+3")
      expect_exp(1729.142857142857, 9, "1.729142857e+3")
      expect_exp(1729.142857142857, 8, "1.72914286e+3")
      expect_exp(1729.142857142857, 7, "1.7291429e+3")
      expect_exp(1729.142857142857, 6, "1.729143e+3")
      expect_exp(1729.142857142857, 5, "1.72914e+3")
      expect_exp(1729.142857142857, 4, "1.7291e+3")
      expect_exp(1729.142857142857, 3, "1.729e+3")
      expect_exp(1729.142857142857, 2, "1.73e+3")
      expect_exp(1729.142857142857, 1, "1.7e+3")
      expect_exp(1729.142857142857, 0, "2e+3")
    end

    it "Carrying" do
      expect_exp(2.0009, 4, "2.0009e+0")
      expect_exp(2.0009, 3, "2.001e+0")
      expect_exp(2.0029, 4, "2.0029e+0")
      expect_exp(2.0029, 3, "2.003e+0")
      expect_exp(2.0099, 4, "2.0099e+0")
      expect_exp(2.0099, 3, "2.010e+0")
      expect_exp(2.0299, 4, "2.0299e+0")
      expect_exp(2.0299, 3, "2.030e+0")
      expect_exp(2.0999, 4, "2.0999e+0")
      expect_exp(2.0999, 3, "2.100e+0")
      expect_exp(2.2999, 4, "2.2999e+0")
      expect_exp(2.2999, 3, "2.300e+0")
      expect_exp(2.9999, 4, "2.9999e+0")
      expect_exp(2.9999, 3, "3.000e+0")
      expect_exp(9.9999, 4, "9.9999e+0")
      expect_exp(9.9999, 3, "1.000e+1")

      expect_exp(2.09, 2, "2.09e+0")
      expect_exp(2.09, 1, "2.1e+0")
      expect_exp(2.29, 2, "2.29e+0")
      expect_exp(2.29, 1, "2.3e+0")
      expect_exp(2.99, 2, "2.99e+0")
      expect_exp(2.99, 1, "3.0e+0")
      expect_exp(9.99, 2, "9.99e+0")
      expect_exp(9.99, 1, "1.0e+1")

      expect_exp(2.9, 1, "2.9e+0")
      expect_exp(2.9, 0, "3e+0")
      expect_exp(9.9, 1, "9.9e+0")
      expect_exp(9.9, 0, "1e+1")
    end

    it "Exponents" do
      expect_exp(9.99e-100, 2, "9.99e-100")
      expect_exp(9.99e-99, 2, "9.99e-99")
      expect_exp(9.99e-10, 2, "9.99e-10")
      expect_exp(9.99e-9, 2, "9.99e-9")
      expect_exp(9.99e-1, 2, "9.99e-1")
      expect_exp(9.99e+0, 2, "9.99e+0")
      expect_exp(9.99e+1, 2, "9.99e+1")
      expect_exp(9.99e+9, 2, "9.99e+9")
      expect_exp(9.99e+10, 2, "9.99e+10")
      expect_exp(9.99e+99, 2, "9.99e+99")
      expect_exp(9.99e+100, 2, "9.99e+100")

      expect_exp(9.99e-100, 1, "1.0e-99")
      expect_exp(9.99e-99, 1, "1.0e-98")
      expect_exp(9.99e-10, 1, "1.0e-9")
      expect_exp(9.99e-9, 1, "1.0e-8")
      expect_exp(9.99e-1, 1, "1.0e+0")
      expect_exp(9.99e+0, 1, "1.0e+1")
      expect_exp(9.99e+1, 1, "1.0e+2")
      expect_exp(9.99e+9, 1, "1.0e+10")
      expect_exp(9.99e+10, 1, "1.0e+11")
      expect_exp(9.99e+99, 1, "1.0e+100")
      expect_exp(9.99e+100, 1, "1.0e+101")
    end

    it "AllBinaryExponents" do
      {% for tc in ALL_BINARY_EXPONENTS %}
        expect_exp({{ tc[0] }}, {{ tc[2] }}, exp_reference({{ tc[0] }}, {{ tc[2] }}))
      {% end %}
    end

    it "PrintDecimalPoint" do
      # These values exercise each codepath.
      expect_exp(1e+54, 0, "1e+54")
      expect_exp(1e+54, 1, "1.0e+54")
      expect_exp(1e-63, 0, "1e-63")
      expect_exp(1e-63, 1, "1.0e-63")
      expect_exp(1e+83, 0, "1e+83")
      expect_exp(1e+83, 1, "1.0e+83")
    end
  end

  describe ".d2gen" do
    it "Basic" do
      expect_gen(0.0, 4, "0")
      expect_gen(1.729, 4, "1.729")
    end

    it "corner cases" do
      expect_gen(Float64::MIN_SUBNORMAL, 1000,
        "4.940656458412465441765687928682213723650598026143247644255856825006755072702087518652998363616359923797965646954457177309266567103559397963987747960107818781263007131903114045278458171678489821036887186360569987307230500063874091535649843873124733972731696151400317153853980741262385655911710266585566867681870395603106249319452715914924553293054565444011274801297099995419319894090804165633245247571478690147267801593552386115501348035264934720193790268107107491703332226844753335720832431936092382893458368060106011506169809753078342277318329247904982524730776375927247874656084778203734469699533647017972677717585125660551199131504891101451037862738167250955837389733598993664809941164205702637090279242767544565229087538682506419718265533447265625e-324")
      expect_gen(Float64::MIN_POSITIVE.prev_float, 1000,
        "2.2250738585072008890245868760858598876504231122409594654935248025624400092282356951787758888037591552642309780950434312085877387158357291821993020294379224223559819827501242041788969571311791082261043971979604000454897391938079198936081525613113376149842043271751033627391549782731594143828136275113838604094249464942286316695429105080201815926642134996606517803095075913058719846423906068637102005108723282784678843631944515866135041223479014792369585208321597621066375401613736583044193603714778355306682834535634005074073040135602968046375918583163124224521599262546494300836851861719422417646455137135420132217031370496583210154654068035397417906022589503023501937519773030945763173210852507299305089761582519159720757232455434770912461317493580281734466552734375e-308")
      expect_gen(Float64::MIN_POSITIVE, 1000,
        "2.225073858507201383090232717332404064219215980462331830553327416887204434813918195854283159012511020564067339731035811005152434161553460108856012385377718821130777993532002330479610147442583636071921565046942503734208375250806650616658158948720491179968591639648500635908770118304874799780887753749949451580451605050915399856582470818645113537935804992115981085766051992433352114352390148795699609591288891602992641511063466313393663477586513029371762047325631781485664350872122828637642044846811407613911477062801689853244110024161447421618567166150540154285084716752901903161322778896729707373123334086988983175067838846926092773977972858659654941091369095406136467568702398678315290680984617210924625396728515625e-308")
      expect_gen(Float64::MAX, 1000,
        "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368")

      expect_gen(Float64::MIN_SUBNORMAL, 6, "4.94066e-324")
      expect_gen(Float64::MIN_POSITIVE.prev_float, 6, "2.22507e-308")
      expect_gen(Float64::MIN_POSITIVE, 6, "2.22507e-308")
      expect_gen(Float64::MAX, 6, "1.79769e+308")
    end

    it "maximum-length output" do
      expect_gen(hexfloat("0x1.fffffffffffffp-1022"), 1000,
        "4.4501477170144022721148195934182639518696390927032912960468522194496444440421538910330590478162701758282983178260792422137401728773891892910553144148156412434867599762821265346585071045737627442980259622449029037796981144446145705102663115100318287949527959668236039986479250965780342141637013812613333119898765515451440315261253813266652951306000184917766328660755595837392240989947807556594098101021612198814605258742579179000071675999344145086087205681577915435923018910334964869420614052182892431445797605163650903606514140377217442262561590244668525767372446430075513332450079650686719491377688478005309963967709758965844137894433796621993967316936280457084866613206797017728916080020698679408551343728867675409720757232455434770912461317493580281734466552734375e-308")
      expect_gen(hexfloat("0x1.fffffffffffffp-14"), 1000,
        "0.000122070312499999986447472843931194574906839989125728607177734375")
    end

    it "varying precision" do
      expect_gen(hexfloat("0x1.b04p0"), 0, "2")
      expect_gen(hexfloat("0x1.b04p0"), 1, "2") # fixed notation trims decimal point
      expect_gen(hexfloat("0x1.b04p0"), 2, "1.7")
      expect_gen(hexfloat("0x1.b04p0"), 3, "1.69")
      expect_gen(hexfloat("0x1.b04p0"), 4, "1.688")
      expect_gen(hexfloat("0x1.b04p0"), 5, "1.6885")
      expect_gen(hexfloat("0x1.b04p0"), 6, "1.68848")
      expect_gen(hexfloat("0x1.b04p0"), 7, "1.688477")
      expect_gen(hexfloat("0x1.b04p0"), 8, "1.6884766")
      expect_gen(hexfloat("0x1.b04p0"), 9, "1.68847656")
      expect_gen(hexfloat("0x1.b04p0"), 10, "1.688476562")  # round to even
      expect_gen(hexfloat("0x1.b04p0"), 11, "1.6884765625") # exact
      expect_gen(hexfloat("0x1.b04p0"), 12, "1.6884765625") # trim trailing zeros
      expect_gen(hexfloat("0x1.b04p0"), 13, "1.6884765625")

      expect_gen(hexfloat("0x1.8p-15"), 0, "5e-5")
      expect_gen(hexfloat("0x1.8p-15"), 1, "5e-5") # scientific notation trims decimal point
      expect_gen(hexfloat("0x1.8p-15"), 2, "4.6e-5")
      expect_gen(hexfloat("0x1.8p-15"), 3, "4.58e-5")
      expect_gen(hexfloat("0x1.8p-15"), 4, "4.578e-5")
      expect_gen(hexfloat("0x1.8p-15"), 5, "4.5776e-5")
      expect_gen(hexfloat("0x1.8p-15"), 6, "4.57764e-5")
      expect_gen(hexfloat("0x1.8p-15"), 7, "4.577637e-5")
      expect_gen(hexfloat("0x1.8p-15"), 8, "4.5776367e-5")
      expect_gen(hexfloat("0x1.8p-15"), 9, "4.57763672e-5")
      expect_gen(hexfloat("0x1.8p-15"), 10, "4.577636719e-5")
      expect_gen(hexfloat("0x1.8p-15"), 11, "4.5776367188e-5")  # round to even
      expect_gen(hexfloat("0x1.8p-15"), 12, "4.57763671875e-5") # exact
      expect_gen(hexfloat("0x1.8p-15"), 13, "4.57763671875e-5") # trim trailing zeros
      expect_gen(hexfloat("0x1.8p-15"), 14, "4.57763671875e-5")
    end

    it "trim trailing zeros" do
      expect_gen(hexfloat("0x1.80015p0"), 1, "2") # fixed notation trims decimal point
      expect_gen(hexfloat("0x1.80015p0"), 2, "1.5")
      expect_gen(hexfloat("0x1.80015p0"), 3, "1.5") # general trims trailing zeros
      expect_gen(hexfloat("0x1.80015p0"), 4, "1.5")
      expect_gen(hexfloat("0x1.80015p0"), 5, "1.5")
      expect_gen(hexfloat("0x1.80015p0"), 6, "1.50002")
      expect_gen(hexfloat("0x1.80015p0"), 7, "1.50002")
      expect_gen(hexfloat("0x1.80015p0"), 8, "1.50002")
      expect_gen(hexfloat("0x1.80015p0"), 9, "1.50002003")
      expect_gen(hexfloat("0x1.80015p0"), 10, "1.500020027")
      expect_gen(hexfloat("0x1.80015p0"), 11, "1.5000200272")
      expect_gen(hexfloat("0x1.80015p0"), 12, "1.50002002716")
      expect_gen(hexfloat("0x1.80015p0"), 13, "1.500020027161")
      expect_gen(hexfloat("0x1.80015p0"), 14, "1.5000200271606")
      expect_gen(hexfloat("0x1.80015p0"), 15, "1.50002002716064")
      expect_gen(hexfloat("0x1.80015p0"), 16, "1.500020027160645")
      expect_gen(hexfloat("0x1.80015p0"), 17, "1.5000200271606445")
      expect_gen(hexfloat("0x1.80015p0"), 18, "1.50002002716064453")
      expect_gen(hexfloat("0x1.80015p0"), 19, "1.500020027160644531")
      expect_gen(hexfloat("0x1.80015p0"), 20, "1.5000200271606445312")  # round to even
      expect_gen(hexfloat("0x1.80015p0"), 21, "1.50002002716064453125") # exact
    end

    it "trim trailing zeros and decimal point" do
      expect_gen(hexfloat("0x1.00015p0"), 1, "1") # fixed notation trims decimal point
      expect_gen(hexfloat("0x1.00015p0"), 2, "1") # general trims decimal point and trailing zeros
      expect_gen(hexfloat("0x1.00015p0"), 3, "1")
      expect_gen(hexfloat("0x1.00015p0"), 4, "1")
      expect_gen(hexfloat("0x1.00015p0"), 5, "1")
      expect_gen(hexfloat("0x1.00015p0"), 6, "1.00002")
      expect_gen(hexfloat("0x1.00015p0"), 7, "1.00002")
      expect_gen(hexfloat("0x1.00015p0"), 8, "1.00002")
      expect_gen(hexfloat("0x1.00015p0"), 9, "1.00002003")
      expect_gen(hexfloat("0x1.00015p0"), 10, "1.000020027")
      expect_gen(hexfloat("0x1.00015p0"), 11, "1.0000200272")
      expect_gen(hexfloat("0x1.00015p0"), 12, "1.00002002716")
      expect_gen(hexfloat("0x1.00015p0"), 13, "1.000020027161")
      expect_gen(hexfloat("0x1.00015p0"), 14, "1.0000200271606")
      expect_gen(hexfloat("0x1.00015p0"), 15, "1.00002002716064")
      expect_gen(hexfloat("0x1.00015p0"), 16, "1.000020027160645")
      expect_gen(hexfloat("0x1.00015p0"), 17, "1.0000200271606445")
      expect_gen(hexfloat("0x1.00015p0"), 18, "1.00002002716064453")
      expect_gen(hexfloat("0x1.00015p0"), 19, "1.000020027160644531")
      expect_gen(hexfloat("0x1.00015p0"), 20, "1.0000200271606445312")  # round to even
      expect_gen(hexfloat("0x1.00015p0"), 21, "1.00002002716064453125") # exact
    end

    it "trim trailing zeros, scientific notation" do
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 1, "1e-6") # scientific notation trims decimal point
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 2, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 3, "1.3e-6") # general trims trailing zeros
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 4, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 5, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 6, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 7, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 8, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 9, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 10, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 11, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 12, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 13, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 14, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 15, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 16, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 17, "1.3e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 18, "1.30000000000000005e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 19, "1.300000000000000047e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 20, "1.3000000000000000471e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 21, "1.30000000000000004705e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 22, "1.300000000000000047052e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 23, "1.3000000000000000470517e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 24, "1.30000000000000004705166e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 25, "1.300000000000000047051664e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 26, "1.3000000000000000470516638e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 27, "1.30000000000000004705166378e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 28, "1.30000000000000004705166378e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 29, "1.3000000000000000470516637804e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 30, "1.30000000000000004705166378044e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 31, "1.30000000000000004705166378044e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 32, "1.3000000000000000470516637804397e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 33, "1.30000000000000004705166378043968e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 34, "1.300000000000000047051663780439679e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 35, "1.3000000000000000470516637804396787e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 36, "1.30000000000000004705166378043967867e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 37, "1.300000000000000047051663780439678675e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 38, "1.3000000000000000470516637804396786748e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 39, "1.30000000000000004705166378043967867484e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 40, "1.300000000000000047051663780439678674838e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 41, "1.3000000000000000470516637804396786748384e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 42, "1.30000000000000004705166378043967867483843e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 43, "1.300000000000000047051663780439678674838433e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 44, "1.3000000000000000470516637804396786748384329e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 45, "1.30000000000000004705166378043967867483843293e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 46, "1.300000000000000047051663780439678674838432926e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 47, "1.3000000000000000470516637804396786748384329258e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 48, "1.30000000000000004705166378043967867483843292575e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 49, "1.300000000000000047051663780439678674838432925753e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 50, "1.3000000000000000470516637804396786748384329257533e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 51, "1.3000000000000000470516637804396786748384329257533e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 52, "1.300000000000000047051663780439678674838432925753295e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 53, "1.3000000000000000470516637804396786748384329257532954e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 54, "1.30000000000000004705166378043967867483843292575329542e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 55, "1.300000000000000047051663780439678674838432925753295422e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 56, "1.3000000000000000470516637804396786748384329257532954216e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 57, "1.3000000000000000470516637804396786748384329257532954216e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 58, "1.3000000000000000470516637804396786748384329257532954216e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 59, "1.3000000000000000470516637804396786748384329257532954216003e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 60, "1.30000000000000004705166378043967867483843292575329542160034e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 61, "1.300000000000000047051663780439678674838432925753295421600342e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 62, "1.3000000000000000470516637804396786748384329257532954216003418e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 63, "1.3000000000000000470516637804396786748384329257532954216003418e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 64, "1.300000000000000047051663780439678674838432925753295421600341797e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 65, "1.3000000000000000470516637804396786748384329257532954216003417969e-6")
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 66, "1.30000000000000004705166378043967867483843292575329542160034179688e-6")  # round to even
      expect_gen(hexfloat("0x1.5cf751db94e6bp-20"), 67, "1.300000000000000047051663780439678674838432925753295421600341796875e-6") # exact
    end

    it "trim trailing zeros and decimal point, scientific notation" do
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 1, "3e-6") # scientific notation trims decimal point
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 2, "3e-6") # general trims decimal point and trailing zeros
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 3, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 4, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 5, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 6, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 7, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 8, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 9, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 10, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 11, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 12, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 13, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 14, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 15, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 16, "3e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 17, "3.0000000000000001e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 18, "3.00000000000000008e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 19, "3.000000000000000076e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 20, "3.000000000000000076e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 21, "3.000000000000000076e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 22, "3.000000000000000076003e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 23, "3.0000000000000000760026e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 24, "3.00000000000000007600257e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 25, "3.000000000000000076002572e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 26, "3.0000000000000000760025723e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 27, "3.00000000000000007600257229e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 28, "3.000000000000000076002572291e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 29, "3.0000000000000000760025722912e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 30, "3.00000000000000007600257229123e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 31, "3.000000000000000076002572291234e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 32, "3.0000000000000000760025722912339e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 33, "3.00000000000000007600257229123386e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 34, "3.000000000000000076002572291233861e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 35, "3.0000000000000000760025722912338608e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 36, "3.00000000000000007600257229123386082e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 37, "3.000000000000000076002572291233860824e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 38, "3.0000000000000000760025722912338608239e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 39, "3.00000000000000007600257229123386082392e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 40, "3.000000000000000076002572291233860823922e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 41, "3.0000000000000000760025722912338608239224e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 42, "3.00000000000000007600257229123386082392244e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 43, "3.000000000000000076002572291233860823922441e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 44, "3.0000000000000000760025722912338608239224413e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 45, "3.00000000000000007600257229123386082392244134e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 46, "3.000000000000000076002572291233860823922441341e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 47, "3.000000000000000076002572291233860823922441341e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 48, "3.00000000000000007600257229123386082392244134098e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 49, "3.000000000000000076002572291233860823922441340983e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 50, "3.0000000000000000760025722912338608239224413409829e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 51, "3.00000000000000007600257229123386082392244134098291e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 52, "3.000000000000000076002572291233860823922441340982914e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 53, "3.000000000000000076002572291233860823922441340982914e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 54, "3.00000000000000007600257229123386082392244134098291397e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 55, "3.000000000000000076002572291233860823922441340982913971e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 56, "3.0000000000000000760025722912338608239224413409829139709e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 57, "3.00000000000000007600257229123386082392244134098291397095e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 58, "3.000000000000000076002572291233860823922441340982913970947e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 59, "3.0000000000000000760025722912338608239224413409829139709473e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 60, "3.00000000000000007600257229123386082392244134098291397094727e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 61, "3.000000000000000076002572291233860823922441340982913970947266e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 62, "3.0000000000000000760025722912338608239224413409829139709472656e-6")
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 63, "3.00000000000000007600257229123386082392244134098291397094726562e-6")  # round to even
      expect_gen(hexfloat("0x1.92a737110e454p-19"), 64, "3.000000000000000076002572291233860823922441340982913970947265625e-6") # exact
    end

    it "large precision with fixed notation and scientific notation" do
      expect_gen(hexfloat("0x1.ba9fbe76c8b44p+0"), 5000, "1.72900000000000009237055564881302416324615478515625")
      expect_gen(hexfloat("0x1.d01ff9abb93d1p-20"), 5000, "1.729000000000000090107283613749533657255597063340246677398681640625e-6")
    end

    it "transitions between fixed notation and scientific notation" do
      expect_gen(5555555.0, 1, "6e+6")
      expect_gen(555555.0, 1, "6e+5")
      expect_gen(55555.0, 1, "6e+4")
      expect_gen(5555.0, 1, "6e+3")
      expect_gen(555.0, 1, "6e+2")
      expect_gen(55.0, 1, "6e+1") # round to even
      expect_gen(5.0, 1, "5")
      expect_gen(hexfloat("0x1p-3"), 1, "0.1")     # 0.125
      expect_gen(hexfloat("0x1p-6"), 1, "0.02")    # 0.015625
      expect_gen(hexfloat("0x1p-9"), 1, "0.002")   # 0.001953125
      expect_gen(hexfloat("0x1p-13"), 1, "0.0001") # 0.0001220703125
      expect_gen(hexfloat("0x1p-16"), 1, "2e-5")   # 1.52587890625e-5
      expect_gen(hexfloat("0x1p-19"), 1, "2e-6")   # 1.9073486328125e-6

      expect_gen(5555555.0, 2, "5.6e+6")
      expect_gen(555555.0, 2, "5.6e+5")
      expect_gen(55555.0, 2, "5.6e+4")
      expect_gen(5555.0, 2, "5.6e+3")
      expect_gen(555.0, 2, "5.6e+2") # round to even
      expect_gen(55.0, 2, "55")
      expect_gen(5.0, 2, "5")
      expect_gen(hexfloat("0x1p-3"), 2, "0.12") # round to even
      expect_gen(hexfloat("0x1p-6"), 2, "0.016")
      expect_gen(hexfloat("0x1p-9"), 2, "0.002")
      expect_gen(hexfloat("0x1p-13"), 2, "0.00012")
      expect_gen(hexfloat("0x1p-16"), 2, "1.5e-5")
      expect_gen(hexfloat("0x1p-19"), 2, "1.9e-6")

      expect_gen(5555555.0, 3, "5.56e+6")
      expect_gen(555555.0, 3, "5.56e+5")
      expect_gen(55555.0, 3, "5.56e+4")
      expect_gen(5555.0, 3, "5.56e+3") # round to even
      expect_gen(555.0, 3, "555")
      expect_gen(55.0, 3, "55")
      expect_gen(5.0, 3, "5")
      expect_gen(hexfloat("0x1p-3"), 3, "0.125")
      expect_gen(hexfloat("0x1p-6"), 3, "0.0156")
      expect_gen(hexfloat("0x1p-9"), 3, "0.00195")
      expect_gen(hexfloat("0x1p-13"), 3, "0.000122")
      expect_gen(hexfloat("0x1p-16"), 3, "1.53e-5")
      expect_gen(hexfloat("0x1p-19"), 3, "1.91e-6")

      expect_gen(5555555.0, 4, "5.556e+6")
      expect_gen(555555.0, 4, "5.556e+5")
      expect_gen(55555.0, 4, "5.556e+4") # round to even
      expect_gen(5555.0, 4, "5555")
      expect_gen(555.0, 4, "555")
      expect_gen(55.0, 4, "55")
      expect_gen(5.0, 4, "5")
      expect_gen(hexfloat("0x1p-3"), 4, "0.125")
      expect_gen(hexfloat("0x1p-6"), 4, "0.01562") # round to even
      expect_gen(hexfloat("0x1p-9"), 4, "0.001953")
      expect_gen(hexfloat("0x1p-13"), 4, "0.0001221")
      expect_gen(hexfloat("0x1p-16"), 4, "1.526e-5")
      expect_gen(hexfloat("0x1p-19"), 4, "1.907e-6")

      expect_gen(5555555.0, 5, "5.5556e+6")
      expect_gen(555555.0, 5, "5.5556e+5") # round to even
      expect_gen(55555.0, 5, "55555")
      expect_gen(5555.0, 5, "5555")
      expect_gen(555.0, 5, "555")
      expect_gen(55.0, 5, "55")
      expect_gen(5.0, 5, "5")
      expect_gen(hexfloat("0x1p-3"), 5, "0.125")
      expect_gen(hexfloat("0x1p-6"), 5, "0.015625")
      expect_gen(hexfloat("0x1p-9"), 5, "0.0019531")
      expect_gen(hexfloat("0x1p-13"), 5, "0.00012207")
      expect_gen(hexfloat("0x1p-16"), 5, "1.5259e-5")
      expect_gen(hexfloat("0x1p-19"), 5, "1.9073e-6")
    end

    it "tricky corner cases" do
      expect_gen(999.999, 1, "1e+3")    # "%.0e" is "1e+3"; X == 3
      expect_gen(999.999, 2, "1e+3")    # "%.1e" is "1.0e+3"; X == 3
      expect_gen(999.999, 3, "1e+3")    # "%.2e" is "1.00e+3"; X == 3
      expect_gen(999.999, 4, "1000")    # "%.3e" is "1.000e+3"; X == 3
      expect_gen(999.999, 5, "1000")    # "%.4e" is "1.0000e+3"; X == 3
      expect_gen(999.999, 6, "999.999") # "%.5e" is "9.99999e+2"; X == 2

      expect_gen(999.99, 1, "1e+3")
      expect_gen(999.99, 2, "1e+3")
      expect_gen(999.99, 3, "1e+3")
      expect_gen(999.99, 4, "1000")
      expect_gen(999.99, 5, "999.99")
      expect_gen(999.99, 6, "999.99")

      # C11's Standardese is slightly vague about how to perform the trial formatting in scientific notation,
      # but the intention is to use precision P - 1, which is what's used when scientific notation is actually chosen.
      # This example verifies this behavior. Here, P == 3 performs trial formatting with "%.2e", triggering rounding.
      # That increases X to 3, forcing scientific notation to be chosen.
      # If P == 3 performed trial formatting with "%.3e", rounding wouldn't happen,
      # X would be 2, and fixed notation would be chosen.
      expect_gen(999.9, 1, "1e+3")  # "%.0e" is "1e+3"; X == 3
      expect_gen(999.9, 2, "1e+3")  # "%.1e" is "1.0e+3"; X == 3
      expect_gen(999.9, 3, "1e+3")  # "%.2e" is "1.00e+3"; X == 3; SPECIAL CORNER CASE
      expect_gen(999.9, 4, "999.9") # "%.3e" is "9.999e+2"; X == 2
      expect_gen(999.9, 5, "999.9") # "%.4e" is "9.9990e+2"; X == 2
      expect_gen(999.9, 6, "999.9") # "%.5e" is "9.99900e+2"; X == 2

      expect_gen(999.0, 1, "1e+3")
      expect_gen(999.0, 2, "1e+3")
      expect_gen(999.0, 3, "999")
      expect_gen(999.0, 4, "999")
      expect_gen(999.0, 5, "999")
      expect_gen(999.0, 6, "999")

      expect_gen(99.9999, 1, "1e+2")
      expect_gen(99.9999, 2, "1e+2")
      expect_gen(99.9999, 3, "100")
      expect_gen(99.9999, 4, "100")
      expect_gen(99.9999, 5, "100")
      expect_gen(99.9999, 6, "99.9999")

      expect_gen(99.999, 1, "1e+2")
      expect_gen(99.999, 2, "1e+2")
      expect_gen(99.999, 3, "100")
      expect_gen(99.999, 4, "100")
      expect_gen(99.999, 5, "99.999")
      expect_gen(99.999, 6, "99.999")

      expect_gen(99.99, 1, "1e+2")
      expect_gen(99.99, 2, "1e+2")
      expect_gen(99.99, 3, "100")
      expect_gen(99.99, 4, "99.99")
      expect_gen(99.99, 5, "99.99")
      expect_gen(99.99, 6, "99.99")

      expect_gen(99.9, 1, "1e+2")
      expect_gen(99.9, 2, "1e+2")
      expect_gen(99.9, 3, "99.9")
      expect_gen(99.9, 4, "99.9")
      expect_gen(99.9, 5, "99.9")
      expect_gen(99.9, 6, "99.9")

      expect_gen(99.0, 1, "1e+2")
      expect_gen(99.0, 2, "99")
      expect_gen(99.0, 3, "99")
      expect_gen(99.0, 4, "99")
      expect_gen(99.0, 5, "99")
      expect_gen(99.0, 6, "99")

      expect_gen(9.99999, 1, "1e+1")
      expect_gen(9.99999, 2, "10")
      expect_gen(9.99999, 3, "10")
      expect_gen(9.99999, 4, "10")
      expect_gen(9.99999, 5, "10")
      expect_gen(9.99999, 6, "9.99999")

      expect_gen(9.9999, 1, "1e+1")
      expect_gen(9.9999, 2, "10")
      expect_gen(9.9999, 3, "10")
      expect_gen(9.9999, 4, "10")
      expect_gen(9.9999, 5, "9.9999")
      expect_gen(9.9999, 6, "9.9999")

      expect_gen(9.999, 1, "1e+1")
      expect_gen(9.999, 2, "10")
      expect_gen(9.999, 3, "10")
      expect_gen(9.999, 4, "9.999")
      expect_gen(9.999, 5, "9.999")
      expect_gen(9.999, 6, "9.999")

      expect_gen(9.99, 1, "1e+1")
      expect_gen(9.99, 2, "10")
      expect_gen(9.99, 3, "9.99")
      expect_gen(9.99, 4, "9.99")
      expect_gen(9.99, 5, "9.99")
      expect_gen(9.99, 6, "9.99")

      expect_gen(9.9, 1, "1e+1")
      expect_gen(9.9, 2, "9.9")
      expect_gen(9.9, 3, "9.9")
      expect_gen(9.9, 4, "9.9")
      expect_gen(9.9, 5, "9.9")
      expect_gen(9.9, 6, "9.9")

      expect_gen(9.0, 1, "9")
      expect_gen(9.0, 2, "9")
      expect_gen(9.0, 3, "9")
      expect_gen(9.0, 4, "9")
      expect_gen(9.0, 5, "9")
      expect_gen(9.0, 6, "9")

      expect_gen(0.999999, 1, "1")
      expect_gen(0.999999, 2, "1")
      expect_gen(0.999999, 3, "1")
      expect_gen(0.999999, 4, "1")
      expect_gen(0.999999, 5, "1")
      expect_gen(0.999999, 6, "0.999999")

      expect_gen(0.99999, 1, "1")
      expect_gen(0.99999, 2, "1")
      expect_gen(0.99999, 3, "1")
      expect_gen(0.99999, 4, "1")
      expect_gen(0.99999, 5, "0.99999")
      expect_gen(0.99999, 6, "0.99999")

      expect_gen(0.9999, 1, "1")
      expect_gen(0.9999, 2, "1")
      expect_gen(0.9999, 3, "1")
      expect_gen(0.9999, 4, "0.9999")
      expect_gen(0.9999, 5, "0.9999")
      expect_gen(0.9999, 6, "0.9999")

      expect_gen(0.999, 1, "1")
      expect_gen(0.999, 2, "1")
      expect_gen(0.999, 3, "0.999")
      expect_gen(0.999, 4, "0.999")
      expect_gen(0.999, 5, "0.999")
      expect_gen(0.999, 6, "0.999")

      expect_gen(0.99, 1, "1")
      expect_gen(0.99, 2, "0.99")
      expect_gen(0.99, 3, "0.99")
      expect_gen(0.99, 4, "0.99")
      expect_gen(0.99, 5, "0.99")
      expect_gen(0.99, 6, "0.99")

      expect_gen(0.9, 1, "0.9")
      expect_gen(0.9, 2, "0.9")
      expect_gen(0.9, 3, "0.9")
      expect_gen(0.9, 4, "0.9")
      expect_gen(0.9, 5, "0.9")
      expect_gen(0.9, 6, "0.9")

      expect_gen(0.0999999, 1, "0.1")
      expect_gen(0.0999999, 2, "0.1")
      expect_gen(0.0999999, 3, "0.1")
      expect_gen(0.0999999, 4, "0.1")
      expect_gen(0.0999999, 5, "0.1")
      expect_gen(0.0999999, 6, "0.0999999")

      expect_gen(0.099999, 1, "0.1")
      expect_gen(0.099999, 2, "0.1")
      expect_gen(0.099999, 3, "0.1")
      expect_gen(0.099999, 4, "0.1")
      expect_gen(0.099999, 5, "0.099999")
      expect_gen(0.099999, 6, "0.099999")

      expect_gen(0.09999, 1, "0.1")
      expect_gen(0.09999, 2, "0.1")
      expect_gen(0.09999, 3, "0.1")
      expect_gen(0.09999, 4, "0.09999")
      expect_gen(0.09999, 5, "0.09999")
      expect_gen(0.09999, 6, "0.09999")

      expect_gen(0.0999, 1, "0.1")
      expect_gen(0.0999, 2, "0.1")
      expect_gen(0.0999, 3, "0.0999")
      expect_gen(0.0999, 4, "0.0999")
      expect_gen(0.0999, 5, "0.0999")
      expect_gen(0.0999, 6, "0.0999")

      expect_gen(0.099, 1, "0.1")
      expect_gen(0.099, 2, "0.099")
      expect_gen(0.099, 3, "0.099")
      expect_gen(0.099, 4, "0.099")
      expect_gen(0.099, 5, "0.099")
      expect_gen(0.099, 6, "0.099")

      expect_gen(0.09, 1, "0.09")
      expect_gen(0.09, 2, "0.09")
      expect_gen(0.09, 3, "0.09")
      expect_gen(0.09, 4, "0.09")
      expect_gen(0.09, 5, "0.09")
      expect_gen(0.09, 6, "0.09")

      expect_gen(0.00999999, 1, "0.01")
      expect_gen(0.00999999, 2, "0.01")
      expect_gen(0.00999999, 3, "0.01")
      expect_gen(0.00999999, 4, "0.01")
      expect_gen(0.00999999, 5, "0.01")
      expect_gen(0.00999999, 6, "0.00999999")

      expect_gen(0.0099999, 1, "0.01")
      expect_gen(0.0099999, 2, "0.01")
      expect_gen(0.0099999, 3, "0.01")
      expect_gen(0.0099999, 4, "0.01")
      expect_gen(0.0099999, 5, "0.0099999")
      expect_gen(0.0099999, 6, "0.0099999")

      expect_gen(0.009999, 1, "0.01")
      expect_gen(0.009999, 2, "0.01")
      expect_gen(0.009999, 3, "0.01")
      expect_gen(0.009999, 4, "0.009999")
      expect_gen(0.009999, 5, "0.009999")
      expect_gen(0.009999, 6, "0.009999")

      expect_gen(0.00999, 1, "0.01")
      expect_gen(0.00999, 2, "0.01")
      expect_gen(0.00999, 3, "0.00999")
      expect_gen(0.00999, 4, "0.00999")
      expect_gen(0.00999, 5, "0.00999")
      expect_gen(0.00999, 6, "0.00999")

      expect_gen(0.0099, 1, "0.01")
      expect_gen(0.0099, 2, "0.0099")
      expect_gen(0.0099, 3, "0.0099")
      expect_gen(0.0099, 4, "0.0099")
      expect_gen(0.0099, 5, "0.0099")
      expect_gen(0.0099, 6, "0.0099")

      expect_gen(0.009, 1, "0.009")
      expect_gen(0.009, 2, "0.009")
      expect_gen(0.009, 3, "0.009")
      expect_gen(0.009, 4, "0.009")
      expect_gen(0.009, 5, "0.009")
      expect_gen(0.009, 6, "0.009")

      expect_gen(0.000999999, 1, "0.001")
      expect_gen(0.000999999, 2, "0.001")
      expect_gen(0.000999999, 3, "0.001")
      expect_gen(0.000999999, 4, "0.001")
      expect_gen(0.000999999, 5, "0.001")
      expect_gen(0.000999999, 6, "0.000999999")

      expect_gen(0.00099999, 1, "0.001")
      expect_gen(0.00099999, 2, "0.001")
      expect_gen(0.00099999, 3, "0.001")
      expect_gen(0.00099999, 4, "0.001")
      expect_gen(0.00099999, 5, "0.00099999")
      expect_gen(0.00099999, 6, "0.00099999")

      expect_gen(0.0009999, 1, "0.001")
      expect_gen(0.0009999, 2, "0.001")
      expect_gen(0.0009999, 3, "0.001")
      expect_gen(0.0009999, 4, "0.0009999")
      expect_gen(0.0009999, 5, "0.0009999")
      expect_gen(0.0009999, 6, "0.0009999")

      expect_gen(0.000999, 1, "0.001")
      expect_gen(0.000999, 2, "0.001")
      expect_gen(0.000999, 3, "0.000999")
      expect_gen(0.000999, 4, "0.000999")
      expect_gen(0.000999, 5, "0.000999")
      expect_gen(0.000999, 6, "0.000999")

      expect_gen(0.00099, 1, "0.001")
      expect_gen(0.00099, 2, "0.00099")
      expect_gen(0.00099, 3, "0.00099")
      expect_gen(0.00099, 4, "0.00099")
      expect_gen(0.00099, 5, "0.00099")
      expect_gen(0.00099, 6, "0.00099")

      expect_gen(0.0009, 1, "0.0009")
      expect_gen(0.0009, 2, "0.0009")
      expect_gen(0.0009, 3, "0.0009")
      expect_gen(0.0009, 4, "0.0009")
      expect_gen(0.0009, 5, "0.0009")
      expect_gen(0.0009, 6, "0.0009")

      # Having a scientific exponent X == -5 triggers scientific notation.
      # If rounding adjusts this to X == -4, then fixed notation will be selected.
      expect_gen(0.0000999999, 1, "0.0001")
      expect_gen(0.0000999999, 2, "0.0001")
      expect_gen(0.0000999999, 3, "0.0001")
      expect_gen(0.0000999999, 4, "0.0001")
      expect_gen(0.0000999999, 5, "0.0001")
      expect_gen(0.0000999999, 6, "9.99999e-5")

      expect_gen(0.000099999, 1, "0.0001")
      expect_gen(0.000099999, 2, "0.0001")
      expect_gen(0.000099999, 3, "0.0001")
      expect_gen(0.000099999, 4, "0.0001")
      expect_gen(0.000099999, 5, "9.9999e-5")
      expect_gen(0.000099999, 6, "9.9999e-5")

      expect_gen(0.00009999, 1, "0.0001")
      expect_gen(0.00009999, 2, "0.0001")
      expect_gen(0.00009999, 3, "0.0001")
      expect_gen(0.00009999, 4, "9.999e-5")
      expect_gen(0.00009999, 5, "9.999e-5")
      expect_gen(0.00009999, 6, "9.999e-5")

      expect_gen(0.0000999, 1, "0.0001")
      expect_gen(0.0000999, 2, "0.0001")
      expect_gen(0.0000999, 3, "9.99e-5")
      expect_gen(0.0000999, 4, "9.99e-5")
      expect_gen(0.0000999, 5, "9.99e-5")
      expect_gen(0.0000999, 6, "9.99e-5")

      expect_gen(0.000099, 1, "0.0001")
      expect_gen(0.000099, 2, "9.9e-5")
      expect_gen(0.000099, 3, "9.9e-5")
      expect_gen(0.000099, 4, "9.9e-5")
      expect_gen(0.000099, 5, "9.9e-5")
      expect_gen(0.000099, 6, "9.9e-5")

      expect_gen(0.00009, 1, "9e-5")
      expect_gen(0.00009, 2, "9e-5")
      expect_gen(0.00009, 3, "9e-5")
      expect_gen(0.00009, 4, "9e-5")
      expect_gen(0.00009, 5, "9e-5")
      expect_gen(0.00009, 6, "9e-5")

      # Rounding test cases without exponent-adjusting behavior.
      expect_gen(2999.999, 1, "3e+3")
      expect_gen(2999.999, 2, "3e+3")
      expect_gen(2999.999, 3, "3e+3")
      expect_gen(2999.999, 4, "3000")
      expect_gen(2999.999, 5, "3000")
      expect_gen(2999.999, 6, "3000")

      expect_gen(2999.99, 1, "3e+3")
      expect_gen(2999.99, 2, "3e+3")
      expect_gen(2999.99, 3, "3e+3")
      expect_gen(2999.99, 4, "3000")
      expect_gen(2999.99, 5, "3000")
      expect_gen(2999.99, 6, "2999.99")

      expect_gen(2999.9, 1, "3e+3")
      expect_gen(2999.9, 2, "3e+3")
      expect_gen(2999.9, 3, "3e+3")
      expect_gen(2999.9, 4, "3000")
      expect_gen(2999.9, 5, "2999.9")
      expect_gen(2999.9, 6, "2999.9")

      expect_gen(2999.0, 1, "3e+3")
      expect_gen(2999.0, 2, "3e+3")
      expect_gen(2999.0, 3, "3e+3")
      expect_gen(2999.0, 4, "2999")
      expect_gen(2999.0, 5, "2999")
      expect_gen(2999.0, 6, "2999")

      expect_gen(299.999, 1, "3e+2")
      expect_gen(299.999, 2, "3e+2")
      expect_gen(299.999, 3, "300")
      expect_gen(299.999, 4, "300")
      expect_gen(299.999, 5, "300")
      expect_gen(299.999, 6, "299.999")

      expect_gen(299.99, 1, "3e+2")
      expect_gen(299.99, 2, "3e+2")
      expect_gen(299.99, 3, "300")
      expect_gen(299.99, 4, "300")
      expect_gen(299.99, 5, "299.99")
      expect_gen(299.99, 6, "299.99")

      expect_gen(299.9, 1, "3e+2")
      expect_gen(299.9, 2, "3e+2")
      expect_gen(299.9, 3, "300")
      expect_gen(299.9, 4, "299.9")
      expect_gen(299.9, 5, "299.9")
      expect_gen(299.9, 6, "299.9")

      expect_gen(299.0, 1, "3e+2")
      expect_gen(299.0, 2, "3e+2")
      expect_gen(299.0, 3, "299")
      expect_gen(299.0, 4, "299")
      expect_gen(299.0, 5, "299")
      expect_gen(299.0, 6, "299")

      expect_gen(29.999, 1, "3e+1")
      expect_gen(29.999, 2, "30")
      expect_gen(29.999, 3, "30")
      expect_gen(29.999, 4, "30")
      expect_gen(29.999, 5, "29.999")
      expect_gen(29.999, 6, "29.999")

      expect_gen(29.99, 1, "3e+1")
      expect_gen(29.99, 2, "30")
      expect_gen(29.99, 3, "30")
      expect_gen(29.99, 4, "29.99")
      expect_gen(29.99, 5, "29.99")
      expect_gen(29.99, 6, "29.99")

      expect_gen(29.9, 1, "3e+1")
      expect_gen(29.9, 2, "30")
      expect_gen(29.9, 3, "29.9")
      expect_gen(29.9, 4, "29.9")
      expect_gen(29.9, 5, "29.9")
      expect_gen(29.9, 6, "29.9")

      expect_gen(29.0, 1, "3e+1")
      expect_gen(29.0, 2, "29")
      expect_gen(29.0, 3, "29")
      expect_gen(29.0, 4, "29")
      expect_gen(29.0, 5, "29")
      expect_gen(29.0, 6, "29")

      expect_gen(2.999, 1, "3")
      expect_gen(2.999, 2, "3")
      expect_gen(2.999, 3, "3")
      expect_gen(2.999, 4, "2.999")
      expect_gen(2.999, 5, "2.999")
      expect_gen(2.999, 6, "2.999")

      expect_gen(2.99, 1, "3")
      expect_gen(2.99, 2, "3")
      expect_gen(2.99, 3, "2.99")
      expect_gen(2.99, 4, "2.99")
      expect_gen(2.99, 5, "2.99")
      expect_gen(2.99, 6, "2.99")

      expect_gen(2.9, 1, "3")
      expect_gen(2.9, 2, "2.9")
      expect_gen(2.9, 3, "2.9")
      expect_gen(2.9, 4, "2.9")
      expect_gen(2.9, 5, "2.9")
      expect_gen(2.9, 6, "2.9")

      expect_gen(2.0, 1, "2")
      expect_gen(2.0, 2, "2")
      expect_gen(2.0, 3, "2")
      expect_gen(2.0, 4, "2")
      expect_gen(2.0, 5, "2")
      expect_gen(2.0, 6, "2")

      expect_gen(0.2999, 1, "0.3")
      expect_gen(0.2999, 2, "0.3")
      expect_gen(0.2999, 3, "0.3")
      expect_gen(0.2999, 4, "0.2999")
      expect_gen(0.2999, 5, "0.2999")
      expect_gen(0.2999, 6, "0.2999")

      expect_gen(0.299, 1, "0.3")
      expect_gen(0.299, 2, "0.3")
      expect_gen(0.299, 3, "0.299")
      expect_gen(0.299, 4, "0.299")
      expect_gen(0.299, 5, "0.299")
      expect_gen(0.299, 6, "0.299")

      expect_gen(0.29, 1, "0.3")
      expect_gen(0.29, 2, "0.29")
      expect_gen(0.29, 3, "0.29")
      expect_gen(0.29, 4, "0.29")
      expect_gen(0.29, 5, "0.29")
      expect_gen(0.29, 6, "0.29")

      expect_gen(0.2, 1, "0.2")
      expect_gen(0.2, 2, "0.2")
      expect_gen(0.2, 3, "0.2")
      expect_gen(0.2, 4, "0.2")
      expect_gen(0.2, 5, "0.2")
      expect_gen(0.2, 6, "0.2")

      expect_gen(0.02999, 1, "0.03")
      expect_gen(0.02999, 2, "0.03")
      expect_gen(0.02999, 3, "0.03")
      expect_gen(0.02999, 4, "0.02999")
      expect_gen(0.02999, 5, "0.02999")
      expect_gen(0.02999, 6, "0.02999")

      expect_gen(0.0299, 1, "0.03")
      expect_gen(0.0299, 2, "0.03")
      expect_gen(0.0299, 3, "0.0299")
      expect_gen(0.0299, 4, "0.0299")
      expect_gen(0.0299, 5, "0.0299")
      expect_gen(0.0299, 6, "0.0299")

      expect_gen(0.029, 1, "0.03")
      expect_gen(0.029, 2, "0.029")
      expect_gen(0.029, 3, "0.029")
      expect_gen(0.029, 4, "0.029")
      expect_gen(0.029, 5, "0.029")
      expect_gen(0.029, 6, "0.029")

      expect_gen(0.02, 1, "0.02")
      expect_gen(0.02, 2, "0.02")
      expect_gen(0.02, 3, "0.02")
      expect_gen(0.02, 4, "0.02")
      expect_gen(0.02, 5, "0.02")
      expect_gen(0.02, 6, "0.02")

      expect_gen(0.002999, 1, "0.003")
      expect_gen(0.002999, 2, "0.003")
      expect_gen(0.002999, 3, "0.003")
      expect_gen(0.002999, 4, "0.002999")
      expect_gen(0.002999, 5, "0.002999")
      expect_gen(0.002999, 6, "0.002999")

      expect_gen(0.00299, 1, "0.003")
      expect_gen(0.00299, 2, "0.003")
      expect_gen(0.00299, 3, "0.00299")
      expect_gen(0.00299, 4, "0.00299")
      expect_gen(0.00299, 5, "0.00299")
      expect_gen(0.00299, 6, "0.00299")

      expect_gen(0.0029, 1, "0.003")
      expect_gen(0.0029, 2, "0.0029")
      expect_gen(0.0029, 3, "0.0029")
      expect_gen(0.0029, 4, "0.0029")
      expect_gen(0.0029, 5, "0.0029")
      expect_gen(0.0029, 6, "0.0029")

      expect_gen(0.002, 1, "0.002")
      expect_gen(0.002, 2, "0.002")
      expect_gen(0.002, 3, "0.002")
      expect_gen(0.002, 4, "0.002")
      expect_gen(0.002, 5, "0.002")
      expect_gen(0.002, 6, "0.002")

      expect_gen(0.0002999, 1, "0.0003")
      expect_gen(0.0002999, 2, "0.0003")
      expect_gen(0.0002999, 3, "0.0003")
      expect_gen(0.0002999, 4, "0.0002999")
      expect_gen(0.0002999, 5, "0.0002999")
      expect_gen(0.0002999, 6, "0.0002999")

      expect_gen(0.000299, 1, "0.0003")
      expect_gen(0.000299, 2, "0.0003")
      expect_gen(0.000299, 3, "0.000299")
      expect_gen(0.000299, 4, "0.000299")
      expect_gen(0.000299, 5, "0.000299")
      expect_gen(0.000299, 6, "0.000299")

      expect_gen(0.00029, 1, "0.0003")
      expect_gen(0.00029, 2, "0.00029")
      expect_gen(0.00029, 3, "0.00029")
      expect_gen(0.00029, 4, "0.00029")
      expect_gen(0.00029, 5, "0.00029")
      expect_gen(0.00029, 6, "0.00029")

      expect_gen(0.0002, 1, "0.0002")
      expect_gen(0.0002, 2, "0.0002")
      expect_gen(0.0002, 3, "0.0002")
      expect_gen(0.0002, 4, "0.0002")
      expect_gen(0.0002, 5, "0.0002")
      expect_gen(0.0002, 6, "0.0002")

      expect_gen(0.00002999, 1, "3e-5")
      expect_gen(0.00002999, 2, "3e-5")
      expect_gen(0.00002999, 3, "3e-5")
      expect_gen(0.00002999, 4, "2.999e-5")
      expect_gen(0.00002999, 5, "2.999e-5")
      expect_gen(0.00002999, 6, "2.999e-5")

      expect_gen(0.0000299, 1, "3e-5")
      expect_gen(0.0000299, 2, "3e-5")
      expect_gen(0.0000299, 3, "2.99e-5")
      expect_gen(0.0000299, 4, "2.99e-5")
      expect_gen(0.0000299, 5, "2.99e-5")
      expect_gen(0.0000299, 6, "2.99e-5")

      expect_gen(0.000029, 1, "3e-5")
      expect_gen(0.000029, 2, "2.9e-5")
      expect_gen(0.000029, 3, "2.9e-5")
      expect_gen(0.000029, 4, "2.9e-5")
      expect_gen(0.000029, 5, "2.9e-5")
      expect_gen(0.000029, 6, "2.9e-5")

      expect_gen(0.00002, 1, "2e-5")
      expect_gen(0.00002, 2, "2e-5")
      expect_gen(0.00002, 3, "2e-5")
      expect_gen(0.00002, 4, "2e-5")
      expect_gen(0.00002, 5, "2e-5")
      expect_gen(0.00002, 6, "2e-5")
    end

    it "transitions between values of the scientific exponent X" do
      {% for tc in GEN_TRANSITIONS %}
        expect_gen(hexfloat({{ tc[0] }}), {{ tc[1] }}, {{ tc[2] }}, file: {{ tc.filename }}, line: {{ tc.line_number }})
      {% end %}
    end

    it "UCRT had trouble with rounding this value" do
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 105, "109995565999999994887854821710219658911365648587951921896774663603198787416706536331386569598149846892544")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 19, "1.099955659999999949e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 18, "1.09995565999999995e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 17, "1.0999556599999999e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 16, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 15, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 14, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 13, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 12, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 11, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 10, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 9, "1.09995566e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 8, "1.0999557e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 7, "1.099956e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 6, "1.09996e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 5, "1.1e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 4, "1.1e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 3, "1.1e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 2, "1.1e+104")
      expect_gen(hexfloat("0x1.88e2d605edc3dp+345"), 1, "1e+104")
    end

    it "more cases that the UCRT had trouble with (e.g. DevCom-1093399)" do
      expect_gen(hexfloat("0x1.8p+62"), 17, "6.9175290276410819e+18")
      expect_gen(hexfloat("0x1.0a2742p+17"), 6, "136271")
      expect_gen(hexfloat("0x1.f8b0f962cdffbp+205"), 14, "1.0137595739223e+62")
      expect_gen(hexfloat("0x1.f8b0f962cdffbp+205"), 17, "1.0137595739222531e+62")
      expect_gen(hexfloat("0x1.f8b0f962cdffbp+205"), 51, "1.01375957392225305727423222620636224221808910954041e+62")
      expect_gen(hexfloat("0x1.f8b0f962cdffbp+205"), 55, "1.013759573922253057274232226206362242218089109540405973e+62")
    end
  end
end
