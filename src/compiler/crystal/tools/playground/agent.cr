require "http"
require "json"

class Crystal::Playground::Agent
  @send_runtime = true

  def initialize(url, @tag : Int32)
    @ws = HTTP::WebSocket.new(URI.parse(url))
  end

  def i(line, names = nil)
    value = begin
      yield
    rescue ex
      if @send_runtime
        @send_runtime = false # send only the inner runtime exception
        send "runtime-exception" do |json|
          json.field "line", line
          json.field "exception", ex.to_s
        end
      end
      raise ex
    end

    send "value" do |json|
      json.field "line", line
      json.field "value", safe_to_value(value)
      json.field "value_type", typeof(value).to_s

      if names && value.is_a?(Tuple)
        json.field "data" do
          json.object do
            value.to_a.zip(names) do |v, name|
              json.field name, safe_to_value(v)
            end
          end
        end
      end
    end

    value
  end

  def safe_to_value(value)
    to_value(value) rescue "(error)"
  end

  def to_value(value)
    value.inspect
  end

  private def send(message_type)
    message = JSON.build do |json|
      json.object do
        json.field "tag", @tag
        json.field "type", message_type

        yield json
      end
    end

    @ws.send(message) rescue nil
  end
end
