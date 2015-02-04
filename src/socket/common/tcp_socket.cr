class TCPSocket
  def self.open(host, port)
    sock = new(host, port)
    begin
      yield sock
    ensure
      sock.close
    end
  end
end
