require "c/winnt"
require "c/win_def"
require "c/int_safe"

lib LibC

  #GetSystemInfo - https://docs.microsoft.com/en-us/windows/desktop/api/sysinfoapi/nf-sysinfoapi-getsysteminfo
  
  fun NTGetSystemInfo = GetSystemInfo(system_info : SystemInfo*)
  
  PROCESSOR_ARCHITECTURE_AMD64 = 9
  PROCESSOR_ARCHITECTURE_ARM = 5
  PROCESSOR_ARCHITECTURE_ARM64 = 12
  PROCESSOR_ARCHITECTURE_IA64 = 6
  PROCESSOR_ARCHITECTURE_INTEL = 0
  PROCESSOR_ARCHITECTURE_UNKNOWN = 0xffff

  struct ProcessorInfo
    wProcessorArchitecture : WORD
    wReserved : WORD
  end

  union OEMProcessorInfo
    dwOemId : DWORD
    processorInfo : ProcessorInfo
  end

  struct SystemInfo
    oemProcessorInfo : OEMProcessorInfo
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


  #GetComputerNameExA - https://docs.microsoft.com/en-us/windows/desktop/api/sysinfoapi/nf-sysinfoapi-getcomputernameexa

  fun NTGetComputerNameExA = GetComputerNameExA(computer_name_format : ComputerNameFormat,
                                              machine_name : CHAR[NT_COMPUTER_NAME_SIZE]*,
                                              machine_name_size_ptr : DWORD_PTR) : BOOLEAN

  NT_COMPUTER_NAME_SIZE = 256

  enum ComputerNameFormat
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
