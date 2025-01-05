#! /usr/bin/env crystal

# This helper queries merged pull requests for a given milestone from the GitHub API
# and creates formatted changelog entries.
#
# Pull requests that are already referenced in CHANGELOG.md are omitted, which
# makes it easy to incrementally add entries.
#
# Entries are grouped by topic (based on topic labels) and ordered by merge date.
# Some annotations are automatically added based on labels.
#
# Usage:
#
#   scripts/github-changelog.cr <milestone>
#
# Environment variables:
#   GITHUB_TOKEN: Access token for the GitHub API (required)
require "http/client"
require "json"

abort "Missing GITHUB_TOKEN env variable" unless ENV["GITHUB_TOKEN"]?
api_token = ENV["GITHUB_TOKEN"]

case ARGV.size
when 0
  abort "Missing <milestone> argument"
when 1
  repository = "crystal-lang/crystal"
  milestone = ARGV.first
when 2
  repository = ARGV[0]
  milestone = ARGV[1]
else
  abort "Too many arguments. Usage:\n  #{PROGRAM_NAME} [<GH repo ref>] <milestone>"
end

def query_prs(api_token, repository, milestone : String, cursor : String?)
  query = <<-GRAPHQL
    query($milestone: String, $owner: String!, $repository: String!, $cursor: String) {
      repository(owner: $owner, name: $repository) {
        milestones(query: $milestone, first: 1) {
          nodes {
            closedAt
            description
            dueOn
            title
            pullRequests(first: 100, after: $cursor) {
              nodes {
                number
                title
                mergedAt
                permalink
                author {
                  login
                }
                labels(first: 10) {
                  nodes {
                    name
                  }
                }
              }
              pageInfo {
                endCursor
                hasNextPage
              }
            }
          }
        }
      }
    }
    GRAPHQL

  owner, _, name = repository.partition("/")
  variables = {
    owner:      owner,
    repository: name,
    milestone:  milestone,
    cursor:     cursor,
  }

  response = HTTP::Client.post("https://api.github.com/graphql",
    body: {query: query, variables: variables}.to_json,
    headers: HTTP::Headers{
      "Authorization" => "bearer #{api_token}",
    }
  )
  unless response.success?
    abort "GitHub API response: #{response.status}\n#{response.body}"
  end

  response
end

module LabelNameConverter
  def self.from_json(pull : JSON::PullParser)
    pull.on_key! "name" do
      String.new(pull)
    end
  end
end

record Milestone,
  closed_at : Time?,
  description : String?,
  due_on : Time?,
  title : String,
  pull_requests : Array(PullRequest) do
  include JSON::Serializable

  @[JSON::Field(key: "dueOn")]
  @due_on : Time?

  @[JSON::Field(key: "closedAt")]
  @closed_at : Time?

  @[JSON::Field(key: "pullRequests", root: "nodes")]
  @pull_requests : Array(PullRequest)

  def release_date
    closed_at || due_on
  end
end

record PullRequest,
  number : Int32,
  title : String,
  merged_at : Time?,
  permalink : String,
  author : String?,
  labels : Array(String) do
  include JSON::Serializable
  include Comparable(self)

  @[JSON::Field(key: "mergedAt")]
  @merged_at : Time?

  @[JSON::Field(root: "login")]
  @author : String?

  @[JSON::Field(root: "nodes", converter: JSON::ArrayConverter(LabelNameConverter))]
  @labels : Array(String)

  def link_ref(io)
    io << "[#" << number << "]"
  end

  def <=>(other : self)
    sort_tuple <=> other.sort_tuple
  end

  def sort_tuple
    {
      type || "",
      topic || [] of String,
      deprecated? ? 0 : 1,
      merged_at || Time.unix(0),
    }
  end

  def infra_sort_tuple
    {
      topic || [] of String,
      type || "",
      deprecated? ? 0 : 1,
      merged_at || Time.unix(0),
    }
  end

  def primary_topic
    topic.try(&.[0]?) || "other"
  end

  def sub_topic
    topic.try(&.[1..].join(":").presence)
  end

  def topic
    topics.fetch(0) do
      STDERR.puts "Missing topic for ##{number}"
      nil
    end
  end

  def topics
    topics = labels.compact_map { |label|
      label.lchop?("topic:").try(&.split(/:|\//))
    }
    topics.reject! &.[0].==("multithreading")

    topics.sort_by! { |parts|
      topic_priority = case parts[0]
                       when "infrastructure" then 3
                       when "tools"          then 2
                       when "lang"           then 1
                       else                       0
                       end
      {-topic_priority, parts[0]}
    }
  end

  def deprecated?
    labels.includes?("deprecation")
  end

  def breaking?
    labels.includes?("kind:breaking")
  end

  def regression?
    labels.includes?("kind:regression")
  end

  def experimental?
    labels.includes?("experimental")
  end

  def feature?
    labels.includes?("kind:feature")
  end

  def fix?
    labels.includes?("kind:bug")
  end

  def chore?
    labels.includes?("kind:chore")
  end

  def refactor?
    labels.includes?("kind:refactor")
  end

  def docs?
    labels.includes?("kind:docs")
  end

  def specs?
    labels.includes?("kind:specs")
  end

  def performance?
    labels.includes?("performance")
  end

  def infra?
    labels.any?(&.starts_with?("topic:infrastructure"))
  end

  def type
    case
    when feature?     then "feature"
    when docs?        then "docs"
    when specs?       then "specs"
    when fix?         then "fix"
    when chore?       then "chore"
    when performance? then "performance"
    when refactor?    then "refactor"
    else                   nil
    end
  end

  def section
    case
    when breaking? then "breaking"
    when infra?    then "infra"
    else                type || ""
    end
  end

  def fixup?
    md = title.match(/\[fixup #(.\d+)/) || return
    md[1]?.try(&.to_i)
  end
end

def query_milestone(api_token, repository, number)
  cursor = nil
  milestone = nil

  while true
    response = query_prs(api_token, repository, number, cursor)

    parser = JSON::PullParser.new(response.body)
    m = parser.on_key! "data" do
      parser.on_key! "repository" do
        parser.on_key! "milestones" do
          parser.on_key! "nodes" do
            parser.read_begin_array
            Milestone.new(parser)
          ensure
            parser.read_end_array
          end
        end
      end
    end

    if milestone
      milestone.pull_requests.concat m.pull_requests
    else
      milestone = m
    end

    json = JSON.parse(response.body)
    page_info = json.dig("data", "repository", "milestones", "nodes", 0, "pullRequests", "pageInfo")
    break unless page_info["hasNextPage"].as_bool

    cursor = page_info["endCursor"].as_s
  end

  milestone
end

milestone = query_milestone(api_token, repository, milestone)

struct ChangelogEntry
  getter pull_requests : Array(PullRequest)

  def initialize(pr : PullRequest)
    @pull_requests = [pr]
  end

  def pr
    pull_requests[0]
  end

  def to_s(io : IO)
    if sub_topic = pr.sub_topic
      io << "*(" << pr.sub_topic << ")* "
    end
    if pr.labels.includes?("security")
      io << "**[security]** "
    end
    if pr.labels.includes?("breaking-change")
      io << "**[breaking]** "
    end
    if pr.regression?
      io << "**[regression]** "
    end
    if pr.experimental?
      io << "**[experimental]** "
    end
    if pr.deprecated?
      io << "**[deprecation]** "
    end
    io << pr.title.sub(/^\[?(?:#{pr.type}|#{pr.sub_topic})(?::|\]:?) /i, "")

    io << " ("
    pull_requests.join(io, ", ") do |pr|
      pr.link_ref(io)
    end

    authors = collect_authors
    if authors.present?
      io << ", thanks "
      authors.join(io, ", ") do |author|
        io << "@" << author
      end
    end
    io << ")"
  end

  def collect_authors
    authors = [] of String
    pull_requests.each do |pr|
      author = pr.author || next
      authors << author unless authors.includes?(author)
    end
    authors
  end

  def print_ref_labels(io)
    pull_requests.each { |pr| print_ref_label(io, pr) }
  end

  def print_ref_label(io, pr)
    pr.link_ref(io)
    io << ": " << pr.permalink
    io.puts
  end
end

entries = milestone.pull_requests.compact_map do |pr|
  ChangelogEntry.new(pr) unless pr.fixup?
end

milestone.pull_requests.each do |pr|
  parent_number = pr.fixup? || next

  parent_entry = entries.find { |entry| entry.pr.number == parent_number }
  if parent_entry
    parent_entry.pull_requests << pr
  else
    STDERR.puts "Unresolved fixup: ##{parent_number} for: #{pr.title} (##{pr.number})"
  end
end

sections = entries.group_by(&.pr.section)

SECTION_TITLES = {
  "breaking"    => "Breaking changes",
  "feature"     => "Features",
  "fix"         => "Bugfixes",
  "chore"       => "Chores",
  "performance" => "Performance",
  "refactor"    => "Refactor",
  "docs"        => "Documentation",
  "specs"       => "Specs",
  "infra"       => "Infrastructure",
  ""            => "other",
}

TOPIC_ORDER = %w[lang stdlib compiler tools other]

puts "## [#{milestone.title}] (#{milestone.release_date.try(&.to_s("%F")) || "unreleased"})"
if description = milestone.description.presence
  puts
  print "_", description
  puts "_"
end
puts
puts "[#{milestone.title}]: https://github.com/#{repository}/releases/#{milestone.title}"
puts

def print_entries(entries)
  entries.each do |entry|
    puts "- #{entry}"
  end
  puts

  entries.each(&.print_ref_labels(STDOUT))
  puts
end

SECTION_TITLES.each do |id, title|
  entries = sections[id]? || next
  puts "### #{title}"
  puts

  if id == "infra"
    entries.sort_by!(&.pr.infra_sort_tuple)
    print_entries entries
  else
    topics = entries.group_by(&.pr.primary_topic)

    topic_titles = topics.keys.sort_by! { |k| TOPIC_ORDER.index(k) || Int32::MAX }

    topic_titles.each do |topic_title|
      topic_entries = topics[topic_title]? || next

      puts "#### #{topic_title}"
      puts

      topic_entries.sort_by!(&.pr)
      print_entries topic_entries
    end
  end
end
