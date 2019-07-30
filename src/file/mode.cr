class ::File < IO::FileDescriptor
  @[Flags]
  enum Mode
    Read
    Write
    ReadWrite

    Create
    CreateNew
    Append
    Truncate

    Sync
    SymlinkNoFollow
  end
end
