lib LibC
  struct Tls_get_record
    tls_type : UInt8
    tls_vmajor : UInt8
    tls_vminor : UInt8
    tls_length : UInt16
  end

  struct Tls_enable
    cipher_key : UInt8*
    iv : UInt8*
    auth_key : UInt8*
    cipher_algorithm : Int
    cipher_key_len : Int
    iv_len : Int
    auth_algorithm : Int
    auth_key_len : Int
    flags : Int
    tls_vmajor : UInt8
    tls_vminor : UInt8
    rec_seq : UInt8[8]
  end
end
