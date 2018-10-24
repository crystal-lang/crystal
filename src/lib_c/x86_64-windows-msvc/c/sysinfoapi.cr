require "c/winnt"
require "c/win_def"
require "c/int_safe"

lib LibC
  fun GetNativeSystemInfo = GetNativeSystemInfo(system_info : SYSTEM_INFO*)

  PROCESSOR_ARCHITECTURE_AMD64   =      9
  PROCESSOR_ARCHITECTURE_ARM     =      5
  PROCESSOR_ARCHITECTURE_ARM64   =     12
  PROCESSOR_ARCHITECTURE_IA64    =      6
  PROCESSOR_ARCHITECTURE_INTEL   =      0
  PROCESSOR_ARCHITECTURE_UNKNOWN = 0xffff

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
    lpMinimumApplicationAddress : LPVOID
    lpMaximumApplicationAddress : LPVOID
    dwActiveProcessorMask : DWORD_PTR
    dwNumberOfProcessors : DWORD
    dwProcessorType : DWORD
    dwAllocationGranularity : DWORD
    wProcessorLevel : WORD
    wProcessorRevision : WORD
  end

  fun GetComputerNameExW = GetComputerNameExW(computer_name_format : COMPUTER_NAME_FORMAT,
                                              machine_name : WCHAR[MAX_COMPUTER_NAME_SIZE]*,
                                              machine_name_size_ptr : DWORD_PTR) : BOOLEAN

  MAX_COMPUTER_NAME_SIZE = 255

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
