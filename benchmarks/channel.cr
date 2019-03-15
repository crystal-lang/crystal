COUNT = 10_000_000_u64

class Tasks
  getter :done

  def initialize(gcount, ccount)
    @chan = Channel::Unbuffered(Int32).new
    @done = Channel::Buffered(Nil).new
    @gdone = Atomic(Int32).new(gcount)
    @cdone = Atomic(Int32).new(ccount)
  end

  def generate(count)
    1.upto(count) { |i| @chan.send(i) }

    if @gdone.add(-1) == 1
      @chan.close
    end
  end

  def consume
    while @chan.receive?
    end

    if @cdone.add(-1) == 1
      @done.send(nil)
    end
  end
end

nprocs = Crystal::NPROCS

gcount = (ARGV[0]? || "2").to_i
ccount = (ARGV[1]? || "2").to_i

cocount = gcount + ccount
count = COUNT / gcount
tasks = Tasks.new(gcount, ccount)

gcount.times do
  spawn tasks.generate(count)
end
ccount.times do
  spawn tasks.consume
end

duration = Time.measure { tasks.done.receive }.total_milliseconds

printf "channel[%d/%d]: crystal: %d messages in %d ms, %d messages per second\n",
        nprocs, cocount, COUNT, duration, ((1000_i64 * COUNT) / duration)
