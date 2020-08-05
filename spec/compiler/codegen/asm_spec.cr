require "../../spec_helper"

describe "Code gen: asm" do
  # TODO: arm asm tests
  {% if flag?(:i386) || flag?(:x86_64) %}
    it "codegens without inputs" do
      run(%(
        dst = uninitialized Int32
        asm("mov $$1234, $0" : "=r"(dst))
        dst
        )).to_i.should eq(1234)
    end

    it "codegens with two outputs" do
      run(%(
        dst1 = uninitialized Int32
        dst2 = uninitialized Int32
        asm("
          mov $$0x1234, $0
          mov $$0x5678, $1" : "=r"(dst1), "=r"(dst2))
        (dst1.unsafe_shl(16)) | dst2
        )).to_i.should eq(0x12345678)
    end

    it "codegens with one input" do
      run(%(
        src = 1234
        dst = uninitialized Int32
        asm("mov $1, $0" : "=r"(dst) : "r"(src))
        dst
        )).to_i.should eq(1234)
    end

    it "codegens with two inputs" do
      run(%(
        c = uninitialized Int32
        a = 20
        b = 22
        asm(
          "add $2, $0"
             : "=r"(c)
             : "0"(a), "r"(b)
          )
        c
        )).to_i.should eq(42)
    end
  {% end %}
end
