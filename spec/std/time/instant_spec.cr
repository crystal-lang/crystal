require "spec"

describe "Time.instant" do
  it "returns always increasing monotonic clock" do
    start = Time.instant
    loop do
      reading = Time.instant
      reading.should be >= start
      break if reading > start
    end
  end
end

describe Time::Instant do
  describe "#<=>" do
    it "compares" do
      t1 = Time.instant
      sleep(1.nanosecond)
      t2 = Time.instant

      (t1 <=> t2).should eq(-1)
      (t1 == t2).should be_false
      (t1 < t2).should be_true
    end
  end

  describe "math" do
    it do
      t1 = Time.instant

      (t1 + 1.second - 1.second).should eq t1
    end

    it "associative" do
      t1 = Time.instant
      offset = 5.milliseconds

      ((t1 + offset) - t1).should eq (t1 - t1) + offset
    end

    it "nanosecond precision" do
      t1 = Time.instant
      offset = 1.nanosecond

      ((t1 + offset) - t1).should eq offset
    end
  end

  describe "#duration_since" do
    it "calculates" do
      t1 = Time.instant
      t2 = Time.instant
      duration = t2.duration_since(t1)

      (t2 - duration).should eq(t1)
      (t1 + duration).should eq(t2)
    end

    it "saturates" do
      t2 = Time.instant
      t1 = t2 - 1.second
      t1.duration_since(t2).should eq Time::Span::ZERO
    end
  end

  describe "#elapsed" do
    it "calculates" do
      t1 = Time.instant - 12.microseconds
      t1.elapsed.should be >= 12.microseconds
    end
  end
end
