require "c/ntdef"
require "c/winnt"

@[Link("ntdll")]
lib LibNTDLL
  alias NTSTATUS = LibC::ULONG
  alias ACCESS_MASK = LibC::DWORD

  GENERIC_ALL = 0x10000000_u32

  fun NtCreateWaitCompletionPacket(
    waitCompletionPacketHandle : LibC::HANDLE*,
    desiredAccess : ACCESS_MASK,
    objectAttributes : LibC::OBJECT_ATTRIBUTES*,
  ) : NTSTATUS

  fun NtAssociateWaitCompletionPacket(
    waitCompletionPacketHandle : LibC::HANDLE,
    ioCompletionHandle : LibC::HANDLE,
    targetObjectHandle : LibC::HANDLE,
    keyContext : Void*,
    apcContext : Void*,
    ioStatus : NTSTATUS,
    ioStatusInformation : LibC::ULONG*,
    alreadySignaled : LibC::BOOLEAN*,
  ) : NTSTATUS

  fun NtCancelWaitCompletionPacket(
    waitCompletionPacketHandle : LibC::HANDLE,
    removeSignaledPacket : LibC::BOOLEAN,
  ) : NTSTATUS
end
