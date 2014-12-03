require "spec"
require "http/server"

describe HTTP::WebSocketHandler do
  it "returns not found if the request is not an websocket upgrade" do
    handler = HTTP::WebSocketHandler.new {}
    response = handler.call HTTP::Request.new("GET", "/")
    response.status_code.should eq(404)
    response.upgrade_handler.should be_nil
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
    response.status_code.should eq(101)
    response.headers["Upgrade"].should eq("websocket")
    response.headers["Connection"].should eq("Upgrade")
    response.headers["Sec-WebSocket-Accept"].should eq("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    response.upgrade_handler.should_not be_nil
  end
end
