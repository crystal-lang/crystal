require "ecr/macros"

module Crystal::Doc
  record TypeTemplate, type, types do
    ECR.def_to_s "#{__DIR__}/html/type.html"
  end

  record ListItemsTemplate, types, current_type do
    ECR.def_to_s "#{__DIR__}/html/list_items.html"
  end

  record MethodSummaryTemplate, title, methods do
    ECR.def_to_s "#{__DIR__}/html/method_summary.html"
  end

  record MethodDetailTemplate, title, methods do
    ECR.def_to_s "#{__DIR__}/html/method_detail.html"
  end

  record MethodsInheritedTemplate, type, ancestor, methods, label do
    ECR.def_to_s "#{__DIR__}/html/methods_inherited.html"
  end

  record OtherTypesTemplate, title, type, other_types do
    ECR.def_to_s "#{__DIR__}/html/other_types.html"
  end

  record MainTemplate, body, types, repository_name do
    ECR.def_to_s "#{__DIR__}/html/main.html"
  end

  struct JsTypeTemplate
    ECR.def_to_s "#{__DIR__}/html/js/doc.js"
  end

  struct StyleTemplate
    ECR.def_to_s "#{__DIR__}/html/css/style.css"
  end
end
