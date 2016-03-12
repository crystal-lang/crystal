require "http"
require "json"

class Crystal::Playground::Agent
  def initialize(url, @session, @tag)
    @ws = HTTP::WebSocket.new(URI.parse(url))
  end

  def i # para la lineas en blanco
  end

  def i(value, line = __LINE__)
    send "value" do |json|
      json.field "line", line
      json.field "value", value.inspect
    end

    value
  end

  def exit(status)
    send "exit" do |json|
      json.field "status", status
    end
  end

  private def send(message_type)
    message = String.build do |io|
      io.json_object do |json|
        json.field "session", @session
        json.field "tag", @tag
        json.field "type", message_type

        yield json
      end
    end

    @ws.send(message) rescue nil
  end
end
