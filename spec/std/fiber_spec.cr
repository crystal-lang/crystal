require "spec"
require "fiber"

describe "Fiber" do
  it "does yield and resume" do
    a = 0

    fiber = Fiber.new do
      a = 1
      Fiber.yield
      a = 2
      Fiber.yield
      a = 3
    end

    a.should eq(0)

    fiber.resume
    a.should eq(1)

    fiber.resume
    a.should eq(2)

    fiber.resume
    a.should eq(3)
  end
end
