{% skip_file if flag?(:win32) || flag?(:aarch64) %}

require "./spec_helper"

describe VaList do
  it "works with C code", tags: %w[slow] do
    compile_and_run_source_with_c(
      %(
          #include <stdarg.h>
          extern int foo_f(int,...);
          int foo() {
            return foo_f(3,1,2,3);
          }

          int read_arg(va_list *ap) {
            return va_arg(*ap, int);
          }
        ),
      %(
        lib LibFoo
          fun foo : LibC::Int
          fun read_arg(ap : LibC::VaList*) : LibC::Int
        end

        fun foo_f(count : LibC::Int, ...) : LibC::Int
          sum = 0
          VaList.open do |list|
            ap = list.to_unsafe
            count.times do |i|
              sum += LibFoo.read_arg(pointerof(ap))
            end
          end
          sum
        end

        puts LibFoo.foo
      )) do |status, output|
      status.success?.should be_true
      output.to_i.should eq(6)
    end
  end
end
