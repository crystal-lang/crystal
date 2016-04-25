class OpenSSL::SSL::Context
  def self.default : self
    @@default ||= new
  end

  # Do not remove this until version > 0.15.0, it's needed in 0.15.0
  @handle : LibSSL::SSLContext

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
