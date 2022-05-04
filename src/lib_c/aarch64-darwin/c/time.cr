require "./sys/types"

lib LibC
  struct Timespec
    tv_sec : TimeT
    tv_nsec : Long
  end
end
