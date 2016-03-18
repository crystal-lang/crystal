require "spec"

describe Thread::Attributes do
  it "set the stack size" do
    ptr = Pointer(Void).new(4096)
    size = 65536

    attr = Thread::Attributes.new
    attr.stack = {ptr, size}
    attr.stack.should eq({ptr, size})
  end
end
