struct Crystal::System::FileInfo
  # Size of the file, in bytes.
  # def size : Int64

  # The permissions of the file.
  # def permissions : Permissions

  # The type of the file.
  # def type : Type

  # The special flags this file has set.
  # def flags : Flags

  # The last time this file was modified.
  # def modification_time : Time

  # The user ID that the file belongs to.
  # def owner_id : String

  # The group ID that the file belongs to.
  # def group_id : String

  # Returns true if this `FileInfo` and *other* are of the same file.
  # def same_file?(other : self) : Bool
end

{% if flag?(:unix) %}
  require "./unix/file_info"
{% elsif flag?(:win32) %}
  require "./win32/file_info"
{% else %}
  {% raise "No Crystal::System::File implementation available" %}
{% end %}
