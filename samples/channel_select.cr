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
  index, value = Channel.select(ch1.receive_op, ch2.receive_op, ch3.receive_op)
  case index
  when 0
    int = value.as(typeof(ch1.receive))
    puts "Int: #{int}"
  when 1
    float = value.as(typeof(ch2.receive))
    puts "Float: #{float}"
  when 2
    break
  else
    raise "BUG: Channel.select returned invalid index #{index}"
  end
end
