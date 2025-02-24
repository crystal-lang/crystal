#! /usr/bin/env crystal

require "http"
require "json"
require "ecr"

record Entity, characters : String, codepoints : Array(Int32) do
  include JSON::Serializable
  include JSON::Serializable::Strict
end

single_char_entities = [] of {String, Entity}
double_char_entities = [] of {String, Entity}

HTTP::Client.get("https://html.spec.whatwg.org/entities.json") do |res|
  Hash(String, Entity).from_json(res.body_io).each do |name, entity|
    name = name.rchop(';').lchop?('&') || raise "Entity does not begin with &"

    entities =
      case entity.codepoints.size
      when 1; single_char_entities
      when 2; double_char_entities
      else    raise "Unknown entity codepoint size"
      end

    entities << {name, entity}
  end
end

single_char_entities.uniq!(&.first).sort_by!(&.first)
double_char_entities.uniq!(&.first).sort_by!(&.first)

max_entity_name_size = {
  single_char_entities.max_of { |name, _| name.size },
  double_char_entities.max_of { |name, _| name.size },
}.max

path = "#{__DIR__}/../src/html/entities.cr"
File.open(path, "w") do |file|
  ECR.embed "#{__DIR__}/html_entities.ecr", file
end

`crystal tool format #{path}`
