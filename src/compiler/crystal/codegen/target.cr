require "llvm"

class Crystal::Codegen::Target
  class Error < Crystal::LocationlessException
  end

  getter architecture : String
  getter vendor : String
  getter environment : String

  def initialize(target_triple : String)
    # Let LLVM convert the user-inputted target triple into at least a target
    # triple with the architecture, vendor and OS in the correct place.
    target_triple = LLVM.normalize_triple(target_triple.downcase)

    @architecture, @vendor, @environment = target_triple.split('-', 3)

    # Perform additional normalisation and parsing
    case @architecture
    when "i486", "i586", "i686"
      @architecture = "i386"
    when "amd64"
      @architecture = "x86_64"
    when .starts_with?("arm")
      @architecture = "arm"
    end
  end

  def environment_parts
    @environment.split('-')
  end

  def pointer_bit_width
    case @architecture
    when "x86_64", "aarch64"
      64
    else
      32
    end
  end

  def os_name
    case self
    when .macos?
      "darwin"
    when .freebsd?
      "freebsd"
    when .openbsd?
      "openbsd"
    else
      environment
    end
  end

  def macos?
    @environment.starts_with?("darwin") || @environment.starts_with?("macos")
  end

  def freebsd?
    @environment.starts_with?("freebsd")
  end

  def freebsd_version
    if @environment =~ /freebsd(\d+)\.\d+/
      $1.to_i
    else
      nil
    end
  end

  def openbsd?
    @environment.starts_with?("openbsd")
  end

  def linux?
    @environment.starts_with?("linux")
  end

  def unix?
    macos? || freebsd? || openbsd? || linux?
  end

  def gnu?
    environment_parts.any? { |part| {"gnu", "gnueabi", "gnueabihf"}.includes? part }
  end

  def musl?
    environment_parts.any? { |part| {"musl", "musleabi", "musleabihf"}.includes? part }
  end

  def windows?
    @environment.starts_with?("win32") || @environment.starts_with?("windows")
  end

  def msvc?
    windows? && environment_parts.includes?("msvc")
  end

  def win32?
    windows? && (msvc? || gnu?)
  end

  def armhf?
    environment_parts.includes?("gnueabihf") || environment_parts.includes?("musleabihf")
  end

  def to_target_machine(cpu = "", features = "", release = false) : LLVM::TargetMachine
    case @architecture
    when "i386", "x86_64"
      LLVM.init_x86
    when "aarch64"
      LLVM.init_aarch64
    when "arm"
      LLVM.init_arm

      # Enable most conservative FPU for hard-float capable targets, unless a
      # CPU is defined (it will most certainly enable a better FPU) or
      # features contains a floating-point definition.
      if cpu.empty? && !features.includes?("fp") && armhf?
        features += "+vfp2"
      end
    else
      raise Target::Error.new("Unsupported architecture for target triple: #{self}")
    end

    opt_level = release ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None

    target = LLVM::Target.from_triple(self.to_s)
    target.create_target_machine(self.to_s, cpu: cpu, features: features, opt_level: opt_level).not_nil!
  end

  def to_s(io : IO) : Nil
    io << architecture << '-' << vendor << '-' << environment
  end
end
