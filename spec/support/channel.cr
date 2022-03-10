def schedule_timeout(c : Channel(Symbol))
  spawn do
    sleep 1
    c.send(:timeout)
  end
end
