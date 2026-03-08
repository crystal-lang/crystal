require "spec"

it "creates Hash at maximum capacity" do
  # we don't try to go as high as Int32::MAX because it would allocate 18GB of
  # memory in total. This already tests for Int32 overflows while 'only' needing
  # 4.5GB of memory.
  Hash(Int32, Int32).new(initial_capacity: (Int32::MAX // 4) + 1)
end
