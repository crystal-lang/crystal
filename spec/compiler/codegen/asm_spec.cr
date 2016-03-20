require "../../spec_helper"

describe "Code gen: asm" do
  it "codegens without inputs" do
    run(%(
      dst = uninitialized Int32
      asm("mov $$1234, $0" : "=r"(dst))
      dst
      )).to_i.should eq(1234)
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
end
