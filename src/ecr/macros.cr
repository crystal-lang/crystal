macro embed_ecr(filename, io_name)
  \{{ run("ecr/process", {{filename}}, {{io_name}}) }}
end

macro ecr_file(filename)
  def to_s(__io__)
    embed_ecr {{filename}}, "__io__"
  end
end

