{% skip_file unless flag?(:x86_64) && !flag?(:win32) %}
require "../../../spec_helper"

describe "Code gen: C ABI x86_64" do
  it "passes struct less than 64 bits as { i64 }" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int8
          y : Int16
        end

        fun foo(s : Struct)
      end

      s = LibFoo::Struct.new
      LibFoo.foo(s)
      ))
    str = mod.to_s
    str.should contain("call void @foo({ i64 }")
    str.should contain("declare void @foo({ i64 })")
  end

  it "passes struct less than 64 bits as { i64 } in varargs" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int8
          y : Int16
        end

        fun foo(...)
      end

      s = LibFoo::Struct.new
      LibFoo.foo(s)
      ))
    str = mod.to_s
    str.should contain("call void (...)")
  end

  it "passes struct between 64 and 128 bits as { i64, i64 }" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int64
          y : Int16
        end

        fun foo(s : Struct)
      end

      s = LibFoo::Struct.new
      LibFoo.foo(s)
      ))
    str = mod.to_s
    str.should contain("call void @foo({ i64, i64 }")
    str.should contain("declare void @foo({ i64, i64 })")
  end

  it "passes struct between 64 and 128 bits as { i64, i64 } (with multiple modules/contexts)" do
    codegen(%(
      require "prelude"

      lib LibFoo
        struct Struct
          x : Int64
          y : Int16
        end

        fun foo(s : Struct)
      end

      module Moo
        def self.moo
          s = LibFoo::Struct.new
          LibFoo.foo(s)
        end
      end

      Moo.moo
      ))
  end

  it "passes struct bigger than128 bits with byval" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int64
          y : Int64
          z : Int8
        end

        fun foo(s : Struct)
      end

      s = LibFoo::Struct.new
      LibFoo.foo(s)
      ))
    str = mod.to_s
    str.scan(/byval/).size.should eq(2)
  end

  it "returns struct less than 64 bits as { i64 }" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int8
          y : Int16
        end

        fun foo : Struct
      end

      str = LibFoo.foo
      ))
    str = mod.to_s
    str.should contain("call { i64 } @foo()")
    str.should contain("declare { i64 } @foo()")
  end

  it "returns struct between 64 and 128 bits as { i64, i64 }" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int64
          y : Int16
        end

        fun foo : Struct
      end

      str = LibFoo.foo
      ))
    str = mod.to_s
    str.should contain("call { i64, i64 } @foo()")
    str.should contain("declare { i64, i64 } @foo()")
  end

  it "returns struct bigger than 128 bits with sret" do
    mod = codegen(%(
      lib LibFoo
        struct Struct
          x : Int64
          y : Int64
          z : Int8
        end

        fun foo(w : Int32) : Struct
      end

      str = LibFoo.foo(1)
      ))
    str = mod.to_s
    str.scan(/sret/).size.should eq(2)

    if LibLLVM::IS_LT_120
      str.should contain("sret, i32") # sret goes as first argument
    else
      str.should contain("sret(%\"struct.LibFoo::Struct\") %0, i32") # sret goes as first argument
    end
  end
end
