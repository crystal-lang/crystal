require "spec"
require "../compiler/spec_helper"

it "VaList works with C code" do
  test_c(
    %(
      extern int foo_f(int,...);
      int foo() {
        return foo_f(3,1,2,3);
      }
    ),
    %(
      lib LibFoo
        fun foo() : LibC::Int
      end

      fun foo_f(count : Int32, ...) : LibC::Int
        sum = 0
        VaList.open do |list|
          count.times do |i|
            sum += list.next(Int32)
          end
        end
        sum
      end

      LibFoo.foo
    ), &.to_i.should eq(6))
end
