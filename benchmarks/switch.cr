COUNT = 10_000_000_u64

nprocs = Crystal::NPROCS

cocount = (ARGV[0]? || "2").to_i
codone = Atomic(Int32).new(cocount)

count = COUNT / cocount
done = Channel(Nil).new

cocount.times do
  spawn do
    count.times do
      Fiber.yield
    end

    if codone.add(-1) == 1
      done.send(nil)
    end
  end
end

duration = Time.measure { done.receive }.total_milliseconds

printf "switch[%d/%d]: crystal: %d yields in %d ms, %d yields per second\n",
        nprocs, cocount, COUNT, duration, ((1000_i64 * COUNT) / duration)
