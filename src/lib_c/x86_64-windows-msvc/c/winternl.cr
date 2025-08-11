@[Link("ntdll")]
lib LibNTDLL
  fun RtlNtStatusToDosError(status : LibC::ULONG) : LibC::ULONG
end
