require "./windows_registry"

module Crystal::System::MIME
  CONTENT_TYPE = System.wstr_literal "Content Type"

  # Load MIME types from operating system source.
  def self.load
    WindowsRegistry.each_name(LibC::HKEY_CLASSES_ROOT) do |name|
      # skip anything that is not a file extension
      next if name.size < 2 || !(name[0] === '.')

      WindowsRegistry.open?(LibC::HKEY_CLASSES_ROOT, name) do |sub_handle|
        content_type = WindowsRegistry.get_string(sub_handle, CONTENT_TYPE)
        if content_type
          begin
            ::MIME.register String.from_utf16(name), content_type
          rescue ArgumentError
            # skip registry entries with an invalid Content Type value
          end
        end
      end
    end
  end
end
