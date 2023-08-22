module Crystal::System::MIME
  MIME_SOURCES = {
    "/etc/mime.types",                      # Linux
    "/etc/httpd/mime.types",                # Apache on Mac OS X
    "/usr/local/etc/mime.types",            # FreeBSD
    "/usr/share/misc/mime.types",           # OpenBSD
    "/etc/httpd/conf/mime.types",           # Apache
    "/etc/apache/mime.types",               # Apache 1
    "/etc/apache2/mime.types",              # Apache 2
    "/usr/local/lib/netscape/mime.types",   # Netscape
    "/usr/local/etc/httpd/conf/mime.types", # Apache 1.2
  }

  # Load MIME types from operating system source.
  def self.load
    MIME_SOURCES.each do |path|
      next unless ::File.exists?(path)
      ::File.open(path) do |file|
        ::MIME.load_mime_database file
      end
    rescue
    end
  end
end
