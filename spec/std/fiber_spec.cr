require "spec"

describe Fiber do
  it "#resumable?" do
    done = false
    resumable = nil

    fiber = spawn do
      resumable = Fiber.current.resumable?
      done = true
    end

    fiber.resumable?.should be_true

    until done
      Fiber.yield
    end

    resumable.should be_false
  end
end
