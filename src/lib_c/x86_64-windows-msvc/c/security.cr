require "c/winnt"

@[Link("secur32")]
lib LibC
  enum EXTENDED_NAME_FORMAT
    NameUnknown          =  0
    NameFullyQualifiedDN =  1
    NameSamCompatible    =  2
    NameDisplay          =  3
    NameUniqueId         =  6
    NameCanonical        =  7
    NameUserPrincipal    =  8
    NameCanonicalEx      =  9
    NameServicePrincipal = 10
    NameDnsDomain        = 12
    NameGivenName        = 13
    NameSurname          = 14
  end

  fun TranslateNameW(lpAccountName : LPWSTR, accountNameFormat : EXTENDED_NAME_FORMAT, desiredNameFormat : EXTENDED_NAME_FORMAT, lpTranslatedName : LPWSTR, nSize : ULong*) : BOOLEAN
end
