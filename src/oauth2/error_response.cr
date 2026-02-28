require "json"

struct OAuth2::ErrorResponse
  include JSON::Serializable

  getter error : String
end
