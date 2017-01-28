# Supported compression methods in the current implementation.
enum Zip::CompressionMethod : UInt16
  STORED   = 0
  DEFLATED = 8
end
