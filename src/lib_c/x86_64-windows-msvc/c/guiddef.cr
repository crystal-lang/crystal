lib LibC
  struct GUID
    data1 : UInt32
    data2 : UInt16
    data3 : UInt16
    data4 : UInt8[8]
  end
end

struct LibC::GUID
  def initialize(@data1 : UInt32, @data2 : UInt16, @data3 : UInt16, @data4 : UInt8[8])
  end
end
