require "ecr/macros"

module Crystal::Doc
  struct TypeTemplate
    getter type

    def initialize(@type)
    end

    ecr_file "#{__DIR__}/type.ecr"
  end
end
