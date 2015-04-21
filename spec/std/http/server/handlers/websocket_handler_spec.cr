require "spec"
require "http/server"

describe HTTP::WebSocketHandler do
  it "returns not found if the request is not an websocket upgrade" do
    handler = HTTP::WebSocketHandler.new {}
    response = handler.call HTTP::Request.new("GET", "/")
    expect(response.status_code).to eq(404)
    expect(response.upgrade_handler).to be_nil
  end

  it "gives upgrade response for websocket upgrade request" do
    handler = HTTP::WebSocketHandler.new {}
    headers = HTTP::Headers {
      "Upgrade": "websocket",
      "Connection": "Upgrade",
      "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ=="
    }
    request = HTTP::Request.new("GET", "/", headers)
    response = handler.call request
    expect(response.status_code).to eq(101)
    expect(response.headers["Upgrade"]).to eq("websocket")
    expect(response.headers["Connection"]).to eq("Upgrade")
    expect(response.headers["Sec-WebSocket-Accept"]).to eq("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    expect(response.upgrade_handler).to_not be_nil
  end
end
