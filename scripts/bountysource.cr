require "http/client"
require "json"

module BountySource
  class API
    def initialize(@team : String, @token : String)
      @client = HTTP::Client.new("api.bountysource.com", ssl: true)
    end

    def support_levels
      headers = HTTP::Headers{
        "Accept":        "application/vnd.bountysource+json; version=2",
        "Authorization": "token #{@token}",
        "User-Agent":    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
        "Referer":       "https://salt.bountysource.com/teams/crystal-lang/admin/supporters",
        "Origin":        "https://salt.bountysource.com",
      }
      response = @client.get("/support_levels?supporters_for_team=#{@team}", headers: headers).body
      Array(SupportLevel).from_json(response)
    end

    def supporters
      headers = HTTP::Headers{
        "Accept":        "application/vnd.bountysource+json; version=2",
        "Authorization": "token #{@token}",
        "User-Agent":    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
        "Referer":       "https://salt.bountysource.com/teams/crystal-lang/admin/supporters",
        "Origin":        "https://salt.bountysource.com",
      }
      response = @client.get("/supporters?order=monthly&per_page=200&team_slug=#{@team}", headers: headers).body
      Array(Supporters).from_json(response)
    end

    def user(slug)
      headers = HTTP::Headers{
        "Accept":     "application/vnd.bountysource+json; version=1",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
      }
      response = @client.get("/users/#{slug}?access_token=#{@token}", headers: headers).body
      User.from_json(response)
    end
  end

  class Supporters
    JSON.mapping({
      type:            {type: String, nilable: true},
      id:              {type: Int64, nilable: true},
      slug:            {type: String, nilable: true},
      display_name:    String,
      image_url_large: String,
      monthly_amount:  Float64,
      alltime_amount:  Float64,
      created_at:      String,
    })
  end

  class SupportLevel
    JSON.mapping({
      id:         Int64,
      amount:     Float64,
      status:     String,
      created_at: {type: Time, converter: Time::Format.new("%FT%T.%LZ")},
      owner:      Owner,
      reward:     {type: Reward, nilable: true},
    })

    class Owner
      JSON.mapping({
        display_name: String,
        slug:         {type: String, nilable: true},
      })
    end

    class Reward
      JSON.mapping({
        id:          Int64,
        title:       String,
        description: String,
        amount:      Float64,
      })
    end
  end

  class User
    JSON.mapping({
      id:              Int64,
      slug:            String,
      display_name:    String,
      url:             {type: String, nilable: true},
      github_account:  {type: Account, nilable: true},
      twitter_account: {type: Account, nilable: true},
    })

    class Account
      JSON.mapping({
        display_name: String,
      })
    end
  end
end

module GitHub
  class API
    def initialize
      @client = HTTP::Client.new("api.github.com", ssl: true)
    end

    def user(username)
      response = @client.get("/users/#{username}").body
      User.from_json(response)
    end

    class User
      JSON.mapping({
        name: {type: String, nilable: true},
        blog: {type: String, nilable: true},
      })
    end
  end
end

record Sponsor, name, url, logo, this_month, all_time, since

token = ARGV[0]?
unless token
  puts <<-USAGE
  Usage: bountysource <token>

  To find out your <token> check the Network traffic in a browser when hitting
  BountySource and look for an Authorization header or access_token parameter
  in JSON requests.
  USAGE
  exit
end

team = "crystal-lang"
bountysource = BountySource::API.new(team, token)

github = GitHub::API.new

supporters = bountysource.supporters

support_levels = bountysource.support_levels
support_levels.select! { |s| s.status == "active" && s.owner.display_name != "Anonymous" }
support_levels.sort_by! &.amount

sponsors = [] of Sponsor

support_levels.each do |support_level|
  name = support_level.owner.display_name
  url = nil
  if slug = support_level.owner.slug
    user = bountysource.user(slug)
    url = user.url
    unless url
      if (github_account = user.github_account)
        github_user = github.user(github_account.display_name)
        name = github_user.name || name
        url = github_user.blog || "https://github.com/#{github_account.display_name}"
      elsif (twitter_account = user.twitter_account)
        url = "http://twitter.com/#{twitter_account.display_name}"
      end
    end
  end

  if url && !(url.starts_with?("http://") || url.starts_with?("https://"))
    url = "http://#{url}"
  end

  amount = support_level.amount

  show_url = url && amount >= 5

  url = show_url ? url.not_nil! : ""

  supporter = supporters.find { |s| s.display_name == support_level.owner.display_name }
  if supporter
    show_logo = amount >= 75
    logo = ""
    if show_logo
      HTTP::Client.get(supporter.image_url_large) do |logo_request|
        ext = case logo_request.content_type
              when "image/jpeg"
                "jpg"
              when "image/png"
                "png"
              else
                raise "not implemented image type #{logo_request.content_type}"
              end
        logo = "/images/sponsors/#{name.downcase.gsub(/\W/, "_")}.#{ext}"
        local_file = logo[1..-1]
        unless File.exists?(local_file)
          File.open(local_file, "w") do |f|
            IO.copy logo_request.body_io, f
          end
        end
      end
    end

    all_time = supporter.alltime_amount
    since = Time.parse(supporter.created_at[0..10], "%F")
  else
    raise "unable to match: #{support_level.owner.display_name} in supporters"
  end
  sponsors << Sponsor.new(name, url, logo, amount, all_time, since)
end

sponsors.sort_by! { |s| {-s.this_month, -s.all_time, s.name.downcase} }.uniq!

puts "- sponsors = [nil,"
sponsors.each do |sponsor|
  # pp sponsor
  data = {} of String => String | Int32
  data["logo"] = sponsor.logo unless sponsor.logo.empty?
  data["name"] = sponsor.name
  data["url"] = sponsor.url unless sponsor.url.empty?
  data["this_month"] = sponsor.this_month.to_i
  data["all_time"] = sponsor.all_time.to_i
  data["since"] = sponsor.since.to_s("%b %-d, %Y")
  puts %(              #{data.to_json},)
end
puts "             ].compact"
