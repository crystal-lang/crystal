require "crystal/system/mime"

# This module implements a global MIME registry.
#
# NOTE: To use `MIME`, you must explicitly import it with `require "mime"`
#
# ```
# require "mime"
#
# MIME.from_extension(".html")         # => "text/html"
# MIME.from_filename("path/file.html") # => "text/html"
# ```
#
# The registry will be populated with some default values (see `DEFAULT_TYPES`)
# as well as the operating system's MIME database.
#
# Default initialization can be skipped by calling `MIME.init(false)` before the first
# query to the MIME database.
#
# ## OS-provided MIME database
#
# On a POSIX system, the following files are tried to be read in sequential order,
# stopping at the first existing file. These values override those from `DEFAULT_TYPES`.
#
# ```plain
# /etc/mime.types
# /etc/httpd/mime.types                    # Mac OS X
# /etc/httpd/conf/mime.types               # Apache
# /etc/apache/mime.types                   # Apache 1
# /etc/apache2/mime.types                  # Apache 2
# /usr/local/etc/httpd/conf/mime.types
# /usr/local/lib/netscape/mime.types
# /usr/local/etc/httpd/conf/mime.types     # Apache 1.2
# /usr/local/etc/mime.types                # FreeBSD
# /usr/share/misc/mime.types               # OpenBSD
# ```
#
# ## Registering custom MIME types
#
# Applications can register their own MIME types:
#
# ```
# require "mime"
#
# MIME.from_extension?(".cr")     # => nil
# MIME.extensions("text/crystal") # => Set(String).new
#
# MIME.register(".cr", "text/crystal")
# MIME.from_extension?(".cr")     # => "text/crystal"
# MIME.extensions("text/crystal") # => Set(String){".cr"}
# ```
#
# ## Loading a custom MIME database
#
# To load a custom MIME database, `load_mime_database` can be called with an
# `IO` to read the database from.
#
# ```
# require "mime"
#
# # Load user-defined MIME types
# File.open("~/.mime.types") do |io|
#   MIME.load_mime_database(io)
# end
# ```
#
# Loaded values override previously defined mappings.
#
# The data format must follow the format of `mime.types`: Each line declares
# a MIME type followed by a whitespace-separated list of extensions mapped to
# this type. Everything following a `#` is considered a comment until the end of
# line. Empty lines are ignored.
#
# ```plain
# text/html html htm
#
# # comment
# ```
module MIME
  class Error < Exception
  end

  @@initialized = false
  @@types = {} of String => String
  @@types_lower = {} of String => String
  @@extensions = {} of String => Set(String)

  # A limited set of default MIME types.
  DEFAULT_TYPES = {
    ".css"  => "text/css; charset=utf-8",
    ".gif"  => "image/gif",
    ".htm"  => "text/html; charset=utf-8",
    ".html" => "text/html; charset=utf-8",
    ".jpg"  => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".js"   => "text/javascript; charset=utf-8",
    ".json" => "application/json",
    ".pdf"  => "application/pdf",
    ".png"  => "image/png",
    ".svg"  => "image/svg+xml",
    ".txt"  => "text/plain; charset=utf-8",
    ".xml"  => "text/xml; charset=utf-8",
    ".wasm" => "application/wasm",
    ".webp" => "image/webp",
  }

  # Initializes the MIME database.
  #
  # The default behaviour is to load the internal defaults as well as the OS-provided
  # MIME database. This can be disabled with *load_defaults* set to `false`.
  #
  # This method usually doesn't need to be called explicitly when the default behaviour is expected.
  # It will be called implicitly with `load_defaults: true` when a query method
  # is called and the MIME database has not been initialized before.
  #
  # Calling this method repeatedly is allowed.
  def self.init(load_defaults : Bool = true) : Nil
    @@initialized = true

    if load_defaults
      DEFAULT_TYPES.each do |ext, type|
        register ext, type
      end

      Crystal::System::MIME.load
    end
  end

  # Initializes the MIME database loading contents from a file.
  #
  # This will neither load the internal defaults nor the OS-provided MIME database,
  # only the database at *filename* (using `.load_mime_database`).
  #
  # Calling this method repeatedly is allowed.
  def self.init(filename : String) : Nil
    init(load_defaults: false)

    File.open(filename, "r") do |file|
      load_mime_database(file)
    end
  end

  private def self.initialize_types
    init unless @@initialized
  end

  # Looks up the MIME type associated with *extension*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Returns *default* if *extension* is not registered.
  def self.from_extension(extension : String, default) : String
    from_extension(extension) { default }
  end

  # Looks up the MIME type associated with *extension*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Raises `KeyError` if *extension* is not registered.
  def self.from_extension(extension : String) : String
    from_extension(extension) { raise KeyError.new("Missing MIME type for extension #{extension.inspect}") }
  end

  # Looks up the MIME type associated with *extension*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Returns `nil` if *extension* is not registered.
  def self.from_extension?(extension : String) : String?
    from_extension(extension) { nil }
  end

  # Looks up the MIME type associated with *extension*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Runs the given block if *extension* is not registered.
  def self.from_extension(extension : String, &block)
    initialize_types

    @@types.fetch(extension) { @@types_lower.fetch(extension.downcase) { yield extension } }
  end

  # Looks up the MIME type associated with the extension in *filename*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Returns *default* if extension is not registered.
  def self.from_filename(filename : String | Path, default) : String
    from_extension(File.extname(filename.to_s), default)
  end

  # Looks up the MIME type associated with the extension in *filename*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Raises `KeyError` if extension is not registered.
  def self.from_filename(filename : String | Path) : String
    from_extension(File.extname(filename.to_s))
  end

  # Looks up the MIME type associated with the extension in *filename*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Returns `nil` if extension is not registered.
  def self.from_filename?(filename : String | Path) : String?
    from_extension?(File.extname(filename.to_s))
  end

  # Looks up the MIME type associated with the extension in *filename*.
  #
  # A case-sensitive search is tried first, if this yields no result, it is
  # matched case-insensitive. Runs the given block if extension is not registered.
  def self.from_filename(filename : String | Path, &block)
    from_extension(File.extname(filename.to_s)) { |extension| yield extension }
  end

  # Register *type* for *extension*.
  #
  # *extension* must start with a dot (`.`) and must not contain any null bytes.
  def self.register(extension : String, type : String) : Nil
    raise ArgumentError.new("Extension does not start with a dot: #{extension.inspect}") unless extension.starts_with?('.')
    extension.check_no_null_byte

    initialize_types

    # If the same extension had a different type registered before, it needs to
    # be removed from the extensions list.
    if previous_type = @@types[extension]?
      if extensions = @@extensions[parse_media_type(previous_type)]?
        extensions.delete(extension)
      end
    end

    mediatype = parse_media_type(type) || raise ArgumentError.new "Invalid media type: #{type}"

    @@types[extension] = type
    @@types_lower[extension.downcase] = type

    @@extensions.put_if_absent(mediatype) { Set(String).new } << extension
  end

  # Returns all extensions registered for *type*.
  def self.extensions(type : String) : Set(String)
    initialize_types

    @@extensions.fetch(type) { Set(String).new }
  end

  # tspecial as defined by RFC 1521 and RFC 2045.
  private TSPECIAL_CHARACTERS = {'(', ')', '<', '>', '@', ',', ';', ':', '\\', '"', '/', '[', ']', '?', '='}

  private def self.parse_media_type(type : String) : String?
    reader = Char::Reader.new(type)

    sub_type_start = -1
    while reader.has_next?
      case char = reader.current_char
      when ';'
        break
      when '/'
        return nil if sub_type_start > -1
        sub_type_start = reader.pos
        reader.next_char
      else
        if TSPECIAL_CHARACTERS.includes?(char) || 0x20 > char.ord > 0x7F
          return nil
        end

        reader.next_char
      end
    end

    if reader.pos == 0
      return nil
    end

    type.byte_slice(0, reader.pos).strip.downcase
  end

  # Reads MIME type mappings from *io* and registers the extension-to-type
  # relation (see `.register`).
  #
  # The format follows that of `mime.types`: Each line is list of MIME type and
  # zero or more extensions, separated by whitespace.
  def self.load_mime_database(io : IO) : Nil
    while line = io.gets
      fields = line.split

      fields.each_with_index do |field, i|
        extension = field
        break if extension.starts_with?('#')
        next if i == 0 # first index contains the media type

        register ".#{extension}", fields[0]
      end
    end
  end
end
