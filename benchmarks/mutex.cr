COUNT = 10_000_000_u64

nprocs = Crystal::NPROCS

cocount = (ARGV[0]? || "2").to_i
codone = Atomic(Int32).new(cocount)

count = COUNT / cocount
done = Channel(Nil).new

mutex = Mutex.new
increment = 0_u64

cocount.times do
  spawn do
    count.times do
      mutex.lock
      increment += 1
      mutex.unlock
    end

    if codone.add(-1) == 1
      done.send(nil)
    end
  end
end

duration = Time.measure { done.receive }.total_milliseconds

printf "mutex[%d/%d]: crystal: %d locks in %d ms, %d locks per second (increment=%d)\n",
        nprocs, cocount, COUNT, duration, ((1000_i64 * COUNT) / duration), increment
