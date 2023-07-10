require "c/win_def"
require "c/minwinbase"
require "c/winnt"

@[Link("crypt32")]
lib LibC
  alias HCERTSTORE = Void*
  alias HCRYPTPROV_LEGACY = Void*

  struct CERT_NAME_BLOB
    cbData : DWORD
    pbData : BYTE*
  end

  struct CRYPT_INTEGER_BLOB
    cbData : DWORD
    pbData : BYTE*
  end

  struct CRYPT_OBJID_BLOB
    cbData : DWORD
    pbData : BYTE*
  end

  struct CRYPT_BIT_BLOB
    cbData : DWORD
    pbData : BYTE*
    cUnusedBits : DWORD
  end

  struct CRYPT_ALGORITHM_IDENTIFIER
    pszObjId : LPSTR
    parameters : CRYPT_OBJID_BLOB
  end

  struct CERT_PUBLIC_KEY_INFO
    algorithm : CRYPT_ALGORITHM_IDENTIFIER
    publicKey : CRYPT_BIT_BLOB
  end

  struct CERT_EXTENSION
    pszObjId : LPSTR
    fCritical : BOOL
    value : CRYPT_OBJID_BLOB
  end

  struct CERT_INFO
    dwVersion : DWORD
    serialNumber : CRYPT_INTEGER_BLOB
    signatureAlgorithm : CRYPT_ALGORITHM_IDENTIFIER
    issuer : CERT_NAME_BLOB
    notBefore : FILETIME
    notAfter : FILETIME
    subject : CERT_NAME_BLOB
    subjectPublicKeyInfo : CERT_PUBLIC_KEY_INFO
    issuerUniqueId : CRYPT_BIT_BLOB
    subjectUniqueId : CRYPT_BIT_BLOB
    cExtension : DWORD
    rgExtension : CERT_EXTENSION*
  end

  struct CERT_USAGE
    cUsageIdentifier : DWORD
    rgpszUsageIdentifier : LPSTR*
  end

  X509_ASN_ENCODING   = 0x00000001
  PKCS_7_ASN_ENCODING = 0x00010000

  struct CERT_CONTEXT
    dwCertEncodingType : DWORD
    pbCertEncoded : BYTE*
    cbCertEncoded : DWORD
    pCertInfo : CERT_INFO*
    hCertStore : HCERTSTORE
  end

  fun CertOpenSystemStoreW(hProv : HCRYPTPROV_LEGACY, szSubsystemProtocol : LPWSTR) : HCERTSTORE
  fun CertCloseStore(hCertStore : HCERTSTORE, dwFlags : DWORD) : BOOL

  fun CertEnumCertificatesInStore(hCertStore : HCERTSTORE, pPrevCertContext : CERT_CONTEXT*) : CERT_CONTEXT*
  fun CertGetEnhancedKeyUsage(pCertContext : CERT_CONTEXT*, dwFlags : DWORD, pUsage : CERT_USAGE*, pcbUsage : DWORD*) : BOOL
end
