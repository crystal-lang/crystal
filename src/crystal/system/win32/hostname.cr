require "c/sysinfoapi"

module Crystal::System
  def self.hostname
    retry_wstr_buffer do |buffer, small_buf|
      name_size = LibC::DWORD.new(buffer.size)
      if LibC.GetComputerNameExW(LibC::COMPUTER_NAME_FORMAT::ComputerNameDnsHostname, buffer, pointerof(name_size)) != 0
        break String.from_utf16(buffer[0, name_size])
      elsif small_buf && name_size > 0
        next name_size
      else
        raise RuntimeError.from_winerror("Could not get hostname")
      end
    end
  end
end
