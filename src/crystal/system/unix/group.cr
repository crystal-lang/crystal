require "c/grp"

class Crystal::System::Group
  getter name : String
  getter password : String
  getter id : LibC::GidT
  getter members : Array(String)

  private def initialize(@name, @password, @id, @members)
  end

  private def self.extract_members(gr_mem)
    members = Array(String).new

    n = 0
    while gr_mem[n]
      members << String.new(gr_mem[n])
      n += 1
    end

    members
  end

  private def self.from_struct(grp)
    new(String.new(grp.gr_name), String.new(grp.gr_passwd), grp.gr_gid, self.extract_members(grp.gr_mem))
  end

  def self.from_name?(groupname : String)
    groupname.check_no_null_byte

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    buf = Bytes.new(1024)

    ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise Errno.new("getgrnam_r") if ret != 0
    return nil if grp_pointer.null?

    self.from_struct(grp)
  end

  def self.from_id?(groupid : LibC::GidT)
    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    buf = Bytes.new(1024)

    ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise Errno.new("getgrgid_r") if ret != 0
    return nil if grp_pointer.null?

    self.from_struct(grp)
  end
end
