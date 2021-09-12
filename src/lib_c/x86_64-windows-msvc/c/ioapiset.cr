lib LibC
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
end
