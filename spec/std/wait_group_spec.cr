require "spec"
require "wait_group"

describe WaitGroup do
  it "waits until all concurrent executions are done" do
    wg = WaitGroup.new
    wg.add(500)
    count = Atomic(Int32).new(0)

    500.times do
      ::spawn do
        count.add(1)
        wg.done
      end
    end

    wg.wait
    count.get.should eq(500)
  end
end
