require "c/ntdef"
require "c/winnt"

@[Link("ntdll")]
lib LibNTDLL
  alias NTSTATUS = LibC::ULONG
  alias ACCESS_MASK = LibC::DWORD

  GENERIC_ALL = 0x10000000_u32

  alias NtCreateWaitCompletionPacketProc = Proc(LibC::HANDLE*, ACCESS_MASK, LibC::OBJECT_ATTRIBUTES*, NTSTATUS)
  alias NtAssociateWaitCompletionPacketProc = Proc(LibC::HANDLE, LibC::HANDLE, LibC::HANDLE, Void*, Void*, NTSTATUS, LibC::ULONG*, LibC::BOOLEAN*, NTSTATUS)
  alias NtCancelWaitCompletionPacketProc = Proc(LibC::HANDLE, LibC::BOOLEAN, NTSTATUS)

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
