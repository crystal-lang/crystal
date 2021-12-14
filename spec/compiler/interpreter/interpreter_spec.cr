{% skip_file if flag?(:without_interpreter) %}
require "../spec_helper"

private macro assert_overflows(code, file = __FILE__, line = __LINE__)
  it "overlows on {{code}}", file: {{file}}, line: {{line}} do
    interpret(%(
      class OverflowError < Exception; end

      fun __crystal_raise_overflow : NoReturn
        raise OverflowError.new
      end

      @[Primitive(:interpreter_raise_without_backtrace)]
      def raise(exception : Exception) : NoReturn
      end

      begin
        a = {{code}}
        1
      rescue OverflowError
        2
      end
    )).should eq(2)
  end
end

describe Crystal::Repl::Interpreter do
  context "literals" do
    it "interprets nil" do
      interpret("nil").should be_nil
    end

    it "interprets a bool (false)" do
      interpret("false").should be_false
    end

    it "interprets a bool (true)" do
      interpret("true").should be_true
    end

    it "interprets an Int8" do
      interpret("123_i8").should eq(123_i8)
    end

    it "interprets an UInt8" do
      interpret("145_u8").should eq(145_u8)
    end

    it "interprets an Int16" do
      interpret("12345_i16").should eq(12345_i16)
    end

    it "interprets an UInt16" do
      interpret("12389_u16").should eq(12389_u16)
    end

    it "interprets an Int32" do
      interpret("123456789_i32").should eq(123456789)
    end

    it "interprets an UInt32" do
      interpret("323456789_u32").should eq(323456789_u32)
    end

    it "interprets an Int64" do
      interpret("123_i64").should eq(123_i64)
    end

    it "interprets an UInt64" do
      interpret("123_u64").should eq(123_u64)
    end

    it "interprets an Int128" do
      interpret("123_i128").should eq(123_i128)
    end

    it "interprets an UInt128" do
      interpret("123_u128").should eq(123_u128)
    end

    it "interprets a Float32" do
      interpret("1.5_f32").should eq(1.5_f32)
    end

    it "interprets a Float64" do
      interpret("1.5").should eq(1.5)
    end

    it "interprets a char" do
      interpret("'a'").should eq('a')
    end

    it "interprets a String literal" do
      interpret(%("Hello world!")).should eq("Hello world!")
    end

    it "uses a string pool" do
      interpret(<<-CODE).should eq(true)
        "a".object_id == "a".object_id
      CODE
    end

    it "precomputes string literal length" do
      interpret(<<-CODE).should eq(1)
        "旅".@length
      CODE
    end
  end

  context "local variables" do
    it "interprets variable set" do
      interpret(<<-CODE).should eq(1)
      a = 1
      CODE
    end

    it "interprets variable set and get" do
      interpret(<<-CODE).should eq(1)
      a = 1
      a
      CODE
    end

    it "interprets variable set and get, second local var" do
      interpret(<<-CODE).should eq(1)
      x = 10
      a = 1
      a
      CODE
    end

    it "interprets variable set and get with operations" do
      interpret(<<-CODE).should eq(6)
      a = 1
      b = 2
      c = 3
      a + b + c
      CODE
    end

    it "interprets uninitialized" do
      interpret(<<-CODE).should eq(3)
        a = uninitialized Int32
        a = 3
        a
        CODE
    end

    it "doesn't declare variable with no type" do
      interpret(<<-CODE).should eq(nil)
      x = nil
      if x
        y = x
      end
      CODE
    end

    it "doesn't declare variable with no type inside method" do
      interpret(<<-CODE).should eq(nil)
        def foo(x)
          if x
            y = x
          end
        end

        foo(nil)
      CODE
    end

    it "assigns to underscore" do
      interpret(<<-CODE).should eq(1)
        _ = (a = 1)
        a
      CODE
    end

    it "doesn't discard underscore right hand side" do
      interpret(<<-CODE).should eq(1)
        a = (_ = 1)
        a
      CODE
    end

    it "interprets at the class level" do
      interpret(<<-CODE).should eq(1)
        x = 0

        class Foo
          x = self.foo

          def self.foo
            bar
          end

          def self.bar
            1
          end
        end

        x
      CODE
    end
  end

  context "conversion" do
    {% for target_type in %w(u8 i8 u16 i16 u32 i32 u i u64 i64 f32 f64).map(&.id) %}
      it "interprets Int8::MAX#to_{{target_type}}!" do
        interpret("#{Int8::MAX}_i8.to_{{target_type}}!").should eq(Int8::MAX.to_{{target_type}}!)
      end

      it "interprets Int8::MIN#to_{{target_type}}!" do
        interpret("#{Int8::MIN}_i8.to_{{target_type}}!").should eq(Int8::MIN.to_{{target_type}}!)
      end

      it "interprets UInt8::MAX#to_{{target_type}}!" do
        interpret("#{UInt8::MAX}_u8.to_{{target_type}}!").should eq(UInt8::MAX.to_{{target_type}}!)
      end

      it "interprets Int16::MAX#to_{{target_type}}!" do
        interpret("#{Int16::MAX}_i16.to_{{target_type}}!").should eq(Int16::MAX.to_{{target_type}}!)
      end

      it "interprets Int16::MIN#to_{{target_type}}!" do
        interpret("#{Int16::MIN}_i16.to_{{target_type}}!").should eq(Int16::MIN.to_{{target_type}}!)
      end

      it "interprets UInt16::MAX#to_{{target_type}}!" do
        interpret("#{UInt16::MAX}_u16.to_{{target_type}}!").should eq(UInt16::MAX.to_{{target_type}}!)
      end

      it "interprets Int32::MAX#to_{{target_type}}!" do
        interpret("#{Int32::MAX}.to_{{target_type}}!").should eq(Int32::MAX.to_{{target_type}}!)
      end

      it "interprets Int32::MIN#to_{{target_type}}!" do
        interpret("#{Int32::MIN}.to_{{target_type}}!").should eq(Int32::MIN.to_{{target_type}}!)
      end

      it "interprets UInt32::MAX#to_{{target_type}}!" do
        interpret("#{UInt32::MAX}_u32.to_{{target_type}}!").should eq(UInt32::MAX.to_{{target_type}}!)
      end

      it "interprets Int64::MAX#to_{{target_type}}!" do
        interpret("#{Int64::MAX}_i64.to_{{target_type}}!").should eq(Int64::MAX.to_{{target_type}}!)
      end

      it "interprets Int64::MIN#to_{{target_type}}!" do
        interpret("#{Int64::MIN}_i64.to_{{target_type}}!").should eq(Int64::MIN.to_{{target_type}}!)
      end

      it "interprets UInt64::MAX#to_{{target_type}}!" do
        interpret("#{UInt64::MAX}_u64.to_{{target_type}}!").should eq(UInt64::MAX.to_{{target_type}}!)
      end

      it "interprets Float32#to_{{target_type}}! (positive)" do
        f = 23.8_f32
        interpret("23.8_f32.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end

      it "interprets Float32#to_{{target_type}}! (negative)" do
        f = -23.8_f32
        interpret("-23.8_f32.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end

      it "interprets Float64#to_{{target_type}}! (positive)" do
        f = 23.8_f64
        interpret("23.8_f64.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end

      it "interprets Float64#to_{{target_type}}! (negative)" do
        f = -23.8_f64
        interpret("-23.8_f64.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end
    {% end %}

    it "interprets Char#ord" do
      interpret("'a'.ord").should eq('a'.ord)
    end

    it "Int32#unsafe_chr" do
      interpret("97.unsafe_chr").should eq(97.unsafe_chr)
    end

    it "UInt8#unsafe_chr" do
      interpret("97_u8.unsafe_chr").should eq(97.unsafe_chr)
    end

    it "discards conversion" do
      interpret(<<-CODE).should eq(3)
      1.to_i8!
      3
      CODE
    end

    it "discards conversion with local var" do
      interpret(<<-CODE).should eq(3)
      x = 1
      x.to_i8!
      3
      CODE
    end
  end

  context "overflow" do
    context "+" do
      assert_overflows 1_u8 + 255
      assert_overflows 1_i8 + 128
      assert_overflows 1_u16 + 65535
      assert_overflows 1_i16 + 32767
      assert_overflows 1_u32 + 4294967295
      assert_overflows 1_i32 + 2147483647
      assert_overflows 1_u64 + 18446744073709551615
      assert_overflows 1_i64 + 9223372036854775807
    end

    context "-" do
      assert_overflows 1_u8 - 2
      assert_overflows 1_i8 - 256
      assert_overflows 1_u16 - 2
      assert_overflows 1_i16 - 32770
      assert_overflows 1_u32 - 2
      assert_overflows 1_i32 - 2147483650
      assert_overflows 1_u64 - 2
      assert_overflows 1_i64 - 9223372036854775810
    end

    context "*" do
      assert_overflows 10_u8 * 26
      assert_overflows 10_i8 * 14
      assert_overflows 10_u16 * 6600
      assert_overflows 10_i16 * 3300
      assert_overflows 20_u32 * 429496729
      assert_overflows 20_i32 * 214748364
      assert_overflows 20_u64 * 1844674407370955161
      assert_overflows 20_i64 * 922337203685477580
    end

    context "conversion" do
      assert_overflows 128_u8.to_i8

      assert_overflows -1_i8.to_u8
      assert_overflows -1_i8.to_u16
      assert_overflows -1_i8.to_u32
      assert_overflows -1_i8.to_u64

      assert_overflows 128_u16.to_i8
      assert_overflows 32768_u16.to_i16

      assert_overflows -1_i16.to_u8
      assert_overflows -1_i16.to_u16
      assert_overflows -1_i16.to_u32
      assert_overflows -1_i16.to_u64

      assert_overflows 128_u32.to_i8
      assert_overflows 32768_u32.to_i16
      assert_overflows 2147483648_u32.to_i32

      assert_overflows -1_i32.to_u8
      assert_overflows -1_i32.to_u16
      assert_overflows -1_i32.to_u32
      assert_overflows -1_i32.to_u64

      assert_overflows 128_u64.to_i8
      assert_overflows 32768_u64.to_i16
      assert_overflows 2147483648_u64.to_i32
      assert_overflows 9223372036854775808_u64.to_i64

      assert_overflows -1_i64.to_u8
      assert_overflows -1_i64.to_u16
      assert_overflows -1_i64.to_u32
      assert_overflows -1_i64.to_u64

      assert_overflows 256_f32.to_u8
      assert_overflows 128_f32.to_i8
      assert_overflows 65536_f32.to_u16
      assert_overflows 32768_f32.to_i16

      # TODO: uncomment these once they also overflow on compiled Crystal
      # assert_overflows 4294967296_f32.to_u32
      # assert_overflows 2147483648_f32.to_i32
      # assert_overflows 18446744073709551616_f32.to_u64
      # assert_overflows 9223372036854775808_f32.to_i64

      assert_overflows 256_f64.to_u8
      assert_overflows 128_f64.to_i8
      assert_overflows 65536_f64.to_u16
      assert_overflows 32768_f64.to_i16
      assert_overflows 4294967296_f64.to_u32
      assert_overflows 2147483648_f64.to_i32

      # TODO: uncomment these once they also overflow on compiled Crystal
      # assert_overflows 18446744073709551616_f64.to_u64
      # assert_overflows 9223372036854775808_f64.to_i64

      assert_overflows 1.7976931348623157e+308.to_f32
    end
  end

  context "math" do
    it "interprets Int32 + Int32" do
      interpret("1 + 2").should eq(3)
    end

    it "interprets Int32 &+ Int32" do
      interpret("1 &+ 2").should eq(3)
    end

    it "interprets Int64 + Int64" do
      interpret("1_i64 + 2_i64").should eq(3)
    end

    it "interprets Int32 - Int32" do
      interpret("1 - 2").should eq(-1)
    end

    it "interprets Int32 &- Int32" do
      interpret("1 &- 2").should eq(-1)
    end

    it "interprets Int32 * Int32" do
      interpret("2 * 3").should eq(6)
    end

    it "interprets Int32 &* Int32" do
      interpret("2 &* 3").should eq(6)
    end

    it "interprets UInt64 * Int32" do
      interpret("2_u64 * 3").should eq(6)
    end

    it "interprets UInt8 | Int32" do
      interpret("1_u8 | 2").should eq(3)
    end

    it "interprets UInt64 | UInt32" do
      interpret("1_u64 | 2_u32").should eq(3)
    end

    it "interprets UInt32 - Int32" do
      interpret("3_u32 - 2").should eq(1)
    end

    it "interprets Int32 + Float64" do
      interpret("1 + 2.5").should eq(3.5)
    end

    it "interprets Float32 + Float64" do
      interpret("1.0_f32 + 0.0").should eq(1.0_f32)
    end

    it "interprets Float64 + Int32" do
      interpret("2.5 + 1").should eq(3.5)
    end

    it "interprets Float64 + Float64" do
      interpret("2.5 + 2.3").should eq(4.8)
    end

    it "interprets Float64 - Float64" do
      interpret("2.5 - 2.3").should eq(2.5 - 2.3)
    end

    it "interprets Float64 * Float64" do
      interpret("2.5 * 2.3").should eq(2.5 * 2.3)
    end

    it "interprets Int8 + Int8" do
      interpret("1_i8 + 2_i8").should eq(3)
    end

    it "interprets UInt64 & Int32" do
      interpret("604_u64 & 4095").should eq(604)
    end

    it "interprets Int128 + Int32" do
      interpret("1_i128 + 2").should eq(3)
    end

    it "discards math" do
      interpret("1 + 2; 4").should eq(4)
    end

    it "interprets Int32.unsafe_shl(Int32) with self" do
      interpret(<<-CODE).should eq(4)
        struct Int32
          def shl2
            unsafe_shl(2)
          end
        end

        a = 1
        a.shl2
        CODE
    end
  end

  context "comparisons" do
    it "interprets Bool == Bool (false)" do
      interpret("true == false").should be_false
    end

    it "interprets Bool == Bool (true)" do
      interpret("true == true").should be_true
    end

    it "interprets Bool != Bool (false)" do
      interpret("true != true").should be_false
    end

    it "interprets Bool != Bool (true)" do
      interpret("true != false").should be_true
    end

    it "interprets Int32 < Int32" do
      interpret("1 < 2").should be_true
    end

    it "interprets Int32 == Int32 (true)" do
      interpret("1 == 1").should be_true
    end

    it "interprets Int32 == Int32 (false)" do
      interpret("1 == 2").should be_false
    end

    it "interprets Int32 != Int32 (true)" do
      interpret("1 != 2").should be_true
    end

    it "interprets Int32 != Int32 (false)" do
      interpret("1 != 1").should be_false
    end

    it "interprets Int32 == UInt64 (true)" do
      interpret("1 == 1_u64").should be_true
    end

    it "interprets Int32 == UInt64 (false)" do
      interpret("2 == 1_u64").should be_false
    end

    it "interprets Int32 != UInt64 (true)" do
      interpret("1 != 2_u64").should be_true
    end

    it "interprets Int32 != UInt64 (false)" do
      interpret("1 != 1_u64").should be_false
    end

    it "interprets UInt64 != Int32 (true)" do
      interpret("2_u64 != 1").should be_true
    end

    it "interprets UInt64 != Int32 (false)" do
      interpret("1_u64 != 1").should be_false
    end

    it "interprets Int128 == Int128 (false)" do
      interpret("1_i128 == 2_i128").should be_false
    end

    it "interprets Int128 == Int128 (true)" do
      interpret("1_i128 == 1_i128").should be_true
    end

    it "interprets Float32 / Int32" do
      interpret("2.5_f32 / 2").should eq(2.5_f32 / 2)
    end

    it "interprets Float32 / Float32" do
      interpret("2.5_f32 / 2.1_f32").should eq(2.5_f32 / 2.1_f32)
    end

    it "interprets Float64 / Float64" do
      interpret("2.5 / 2.1").should eq(2.5 / 2.1)
    end

    it "interprets Float32 fdiv Float64" do
      interpret("2.5_f32.fdiv(2.1_f64)").should eq(2.5_f32.fdiv(2.1_f64))
    end

    it "interprets Float64 fdiv Float32" do
      interpret("2.5_f64.fdiv(2.1_f32)").should eq(2.5_f64.fdiv(2.1_f32))
    end

    it "interprets Int32 == Float64 (true)" do
      interpret("1 == 1.0").should be_true
    end

    it "interprets Int32 == Float64 (false)" do
      interpret("1 == 1.2").should be_false
    end

    it "interprets Int32 > Float64 (true)" do
      interpret("2 > 1.9").should be_true
    end

    it "interprets Int32 > Float64 (false)" do
      interpret("2 > 2.1").should be_false
    end

    it "interprets UInt8 < Int32 (true, right is greater than zero)" do
      interpret("1_u8 < 2").should be_true
    end

    it "interprets UInt8 < Int32 (false, right is greater than zero)" do
      interpret("1_u8 < 0").should be_false
    end

    it "interprets UInt8 < Int32 (false, right is less than zero)" do
      interpret("1_u8 < -1").should be_false
    end

    it "interprets UInt64 < Int32 (true, right is greater than zero)" do
      interpret("1_u64 < 2").should be_true
    end

    it "interprets UInt64 < Int32 (false, right is greater than zero)" do
      interpret("1_u64 < 0").should be_false
    end

    it "interprets UInt64 < Int32 (false, right is less than zero)" do
      interpret("1_u64 < -1").should be_false
    end

    it "interprets UInt64 > UInt32 (true)" do
      interpret("1_u64 > 0_u32").should be_true
    end

    it "interprets UInt64 > UInt32 (false)" do
      interpret("0_u64 > 1_u32").should be_false
    end

    it "interprets UInt32 < Int32 (true)" do
      interpret("1_u32 < 2").should be_true
    end

    it "interprets UInt32 < Int32 (false)" do
      interpret("1_u32 < 1").should be_false
    end

    it "interprets UInt64 == Int32 (false when Int32 < 0)" do
      interpret("1_u64 == -1").should be_false
    end

    it "interprets UInt64 == Int32 (false when Int32 >= 0)" do
      interpret("1_u64 == 0").should be_false
    end

    it "interprets UInt64 == Int32 (true when Int32 >= 0)" do
      interpret("1_u64 == 1").should be_true
    end

    it "interprets Char == Char (false)" do
      interpret("'a' == 'b'").should be_false
    end

    it "interprets Char == Char (true)" do
      interpret("'a' == 'a'").should be_true
    end

    it "interprets Int32 < Float64" do
      interpret("1 < 2.5").should be_true
    end

    it "interprets Float64 < Int32" do
      interpret("1.2 < 2").should be_true
    end

    it "interprets Float64 < Float64" do
      interpret("1.2 < 2.3").should be_true
    end

    it "interprets UInt64.unsafe_mod(UInt64)" do
      interpret(<<-CODE).should eq(906272454103984)
        a = 10097976637018756016_u64
        b = 9007199254740992_u64
        a.unsafe_mod(b)
        CODE
    end

    it "discards comparison" do
      interpret("1 < 2; 3").should eq(3)
    end
  end

  context "logical operations" do
    it "interprets not for nil" do
      interpret("!nil").should eq(true)
    end

    it "interprets not for nil type" do
      interpret("x = 1; !(x = 2; nil); x").should eq(2)
    end

    it "interprets not for bool true" do
      interpret("!true").should eq(false)
    end

    it "interprets not for bool false" do
      interpret("!false").should eq(true)
    end

    it "discards nil not" do
      interpret("!nil; 3").should eq(3)
    end

    it "discards bool not" do
      interpret("!false; 3").should eq(3)
    end

    it "interprets not for bool false" do
      interpret("!false").should eq(true)
    end

    it "interprets not for mixed union (nil)" do
      interpret("!(1 == 1 ? nil : 2)").should eq(true)
    end

    it "interprets not for mixed union (false)" do
      interpret("!(1 == 1 ? false : 2)").should eq(true)
    end

    it "interprets not for mixed union (true)" do
      interpret("!(1 == 1 ? true : 2)").should eq(false)
    end

    it "interprets not for mixed union (other)" do
      interpret("!(1 == 1 ? 2 : true)").should eq(false)
    end

    it "interprets not for nilable type (false)" do
      interpret(%(!(1 == 1 ? "hello" : nil))).should eq(false)
    end

    it "interprets not for nilable type (true)" do
      interpret(%(!(1 == 1 ? nil : "hello"))).should eq(true)
    end

    it "interprets not for nilable proc type (true)" do
      interpret(<<-CODE).should eq(true)
        a =
          if 1 == 1
            nil
          else
            ->{ 1 }
          end
        !a
        CODE
    end

    it "interprets not for nilable proc type (false)" do
      interpret(<<-CODE).should eq(false)
        a =
          if 1 == 1
            ->{ 1 }
          else
            nil
          end
        !a
        CODE
    end

    it "interprets not for generic class instance type" do
      interpret(<<-CODE).should eq(false)
        class Foo(T)
        end

        foo = Foo(Int32).new
        !foo
        CODE
    end

    it "interprets not for nilable type (false)" do
      interpret(<<-CODE).should eq(false)
        class Foo
        end

        a =
          if 1 == 1
            "a"
          elsif 1 == 1
            Foo.new
          else
            nil
          end
        !a
        CODE
    end

    it "interprets not for nilable type (true)" do
      interpret(<<-CODE).should eq(true)
        class Foo
        end

        a =
          if 1 == 1
            nil
          elsif 1 == 1
            Foo.new
          else
            "a"
          end
        !a
        CODE
    end
  end

  context "control flow" do
    it "interprets if (true literal)" do
      interpret("true ? 2 : 3").should eq(2)
    end

    it "interprets if (false literal)" do
      interpret("false ? 2 : 3").should eq(3)
    end

    it "interprets if (nil literal)" do
      interpret("nil ? 2 : 3").should eq(3)
    end

    it "interprets if bool (true)" do
      interpret("1 == 1 ? 2 : 3").should eq(2)
    end

    it "interprets if bool (false)" do
      interpret("1 == 2 ? 2 : 3").should eq(3)
    end

    it "interprets if (nil type)" do
      interpret("a = nil; a ? 2 : 3").should eq(3)
    end

    it "interprets if (int type)" do
      interpret("a = 1; a ? 2 : 3").should eq(2)
    end

    it "interprets if union type with bool, true" do
      interpret("a = 1 == 1 ? 1 : false; a ? 2 : 3").should eq(2)
    end

    it "interprets if union type with bool, false" do
      interpret("a = 1 == 2 ? 1 : false; a ? 2 : 3").should eq(3)
    end

    it "interprets if union type with nil, false" do
      interpret("a = 1 == 2 ? 1 : nil; a ? 2 : 3").should eq(3)
    end

    it "interprets if pointer, true" do
      interpret("ptr = Pointer(Int32).new(1_u64); ptr ? 2 : 3").should eq(2)
    end

    it "interprets if pointer, false" do
      interpret("ptr = Pointer(Int32).new(0_u64); ptr ? 2 : 3").should eq(3)
    end

    it "interprets unless" do
      interpret("unless 1 == 1; 2; else; 3; end").should eq(3)
    end

    it "discards if" do
      interpret("1 == 1 ? 2 : 3; 4").should eq(4)
    end

    it "interprets while" do
      interpret(<<-CODE).should eq(10)
        a = 0
        while a < 10
          a = a + 1
        end
        a
        CODE
    end

    it "interprets while, returns nil" do
      interpret(<<-CODE).should eq(nil)
        a = 0
        while a < 10
          a = a + 1
        end
        CODE
    end

    it "interprets until" do
      interpret(<<-CODE).should eq(10)
        a = 0
        until a == 10
          a = a + 1
        end
        a
      CODE
    end

    it "interprets break inside while" do
      interpret(<<-CODE).should eq(3)
        a = 0
        while a < 10
          a += 1
          break if a == 3
        end
        a
        CODE
    end

    it "interprets break inside nested while" do
      interpret(<<-CODE).should eq(6)
        a = 0
        b = 0
        c = 0

        while a < 3
          while b < 3
            b += 1
            c += 1
            break if b == 1
          end

          a += 1
          c += 1
          break if a == 3
        end

        c
        CODE
    end

    it "interprets break inside while inside block" do
      interpret(<<-CODE).should eq(3)
        def foo
          yield
          20
        end

        a = 0
        foo do
          while a < 10
            a += 1
            break if a == 3
          end
        end
        a
        CODE
    end

    it "interprets break with value inside while (through break)" do
      interpret(<<-CODE).should eq(8)
        a = 0
        x = while a < 10
          a += 1
          break 8 if a == 3
        end
        x || 10
        CODE
    end

    it "interprets break with value inside while (through normal flow)" do
      interpret(<<-CODE).should eq(10)
        a = 0
        x = while a < 10
          a += 1
          break 8 if a == 20
        end
        x || 10
        CODE
    end

    it "interprets next inside while" do
      interpret(<<-CODE).should eq(1 + 2 + 8 + 9 + 10)
        a = 0
        x = 0
        while a < 10
          a += 1

          next if 3 <= a <= 7

          x += a
        end
        x
        CODE
    end

    it "interprets next inside while inside block" do
      interpret(<<-CODE).should eq(1 + 2 + 8 + 9 + 10)
        def foo
          yield
          10
        end

        a = 0
        x = 0
        foo do
          while a < 10
            a += 1

            next if 3 <= a <= 7

            x += a
          end
        end
        x
        CODE
    end

    it "discards while" do
      interpret("while 1 == 2; 3; end; 4").should eq(4)
    end

    it "interprets return" do
      interpret(<<-CODE).should eq(2)
        def foo(x)
          if x == 1
            return 2
          end

          3
        end

        foo(1)
      CODE
    end

    it "interprets return Nil" do
      interpret(<<-CODE).should be_nil
        def foo : Nil
          1
        end

        foo
      CODE
    end

    it "interprets return implicit nil and Int32" do
      interpret(<<-CODE).should eq(10)
        def foo(x)
          if x == 1
            return
          end

          3
        end

        z = foo(1)
        if z.is_a?(Int32)
          z
        else
          10
        end
      CODE
    end
  end

  context "pointers" do
    it "interprets pointer set and get (int)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 10
        ptr.value
      CODE
    end

    it "interprets pointer set and get (bool)" do
      interpret(<<-CODE).should be_true
        ptr = Pointer(Bool).malloc(1_u64)
        ptr.value = true
        ptr.value
      CODE
    end

    it "interprets pointer set and get (clear stack)" do
      interpret(<<-CODE).should eq(50.unsafe_chr)
        ptr = Pointer(UInt8).malloc(1_u64)
        ptr.value = 50_u8
        ptr.value.unsafe_chr
      CODE
    end

    it "interprets pointerof, mutates pointer, read var" do
      interpret(<<-CODE).should eq(2)
        a = 1
        ptr = pointerof(a)
        ptr.value = 2
        a
      CODE
    end

    it "interprets pointerof, mutates var, read pointer" do
      interpret(<<-CODE).should eq(2)
        a = 1
        ptr = pointerof(a)
        a = 2
        ptr.value
      CODE
    end

    it "interprets pointerof and mutates memory (there are more variables)" do
      interpret(<<-CODE).should eq(2)
        x = 42
        a = 1
        ptr = pointerof(a)
        ptr.value = 2
        a
      CODE
    end

    it "pointerof instance var" do
      interpret(<<-CODE).should eq(2)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def x_ptr
            pointerof(@x)
          end
        end

        foo = Foo.new(1)
        ptr = foo.x_ptr
        ptr.value = 2
        foo.x
      CODE
    end

    it "pointerof class var" do
      interpret(<<-CODE).should eq(2)
        class Foo
          @@x : Int32?

          def self.x_ptr
            pointerof(@@x)
          end

          def self.x
            @@x
          end
        end

        ptr = Foo.x_ptr
        v = ptr.value
        ptr.value = 2
        x = Foo.x
        x || 0
      CODE
    end

    it "pointerof read instance var" do
      interpret(<<-CODE).should eq(2)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def x_ptr
            pointerof(@x)
          end
        end

        foo = Foo.new(1)
        ptr = pointerof(foo.@x)
        ptr.value = 2
        foo.x
      CODE
    end

    it "interprets pointer set and get (union type)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32 | Bool).malloc(1_u64)
        ptr.value = 10
        value = ptr.value
        if value.is_a?(Int32)
          value
        else
          20
        end
      CODE
    end

    it "interprets pointer set and get (union type, setter value)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32 | Bool).malloc(1_u64)
        ptr.value = 10
      CODE
    end

    it "interprets pointer new and pointer address" do
      interpret(<<-CODE).should eq(123_u64)
        ptr = Pointer(Int32 | Bool).new(123_u64)
        ptr.address
      CODE
    end

    it "interprets pointer diff" do
      interpret(<<-CODE).should eq(8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
      CODE
    end

    it "interprets pointer diff, negative" do
      interpret(<<-CODE).should eq(-8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr2 - ptr1
      CODE
    end

    it "discards pointer malloc" do
      interpret(<<-CODE).should eq(1)
        Pointer(Int32).malloc(1_u64)
        1
      CODE
    end

    it "discards pointer get" do
      interpret(<<-CODE).should eq(1)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value
        1
      CODE
    end

    it "discards pointer set" do
      interpret(<<-CODE).should eq(1)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 1
      CODE
    end

    it "discards pointer new" do
      interpret(<<-CODE).should eq(1)
        Pointer(Int32).new(1_u64)
        1
      CODE
    end

    it "discards pointer diff" do
      interpret(<<-CODE).should eq(1)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
        1
      CODE
    end

    it "discards pointerof" do
      interpret(<<-CODE).should eq(3)
        a = 1
        pointerof(a)
        3
      CODE
    end

    it "interprets pointer add" do
      interpret(<<-CODE).should eq(9)
        ptr = Pointer(Int32).new(1_u64)
        ptr2 = ptr + 2_i64
        ptr2.address
      CODE
    end

    it "discards pointer add" do
      interpret(<<-CODE).should eq(3)
        ptr = Pointer(Int32).new(1_u64)
        ptr + 2_i64
        3
      CODE
    end

    it "interprets pointer realloc" do
      interpret(<<-CODE).should eq(3)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr2 = ptr.realloc(2_u64)
        3
      CODE
    end

    it "discards pointer realloc" do
      interpret(<<-CODE).should eq(3)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.realloc(2_u64)
        3
      CODE
    end

    it "interprets pointer realloc wrapper" do
      interpret(<<-CODE).should eq(3)
        struct Pointer(T)
          def realloc(n)
            realloc(n.to_u64)
          end
        end

        ptr = Pointer(Int32).malloc(1_u64)
        ptr2 = ptr.realloc(2)
        3
      CODE
    end

    it "interprets nilable pointer truthiness" do
      interpret(<<-CODE).should eq(1)
        ptr = 1 == 1 ? Pointer(UInt8).malloc(1) : nil
        if ptr
          1
        else
          2
        end
      CODE
    end
  end

  context "unions" do
    it "put and remove from union, together with is_a? (truthy case)" do
      interpret(<<-CODE).should eq(2)
        a = 1 == 1 ? 2 : true
        a.is_a?(Int32) ? a : 4
        CODE
    end

    it "put and remove from union, together with is_a? (falsey case)" do
      interpret(<<-CODE).should eq(true)
        a = 1 == 2 ? 2 : true
        a.is_a?(Int32) ? true : a
        CODE
    end

    it "returns union type" do
      interpret(<<-CODE).should eq('a')
        def foo
          if 1 == 1
            return 'a'
          end

          3
        end

        x = foo
        if x.is_a?(Char)
          x
        else
          'b'
        end
        CODE
    end

    it "put and remove from union in local var" do
      interpret(<<-CODE).should eq(3)
        a = 1 == 1 ? 2 : true
        a = 3
        a.is_a?(Int32) ? a : 4
        CODE
    end

    it "put and remove from union in instance var" do
      interpret(<<-CODE).should eq(2)
        class Foo
          @x : Int32 | Char

          def initialize
            if 1 == 1
              @x = 2
            else
              @x = 'a'
            end
          end

          def x
            @x
          end
        end

        foo = Foo.new
        z = foo.x
        if z.is_a?(Int32)
          z
        else
          10
        end
      CODE
    end

    it "discards is_a?" do
      interpret(<<-CODE).should eq(3)
        a = 1 == 1 ? 2 : true
        a.is_a?(Int32)
        3
        CODE
    end

    it "converts from NilableType to NonGenericClassType" do
      interpret(<<-CODE).should eq("a")
        a = 1 == 1 ? "a" : nil
        a || "b"
        CODE
    end

    it "puts union inside union" do
      interpret(<<-CODE).should eq('a'.ord)
        a = 'a' || 1 || true
        case a
        in Char
          a.ord
        in Int32
          a
        in Bool
          20
        end
        CODE
    end
  end

  context "is_a?" do
    it "does is_a? from NilableType to NonGenericClassType (true)" do
      interpret(<<-CODE).should eq("hello")
        a = "hello" || nil
        if a.is_a?(String)
          a
        else
          "bar"
        end
        CODE
    end

    it "does is_a? from NilableType to NonGenericClassType (false)" do
      interpret(<<-CODE).should eq("bar")
        a = 1 == 1 ? nil : "hello"
        if a.is_a?(String)
          a
        else
          z = a
          "bar"
        end
        CODE
    end

    it "does is_a? from NilableType to GenericClassInstanceType (true)" do
      interpret(<<-CODE).should eq(1)
        class Foo(T)
          def initialize(@x : T)
          end

          def x
            @x
          end
        end

        a = Foo.new(1) || nil
        if a.is_a?(Foo)
          a.x
        else
          2
        end
        CODE
    end

    it "does is_a? from NilableType to GenericClassInstanceType (false)" do
      interpret(<<-CODE).should eq(2)
        class Foo(T)
          def initialize(@x : T)
          end

          def x
            @x
          end
        end

        a = 1 == 1 ? nil : Foo.new(1)
        if a.is_a?(Foo)
          a.x
        else
          z = a
          2
        end
        CODE
    end

    it "does is_a? from NilableReferenceUnionType to NonGenericClassType (true)" do
      interpret(<<-CODE).should eq("hello")
        class Foo
        end

        a = 1 == 1 ? "hello" : (1 == 1 ? Foo.new : nil)
        if a.is_a?(String)
          a
        else
          "bar"
        end
        CODE
    end

    it "does is_a? from NilableReferenceUnionType to NonGenericClassType (false)" do
      interpret(<<-CODE).should eq("baz")
        class Foo
        end

        a = 1 == 1 ? "hello" : (1 == 1 ? Foo.new : nil)
        if a.is_a?(Foo)
          "bar"
        else
          "baz"
        end
        CODE
    end

    it "does is_a? from VirtualType to NonGenericClassType (true)" do
      interpret(<<-CODE).should eq(2)
        class Foo
          def x
            1
          end
        end

        class Bar < Foo
          def x
            2
          end
        end

        foo = Bar.new || Foo.new
        if foo.is_a?(Bar)
          foo.x
        else
          20
        end
        CODE
    end

    it "does is_a? from VirtualType to NonGenericClassType (false)" do
      interpret(<<-CODE).should eq(20)
        class Foo
          def x
            1
          end
        end

        class Bar < Foo
          def x
            2
          end
        end

        foo = Foo.new || Bar.new
        if foo.is_a?(Bar)
          foo.x
        else
          20
        end
        CODE
    end

    it "does is_a? from NilableProcType to Nil" do
      interpret(<<-CODE).should eq(10)
        proc = 1 == 1 ? nil : ->{ 1 }
        if proc.nil?
          10
        else
          20
        end
        CODE
    end

    it "does is_a? from NilableProcType to non-Nil" do
      interpret(<<-CODE).should eq(10)
        proc = 1 == 2 ? nil : ->{ 10 }
        if proc.is_a?(Proc)
          proc.call
        else
          20
        end
        CODE
    end
  end

  context "responds_to?" do
    it "does responds_to?" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def foo
            @x
          end
        end

        class Bar
          def initialize
            @x = 1
            @y = 2
          end

          def bar
            @y
          end
        end

        a = 0
        foo = Foo.new || Bar.new
        if foo.responds_to?(:foo)
          a += foo.foo
        end

        bar = Bar.new || Foo.new
        if bar.responds_to?(:bar)
          a += bar.bar
        end

        a
        CODE
    end
  end

  context "typeof" do
    it "interprets typeof instance type" do
      context, repl_value = interpret_with_context("typeof(1)")
      repl_value.value.should eq(context.program.int32.metaclass)
    end

    it "interprets typeof metaclass type" do
      context, repl_value = interpret_with_context("typeof(Int32)")
      repl_value.value.should eq(context.program.class_type)
    end

    it "interprets typeof virtual type" do
      interpret(<<-CODE, prelude: "prelude").should eq("Foo")
        abstract class Foo
        end

        class Bar < Foo
        end

        class Baz < Foo
        end

        foo = Baz.new.as(Foo)
        typeof(foo).to_s
      CODE
    end
  end

  context "types" do
    it "interprets path to type" do
      context, repl_value = interpret_with_context("String")
      repl_value.value.should eq(context.program.string.metaclass)
    end

    it "interprets class for non-union type" do
      context, repl_value = interpret_with_context("1.class")
      repl_value.value.should eq(context.program.int32)
    end

    it "discards class for non-union type" do
      interpret("1.class; 2").should eq(2)
    end

    it "interprets class for virtual_type type" do
      interpret(<<-CODE, prelude: "prelude").should eq("Bar")
          class Foo; end
          class Bar < Foo; end

          bar = Bar.new || Foo.new
          bar.class.to_s
        CODE
    end

    it "interprets class for virtual_type type (struct)" do
      interpret(<<-CODE, prelude: "prelude").should eq("Baz")
          abstract struct Foo; end
          struct Bar < Foo; end
          struct Baz < Foo; end

          baz = Baz.new || Bar.new
          baz.class.to_s
        CODE
    end

    it "discards class for virtual_type type" do
      interpret(<<-CODE).should eq(2)
          class Foo; end
          class Bar < Foo; end

          bar = Bar.new || Foo.new
          bar.class
          2
        CODE
    end

    it "interprets crystal_type_id for nil" do
      interpret("nil.crystal_type_id").should eq(0)
    end

    it "interprets crystal_type_id for non-nil" do
      context, repl_value = interpret_with_context("1.crystal_type_id")
      repl_value.value.should eq(context.type_id(context.program.int32))
    end

    it "interprets class_crystal_instance_type_id" do
      interpret(<<-CODE, prelude: "prelude").should be_true
        class Foo
        end

        Foo.new.crystal_type_id == Foo.crystal_instance_type_id
        CODE
    end

    it "discards Path" do
      interpret("String; 1").should eq(1)
    end

    it "discards typeof" do
      interpret("typeof(1); 1").should eq(1)
    end

    it "discards generic" do
      interpret("Pointer(Int32); 1").should eq(1)
    end

    it "discards .class" do
      interpret("1.class; 1").should eq(1)
    end

    it "discards crystal_type_id" do
      interpret("nil.crystal_type_id; 1").should eq(1)
    end
  end

  context "sizeof" do
    it "interprets sizeof typeof" do
      interpret("sizeof(typeof(1))").should eq(4)
    end
  end

  context "calls" do
    it "calls a top-level method without arguments and no local vars" do
      interpret(<<-CODE).should eq(3)
        def foo
          1 + 2
        end

        foo
        CODE
    end

    it "calls a top-level method without arguments but with local vars" do
      interpret(<<-CODE).should eq(3)
        def foo
          x = 1
          y = 2
          x + y
        end

        x = foo
        x
        CODE
    end

    it "calls a top-level method with two arguments" do
      interpret(<<-CODE).should eq(3)
        def foo(x, y)
          x + y
        end

        x = foo(1, 2)
        x
        CODE
    end

    it "interprets call with default values" do
      interpret(<<-CODE).should eq(3)
        def foo(x = 1, y = 2)
          x + y
        end

        foo
        CODE
    end

    it "interprets call with named arguments" do
      interpret(<<-CODE).should eq(-15)
        def foo(x, y)
          x - y
        end

        foo(y: 25, x: 10)
        CODE
    end

    it "interprets self for primitive types" do
      interpret(<<-CODE).should eq(42)
        struct Int32
          def foo
            self
          end
        end

        42.foo
        CODE
    end

    it "interprets explicit self call for primitive types" do
      interpret(<<-CODE).should eq(42)
        struct Int32
          def foo
            self.bar
          end

          def bar
            self
          end
        end

        42.foo
        CODE
    end

    it "interprets implicit self call for pointer" do
      interpret(<<-CODE).should eq(1)
        struct Pointer(T)
          def plus1
            self + 1_i64
          end
        end

        ptr = Pointer(UInt8).malloc(1_u64)
        ptr2 = ptr.plus1
        (ptr2 - ptr)
        CODE
    end

    it "interprets call with if" do
      interpret(<<-CODE).should eq(2)
        def foo
          1 == 1 ? 2 : 3
        end

        foo
        CODE
    end

    it "does call with struct as obj" do
      interpret(<<-CODE).should eq(3)
        struct Foo
          def initialize(@x : Int64)
          end

          def itself
            self
          end

          def x
            @x + 2_i64
          end
        end

        def foo
          Foo.new(1_i64)
        end

        foo.x
      CODE
    end

    it "does call with struct as obj (2)" do
      interpret(<<-CODE).should eq(2)
        struct Foo
          def two
            2
          end
        end

        Foo.new.two
      CODE
    end

    it "does call on instance var that's a struct, from a class" do
      interpret(<<-CODE).should eq(10)
        class Foo
          def initialize
            @x = 0_i64
            @y = 0_i64
            @z = 0_i64
            @bar = Bar.new(2)
          end

          def foo
            @bar.mutate
            @bar.x
          end
        end

        struct Bar
          def initialize(@x : Int32)
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end
        end

        Foo.new.foo
      CODE
    end

    it "does call on instance var that's a struct, from a struct" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 0_i64
            @y = 0_i64
            @z = 0_i64
            @bar = Bar.new(2)
          end

          def foo
            @bar.mutate
            @bar.x
          end
        end

        struct Bar
          def initialize(@x : Int32)
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end
        end

        Foo.new.foo
      CODE
    end

    it "discards call with struct as obj" do
      interpret(<<-CODE).should eq(4)
        struct Foo
          def initialize(@x : Int64)
          end

          def itself
            self
          end

          def x
            @x + 2_i64
          end
        end

        def foo
          Foo.new(1_i64)
        end

        foo.x
        4
      CODE
    end

    it "does call on constant that's a struct, takes a pointer to instance var" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        CONST = Foo.new
        CONST.to_unsafe.value
      CODE
    end

    it "does call on constant that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        CONST = Foo.new
        c = (1 == 1 ? CONST : CONST).to_unsafe
        c.value
      CODE
    end

    it "does call on var that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        a = Foo.new
        c = (1 == 1 ? a : a).to_unsafe
        c.value
      CODE
    end

    it "does call on ivar that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        struct Bar
          def initialize
            @foo = Foo.new
          end

          def do_it
            c = (1 == 1 ? @foo : @foo).to_unsafe
            c.value
          end
        end

        Bar.new.do_it
      CODE
    end

    it "does call on self that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end

          def do_it
            c = (1 == 1 ? self : self).to_unsafe
            c.value
          end
        end

        Foo.new.do_it
      CODE
    end

    it "does call on Pointer#value that's a struct, takes a pointer to instance var" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        foo = Foo.new
        ptr = pointerof(foo)
        c = ptr.value.to_unsafe
        c.value
      CODE
    end

    it "does call on read instance var that's a struct, takes a pointer to instance var" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        class Bar
          def initialize(@foo : Foo)
          end
        end

        foo = Foo.new
        bar = Bar.new(foo)
        c = bar.@foo.to_unsafe
        c.value
      CODE
    end

    it "does ReadInstanceVar with wants_struct_pointer" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 1
            @y = 10
            @bar = Bar.new
          end
        end

        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        entry = Pointer(Foo).malloc(1)
        entry.value = Foo.new
        ptr = entry.value.@bar.to_unsafe
        ptr.value
      CODE
    end

    it "does Assign var with wants_struct_pointer" do
      interpret(<<-CODE).should eq(42)
        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        bar = Bar.new
        ptr = (x = bar).to_unsafe
        ptr.value
      CODE
    end

    it "does Assign instance var with wants_struct_pointer" do
      interpret(<<-CODE).should eq(42)
        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        class Foo
          @x : Bar?

          def foo
            bar = Bar.new
            ptr = (@x = bar).to_unsafe
            ptr.value
          end
        end

        Foo.new.foo
      CODE
    end

    it "does Assign class var with wants_struct_pointer" do
      interpret(<<-CODE).should eq(42)
        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        class Foo
          @@x : Bar?

          def foo
            bar = Bar.new
            ptr = (@@x = bar).to_unsafe
            ptr.value
          end
        end

        Foo.new.foo
      CODE
    end

    it "inlines method that just reads an instance var" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 1
            @y = 10
            @bar = Bar.new
          end

          def bar
            @bar
          end
        end

        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        entry = Pointer(Foo).malloc(1)
        entry.value = Foo.new
        ptr = entry.value.bar.to_unsafe
        ptr.value
      CODE
    end

    it "inlines method that just reads an instance var, but produces side effects of args" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize
            @x = 1
            @y = 10
            @bar = Bar.new
          end

          def bar(x)
            @bar
          end
        end

        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 32
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        entry = Pointer(Foo).malloc(1)
        entry.value = Foo.new
        a = 1
        ptr = entry.value.bar(a = 10).to_unsafe
        ptr.value + a
      CODE
    end

    it "inlines method that just reads an instance var (2)" do
      interpret(<<-CODE).should eq(2)
        abstract class Abstract
        end

        class Concrete < Abstract
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        original = Concrete.new(2).as(Abstract)
        original.x
      CODE
    end

    it "puts struct pointer after tuple indexer" do
      interpret(<<-CODE).should eq(1)
        struct Point
          def initialize(@x : Int64)
          end

          def x
            @x
          end
        end

        a = Point.new(1_u64)
        t = {a}
        t[0].x
      CODE
    end

    it "mutates call argument" do
      interpret(<<-CODE).should eq(9000)
        def foo(x)
          if 1 == 0
            x = "hello"
          end

          if x.is_a?(Int32)
            x
          else
            10
          end
        end

        foo 9000
      CODE
    end

    it "inlines call that returns self" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end

          def mutate_itself
            itself.mutate
          end

          def itself
            self
          end
        end

        foo = Foo.new
        foo.mutate_itself
        foo.x
      CODE
    end

    it "inlines call that returns self (2)" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end

          def mutate_itself
            self.itself.mutate
          end

          def itself
            self
          end
        end

        foo = Foo.new
        foo.mutate_itself
        foo.x
      CODE
    end

    it "mutates through pointer (1)" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def ptr
            pointerof(@x)
          end

          def mutate
            @x = 10
            self
          end

          def x
            @x
          end
        end

        def foo
          Foo.allocate
        end

        foo.mutate.ptr.value
      CODE
    end

    it "mutates through pointer (2)" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def ptr
            pointerof(@x)
          end

          def mutate
            @x = 10
            self
          end

          def x
            @x
          end
        end

        def foo
          Foo.allocate
        end

        x = foo.mutate.ptr
        x.value
      CODE
    end

    it "mutates through pointer (3)" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end
        end

        ptr = Pointer(Foo).malloc(1_u64)
        ptr.value = Foo.new
        ptr.value.mutate
        ptr.value.x
      CODE
    end

    it "mutates through read instance var" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar
          end
        end

        struct Bar
          def initialize
            @z = 0
          end

          def z=(@z)
          end

          def z
            @z
          end
        end

        foo = Foo.new
        foo.@bar.z = 10
        foo.bar.z
      CODE
    end

    it "mutates through inlined instance var with receiver" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar
          end
        end

        struct Bar
          def initialize
            @z = 0
          end

          def z=(@z)
          end

          def z
            @z
          end
        end

        foo = Foo.new
        foo.bar.z = 10
        foo.bar.z
      CODE
    end

    it "mutates through inlined instance var without receiver" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar
          end

          def mutate
            bar.z = 10
          end
        end

        struct Bar
          def initialize
            @z = 0
          end

          def z=(@z)
          end

          def z
            @z
          end
        end

        foo = Foo.new
        foo.mutate
        foo.bar.z
      CODE
    end
  end

  context "multidispatch" do
    it "does dispatch on one argument" do
      interpret(<<-CODE).should eq(42)
        def foo(x : Char)
          x.ord.to_i32
        end

        def foo(x : Int32)
          x
        end

        a = 42 || 'a'
        foo(a)
      CODE
    end

    it "does dispatch on one argument inside module with implicit self" do
      interpret(<<-CODE).should eq(42)
        module Moo
          def self.foo(x : Char)
            x.ord.to_i32
          end

          def self.foo(x : Int32)
            x
          end

          def self.bar
            a = 42 || 'a'
            foo(a)
          end
        end

        Moo.bar
      CODE
    end

    it "does dispatch on one argument inside module with explicit receiver" do
      interpret(<<-CODE).should eq(42)
        module Moo
          def self.foo(x : Char)
            x.ord.to_i32
          end

          def self.foo(x : Int32)
            x
          end

          def self.bar
          end
        end

        a = 42 || 'a'
        Moo.foo(a)
      CODE
    end

    it "does dispatch on receiver type" do
      interpret(<<-CODE).should eq(42)
        struct Char
          def foo
            self.ord.to_i32
          end
        end

        struct Int32
          def foo
            self
          end
        end

        a = 42 || 'a'
        a.foo
      CODE
    end

    it "does dispatch on receiver type and argument type" do
      interpret(<<-CODE).should eq(42 + 'b'.ord)
        struct Char
          def foo(x : Int32)
            self.ord.to_i32 + x
          end

          def foo(x : Char)
            self.ord.to_i32 + x.ord.to_i32
          end
        end

        struct Int32
          def foo(x : Int32)
            self + x
          end

          def foo(x : Char)
            self + x.ord.to_i32
          end
        end

        a = 42 || 'a'
        b = 'b' || 43
        a.foo(b)
      CODE
    end

    it "does dispatch on receiver type and argument type, multiple times" do
      interpret(<<-CODE).should eq(2 * (42 + 'b'.ord))
        struct Char
          def foo(x : Int32)
            self.ord.to_i32 + x
          end

          def foo(x : Char)
            self.ord.to_i32 + x.ord.to_i32
          end
        end

        struct Int32
          def foo(x : Int32)
            self + x
          end

          def foo(x : Char)
            self + x.ord.to_i32
          end
        end

        a = 42 || 'a'
        b = 'b' || 43
        x = a.foo(b)
        y = a.foo(b)
        x + y
      CODE
    end

    it "does dispatch on one argument with struct receiver, and modifies it" do
      interpret(<<-CODE).should eq(32)
        struct Foo
          def initialize
            @x = 2_i64
          end

          def foo(x : Int32)
            v = @x + x
            @x = 10_i64
            v
          end

          def foo(x : Char)
            v = @x + x.ord.to_i32
            @x = 30_i64
            v
          end

          def x
            @x
          end
        end

        foo = Foo.new

        a = 20 || 'a'
        b = foo.foo(a)
        b + foo.x
      CODE
    end

    it "downcasts self from union to struct (pass pointer to self)" do
      interpret(<<-CODE).should eq(2)
        class Foo
          def initialize
            @x = 1_i64
          end

          def x
            @x
          end
        end

        struct Point
          def initialize
            @x = 2_i64
          end

          def x
            @x
          end
        end

        obj = Point.new || Foo.new
        obj.x
      CODE
    end

    it "does dispatch on virtual type" do
      interpret(<<-CODE).should eq(4)
        abstract class Foo
          def foo
            1
          end
        end

        class Bar < Foo
        end

        class Baz < Foo
          def foo
            3
          end
        end

        class Qux < Foo
        end

        foo = Bar.new || Baz.new
        x = foo.foo

        foo = Baz.new || Bar.new
        y = foo.foo

        x + y
      CODE
    end

    it "does dispatch on one argument with block" do
      interpret(<<-CODE).should eq(42)
        def foo(x : Char)
          yield x.ord.to_i32
        end

        def foo(x : Int32)
          yield x
        end

        a = 32 || 'a'
        foo(a) do |x|
          x + 10
        end
      CODE
    end

    it "doesn't compile block if it's not used (no yield)" do
      interpret(<<-CODE).should eq(2)
        class Object
          def try
            yield self
          end
        end

        struct Nil
          def try(&)
            self
          end
        end

        a = 1 || nil
        b = a.try { |x| x + 1 }
        b || 10
      CODE
    end

    it "does multidispatch on virtual metaclass type (1)" do
      interpret(<<-CODE).should eq("BB")
        class Class
          def lt(other : T.class) : String forall T
            {% @type %}
            other.gt(self)
          end

          def gt(other : T.class) forall T
            {{ @type.stringify + T.stringify }}
          end
        end

        class A
        end

        class B < A
        end

        t = B || A
        t.lt(t)
      CODE
    end

    it "does multidispatch on virtual metaclass type (2)" do
      interpret(<<-CODE).should eq("BB")
        class Class
          def lt(other : T.class) : String forall T
            {% @type %}
            other.gt(self)
          end

          def gt(other : T.class) forall T
            {{ @type.stringify + T.stringify }}
          end
        end

        class A
        end

        class B < A
        end

        class C < B
        end

        t = B || A
        t.lt(t)
      CODE
    end

    it "passes self as pointer when doing multidispatch" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        struct Bar
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        foo = Foo.new(0) || Bar.new(1)
        foo.to_unsafe.value = 10
        foo.x
      CODE
    end

    it "passes self as pointer when doing multidispatch (2)" do
      interpret(<<-CODE).should be_true
        struct Tuple
          def ==(other)
            false
          end
        end

        a = 1.as(Int32 | Tuple(Int64, Int64))
        a == 1
      CODE
    end

    it "initialize multidispatch" do
      interpret(<<-CODE).should eq(1)
        struct Foo
          def initialize(x : Int64)
            initialize(x, 1 || 'a')
          end

          def initialize(@x : Int64, y : Int32)
          end

          def initialize(@x : Int64, y : Char)
          end

          def x
            @x
          end
        end

        Foo.new(1_i64).x
      CODE
    end

    it "does multidispatch with mandatory named arguments" do
      interpret(<<-CODE).should eq(1)
        class Object
          def foo(obj, *, file = "")
            obj
          end
        end

        ("" || nil).foo 1, file: ""
      CODE
    end
  end

  context "classes" do
    it "does allocate, set instance var and get instance var" do
      interpret(<<-CODE).should eq(42)
        class Foo
          @x = 0

          def x=(@x)
          end

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x = 42
        foo.x
      CODE
    end

    it "does constructor" do
      interpret(<<-CODE).should eq(42)
        class Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        foo = Foo.new(42)
        foo.x
      CODE
    end

    it "interprets read instance var" do
      interpret(%(x = "hello".@c)).should eq('h'.ord)
    end

    it "discards allocate" do
      interpret(<<-CODE).should eq(3)
        class Foo
        end

        Foo.allocate
        3
      CODE
    end

    it "calls implicit class self method" do
      interpret(<<-CODE).should eq(10)
        class Foo
          def initialize
            @x = 10
          end

          def foo
            bar
          end

          def bar
            @x
          end
        end

        foo = Foo.new
        foo.foo
      CODE
    end

    it "calls explicit struct self method" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 10
          end

          def foo
            self.bar
          end

          def bar
            @x
          end
        end

        foo = Foo.new
        foo.foo
      CODE
    end

    it "calls implicit struct self method" do
      interpret(<<-CODE).should eq(10)
        struct Foo
          def initialize
            @x = 10
          end

          def foo
            bar
          end

          def bar
            @x
          end
        end

        foo = Foo.new
        foo.foo
      CODE
    end

    it "does object_id" do
      interpret(<<-CODE).should be_true
        class Foo
        end

        foo = Foo.allocate
        object_id = foo.object_id
        address = foo.as(Void*).address
        object_id == address
      CODE
    end
  end

  context "structs" do
    it "does allocate, set instance var and get instance var" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          @x = 0_i64
          @y = 0_i64

          def x=(@x)
          end

          def x
            @x
          end

          def y=(@y)
          end

          def y
            @y
          end
        end

        foo = Foo.allocate
        foo.x = 22_i64
        foo.y = 20_i64
        foo.x + foo.y
      CODE
    end

    it "does constructor" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        foo = Foo.new(42)
        foo.x
      CODE
    end

    it "interprets read instance var of struct" do
      interpret(<<-CODE).should eq(20)
        struct Foo
          @x = 0_i64
          @y = 0_i64

          def y=(@y)
          end

          def y
            @y
          end
        end

        foo = Foo.allocate
        foo.y = 20_i64
        foo.@y
      CODE
    end

    it "casts def body to def type" do
      interpret(<<-CODE).should eq(1)
        struct Foo
          def foo
            return nil if 1 == 2

            self
          end
        end

        value = Foo.new.foo
        value ? 1 : 2
      CODE
    end

    it "discards allocate" do
      interpret(<<-CODE).should eq(3)
        struct Foo
        end

        Foo.allocate
        3
      CODE
    end

    it "mutates struct inside union" do
      interpret(<<-CODE).should eq(2)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        foo = 1 == 1 ? Foo.new : nil
        if foo
          foo.inc
        end

        if foo
          foo.x
        else
          0
        end
      CODE
    end

    it "mutates struct stored in class var" do
      interpret(<<-CODE).should eq(3)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        module Moo
          @@foo = Foo.new

          def self.mutate
            @@foo.inc
          end

          def self.foo
            @@foo
          end
        end

        before = Moo.foo.x
        Moo.mutate
        after = Moo.foo.x
        before + after
      CODE
    end

    it "does simple class instance var initializer" do
      interpret(<<-CODE).should eq(42)
        class Foo
          @x = 42

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CODE
    end

    it "does complex class instance var initializer" do
      interpret(<<-CODE).should eq(42)
        class Foo
          @x : Int32 = begin
            a = 20
            b = 22
            a + b
          end

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CODE
    end

    it "does class instance var initializer inheritance" do
      interpret(<<-CODE).should eq(6)
        module Moo
          @z = 3

          def z
            @z
          end
        end

        class Foo
          include Moo

          @x = 1

          def x
            @x
          end
        end

        class Bar < Foo
          @y = 2

          def y
            @y
          end
        end

        bar = Bar.allocate
        bar.x + bar.y + bar.z
      CODE
    end

    it "does simple struct instance var initializer" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          @x = 42

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CODE
    end
  end

  context "enum" do
    it "does enum value" do
      interpret(<<-CODE).should eq(2)
        enum Color
          Red
          Green
          Blue
        end

        Color::Blue.value
      CODE
    end

    it "does enum new" do
      interpret(<<-CODE).should eq(2)
        enum Color
          Red
          Green
          Blue
        end

        blue = Color.new(2)
        blue.value
      CODE
    end
  end

  context "symbol" do
    it "Symbol#to_s" do
      interpret(<<-CODE).should eq("hello")
        x = :hello
        x.to_s
      CODE
    end

    it "Symbol#to_i" do
      interpret(<<-CODE).should eq(0 + 1 + 2)
        x = :hello
        y = :bye
        z = :foo
        x.to_i + y.to_i + z.to_i
      CODE
    end

    it "symbol equality" do
      interpret(<<-CODE).should eq(9)
        s1 = :foo
        s2 = :bar

        a = 0
        a += 1 if s1 == s1
        a += 2 if s1 == s2
        a += 4 if s1 != s1
        a += 8 if s1 != s2
        a
      CODE
    end
  end

  context "tuple" do
    it "interprets tuple literal and access by known index" do
      interpret(<<-CODE).should eq(6)
        a = {1, 2, 3}
        a[0] + a[1] + a[2]
      CODE
    end

    it "interprets tuple literal of different types (1)" do
      interpret(<<-CODE).should eq(3)
        a = {1, true}
        a[0] + (a[1] ? 2 : 3)
      CODE
    end

    it "interprets tuple literal of different types (2)" do
      interpret(<<-CODE).should eq(3)
        a = {true, 1}
        a[1] + (a[0] ? 2 : 3)
      CODE
    end

    it "discards tuple access" do
      interpret(<<-CODE).should eq(1)
        foo = {1, 2}
        a = foo[0]
        foo[1]
        a
      CODE
    end

    it "interprets tuple self" do
      interpret(<<-CODE).should eq(6)
        struct Tuple
          def itself
            self
          end
        end

        a = {1, 2, 3}
        b = a.itself
        b[0] + b[1] + b[2]
      CODE
    end

    it "extends sign when doing to_i32" do
      interpret(<<-CODE).should eq(-50)
        t = {-50_i16}
        exp = t[0]
        z = exp.to_i32
        CODE
    end

    it "unpacks tuple in block arguments" do
      interpret(<<-CODE).should eq(6)
        def foo
          t = {1, 2, 3}
          yield t
        end

        foo do |x, y, z|
          x + y + z
        end
        CODE
    end

    it "interprets tuple metaclass indexer" do
      interpret(<<-CODE).should eq(2)
        struct Int32
          def self.foo
            2
          end
        end

        a = {1, 'a'}
        a.class[0].foo
      CODE
    end
  end

  context "named tuple" do
    it "interprets named tuple literal and access by known index" do
      interpret(<<-CODE).should eq(6)
        a = {a: 1, b: 2, c: 3}
        a[:a] + a[:b] + a[:c]
      CODE
    end

    it "interprets named tuple metaclass indexer" do
      interpret(<<-CODE).should eq(2)
        struct Int32
          def self.foo
            2
          end
        end

        a = {a: 1, b: 'a'}
        a.class[:a].foo
      CODE
    end
  end

  context "blocks" do
    it "interprets simplest block" do
      interpret(<<-CODE).should eq(1)
        def foo
          yield
        end

        a = 0
        foo do
          a += 1
        end
        a
      CODE
    end

    it "interprets block with multiple yields" do
      interpret(<<-CODE).should eq(2)
        def foo
          yield
          yield
        end

        a = 0
        foo do
          a += 1
        end
        a
      CODE
    end

    it "interprets yield return value" do
      interpret(<<-CODE).should eq(1)
        def foo
          yield
        end

        z = foo do
          1
        end
        z
      CODE
    end

    it "interprets yield inside another block" do
      interpret(<<-CODE).should eq(1)
        def foo
          bar do
            yield
          end
        end

        def bar
          yield
        end

        a = 0
        foo do
          a += 1
        end
        a
      CODE
    end

    it "interprets yield inside def with arguments" do
      interpret(<<-CODE).should eq(18)
        def foo(x)
          a = yield
          a + x
        end

        a = foo(10) do
          8
        end
        a
      CODE
    end

    it "interprets yield expression" do
      interpret(<<-CODE).should eq(2)
        def foo
          yield 1
        end

        a = 1
        foo do |x|
          a += x
        end
        a
      CODE
    end

    it "interprets yield expressions" do
      interpret(<<-CODE).should eq(2 + 2*3 + 4*5)
        def foo
          yield 3, 4, 5
        end

        a = 2
        foo do |x, y, z|
          a += a * x + y * z
        end
        a
      CODE
    end

    it "discards yield expression" do
      interpret(<<-CODE).should eq(3)
        def foo
          yield 1
        end

        a = 2
        foo do
          a = 3
        end
        a
      CODE
    end

    it "yields different values to form a union" do
      interpret(<<-CODE).should eq(5)
        def foo
          yield 1
          yield 'a'
        end

        a = 2
        foo do |x|
          a +=
            case x
            in Int32
              1
            in Char
              2
            end
        end
        a
      CODE
    end

    it "returns from block" do
      interpret(<<-CODE).should eq(42)
        def foo
          baz do
            yield
          end
        end

        def baz
          yield
        end

        def bar
          foo do
            foo do
              return 42
            end
          end

          1
        end

        bar
      CODE
    end

    it "interprets next inside block" do
      interpret(<<-CODE).should eq(10)
        def foo
          yield
        end

        a = 0
        foo do
          if a == 0
            next 10
          end
          20
        end
      CODE
    end

    it "interprets next inside block (union, through next)" do
      interpret(<<-CODE).should eq(10)
        def foo
          yield
        end

        a = 0
        x = foo do
          if a == 0
            next 10
          end
          'a'
        end

        if x.is_a?(Int32)
          x
        else
          20
        end
      CODE
    end

    it "interprets next inside block (union, through normal exit)" do
      interpret(<<-CODE).should eq('a')
        def foo
          yield
        end

        a = 0
        x = foo do
          if a == 1
            next 10
          end
          'a'
        end

        if x.is_a?(Char)
          x
        else
          'b'
        end
      CODE
    end

    it "interprets break inside block" do
      interpret(<<-CODE).should eq(20)
        def baz
          yield
        end

        def foo
          baz do
            w = yield
            w + 100
          end
        end

        a = 0
        foo do
          if a == 0
            break 20
          end
          20
        end
      CODE
    end

    it "interprets break inside block (union, through break)" do
      interpret(<<-CODE).should eq(20)
        def foo
          yield
          'a'
        end

        a = 0
        w = foo do
          if a == 0
            break 20
          end
          20
        end
        if w.is_a?(Int32)
          w
        else
          30
        end
      CODE
    end

    it "interprets break inside block (union, through normal flow)" do
      interpret(<<-CODE).should eq('a')
        def foo
          yield
          'a'
        end

        a = 0
        w = foo do
          if a == 1
            break 20
          end
          20
        end
        if w.is_a?(Char)
          w
        else
          'b'
        end
      CODE
    end

    it "interprets break inside block (union, through return)" do
      interpret(<<-CODE).should eq('a')
        def foo
          yield
          return 'a'
        end

        a = 0
        w = foo do
          if a == 1
            break 20
          end
          20
        end
        if w.is_a?(Char)
          w
        else
          'b'
        end
      CODE
    end

    it "interprets block with args that conflict with a local var" do
      interpret(<<-CODE).should eq(201)
        def foo
          yield 1
        end

        a = 200
        x = 0

        foo do |a|
          x += a
        end

        x + a
      CODE
    end

    it "interprets block with args that conflict with a local var" do
      interpret(<<-CODE).should eq(216)
        def foo
          yield 1
        end

        def bar
          yield 2
        end

        def baz
          yield 3, 4, 5
        end

        # a: 0, 8
        a = 200

        # x: 8, 16
        x = 0

        # a: 16, 24
        foo do |a|
          x += a

          # a: 24, 32
          bar do |a|
            x += a
          end

          # a: 24, 32
          # b: 32, 40
          # c: 40, 48
          baz do |a, b, c|
            x += a
            x += b
            x += c
          end

          x += a
        end
        x + a
      CODE
    end

    it "clears block local variables when calling block" do
      interpret(<<-CODE).should eq(20)
        def foo
          yield 1
        end

        def bar
          a = 1

          foo do |b|
            x = 1
          end

          foo do |b|
            if a == 0 || b == 0
              x = 10
            end

            return x
          end
        end

        z = bar
        if z.is_a?(Nil)
          20
        else
          z
        end
        CODE
    end

    it "clears block local variables when calling block (2)" do
      interpret(<<-CODE).should eq(20)
        def foo
          yield
        end

        a = 0

        foo do
          x = 1
        end

        foo do
          if 1 == 2
            x = 1
          end
          a = x
        end

        if a
          a
        else
          20
        end
        CODE
    end

    it "captures non-closure block" do
      interpret(<<-CODE).should eq(42)
        def capture(&block : Int32 -> Int32)
          block
        end

        # This variable is needed in the test because it's also
        # part of the block, even though it's not closured (it's in node.def.vars)
        a = 100
        b = capture { |x| x + 1 }
        b.call(41)
      CODE
    end

    it "casts yield expression to block var type (not block arg type)" do
      interpret(<<-CODE).should eq(42)
        def foo
          yield 42
        end

        def bar
          foo do |x|
            yield x
            x = nil
          end
        end

        a = 0
        bar { |z| a = z }
        a
      CODE
    end

    it "interprets with ... yield" do
      interpret(<<-CODE).should eq(31)
        struct Int32
          def plus(x : Int32)
            self + x
          end
        end

        def foo
          with 10 yield 20
        end

        foo do |x|
          1 + (plus x)
        end
      CODE
    end

    it "interprets with ... yield with struct" do
      interpret(<<-CODE).should eq(2)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        def foo
          with Foo.new yield
        end

        foo do
          inc
          x
        end
      CODE
    end

    it "interprets yield with splat (1)" do
      interpret(<<-CODE).should eq((2 - 3) * 4)
        def foo
          t = {2, 3, 4}
          yield *t
        end

        a = 0
        foo do |x1, x2, x3|
          a = (x1 - x2) * x3
        end
        a
      CODE
    end

    it "interprets yield with splat (2)" do
      interpret(<<-CODE).should eq((((1 - 2) * 3) - 4) * 5)
        def foo
          t = {2, 3, 4}
          yield 1, *t, 5
        end

        a = 0
        foo do |x1, x2, x3, x4, x5|
          a = (((x1 - x2) * x3) - x4) * x5
        end
        a
      CODE
    end

    it "interprets yield with splat, less block arguments" do
      interpret(<<-CODE).should eq(2 - 3)
        def foo
          t = {2, 3, 4}
          yield *t
        end

        a = 0
        foo do |x1, x2|
          a = x1 - x2
        end
        a
      CODE
    end

    it "interprets block with splat" do
      interpret(<<-CODE).should eq((((1 - 2) * 3) - 4) * 5)
        def foo
          yield 1, 2, 3, 4, 5
        end

        a = 0
        foo do |x1, *x, x5|
          a = (((x1 - x[0]) * x[1]) - x[2]) * x5
        end
        a
      CODE
    end

    it "interprets yield with splat, block with splat" do
      interpret(<<-CODE).should eq((((1 - 2) * 3) - 4) * 5)
        def foo
          t = {1, 2, 3}
          yield *t, 4, 5
        end

        a = 0
        foo do |x1, *x, x5|
          a = (((x1 - x[0]) * x[1]) - x[2]) * x5
        end
        a
      CODE
    end
  end

  context "casts" do
    it "casts from reference to pointer and back" do
      interpret(<<-CODE).should eq("hello")
        x = "hello"
        p = x.as(UInt8*)
        y = p.as(String)
        y
      CODE
    end

    it "casts from reference to nilable reference" do
      interpret(<<-CODE).should eq("hello")
        x = "hello"
        y = x.as(String | Nil)
        if y
          y
        else
          "bye"
        end
      CODE
    end

    it "casts from mixed union type to another mixed union type for caller" do
      interpret(<<-CODE).should eq(true)
        a = 1 == 1 ? 1 : (1 == 1 ? 20_i16 : nil)
        if a
          a < 2
        else
          false
        end
      CODE
    end

    it "casts from nilable type to mixed union type" do
      interpret(<<-CODE).should eq(2)
        ascii = true
        delimiter = 1 == 1 ? nil : "foo"

        if ascii && delimiter
          1
        else
          2
        end
        CODE
    end

    it "casts from nilable type to mixed union type (2)" do
      interpret(<<-CODE).should eq(true)
        y = 1 == 1 ? "a" : nil
        x = true
        x = y
        x.is_a?(String)
      CODE
    end

    it "casts from mixed union type to primitive type" do
      interpret(<<-CODE, prelude: "prelude").should eq(2)
        x = 1 == 1 ? 2 : nil
        x.as(Int32)
      CODE
    end

    it "casts nilable from mixed union type to primitive type (non-nil case)" do
      interpret(<<-CODE).should eq(2)
        x = 1 == 1 ? 2 : nil
        y = x.as?(Int32)
        y ? y : 20
      CODE
    end

    it "casts nilable from mixed union type to primitive type (nil case)" do
      interpret(<<-CODE).should eq(20)
        x = 1 == 1 ? nil : 2
        y = x.as?(Int32)
        y ? y : 20
      CODE
    end

    it "upcasts between tuple types" do
      interpret(<<-CODE, prelude: "prelude").should eq(1 + 'a'.ord)
        a =
          if 1 == 1
            {1, 'a'}
          else
            {true, 3}
          end

        a[0].as(Int32) + a[1].as(Char).ord
      CODE
    end

    it "upcasts between named tuple types, same order" do
      interpret(<<-CODE, prelude: "prelude").should eq(1 + 'a'.ord)
        a =
          if 1 == 1
            {a: 1, b: 'a'}
          else
            {a: true, b: 3}
          end

        a[:a].as(Int32) + a[:b].as(Char).ord
      CODE
    end

    it "upcasts between named tuple types, different order" do
      interpret(<<-CODE, prelude: "prelude").should eq(1 + 'a'.ord)
        a =
          if 1 == 1
            {a: 1, b: 'a'}
          else
            {b:3, a: true}
          end

        a[:a].as(Int32) + a[:b].as(Char).ord
      CODE
    end

    it "upcasts to module type" do
      interpret(<<-CODE).should eq(1)
        module Moo
        end

        class Foo
          include Moo

          def foo
            1
          end
        end

        class Bar
          include Moo

          def foo
            2
          end
        end

        moo = (1 == 1 ? Foo.new : Bar.new).as(Moo)
        if moo.is_a?(Foo)
          moo.foo
        else
          10
        end
      CODE
    end

    it "upcasts virtual type to union" do
      interpret(<<-CODE).should eq(2)
        class Foo
          def foo
            1
          end
        end

        class Bar < Foo
          def foo
            2
          end
        end

        foo = 1 == 1 ? Bar.new : Foo.new
        a = 1 == 1 ? foo : 10
        if a.is_a?(Foo)
          a.foo
        else
          20
        end
      CODE
    end

    it "casts nil to Void*" do
      interpret(<<-CODE).should eq(0)
        module Moo
          def self.moo(r)
            r.as(Void*)
          end
        end

        Moo.moo(nil).address
      CODE
    end

    it "does is_a? with virtual metaclass" do
      interpret(<<-CODE).should eq(1)
        class A
          def self.a
            2
          end
        end

        class B < A
          def self.b
            1
          end
        end

        class C < B
        end

        x = B || A
        if x.is_a?(B.class)
          x.b
        elsif x.is_a?(A.class)
          x.a
        else
          0
        end
        CODE
    end

    it "discards cast" do
      interpret(<<-CODE, prelude: "prelude").should eq(10)
        x = 1 || 'a'
        x.as(Int32)
        10
      CODE
    end

    it "raises when as fails" do
      interpret(<<-CODE, prelude: "prelude").to_s.should contain("cast from Int32 to Char failed")
        x = 1 || 'a'
        begin
          x.as(Char)
          ""
        rescue ex : TypeCastError
          ex.message.not_nil!
        end
      CODE
    end

    it "casts to filtered type, not type in as(...)" do
      interpret(<<-CODE, prelude: "prelude").should eq(1)
        ({1} || 2).as(Tuple)[0]
      CODE
    end

    it "does is_a? with virtual type (struct)" do
      interpret(<<-CODE).should eq(10)
        abstract struct Foo
        end

        struct Bar < Foo
          def initialize(@x : Int32)
          end

          def bar
            @x
          end
        end

        struct Baz < Foo
          def initialize(@x : Int32)
          end

          def baz
            @x
          end
        end

        a = (Bar.new(10) || Baz.new(20)).as(Foo)
        case a
        when Bar
          a.bar
        when Baz
          a.baz
        else
          0
        end
        CODE
    end
  end

  context "constants" do
    it "interprets constant literal" do
      interpret(<<-CODE).should eq(123)
        A = 123
        A
      CODE
    end

    it "interprets complex constant" do
      interpret(<<-CODE).should eq(6)
        A = begin
          a = 1
          b = 2
          a + b
        end
        A + A
      CODE
    end

    it "hoists constants" do
      interpret(<<-CODE).should eq(6)
        x = A + A

        A = begin
          a = 1
          b = 2
          a + b
        end

        x
      CODE
    end

    it "interprets self inside constant inside class" do
      interpret(<<-CODE).should eq(1)
        class Foo
          X = self.foo

          def self.foo
            bar
          end

          def self.bar
            1
          end
        end

        Foo::X
      CODE
    end
  end

  context "class vars" do
    it "interprets class var without initializer" do
      interpret(<<-CODE).should eq(41)
        class Foo
          @@x : Int32?

          def set
            @@x = 41
          end

          def get
            @@x
          end
        end

        foo = Foo.new

        a = 0

        x = foo.get
        a += 1 if x

        foo.set

        x = foo.get
        a += x if x

        a
      CODE
    end

    it "interprets class var with initializer" do
      interpret(<<-CODE).should eq(42)
        class Foo
          @@x = 10

          def set
            @@x = 32
          end

          def get
            @@x
          end
        end

        foo = Foo.new

        a = 0

        x = foo.get
        a += x if x

        foo.set

        x = foo.get
        a += x if x

        a
      CODE
    end

    it "interprets class var for virtual type" do
      interpret(<<-CODE).should eq(30)
        class Foo
          @@x = 1

          def set(@@x)
          end

          def get
            @@x
          end
        end

        class Bar < Foo
        end

        foo = Foo.new
        bar = Bar.new

        foobar = foo || bar
        foobar.set(10)

        barfoo = bar || foo
        barfoo.set(20)

        a = 0
        a += foobar.get
        a += barfoo.get
        a
      CODE
    end

    it "interprets class var for virtual metaclass type" do
      interpret(<<-CODE).should eq(30)
        class Foo
          @@x = 1

          def self.set(@@x)
          end

          def self.get
            @@x
          end
        end

        class Bar < Foo
        end

        foo = Foo
        bar = Bar

        foobar = foo || bar
        foobar.set(10)

        barfoo = bar || foo
        barfoo.set(20)

        a = 0
        a += foobar.get
        a += barfoo.get
        a
      CODE
    end
  end

  context "procs" do
    it "interprets no args proc literal" do
      interpret(<<-CODE).should eq(42)
        proc = ->{ 40 }
        proc.call + 2
      CODE
    end

    it "interprets proc literal with args" do
      interpret(<<-CODE).should eq(30)
        proc = ->(x : Int32, y : Int32) { x + y }
        proc.call(10, 20)
      CODE
    end

    it "interprets call inside Proc type" do
      interpret(<<-CODE).should eq(42)
        struct Proc
          def call2
            call
          end
        end

        proc = ->{ 40 }
        proc.call2 + 2
      CODE
    end

    it "casts from nilable proc type to proc type" do
      interpret(<<-CODE).should eq(42)
        proc =
          if 1 == 1
            ->{ 42 }
          else
            nil
          end

        if proc
          proc.call
        else
          1
        end
      CODE
    end

    it "discards proc call" do
      interpret(<<-CODE).should eq(2)
        proc = ->{ 40 }
        proc.call
        2
      CODE
    end
  end

  context "exception handling" do
    it "does ensure without rescue/raise" do
      interpret(<<-CODE).should eq(12)
        x = 1
        y =
          begin
            10
          ensure
            x = 2
          end
        x + y
      CODE
    end

    it "does rescue when nothing is raised" do
      interpret(<<-CODE).should eq(1)
          a = begin
            1
          rescue
            'a'
          end

          if a.is_a?(Int32)
            a
          else
            10
          end
        CODE
    end

    it "raises and rescues anything" do
      interpret(<<-CODE, prelude: "prelude").should eq(2)
          a = begin
            if 1 == 1
              raise "OH NO"
            else
              'a'
            end
          rescue
            2
          end

          if a.is_a?(Int32)
            a
          else
            10
          end
        CODE
    end

    it "raises and rescues anything, does ensure when an exception is rescued" do
      interpret(<<-CODE, prelude: "prelude").should eq(3)
          a = 0
          b = 0

          begin
            raise "OH NO"
          rescue
            a = 1
          ensure
            b = 2
          end

          a + b
        CODE
    end

    it "raises and rescues specific exception type" do
      interpret(<<-CODE, prelude: "prelude").should eq(2)
          class Ex1 < Exception; end
          class Ex2 < Exception; end

          a = 0

          begin
            raise Ex2.new
          rescue Ex1
            a = 1
          rescue Ex2
            a = 2
          end

          a
        CODE
    end

    it "captures exception in variable" do
      interpret(<<-CODE, prelude: "prelude").should eq(10)
          class Ex1 < Exception
            getter value

            def initialize(@value : Int32)
            end
          end

          a = 0

          begin
            raise Ex1.new(10)
          rescue ex : Ex1
            a = ex.value
          end

          a
        CODE
    end

    it "excutes ensure when exception is raised in body" do
      interpret(<<-CODE, prelude: "prelude").should eq(10)
          a = 0

          begin
            begin
              raise "OH NO"
            ensure
              a = 10
            end
          rescue
          end

          a
        CODE
    end

    it "excutes ensure when exception is raised in rescue" do
      interpret(<<-CODE, prelude: "prelude").should eq(10)
          a = 0

          begin
            begin
              raise "OH NO"
            rescue
              raise "OOPS"
            ensure
              a = 10
            end
          rescue
          end

          a
        CODE
    end

    it "does else" do
      interpret(<<-CODE).should eq(3)
          a =
            begin
              'a'
            rescue
              1
            else
              2
            end

          a + 1
        CODE
    end

    it "does ensure for else" do
      interpret(<<-CODE).should eq(2 + ((1 * 2) + 3))
          x = 1

          a =
            begin
              'a'
            rescue
              1
            else
              x *= 2
              2
            ensure
              x += 3
            end

          a + x
        CODE
    end

    it "does ensure for else when else raises" do
      interpret(<<-CODE, prelude: "prelude").should eq(2)
          x = 1

          begin
            begin
              1
            rescue
              1
            else
              raise "OH NO"
            ensure
              x += 1
            end
          rescue
          end

          x
        CODE
    end

    it "does ensure with explicit return" do
      interpret(<<-CODE).should eq(22)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def foo
          x = 1

          begin
            begin
              x += 1
              if x == 2
                return x
              end
            ensure
              Global.property = 10
            end
          ensure
            Global.property *= 2
          end

          0
        end

        x = foo
        Global.property + x
      CODE
    end

    it "excutes ensure when returning from a block" do
      interpret(<<-CODE).should eq(21)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def foo
          block do
            return 1
          ensure
            Global.property = 10
          end

          0
        end

        x = foo
        Global.property + x
      CODE
    end

    it "excutes ensure when returning from a block (2)" do
      interpret(<<-CODE).should eq(21)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def another_block
          yield
        end

        def something
          another_block do
            return
          end
        end

        def foo
          block do
            return 1
          ensure
            something
            Global.property = 10
          end

          0
        end

        x = foo
        Global.property + x
      CODE
    end

    it "excutes ensure when breaking from a block" do
      interpret(<<-CODE).should eq(18)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def foo
          x = block do
            break 1
          ensure
            Global.property = 10
          end

          x - 3
        end

        x = foo
        Global.property + x
      CODE
    end

    it "excutes ensure when returning a big value from a block" do
      interpret(<<-CODE, prelude: "prelude").should eq(32405)
        module Global
          @@property = 0

          def self.property
            @@property
          end

          def self.property=(@@property)
          end
        end

        def block
          yield
        ensure
          Global.property *= 2
        end

        def foo
          block do
            static_array = StaticArray(Int32, 255).new { |i| i }
            return static_array
          ensure
            Global.property = 10
          end

          nil
        end

        x = foo
        if x
          Global.property + x.sum
        else
          0
        end
      CODE
    end
  end

  context "extern" do
    it "interprets primitive struct_or_union_set and get (struct)" do
      interpret(<<-CODE).should eq(30)
          lib LibFoo
            struct Foo
              x : Int32
              y : Int32
            end
          end

          foo = LibFoo::Foo.new
          foo.x = 10
          foo.y = 20
          foo.x + foo.y
        CODE
    end

    it "discards primitive struct_or_union_set and get (struct)" do
      interpret(<<-CODE).should eq(10)
          lib LibFoo
            struct Foo
              x : Int32
              y : Int32
            end
          end

          foo = LibFoo::Foo.new
          foo.y = 10
        CODE
    end

    it "discards primitive struct_or_union_set because it's a copy" do
      interpret(<<-CODE).should eq(10)
          lib LibFoo
            struct Foo
              x : Int32
              y : Int32
            end
          end

          def copy
            LibFoo::Foo.new
          end

          copy.y = 10
        CODE
    end

    it "interprets primitive struct_or_union_set and get (union)" do
      interpret(<<-CODE).should eq(-2045911175)
          lib LibFoo
            union Foo
              a : Bool
              x : Int64
              y : Int32
            end
          end

          foo = LibFoo::Foo.new
          foo.x = 123456789012345
          foo.y
        CODE
    end

    it "sets extern struct proc field" do
      interpret(<<-CODE).should eq(13)
          lib LibFoo
            struct Foo
              proc : Int32 -> Int32
              field : Int32
            end
          end

          foo = LibFoo::Foo.new
          foo.field = 10
          foo.proc = ->(x : Int32) { x + 1 }
          foo.proc.call(2) + foo.field
        CODE
    end

    it "sets struct field through pointer" do
      interpret(<<-CODE).should eq(20)
          lib LibFoo
            struct Foo
              x : Int32
            end
          end

          foo = LibFoo::Foo.new
          ptr = pointerof(foo)
          ptr.value.x = 20
          foo.x
        CODE
    end
  end

  context "autocast" do
    it "autocasts symbol to enum" do
      interpret(<<-CODE).should eq(1)
          enum Color
            Red
            Green
            Blue
          end

          def foo(x : Color)
            x
          end

          c = foo :green
          c.value
        CODE
    end

    it "autocasts number literal to integer" do
      interpret(<<-CODE).should eq(12)
          def foo(x : UInt8)
            x
          end

          foo(12)
        CODE
    end

    it "autocasts number literal to float" do
      interpret(<<-CODE).should eq(12.0)
          def foo(x : Float64)
            x
          end

          foo(12)
        CODE
    end
  end

  context "closures" do
    it "does closure without args that captures and modifies one local variable" do
      interpret(<<-CODE).should eq(42)
          a = 0
          proc = -> { a = 42 }
          proc.call
          a
        CODE
    end

    it "does closure without args that captures and modifies two local variables" do
      interpret(<<-CODE).should eq(7)
          a = 0
          b = 0
          proc = ->{
            a = 10
            b = 3
          }
          proc.call
          a - b
        CODE
    end

    it "does closure with two args that captures and modifies two local variables" do
      interpret(<<-CODE).should eq(7)
          a = 0
          b = 0
          proc = ->(x : Int32, y : Int32) {
            a = x
            b = y
          }
          proc.call(10, 3)
          a - b
        CODE
    end

    it "does closure and accesses it inside block" do
      interpret(<<-CODE).should eq(42)
          def foo
            yield
          end

          a = 0
          proc = -> { a = 42 }

          x = foo do
            proc.call
            a
          end

          x
        CODE
    end

    it "does closure inside def" do
      interpret(<<-CODE).should eq(42)
          def foo
            a = 0
            proc = -> { a = 42 }
            proc.call
            a
          end

          foo
        CODE
    end

    it "closures def arguments" do
      interpret(<<-CODE).should eq((41 + 1) - (10 + 2))
          def foo(a, b)
            proc = -> { a += 1; b += 2 }
            proc.call
            a - b
          end

          foo(41, 10)
        CODE
    end

    it "does closure inside proc" do
      interpret(<<-CODE).should eq(42)
          proc = ->{
            a = 0
            proc2 = -> { a = 42 }
            proc2.call
            a
          }

          proc.call
        CODE
    end

    it "does closure inside proc, capture proc argument" do
      interpret(<<-CODE).should eq(42)
          proc = ->(a : Int32) {
            proc2 = -> { a += 1 }
            proc2.call
            a
          }

          proc.call(41)
        CODE
    end

    it "does closure inside const" do
      interpret(<<-CODE).should eq(42)
          FOO =
            begin
              a = 0
              proc = -> { a = 42 }
              proc.call
              a
            end

          FOO
        CODE
    end

    it "does closure inside class variable initializer" do
      interpret(<<-CODE).should eq(42)
          class Foo
            @@foo : Int32 =
              begin
                a = 0
                proc = -> { a = 42 }
                proc.call
                a
              end

            def self.foo
              @@foo
            end
          end

          Foo.foo
        CODE
    end

    it "does closure inside block" do
      interpret(<<-CODE).should eq(42)
          def foo
            yield
          end

          foo do
            a = 0
            proc = ->{ a = 42 }
            proc.call
            a
          end
        CODE
    end

    it "does closure inside block, capture block arg" do
      interpret(<<-CODE).should eq(42)
          def foo
            yield 21
          end

          foo do |a|
            proc = ->{ a += 21 }
            proc.call
            a
          end
        CODE
    end

    it "does nested closure inside proc" do
      interpret(<<-CODE).should eq(21)
          a = 0

          proc1 = ->{
            a = 21
            b = 10

            proc2 = ->{
              a += b + 11
            }
          }

          proc2 = proc1.call

          x = a

          proc2.call

          y = a

          y - x
        CODE
    end

    it "does nested closure inside captured blocks" do
      interpret(<<-CODE).should eq(21)
          def capture(&block : -> _)
            block
          end

          a = 0

          proc1 = capture do
            a = 21
            b = 10

            proc2 = capture do
              a += b + 11
            end
          end

          proc2 = proc1.call

          x = a

          proc2.call

          y = a

          y - x
        CODE
    end

    it "does nested closure inside methods and blocks" do
      interpret(<<-CODE).should eq(12)
          def foo
            yield
          end

          a = 0
          proc1 = ->{ a += 10 }

          foo do
            b = 1
            proc2 = ->{ b += a + 1 }

            proc1.call
            proc2.call

            b
          end
        CODE
    end

    it "does closure with pointerof local var" do
      interpret(<<-CODE).should eq(42)
          a = 0
          proc = ->do
            ptr = pointerof(a)
            ptr.value = 42
          end
          proc.call
          a
        CODE
    end

    it "closures self in proc literal" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end

          def closure
            ->{ self.inc }
          end
        end

        foo = Foo.new
        proc = foo.closure
        proc.call
        proc.call
        foo.x
        CODE
    end

    it "closures self in proc literal (implicit self)" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end

          def closure
            ->{ inc }
          end
        end

        foo = Foo.new
        proc = foo.closure
        proc.call
        proc.call
        foo.x
        CODE
    end

    it "closures self and modifies instance var" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def x
            @x
          end

          def closure
            ->{ @x += 1 }
          end
        end

        foo = Foo.new
        proc = foo.closure
        proc.call
        proc.call
        foo.x
        CODE
    end

    it "closures struct and calls method on it" do
      interpret(<<-CODE).should eq(2)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        foo = Foo.new
        proc = ->{ foo.inc }
        proc.call
        foo.x
      CODE
    end

    it "doesn't mix local vars with closured vars" do
      interpret(<<-CODE).should eq(20)
        def foo(x)
          yield x
        end

        foo(10) do |i|
          ->{
            a = i
            foo(20) do |i|
              i
            end
          }.call
        end
      CODE
    end

    it "closures closured block arg" do
      interpret(<<-CODE).should eq(1)
        def foo(&block : -> Int32)
          ->{ block.call }.call
        end

        foo do
          1
        end
      CODE
    end

    it "closures block args after 8 bytes (the closure var)" do
      interpret(<<-CODE).should eq(6)
        def foo
          yield({1, 2, 3})
        end

        foo do |x, y, z|
          ->{ x + y + z }.call
        end
      CODE
    end

    it "passes closured struct instance var as self" do
      interpret(<<-CODE).should eq(10)
        struct Bar
          def bar
            10
          end
        end

        class Foo
          def initialize
            @bar = Bar.new
          end

          def foo
            ->{ @bar.bar }.call
          end
        end

        Foo.new.foo
      CODE
    end
  end

  context "struct set" do
    it "does automatic C cast" do
      interpret(<<-CODE).should eq(1)
          lib LibFoo
            struct Foo
              x : UInt8
            end
          end

          foo = LibFoo::Foo.new
          foo.x = 257
          foo.x
        CODE
    end
  end

  context "magic constants" do
    it "does line number" do
      interpret(<<-CODE).should eq(6)
          def foo(x, line = __LINE__)
            x + line
          end

          foo(1)
        CODE
    end
  end

  context "special vars" do
    it "does special var that's a reference" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(x)
          $? = "hey"
        end

        foo(2)
        $? || "oops"
      CODE
    end

    it "does special var that's a struct" do
      interpret(<<-CODE).should eq(3)
        class Object; def not_nil!; self; end; end

        def foo(x)
          $? = 3
        end

        foo(2)
        $? || 4
      CODE
    end

    it "does special var that's a reference inside block" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def bar
          yield
        end

        def foo(x)
          bar do
            $? = "hey"
          end
        end

        foo(2)
        $? || "oops"
      CODE
    end

    it "does special var that's a reference when there are optional arguments" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(x = 1)
          $? = "hey"
        end

        foo
        $? || "oops"
      CODE
    end

    it "does special var that's a reference for multidispatch" do
      interpret(<<-CODE).should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(x : Int32)
          $? = "hey"
        end

        def foo(x : String)
          $? = "ho"
        end

        a = 1 || "a"
        foo(a)
        $? || "oops"
      CODE
    end
  end

  context "bugs" do
    it "doesn't pass self to top-level method" do
      interpret(<<-CODE).should eq(1)
        struct Int32
          def foo(x)
            self
          end
        end

        def value
          1
        end

        module Moo
          def self.moo
            1.foo(value)
          end
        end

        Moo.moo
      CODE
    end

    it "doesn't pass self to top-level method (FileNode)" do
      interpret(<<-CODE).should eq(1)
        enum Color
          Red
          Green
          Blue
        end

        class Object
          def should(expectation)
            self
          end
        end

        def eq(value)
          value
        end

        private def t(type : Color)
          type
        end

        other = 2
        e = Color::Green.should eq(t :green)
        e.value
      CODE
    end

    it "breaks from current block, not from outer block" do
      interpret(<<-CODE).should eq(2)
        def twice
          # index: 1, block_caller: 0

          yield
          yield
        end

        def bar
          # index: 4, block_caller: 3
          yield
        end

        def foo
          # index: 3, block_caller: 2
          bar do
            # index: 5, block_caller: 2
            yield
          end
        end

        # index: 0

        x = 0

        twice do
          # index: 2
          x += 1
          foo do
            # index: 6

            # parent frame has block_caller: 2,
            # that's where we have to go to
            break
          end
        end

        x
      CODE
    end

    it "doesn't incorrectly consider a non-closure as closure" do
      interpret(<<-CODE, prelude: "prelude").should eq(false)
        c = 0
        ->{
          c
          ->{}.closure?
        }.call
      CODE
    end

    it "doesn't override local variable value with block var with the same name" do
      interpret(<<-CODE).should eq(0)
        def block
          yield 1
        end

        def block2
          yield 10
        end

        def foo
          block do |i|
          end

          i = 0
          block2 do |x|
            i
          end
        end

        foo
      CODE
    end

    it "does leading zeros" do
      interpret(<<-CODE, prelude: "prelude").should eq(8)
        0_i8.leading_zeros_count
      CODE
    end

    it "does multidispatch on virtual struct" do
      interpret(<<-CODE).should eq(true)
        abstract struct Base
        end

        struct Foo < Base
          @x : Int32 | Char

          def initialize
            @x = 0
          end

          def foo
            @x.is_a?(Int32)
          end
        end

        struct Bar < Base
          def foo
            false
          end
        end

        address = Foo.new.as(Base)
        address.foo
      CODE
    end

    it "correctly puts virtual metaclass type in union" do
      interpret(<<-CODE).should eq("Bar")
        abstract struct Foo
        end

        struct Bar < Foo
        end

        struct Baz < Foo
        end

        class Class
          def name : String
            {{ @type.name.stringify }}
          end
        end

        foo = Bar.new.as(Foo)
        foo2 = foo || nil
        foo2.class.name
      CODE
    end

    it "does multidispatch on virtual struct union nil" do
      interpret(<<-CODE).should eq(true)
        abstract struct Foo
          @value = 1
        end

        struct Bar < Foo
        end

        struct Baz < Foo
        end

        class Object
          def itself
            a = 1
            self
          end
        end

        foo = Bar.new.as(Foo)
        bar = (foo || nil).itself
        bar.is_a?(Bar)
     CODE
    end
  end

  context "integration" do
    it "does Int32#to_s" do
      interpret(<<-CODE, prelude: "prelude").should eq("123456789")
        123456789.to_s
      CODE
    end

    it "does Float64#to_s (simple)" do
      interpret(<<-CODE, prelude: "prelude").should eq("1.5")
        1.5.to_s
      CODE
    end

    it "does Float64#to_s (complex)" do
      interpret(<<-CODE, prelude: "prelude").should eq("123456789.12345")
        123456789.12345.to_s
      CODE
    end

    it "does Range#to_a, Array#to_s" do
      interpret(<<-CODE, prelude: "prelude").should eq("[1, 2, 3, 4, 5]")
        (1..5).to_a.to_s
      CODE
    end

    it "does some Hash methods" do
      interpret(<<-CODE, prelude: "prelude").should eq(90)
        h = {} of Int32 => Int32
        10.times do |i|
          h[i] = i * 2
        end
        h.values.sum
      CODE
    end

    it "does CSV" do
      interpret(<<-CODE, prelude: "prelude").should eq((1..6).sum)
        require "csv"

        csv = CSV.new <<-CSV, headers: true
          a, b, c
          1, 2, 3
          4, 5, 6
        CSV

        sum = 0
        csv.each do
          {"a", "b", "c"}.each do |name|
            sum += csv[name].to_i
          end
        end
        sum
      CODE
    end

    it "does JSON" do
      interpret(<<-CODE, prelude: "prelude").should eq(6)
        require "json"

        json = JSON.parse <<-JSON
          {"a": [1, 2, 3]}
          JSON
        json.as_h["a"].as_a.sum(&.as_i)
      CODE
    end

    it "does JSON::Serializable" do
      interpret(<<-CODE, prelude: "prelude").should eq(3)
        require "json"

        record Point, x : Int32, y : Int32 do
          include JSON::Serializable
        end

        point = Point.from_json <<-JSON
          {"x": 1, "y": 2}
        JSON
        point.x + point.y
      CODE
    end

    pending "does YAML" do
      interpret(<<-CODE, prelude: "prelude").should eq(6)
        require "yaml"

        yaml = YAML.parse <<-YAML
          a:
            - 1
            - 2
            - 3
          YAML
        yaml.as_h["a"].as_a.sum(&.as_i)
      CODE
    end

    pending "does YAML::Serializable" do
      interpret(<<-CODE, prelude: "prelude").should eq(3)
        require "yaml"

        record Point, x : Int32, y : Int32 do
          include YAML::Serializable
        end

        point = Point.from_yaml <<-YAML
          x: 1
          y: 2
        YAML
        point.x + point.y
      CODE
    end

    pending "does XML" do
      interpret(<<-CODE, prelude: "prelude").should eq(3)
        require "xml"

        doc = XML.parse(<<-XML
          <?xml version='1.0' encoding='UTF-8'?>
          <people>
            <person id="1" id2="2">
              <name>John</name>
            </person>
          </people>
          XML
        )
        attrs = doc.root.not_nil!.children[1].attributes
        id = attrs["id"].content.to_i
        id2 = attrs["id2"].content.to_i
        id + id2
        CODE
    end

    it "does String#includes?" do
      interpret(<<-CODE, prelude: "prelude").should be_true
        a = "Negative array size: -1"
        b = "Negative array size"
        a.includes?(b)
      CODE
    end

    it "does IO.pipe (checks that StaticArray is passed correctly to C calls)" do
      interpret(<<-CODE, prelude: "prelude").should eq("hello")
        IO.pipe do |r, w|
          w.puts "hello"
          r.gets.not_nil!
        end
      CODE
    end
  end
end

private def interpret(code, *, prelude = "primitives")
  context, value = interpret_with_context(code, prelude: prelude)
  value.value
end

private def interpret_with_context(code, *, prelude = "primitives")
  repl = Crystal::Repl.new
  repl.prelude = prelude

  # We disable the GC for programs that use the prelude because
  # finalizers might kick off after the Context has been finalized,
  # leading to segfaults.
  # This is a bit tricky to solve: the finalizers will run once the
  # context has been destroyed (it's memory is no longer allocated
  # so the objects in the program won't be referenced anymore),
  # but for finalizers to be able to run the context needs to be
  # there! :/
  code = "GC.disable\n#{code}" if prelude == "prelude"

  value = repl.run_code(code)
  {repl.context, value}
end
