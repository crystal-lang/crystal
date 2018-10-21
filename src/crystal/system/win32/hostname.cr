require "c/ntsysteminfo"

module Crystal::System
  def self.hostname
    name_size = LibC::NT_COMPUTER_NAME_SIZE.to_u32
    unless LibC.NTGetComputerNameExA(LibC::ComputerNameFormat::ComputerNameDnsHostname, out machine_name, pointerof(name_size))
        raise Errno.new("Failed to get machine hostname.")
    end
    name = String.new machine_name.to_unsafe
    name
  end
end
