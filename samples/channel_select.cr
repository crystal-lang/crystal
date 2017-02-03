def generator(n : T) forall T
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
  select
  when int = ch1.receive
    puts "Int: #{int}"
  when float = ch2.receive
    puts "Float: #{float}"
  when ch3.receive
    break
  end
end
