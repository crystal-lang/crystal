module Crystal::System
  def self.cpu_count
    # TODO: There isn't a good way to get the number of CPUs on WebAssembly
    1
  end

  def self.effective_cpu_count
    -1
  end
end
