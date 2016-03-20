# Ported from Go sample from this page: http://dancallahan.info/journal/go-concurrency/#How+do+channels+and+goroutines+work+together?

def generate(chan)
  i = 2
  loop do
    chan.send(i)
    i += 1
  end
end

def filter(in_chan, out_chan, prime)
  loop do
    i = in_chan.receive
    if i % prime != 0
      out_chan.send(i)
    end
  end
end

ch = Channel(Int32).new
spawn generate(ch)

100.times do
  prime = ch.receive
  puts prime
  ch1 = Channel(Int32).new
  spawn filter(ch, ch1, prime)
  ch = ch1
end
