def generator(n : T)
  channel = Channel(T).new
  spawn do
    loop do
      sleep n
      channel.send n
    end
  end
  channel
end

ch1 = generator(1)
ch2 = generator(1.5)
ch3 = generator(5)

loop do
  case ch = Channel.select(ch1, ch2, ch3)
  when ch3
    break
  else
    puts ch.receive
  end
end
