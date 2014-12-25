require "ecr/macros"

module Crystal::Doc
  record TypeTemplate, type do
    ecr_file "#{__DIR__}/html/type.html"
  end

  record ListTemplate, types do
    ecr_file "#{__DIR__}/html/list.html"
  end

  record ListItemsTemplate, types do
    ecr_file "#{__DIR__}/html/list_items.html"
  end
end
