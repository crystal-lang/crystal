require "c/winnt"
require "c/win_def"

lib LibC
  fun GetNativeSystemInfo(system_info : SYSTEM_INFO*)

  struct PROCESSOR_INFO
    wProcessorArchitecture : WORD
    wReserved : WORD
  end

  union OEM_PROCESSOR_INFO
    dwOemId : DWORD
    processorInfo : PROCESSOR_INFO
  end

  struct SYSTEM_INFO
    oemProcessorInfo : OEM_PROCESSOR_INFO
    dwPageSize : DWORD
    lpMinimumApplicationAddress : Void*
    lpMaximumApplicationAddress : Void*
    dwActiveProcessorMask : DWORD*
    dwNumberOfProcessors : DWORD
    dwProcessorType : DWORD
    dwAllocationGranularity : DWORD
    wProcessorLevel : WORD
    wProcessorRevision : WORD
  end

  fun GetComputerNameExW(computer_name_format : COMPUTER_NAME_FORMAT,
                         machine_name : LPWSTR,
                         machine_name_size : DWORD*) : BOOLEAN

  enum COMPUTER_NAME_FORMAT
    ComputerNameNetBIOS
    ComputerNameDnsHostname
    ComputerNameDnsDomain
    ComputerNameDnsFullyQualified
    ComputerNamePhysicalNetBIOS
    ComputerNamePhysicalDnsHostname
    ComputerNamePhysicalDomain
    ComputerNamePhysicalDnsFullyQualified
  end
end
