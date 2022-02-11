enum HTTP::WebSocket::CloseCode
  NormalClosure           = 1000
  GoingAway               = 1001
  ProtocolError           = 1002
  UnsupportedData         = 1003
  NoStatusReceived        = 1005
  AbnormalClosure         = 1006
  InvalidFramePayloadData = 1007
  PolicyViolation         = 1008
  MessageTooBig           = 1009
  MandatoryExtension      = 1010
  InternalServerError     = 1011
  ServiceRestart          = 1012
  TryAgainLater           = 1013
  BadGateway              = 1014
  TLSHandshake            = 1015

  # Create a new instance with the given close code, or raise an
  # error if the close code given is not inside 0..4999.
  def self.new(close_code : Int32)
    unless 0 <= close_code <= 4999
      raise ArgumentError.new("Invalid HTTP::WebSocket::CloseCode: #{close_code}")
    end
    previous_def(close_code)
  end
end
