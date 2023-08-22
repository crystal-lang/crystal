enum SpecChannelStatus
  Begin
  End
  Timeout
end

def schedule_timeout(c : Channel(SpecChannelStatus))
  spawn do
    {% if flag?(:interpreted) %}
      # TODO: it's not clear why some interpreter specs
      # take more than 1 second in some cases.
      # See #12429.
      sleep 5
    {% else %}
      sleep 1
    {% end %}
    c.send(SpecChannelStatus::Timeout)
  end
end
