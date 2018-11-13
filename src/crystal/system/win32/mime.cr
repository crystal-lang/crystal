module Crystal::System::MIME
  # Load MIME types from operating system source.
  def self.load
    # TODO: MIME types in Windows are provided by the registry. This needs to be
    # implemented when registry access it is available.
    # Until then, there will no system-provided MIME types in Windows.
  end
end
