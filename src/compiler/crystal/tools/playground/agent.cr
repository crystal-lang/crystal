require "http"
require "json"

class Crystal::Playground::Agent
  def initialize(url, @session, @tag)
    @ws = HTTP::WebSocket.new(URI.parse(url))
  end

  def i # para la lineas en blanco
  end

  def i(value, line = __LINE__)
    @ws.send({
      "type"    => "agent_send",
      "session" => @session,
      "tag"     => @tag,
      "line"    => line,
      "value"   => value.inspect,
    }.to_json) rescue nil
    value
  end
end
