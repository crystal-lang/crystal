class ::File < IO::FileDescriptor
  @[Flags]
  enum Mode
    Read
    Write
    Append

    Create
    CreateNew
    Truncate

    SymlinkNoFollow
  end
end
