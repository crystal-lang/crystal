class OpenSSL::SSL::Context
  @@default : OpenSSL::SSL::Context?

  def self.default
    @@default ||= new
  end

  @handle : LibSSL::SSLContext

  def initialize(method = Method::SSLv23)
    @handle = LibSSL.ssl_ctx_new(method)
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

  def ca_file=(file_path)
    if LibSSL.ssl_ctx_load_verify_locations(@handle, file_path, nil) == 0
      raise "unable to set CA file"
    end
  end

  def certificate_file=(file_path)
    if LibSSL.ssl_ctx_use_certificate_file(@handle, file_path, 1) == 0
      raise "unable to set certificate file"
    end
  end

  def to_unsafe
    @handle
  end
end
