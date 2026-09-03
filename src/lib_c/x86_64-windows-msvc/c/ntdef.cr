lib LibC
  struct UNICODE_STRING
    length : USHORT
    maximumLength : USHORT
    buffer : LPWSTR
  end

  struct OBJECT_ATTRIBUTES
    length : ULONG
    rootDirectory : HANDLE
    objectName : UNICODE_STRING*
    attributes : ULONG
    securityDescriptor : Void*
    securityQualityOfService : Void*
  end
end
