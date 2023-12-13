lib LibC
  fun GetOverlappedResult(
    hFile : HANDLE,
    lpOverlapped : OVERLAPPED*,
    lpNumberOfBytesTransferred : DWORD*,
    bWait : BOOL
  ) : BOOL

  fun CreateIoCompletionPort(
    fileHandle : HANDLE,
    existingCompletionPort : HANDLE,
    completionKey : ULong*,
    numberOfConcurrentThreads : DWORD
  ) : HANDLE

  fun GetQueuedCompletionStatusEx(
    completionPort : HANDLE,
    lpCompletionPortEntries : OVERLAPPED_ENTRY*,
    ulCount : ULong,
    ulNumEntriesRemoved : ULong*,
    dwMilliseconds : DWORD,
    fAlertable : BOOL
  ) : BOOL
  fun CancelIoEx(
    hFile : HANDLE,
    lpOverlapped : OVERLAPPED*
  ) : BOOL
  fun CancelIo(
    hFile : HANDLE
  ) : BOOL

  fun DeviceIoControl(
    hDevice : HANDLE,
    dwIoControlCode : DWORD,
    lpInBuffer : Void*,
    nInBufferSize : DWORD,
    lpOutBuffer : Void*,
    nOutBufferSize : DWORD,
    lpBytesReturned : DWORD*,
    lpOverlapped : OVERLAPPED*
  ) : BOOL
end
