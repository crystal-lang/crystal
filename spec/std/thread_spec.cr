require "spec"

describe "Thread" do
  it "allows passing an argumentless fun to execute" do
    a = 0
    thread = Thread.new { a = 1; 10 }
    thread.join.should eq(10)
    a.should eq(1)
  end

  it "checks if thread is alive" do 
    thread = Thread.new { a = 5}
    thread.alive?.should eq(true)
    thread.join
    thread.alive?.should eq(false)
  end

  it "allows passing a fun with an argument to execute" do
    a = 0
    thread = Thread.new(3) { |i| a += i; 20 }
    thread.join.should eq(20)
    a.should eq(3)
  end

  it "raises inside thread and gets it on join" do
    thread = Thread.new { raise "OH NO" }
    expect_raises Exception, "OH NO" do
      thread.join
    end
  end

  it "gets a non-nilable value from join" do
    thread = Thread.new { 1 }
    value = thread.join
    (value + 2).should eq(3)
  end
end

describe "ConditionVariable" do
  pending "waits and send signal" do
    a = 0
    cv1 = ConditionVariable.new
    cv2 = ConditionVariable.new
    m = Mutex.new

    thread = Thread.new do
      3.times do
        m.synchronize { cv1.wait(m); a += 1; cv2.signal }
      end
    end

    a.should eq(0)
    3.times do |i|
      m.synchronize { cv1.signal; cv2.wait(m) }
      a.should eq(i + 1)
    end

    thread.join
  end
end
