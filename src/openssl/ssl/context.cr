class OpenSSL::SSL::Context
  def self.default
    @@default ||= new
  end

  def initialize
    @handle = LibSSL.ssl_ctx_new(LibSSL.sslv23_method)
  end

  def finalize
    LibSSL.ssl_ctx_free(@handle)
  end

  def certificate_chain=(file_path)
    LibSSL.ssl_ctx_use_certificate_chain_file(@handle, file_path)
  end

  def private_key=(file_path)
    LibSSL.ssl_ctx_use_privatekey_file(@handle, file_path, LibSSL::SSLFileType::PEM)
  end

  def to_unsafe
    @handle
  end
end
