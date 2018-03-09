require "./winnt"

@[Link("advapi32")]
lib LibC
  fun RtlGenRandom = SystemFunction036(random_buffer : Void*, random_buffer_length : ULong) : BOOLEAN
end
