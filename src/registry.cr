{% skip_file unless flag?(:win32) %}
require "winerror"
require "c/winreg"

# This API povides access to the Windows registry. The main type is `Key`.
#
# ```
# Registry::LOCAL_MACHINE.open("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", Registry::SAM::QUERY_VALUE) do |key|
#   key.get_string("SystemRoot") # => "C:\\WINDOWS"
# end
# ```
#
# The Windows API defines some [predefined root keys](https://docs.microsoft.com/en-us/windows/desktop/sysinfo/predefined-keys) that are always open.
# They are available as constants and can be used as entry points to the registry.
#
# * `HKEY_CLASSES_ROOT`
# * `HKEY_CURRENT_USER`
# * `HKEY_LOCAL_MACHINE`
# * `HKEY_USERS`
# * `HKEY_CURRENT_CONFIG`
module Registry
  # Information about file types and their properties.
  CLASSES_ROOT = Key.new(LibC::HKEY_CLASSES_ROOT, "HKEY_CLASSES_ROOT")

  # Preferences of the current user.
  #
  # The kay maps to the current user's subkey in `HKEY_USERS`.
  CURRENT_USER = Key.new(LibC::HKEY_CURRENT_USER, "HKEY_CURRENT_USER")

  # Information about the physical state of the computer, including installed hardware and software.
  LOCAL_MACHINE = Key.new(LibC::HKEY_LOCAL_MACHINE, "HKEY_LOCAL_MACHINE")

  # Preferences of all users.
  #
  # This key contains a subkey per user.
  USERS = Key.new(LibC::HKEY_USERS, "HKEY_USERS")

  # Provides access to performance data.
  PERFORMANCE_DATA = Key.new(LibC::HKEY_PERFORMANCE_DATA, "HKEY_PERFORMANCE_DATA")

  # Information about the hardware profile of the local computer system.
  CURRENT_CONFIG = Key.new(LibC::HKEY_CURRENT_CONFIG, "HKEY_CURRENT_CONFIG")

  # Registry error.
  class Error < Exception
  end

  # Registry key security and access rights.
  # See https://msdn.microsoft.com/en-us/library/windows/desktop/ms724878.aspx
  # for details.
  alias SAM = LibC::REGSAM

  # Registry value types.
  alias ValueType = LibC::ValueType

  # Union of Crystal types representing a registry value.
  alias Value = Bytes | Int32 | String | Int64 | Array(String)

  # This type represents a handle to an open Windows registry key.
  #
  # Keys can be obtained by calling `#open` on an already opened key.
  # The predefined root keys are defined as constants in `Registry`.
  struct Key
    @handle : LibC::HKEY
    @name : String

    # Creates a new instance from an open Windows *handle* (`HKEY`) and *name*.
    #
    # NOTE: This method is only useful if a Windows handle is retrieved from
    # calling external code. Usually, new keys are created by opening subkeys
    # of the predefined root keys available as constants in `Registry`.
    def initialize(@handle : LibC::HKEY, @name : String)
    end

    # Returns the full path of this key.
    getter name : String

    # Returns the Windows handle (`HKEY`) representing this key.
    def to_unsafe : LibC::HKEY
      @handle
    end

    def get_raw?(name : String, buffer : Slice(UInt8)) : {ValueType, UInt32}?
      name.check_no_null_byte

      get_raw?(name.to_utf16, buffer)
    end

    private def get_raw?(name : Slice(UInt16), buffer : Bytes) : {ValueType, UInt32}?
      length = buffer.size.to_u32
      status = LibC.RegQueryValueExW(self, name, nil, out valtype, buffer, pointerof(length))
      case status
      when WinError::ERROR_SUCCESS
        {valtype, length}
      when WinError::ERROR_FILE_NOT_FOUND
        nil
      when WinError::ERROR_MORE_DATA
        {valtype, length}
      else
        raise WinError.new("RegQueryValueExW", status)
      end
    end

    def get_raw(name : String, buffer : Slice(UInt8)) : {ValueType, UInt32}
      get_raw?(name, buffer) || raise Error.new("Value #{name.inspect} does not exist")
    end

    def get_raw(name : String) : {ValueType, Slice(UInt8)}
      name.check_no_null_byte

      name_u16 = name.to_utf16

      Crystal::System.retry_buffer do |buffer, small_buf|
        valtype, length = get_raw?(name_u16, buffer) || raise Error.new("Value #{name.inspect} does not exist")

        if 0 <= length <= buffer.size
          return {valtype, buffer[0, length]}
        elsif small_buf && length > 0
          next length
        else
          raise Error.new("RegQueryValueExW retry buffer")
        end
      end
    end

    def get_raw?(name : String) : {ValueType, Slice(UInt8)}?
      name.check_no_null_byte

      name_u16 = name.to_utf16

      Crystal::System.retry_buffer do |buffer, small_buf|
        raw = get_raw?(name_u16, buffer) || return
        valtype, length = raw

        if 0 <= length <= buffer.size
          return {valtype, buffer[0, length]}
        elsif small_buf && length > 0
          next length
        else
          raise Error.new("RegQueryValueExW retry buffer")
        end
      end
    end

    def get_mui(name : String) : String?
      get_mui?(name) || raise Error.new("Value '#{name}' does not exist")
    end

    def get_mui?(name : String) : String?
      name.check_no_null_byte
      name_u16 = name.to_utf16

      Crystal::System.retry_wstr_buffer do |buffer, small_buf|
        length = buffer.size.to_u32
        pointer = buffer.to_unsafe

        status = LibC.RegLoadMUIStringW(self, name_u16, pointer, length, pointerof(length), 0, Pointer(UInt16).null)

        if status == WinError::ERROR_FILE_NOT_FOUND
          # Try to resolve the string value using the system directory as
          # a DLL search path; this assumes the string value is of the form
          # @[path]\dllname,-strID but with no path given, e.g. @tzres.dll,-320.

          # This approach works with tzres.dll but may have to be revised
          # in the future to allow callers to provide custom search paths.
          pdir = Crystal::System::Env.expand("%SystemRoot%\\system32\\".to_utf16)

          length = buffer.size.to_u32
          status = LibC.RegLoadMUIStringW(self, name_u16, pointer, length, pointerof(length), 0, pdir)
        end

        case status
        when WinError::ERROR_SUCCESS
          if 0 < length <= buffer.size
            # returned length is in bytes, so we need to divide by 2 to get WCHAR length
            return String.from_utf16(buffer[0, length / 2 - 1])
          elsif small_buf && length > 0
            next length
          else
            raise Error.new("RegLoadMUIStringW")
          end
        when WinError::ERROR_FILE_NOT_FOUND
          return
        else
          raise WinError.new("RegLoadMUIStringW", status)
        end
      end
    end

    def get(name : String) : Value
      cast_value *get_raw(name)
    end

    def get?(name : String) : Value?
      if raw = get_raw?(name)
        cast_value *raw
      end
    end

    def get_string?(name : String) : String?
      if raw = get_raw?(name)
        value_string *raw
      end
    end

    def get_string(name : String) : String
      value_string *get_raw(name)
    end

    def set(name : String, data : Bytes, type : ValueType = ValueType::BINARY) : Nil
      name.check_no_null_byte("name")

      status = LibC.RegSetValueExW(self, name.to_utf16, 0, type, data, data.bytesize)
      unless status == WinError::ERROR_SUCCESS
        raise WinError.new("WinRegSetValueExW", status)
      end
    end

    def set(name : String, value : String, type : ValueType = ValueType::SZ) : Nil
      value.check_no_null_byte("value")

      u16_slice = value.to_utf16
      u8_slice = u16_slice.to_unsafe.as(Pointer(UInt8)).to_slice(u16_slice.bytesize)

      set(name, u8_slice, type)
    end

    def set(name : String, value : Int32, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Nil
      raw = uninitialized UInt8[4]
      format.encode(value, raw.to_slice)
      set(name, raw.to_slice, ValueType::DWORD)
    end

    def set(name : String, value : Int64, format : IO::ByteFormat = IO::ByteFormat::LittleEndian) : Nil
      raw = uninitialized UInt8[8]
      format.encode(value, raw.to_slice)
      set(name, raw.to_slice, ValueType::QWORD)
    end

    def set(name : String, value : Enumerable(String)) : Nil
      io = IO::Memory.new
      value.each do |string|
        string.check_no_null_byte

        u16_slice = string.to_utf16
        io.write u16_slice.to_unsafe.as(Pointer(UInt8)).to_slice(u16_slice.bytesize)
        io.write_byte 0_u8
        io.write_byte 0_u8
      end
      io.write_byte 0_u8
      io.write_byte 0_u8

      set(name, io.to_slice, ValueType::MULTI_SZ)
    end

    private def value_string(valtype, buffer) : String?
      case valtype
      when ValueType::SZ
        value_string(buffer)
      when ValueType::EXPAND_SZ
        value_string(buffer, expand: true)
      else
        raise Error.new("Expected string value type, found #{valtype.inspect}")
      end
    end

    private def value_string(buffer : Bytes, expand = false) : String
      wchar_buffer = buffer.to_unsafe.as(Pointer(UInt16)).to_slice(buffer.size / 2 - 1)
      if expand
        wchar_buffer = Crystal::System::Env.expand(wchar_buffer)
        wchar_buffer = wchar_buffer[0, wchar_buffer.size - 1]
      end
      String.from_utf16(wchar_buffer)
    end

    private def value_multi_string(buffer : Bytes) : Array(String)
      wchar_buffer = buffer.to_unsafe.as(Pointer(UInt16))
      strings = [] of String

      end_pointer = (buffer.to_unsafe + buffer.bytesize).as(Pointer(UInt16)) - 1
      while wchar_buffer < end_pointer
        string, wchar_buffer = String.from_utf16(wchar_buffer)
        strings << string
      end

      strings
    end

    private def cast_value(valtype : ValueType, buffer : Bytes) : Value
      case valtype
      when ValueType::BINARY
        buffer
      when ValueType::DWORD
        IO::ByteFormat::LittleEndian.decode(Int32, buffer)
      when ValueType::DWORD_BIG_ENDIAN
        IO::ByteFormat::BigEndian.decode(Int32, buffer)
      when ValueType::EXPAND_SZ
        value_string(buffer, expand: true)
      when ValueType::LINK
        buffer
      when ValueType::MULTI_SZ
        value_multi_string(buffer)
      when ValueType::QWORD
        IO::ByteFormat::LittleEndian.decode(Int64, buffer)
      when ValueType::SZ
        value_string(buffer)
      when ValueType::NONE
        buffer
      else
        raise "unreachable"
      end
    end

    # Opens a subkey at path *name* and returns the new key or `nil` if it does not exist.
    #
    # Users need to ensure the opened key will be closed after usage (see `#close`).
    # *sam* specifies desired access rights to the key to be opened.
    def open?(sub_name : String, sam : SAM = SAM::READ) : Key?
      sub_name.check_no_null_byte

      status = LibC.RegOpenKeyExW(self, sub_name.to_utf16, 0, sam, out sub_handle)

      case status
      when WinError::ERROR_SUCCESS
        Key.new(sub_handle, {@name, sub_name}.join('\\'))
      when WinError::ERROR_FILE_NOT_FOUND
      else
        raise WinError.new("RegOpenKeyExW", status)
      end
    end

    # Opens a subkey at path *name* and returns the new key.
    #
    # Users need to ensure the opened key will be closed after usage (see `#close`).
    # Raises `Registry::Error` if the subkey does not exist.
    #
    # *sam* specifies desired access rights to the key to be opened.
    def open(sub_name : String, sam : SAM = SAM::READ) : Key
      open?(sub_name, sam) || raise Error.new("Key #{sub_name} does not exist.")
    end

    # Opens a subkey at path *name* and yields it to the block.
    #
    # The key is automatically closed after the block returns.
    #
    # Raises `Registry::Error` if the subkey does not exist.
    #
    # *sam* specifies desired access rights to the key to be opened.
    def open(sub_name : String, sam : SAM = SAM::READ, &block : Key ->)
      sub_key = open(sub_name, sam)
      begin
        yield sub_key
      ensure
        sub_key.close
      end
    end

    # Closes the handle.
    def close : Nil
      status = LibC.RegCloseKey(self)

      unless status == WinError::ERROR_SUCCESS || status == WinError::ERROR_INVALID_HANDLE
        raise WinError.new("RegCloseKey", status)
      end
    end

    # Retrieves information about the key.
    def info : KeyInfo
      info = uninitialized KeyInfo
      status = LibC.RegQueryInfoKeyW(self, nil, nil, nil,
        pointerof(info.@sub_key_count), pointerof(info.@max_sub_key_length), nil,
        pointerof(info.@value_count), pointerof(info.@max_value_name_length),
        pointerof(info.@max_value_length), nil, out last_write_time)

      unless status == WinError::ERROR_SUCCESS
        raise WinError.new("RegQueryInfoKeyW", status)
      end

      seconds, nanoseconds = Crystal::System::Time.filetime_to_seconds_and_nanoseconds(last_write_time)
      pointerof(info.@last_write_time).value = Time.utc(seconds: seconds, nanoseconds: nanoseconds)
      info
    end

    # Describes the statistics of a registry key. It is returned by `Key#info`.
    struct KeyInfo
      private def initialize
        @sub_key_count = 0
        @max_sub_key_length = 0
        @value_count = 0
        @max_value_name_length = 0
        @max_value_length = 0
        @last_write_time = Time.utc_now
      end

      getter sub_key_count : UInt32

      # size of the key's subkey with the longest name, in Unicode characters, not including the terminating null byte.
      getter max_sub_key_length : UInt32

      getter value_count : UInt32
      # size of the key's longest value name, in Unicode characters, not including the terminating null byte.

      getter max_value_name_length : UInt32

      # longest data component among the key's values, in bytes.
      getter max_value_length : UInt32

      getter last_write_time : Time
    end

    # Returns a hash of all values in this key.
    def values : Hash(String, String | {ValueType, Bytes})
      values = {} of String => String | {ValueType, Bytes}
      each_value do |name, value|
        values[name] = value
      end
      values
    end

    # Iterates all value names in this key and yields them to the block.
    def each_name(&block : String ->) : Nil
      info = self.info
      buffer = Slice(UInt16).new(info.max_value_name_length + 1)

      info.value_count.times do |i|
        length = buffer.size.to_u32
        status = LibC.RegEnumValueW(self, i, buffer, pointerof(length), nil, nil, nil, nil)
        case status
        when WinError::ERROR_SUCCESS
          yield String.from_utf16(buffer[0, length])
        when WinError::ERROR_NO_MORE_ITEMS
          break
        else
          raise WinError.new("RegEnumValueW", status)
        end
      end
    end

    # Returns all names in this key.
    def names : Array(String)
      names = [] of String
      each_name do |name|
        names << name
      end
      names
    end

    # Iterates all values in this key and yields the name and value to the block.
    def each_value(&block : (String, Value) ->) : Nil
      info = self.info
      name_buffer = Slice(UInt16).new(info.max_value_name_length + 1)
      data_buffer = Slice(UInt8).new(info.max_value_length + 1)

      info.value_count.times do |i|
        name_length = name_buffer.size.to_u32
        data_length = data_buffer.size.to_u32
        status = LibC.RegEnumValueW(self, i, name_buffer, pointerof(name_length), nil,
          out valtype, data_buffer, pointerof(data_length))
        case status
        when WinError::ERROR_SUCCESS
          yield String.from_utf16(name_buffer[0, name_length]), cast_value(valtype, data_buffer[0, data_length])
        when WinError::ERROR_NO_MORE_ITEMS
          break
        else
          raise WinError.new("RegEnumValueW", status)
        end
      end
    end

    # Iterates all subkey names in this key and yields them to the block.
    def each_key(&block : String ->) : Nil
      info = self.info

      name_buffer = Slice(UInt16).new(info.max_sub_key_length + 1)
      info.sub_key_count.times do |i|
        name_length = name_buffer.size.to_u32
        status = LibC.RegEnumKeyExW(self, i, name_buffer, pointerof(name_length), nil, nil, nil, out last_write_time)
        case status
        when WinError::ERROR_SUCCESS
          yield String.from_utf16(name_buffer[0, name_length])
        when WinError::ERROR_NO_MORE_ITEMS
          break
        else
          raise WinError.new("RegEnumKeyExW", status)
        end
      end
    end

    # Returns all subkey names in this key.
    def subkeys : Array(String)
      subkeys = [] of String
      each_key do |key|
        subkeys << key
      end
      subkeys
    end

    # Creates a subkey called *name*.
    #
    # *sam* specifies the access rights for the key to be created.
    def create_key(name : String, sam : SAM = SAM::CREATE_SUB_KEY) : Nil
      create_key?(name, sam) || raise WinError.new("RegCreateKeyExW")
    end

    # Creates a subkey called *name* and returns a boolean indicating whether it was successfully created.
    # Returns `false` if the key could not be created or already existed.
    #
    # *sam* specifies the access rights for the key to be created.
    def create_key?(name : String, sam : SAM = SAM::CREATE_SUB_KEY) : Bool
      name.check_no_null_byte

      status = LibC.RegCreateKeyExW(self, name.to_utf16, 0, nil, LibC::RegOption::NON_VOLATILE, sam, nil, out sub_handle, out disposition)

      unless status == WinError::ERROR_SUCCESS
        return false
      end

      begin
        case disposition
        when LibC::RegDisposition::CREATED_NEW_KEY
        when LibC::RegDisposition::OPENED_EXISTING_KEY
          return false
        end

        true
      ensure
        LibC.RegCloseKey(sub_handle)
      end
    end

    # Deletes the subkey *name* and its values.
    #
    # If *recursive* is `true`, it recursively deletes subkeys.
    #
    # Raises `Registry::Error` if the subkey *name* does not exist.
    def delete_key(name : String, recursive : Bool = true) : Nil
      status = delete_key_impl(name, recursive) do |key, subname|
        key.delete_key(subname)
      end

      unless status == WinError::ERROR_SUCCESS
        raise WinError.new("RegDeleteKeyExW", status)
      end
    end

    # Deletes the subkey *name* and its values.
    #
    # If *recursive* is `true`, it recursively deletes subkeys.
    #
    # Returns `false` if the subkey *name* does not exist.
    def delete_key?(name : String, recursive : Bool = true) : Bool
      status = delete_key_impl(name, recursive) do |key, subname|
        key.delete_key?(subname) || return false
      end

      case status
      when WinError::ERROR_SUCCESS
        true
      when WinError::ERROR_FILE_NOT_FOUND
        false
      else
        raise WinError.new("RegDeleteKeyExW", status)
      end
    end

    private def delete_key_impl(name, recursive)
      name.check_no_null_byte
      name_u16 = name.to_utf16

      status = LibC.RegDeleteKeyExW(self, name_u16, 0, 0)

      if status == WinError::ERROR_ACCESS_DENIED && recursive
        # Need to delete subkeys first, then try again
        open(name, SAM::ALL_ACCESS) do |key|
          # Can't use key.each_key here because the iterator would be disturbed
          # by deleting keys.
          key.subkeys.each do |subname|
            yield key, subname
          end
        end

        status = LibC.RegDeleteKeyExW(self, name_u16, 0, 0)
      end

      status
    end
  end
end
