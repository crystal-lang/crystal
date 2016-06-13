module System::CPU
  enum Vendor
    Unknown,
    Intel,
    AMD
  end

  @[Flags]
  enum Features : UInt64
    SSE,
    SSE2,
    SSE3,
    SSSE3,
    SSE4_1,
    SSE4_2,
    AVX,
    AVX2
  end

  @@vendor_string = "\x00" * 12
  @@vendor = Vendor::Unknown
  @@features = Features::None
  @@initialized = false

  def self.cpuid(fn : Int32, subfn : Int32 = 0)
    ifdef x86_64 || i686
      buf = StaticArray(UInt32, 4).new
      ptr = buf.to_unsafe.address
      asm(%(
        movl $1, %eax
        movl $2, %ecx
        cpuid
        movl %eax, 0x0($0)
        movl %ebx, 0x4($0)
        movl %ecx, 0x8($0)
        movl %edx, 0xc($0)) :: "r"(ptr), "r"(fn), "r"(subfn): "eax", "ebx", "ecx", "edx", "memory")
      buf
    else
      {{ raise "Unsupported platform, only x86_64 and i686 are supported. " }}
    end
  end

  def self.vendor_string
    detect_cpu_features
    @@vendor_string
  end

  def self.vendor
    detect_cpu_features
    @@vendor
  end

  def self.intel?
    vendor == Vendor::Intel
  end

  def self.amd?
    vendor == Vendor::AMD
  end

  def self.features
    detect_cpu_features
    @@features
  end

  # Helper methods
  def self.has_sse?
    (features & Features::SSE) != 0
  end

  def self.has_sse2?
    (features & Features::SSE2) != 0
  end

  def self.has_sse3?
    (features & Features::SSE3) != 0
  end

  def self.has_ssse3?
    (features & Features::SSSE3) != 0
  end

  def self.has_sse4_1?
    (features & Features::SSE4_1) != 0
  end

  def self.has_sse4_2?
    (features & Features::SSE4_2) != 0
  end

  def self.has_avx?
    (features & Features::AVX) != 0
  end

  def self.has_avx2?
    (features & Features::AVX2) != 0
  end

  private def self.detect_cpu_features : Void
    ifdef x86_64 || i686
      return if @@initialized

      vendor_slice = Slice(UInt8).new(12)
      id0 = cpuid(0)

      vendor_slice[0] = (id0[1] >> 0).to_u8
      vendor_slice[1] = (id0[1] >> 8).to_u8
      vendor_slice[2] = (id0[1] >> 16).to_u8
      vendor_slice[3] = (id0[1] >> 24).to_u8
      vendor_slice[4] = (id0[3] >> 0).to_u8
      vendor_slice[5] = (id0[3] >> 8).to_u8
      vendor_slice[6] = (id0[3] >> 16).to_u8
      vendor_slice[7] = (id0[3] >> 24).to_u8
      vendor_slice[8] = (id0[2] >> 0).to_u8
      vendor_slice[9] = (id0[2] >> 8).to_u8
      vendor_slice[10] = (id0[2] >> 16).to_u8
      vendor_slice[11] = (id0[2] >> 24).to_u8

      @@vendor_string = String.new(vendor_slice)

      if @@vendor_string == "GenuineIntel"
        @@vendor = Vendor::Intel
      elsif @@vendor_string == "AuthenticAMD"
        @@vendor = Vendor::AMD
      end

      id1 = cpuid(1)
      id7 = cpuid(7)

      add_feature Features::SSE, id1[3], 25
      add_feature Features::SSE2, id1[3], 26
      add_feature Features::SSE3, id1[2], 0
      add_feature Features::SSSE3, id1[2], 9
      add_feature Features::SSE4_1, id1[2], 19
      add_feature Features::SSE4_2, id1[2], 20
      add_feature Features::AVX, id1[2], 28
      add_feature Features::AVX2, id7[1], 5

      @@initialized = true
    end
  end

  private def self.add_feature(feature : Features, id : UInt32, bit : Int32)
    if (id & (1 << bit)) != 0
      @@features |= feature
    end
  end
end
