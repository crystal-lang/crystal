{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

private macro assert_overflows(code, file = __FILE__, line = __LINE__)
  it "overflows on {{ code }}", file: {{ file }}, line: {{ line }} do
    interpret(%(
      class OverflowError < Exception; end

      fun __crystal_raise_overflow : NoReturn
        raise OverflowError.new
      end

      @[Primitive(:interpreter_raise_without_backtrace)]
      def raise(exception : Exception) : NoReturn
      end

      begin
        a = {{ code }}
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
      interpret(<<-CRYSTAL).should be_true
        "a".object_id == "a".object_id
      CRYSTAL
    end

    it "precomputes string literal length" do
      interpret(<<-CRYSTAL).should eq(1)
        "旅".@length
      CRYSTAL
    end
  end

  context "local variables" do
    it "interprets variable set" do
      interpret(<<-CRYSTAL).should eq(1)
      a = 1
      CRYSTAL
    end

    it "interprets variable set with type restriction (#13023)" do
      interpret(<<-CRYSTAL).should eq(1)
      a : Int32 = 1
      CRYSTAL
    end

    it "interprets variable set and get" do
      interpret(<<-CRYSTAL).should eq(1)
      a = 1
      a
      CRYSTAL
    end

    it "interprets variable set and get, second local var" do
      interpret(<<-CRYSTAL).should eq(1)
      x = 10
      a = 1
      a
      CRYSTAL
    end

    it "interprets variable set and get with operations" do
      interpret(<<-CRYSTAL).should eq(6)
      a = 1
      b = 2
      c = 3
      a + b + c
      CRYSTAL
    end

    it "interprets uninitialized" do
      interpret(<<-CRYSTAL).should eq(3)
        a = uninitialized Int32
        a = 3
        a
        CRYSTAL
    end

    it "doesn't declare variable with no type" do
      interpret(<<-CRYSTAL).should be_nil
      x = nil
      if x
        y = x
      end
      CRYSTAL
    end

    it "doesn't declare variable with no type inside method" do
      interpret(<<-CRYSTAL).should be_nil
        def foo(x)
          if x
            y = x
          end
        end

        foo(nil)
      CRYSTAL
    end

    it "assigns to underscore" do
      interpret(<<-CRYSTAL).should eq(1)
        _ = (a = 1)
        a
      CRYSTAL
    end

    it "doesn't discard underscore right hand side" do
      interpret(<<-CRYSTAL).should eq(1)
        a = (_ = 1)
        a
      CRYSTAL
    end

    it "interprets at the class level" do
      interpret(<<-CRYSTAL).should eq(1)
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
      CRYSTAL
    end

    it "interprets local variable declaration (#12229)" do
      interpret(<<-CRYSTAL).should eq(1)
      a : Int32 = 1
      a
      CRYSTAL
    end
  end

  context "conversion" do
    {% for target_type in %w(u8 i8 u16 i16 u32 i32 u i u64 i64 f32 f64).map(&.id) %}
      it "interprets Int8::MAX#to_{{ target_type }}!" do
        interpret("#{Int8::MAX}_i8.to_{{ target_type }}!").should eq(Int8::MAX.to_{{ target_type }}!)
      end

      it "interprets Int8::MIN#to_{{ target_type }}!" do
        interpret("#{Int8::MIN}_i8.to_{{ target_type }}!").should eq(Int8::MIN.to_{{ target_type }}!)
      end

      it "interprets UInt8::MAX#to_{{ target_type }}!" do
        interpret("#{UInt8::MAX}_u8.to_{{ target_type }}!").should eq(UInt8::MAX.to_{{ target_type }}!)
      end

      it "interprets Int16::MAX#to_{{ target_type }}!" do
        interpret("#{Int16::MAX}_i16.to_{{ target_type }}!").should eq(Int16::MAX.to_{{ target_type }}!)
      end

      it "interprets Int16::MIN#to_{{ target_type }}!" do
        interpret("#{Int16::MIN}_i16.to_{{ target_type }}!").should eq(Int16::MIN.to_{{ target_type }}!)
      end

      it "interprets UInt16::MAX#to_{{ target_type }}!" do
        interpret("#{UInt16::MAX}_u16.to_{{ target_type }}!").should eq(UInt16::MAX.to_{{ target_type }}!)
      end

      it "interprets Int32::MAX#to_{{ target_type }}!" do
        interpret("#{Int32::MAX}.to_{{ target_type }}!").should eq(Int32::MAX.to_{{ target_type }}!)
      end

      it "interprets Int32::MIN#to_{{ target_type }}!" do
        interpret("#{Int32::MIN}.to_{{ target_type }}!").should eq(Int32::MIN.to_{{ target_type }}!)
      end

      it "interprets UInt32::MAX#to_{{ target_type }}!" do
        interpret("#{UInt32::MAX}_u32.to_{{ target_type }}!").should eq(UInt32::MAX.to_{{ target_type }}!)
      end

      it "interprets Int64::MAX#to_{{ target_type }}!" do
        interpret("#{Int64::MAX}_i64.to_{{ target_type }}!").should eq(Int64::MAX.to_{{ target_type }}!)
      end

      it "interprets Int64::MIN#to_{{ target_type }}!" do
        interpret("#{Int64::MIN}_i64.to_{{ target_type }}!").should eq(Int64::MIN.to_{{ target_type }}!)
      end

      it "interprets UInt64::MAX#to_{{ target_type }}!" do
        interpret("#{UInt64::MAX}_u64.to_{{ target_type }}!").should eq(UInt64::MAX.to_{{ target_type }}!)
      end

      it "interprets Float32#to_{{ target_type }}! (positive)" do
        f = 23.8_f32
        interpret("23.8_f32.to_{{ target_type }}!").should eq(f.to_{{ target_type }}!)
      end

      it "interprets Float64#to_{{ target_type }}! (positive)" do
        f = 23.8_f64
        interpret("23.8_f64.to_{{ target_type }}!").should eq(f.to_{{ target_type }}!)
      end

      {% unless target_type.starts_with?("u") %} # Do not test undefined behavior that might differ (#13736)
        it "interprets Float32#to_{{ target_type }}! (negative)" do
          f = -23.8_f32
          interpret("-23.8_f32.to_{{ target_type }}!").should eq(f.to_{{ target_type }}!)
        end

        it "interprets Float64#to_{{ target_type }}! (negative)" do
          f = -23.8_f64
          interpret("-23.8_f64.to_{{ target_type }}!").should eq(f.to_{{ target_type }}!)
        end
      {% end %}
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
      interpret(<<-CRYSTAL).should eq(3)
      1.to_i8!
      3
      CRYSTAL
    end

    it "discards conversion with local var" do
      interpret(<<-CRYSTAL).should eq(3)
      x = 1
      x.to_i8!
      3
      CRYSTAL
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
      assert_overflows 1_u64 + 18446744073709551615u64
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
      assert_overflows 1_i64 - 9223372036854775810u64
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
      interpret(<<-CRYSTAL).should eq(4)
        struct Int32
          def shl2
            unsafe_shl(2)
          end
        end

        a = 1
        a.shl2
        CRYSTAL
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
      interpret(<<-CRYSTAL).should eq(906272454103984)
        a = 10097976637018756016_u64
        b = 9007199254740992_u64
        a.unsafe_mod(b)
        CRYSTAL
    end

    it "discards comparison" do
      interpret("1 < 2; 3").should eq(3)
    end
  end

  context "logical operations" do
    it "interprets not for nil" do
      interpret("!nil").should be_true
    end

    it "interprets not for nil type" do
      interpret("x = 1; !(x = 2; nil); x").should eq(2)
    end

    it "interprets not for bool true" do
      interpret("!true").should be_false
    end

    it "interprets not for bool false" do
      interpret("!false").should be_true
    end

    it "discards nil not" do
      interpret("!nil; 3").should eq(3)
    end

    it "discards bool not" do
      interpret("!false; 3").should eq(3)
    end

    it "interprets not for bool false" do
      interpret("!false").should be_true
    end

    it "interprets not for mixed union (nil)" do
      interpret("!(1 == 1 ? nil : 2)").should be_true
    end

    it "interprets not for mixed union (false)" do
      interpret("!(1 == 1 ? false : 2)").should be_true
    end

    it "interprets not for mixed union (true)" do
      interpret("!(1 == 1 ? true : 2)").should be_false
    end

    it "interprets not for mixed union (other)" do
      interpret("!(1 == 1 ? 2 : true)").should be_false
    end

    it "interprets not for nilable type (false)" do
      interpret(%(!(1 == 1 ? "hello" : nil))).should be_false
    end

    it "interprets not for nilable type (true)" do
      interpret(%(!(1 == 1 ? nil : "hello"))).should be_true
    end

    it "interprets not for nilable proc type (true)" do
      interpret(<<-CRYSTAL).should be_true
        a =
          if 1 == 1
            nil
          else
            ->{ 1 }
          end
        !a
        CRYSTAL
    end

    it "interprets not for nilable proc type (false)" do
      interpret(<<-CRYSTAL).should be_false
        a =
          if 1 == 1
            ->{ 1 }
          else
            nil
          end
        !a
        CRYSTAL
    end

    it "interprets not for generic class instance type" do
      interpret(<<-CRYSTAL).should be_false
        class Foo(T)
        end

        foo = Foo(Int32).new
        !foo
        CRYSTAL
    end

    it "interprets not for nilable type (false)" do
      interpret(<<-CRYSTAL).should be_false
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
        CRYSTAL
    end

    it "interprets not for nilable type (true)" do
      interpret(<<-CRYSTAL).should be_true
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
        CRYSTAL
    end

    it "interprets not for module (#12918)" do
      interpret(<<-CRYSTAL).should be_false
        module MyModule; end

        class One
          include MyModule
        end

        !One.new.as(MyModule)
        CRYSTAL
    end

    it "interprets not for generic module" do
      interpret(<<-CRYSTAL).should be_false
        module MyModule(T); end

        class One
          include MyModule(Int32)
        end

        !One.new.as(MyModule(Int32))
        CRYSTAL
    end

    it "interprets not for generic module metaclass" do
      interpret(<<-CRYSTAL).should be_false
        module MyModule(T); end

        !MyModule(Int32)
        CRYSTAL
    end

    it "interprets not for generic class instance metaclass" do
      interpret(<<-CRYSTAL).should be_false
        class MyClass(T); end

        !MyClass(Int32)
        CRYSTAL
    end

    it "does math primitive on union" do
      interpret(<<-CRYSTAL).should eq(3)
        module Test; end

        a = 1
        a.as(Int32 | Test) &+ 2
        CRYSTAL
    end

    it "does math convert on union" do
      interpret(<<-CRYSTAL).should eq(1)
        module Test; end

        a = 1
        a.as(Int32 | Test).to_i64!
        CRYSTAL
    end
  end
end
