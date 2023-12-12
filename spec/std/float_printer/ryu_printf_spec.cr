# FIXME: this leads to an OOB on wasm32 (#13918)
{% skip_file if flag?(:wasm32) %}

# This file contains test cases derived from:
#
# * https://github.com/ulfjack/ryu
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
end
