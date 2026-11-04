require "spec"

private def once_and_return(flag, &)
  Crystal.once(flag) do
    yield
    return
  end
end

private def once_and_break(flag)
  Crystal.once(flag) { break }
end

describe "Crystal.once" do
  it "marks the flag when the initializer returns" do
    flag = false
    once_and_return(pointerof(flag)) { }
    flag.should be_true
  end

  it "marks the flag when the initializer breaks" do
    flag = false
    once_and_break(pointerof(flag))
    flag.should be_true
  end

  it "resumes waiting fibers when the initializer returns" do
    flag = false
    done = Channel(Nil).new

    once_and_return(pointerof(flag)) do
      spawn do
        Crystal.once(pointerof(flag)) { }
        done.send nil
      end
      Fiber.yield
    end

    select
    when done.receive
    when timeout(1.second)
      fail "waiting fiber was not resumed"
    end
  end
end
