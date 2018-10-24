require "c/sysinfoapi"

module Crystal::System
  def self.hostname
    name_size = LibC::MAX_COMPUTER_NAME_SIZE.to_u32
    unless LibC.GetComputerNameExW(LibC::COMPUTER_NAME_FORMAT::ComputerNameDnsHostname, out machine_name, pointerof(name_size))
      raise WinError.new("Failed to get machine hostname")
    end
    actual_name = Slice.new(machine_name.to_unsafe, name_size)
    String.from_utf16(actual_name)
  end
end
