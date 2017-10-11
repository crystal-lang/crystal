require "spec"

describe Time::Measure do
  it "Time.measure" do
    elapsed = Time.measure { sleep 0.001 }
    elapsed.should be >= 1.millisecond
  end

  it "returns elapsed time" do
    timer = Time::Measure.new
    previous = timer.elapsed

    5.times do
      elapsed = timer.elapsed
      elapsed.should be >= previous
    end
  end

  it "elapsed?" do
    timer = Time::Measure.new

    # disabled: randomly fails
    # timer.elapsed?(0.seconds).should be_true

    timer.elapsed?(5.seconds).should be_false
    timer.elapsed?(5.0).should be_false
    sleep 0.001
    timer.elapsed?(0.001).should be_true
  end
end
