macro embed_ecr(filename)
  \{{ run("ecr/process", {{filename}}) }}
end

macro ecr_file(filename)
  def to_s
    embed_ecr {{filename}}
  end
end

