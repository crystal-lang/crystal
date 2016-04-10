enum OpenSSL::SSL::Method
  SSLv23
  SSLv3
  TLSv1

  def to_unsafe
    case self
    when SSLv23
      LibSSL.sslv23_method
    when SSLv3
      LibSSL.sslv3_method
    when TLSv1
      LibSSL.tlsv1_method
    else
      raise "Unsupported SSL method"
    end
  end
end