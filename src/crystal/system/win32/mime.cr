require "./registry"

module Crystal::System::MIME
  CONTENT_TYPE = "Content Type".to_utf16

  # Load MIME types from operating system source.
  def self.load
    Registry.each_name(LibC::HKEY_CLASSES_ROOT) do |name|
      # skip anything that is not a file extension
      next if name.size < 2 || !(name[0] === '.')

      Registry.open?(LibC::HKEY_CLASSES_ROOT, name) do |sub_handle|
        content_type = Registry.get_string(sub_handle, CONTENT_TYPE)
        if content_type
          ::MIME.register String.from_utf16(name), content_type
        end
      end
    end
  end
end
