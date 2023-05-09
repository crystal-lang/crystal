@[Link("advapi32")]
lib LibC
  fun CreateWellKnownSid(wellKnownSidType : WELL_KNOWN_SID_TYPE, domainSid : SID*, pSid : SID*, cbSid : DWORD*) : BOOL
end
