require "./in6addr"
require "./inaddr"
require "./stdint"

@[Link("iphlpapi")]
lib LibC
  NDIS_IF_MAX_STRING_SIZE = 256
  IF_NAMESIZE             = LibC::NDIS_IF_MAX_STRING_SIZE + 1 # need one more byte for terminating '\0'

  fun if_nametoindex(ifname : Char*) : UInt
  fun if_indextoname(ifindex : UInt, ifname : LibC::Char*) : LibC::Char*

  alias NET_IFINDEX = ULong
  alias NET_LUID = UInt64

  fun ConvertInterfaceLuidToIndex(interfaceLuid : NET_LUID*, interfaceIndex : NET_IFINDEX*) : DWORD
  fun ConvertInterfaceIndexToLuid(interfaceIndex : NET_IFINDEX, interfaceLuid : NET_LUID*) : DWORD

  fun ConvertInterfaceLuidToNameW(interfaceLuid : NET_LUID*, interfaceName : LPWSTR, length : SizeT) : DWORD
  fun ConvertInterfaceNameToLuidW(interfaceName : LPWSTR, interfaceLuid : NET_LUID*) : DWORD
end
