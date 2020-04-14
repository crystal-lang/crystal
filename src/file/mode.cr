class ::File < IO::FileDescriptor
  @[Flags]
  enum Mode
    Read
    Write
    Overwrite
    Append

    Create
    CreateNew
    Truncate

    Sync
    SymlinkNoFollow
  end
end
