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

  record MethodSummaryTemplate, title, methods do
    ecr_file "#{__DIR__}/html/method_summary.html"
  end

  record MethodDetailTemplate, title, methods do
    ecr_file "#{__DIR__}/html/method_detail.html"
  end

  record OtherTypesTemplate, title, type, other_types do
    ecr_file "#{__DIR__}/html/other_types.html"
  end
end
