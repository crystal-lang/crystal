require "./common"
require "uri"

class HTTP::Request
  getter method
  getter headers
  getter body
  getter version
  property! peer_addr

  def initialize(@method : String, @resource, @headers = Headers.new : Headers, @body = nil, @version = "HTTP/1.1")
    if body = @body
      @headers["Content-Length"] = body.bytesize.to_s
    elsif @method == "POST" || @method == "PUT"
      @headers["Content-Length"] = "0"
    end
  end

  # Returns a convenience wrapper around querying and setting cookie related
  # headers, see `HTTP::Cookies`.
  def cookies
    @cookies ||= Cookies.from_headers(headers)
  end

  def resource
    @uri.try(&.full_path) || @resource
  end

  def keep_alive?
    HTTP.keep_alive?(self)
  end

  def ignore_body?
    @method == "HEAD"
  end

  def remote_ip(trust_headers=true)
    if trust_headers
      client_ips = ips_from("Client-Ip").reverse
      forwarded_ips = ips_from("X-Forwarded-For").reverse

      ips = [forwarded_ips, client_ips, peer_addr.ip_address].flatten.compact

      first_remote_ip_address(ips) || peer_addr.ip_address
    else
      peer_addr.ip_address
    end
  end

  def to_io(io)
    io << @method << " " << resource << " " << @version << "\r\n"
    cookies = @cookies
    headers = cookies ? cookies.add_request_headers(@headers) : @headers
    HTTP.serialize_headers_and_body(io, headers, @body, @version)
  end

  def self.from_io(io)
    request_line = io.gets
    return unless request_line

    method, resource, http_version = request_line.split
    HTTP.parse_headers_and_body(io) do |headers, body|
      return new method, resource, headers, body.try &.gets_to_end, http_version
    end

    # Unexpected end of http request
    nil
  end

  # Lazily parses request's path component.
  delegate "path", uri

  # Sets request's path component.
  delegate "path=", uri

  # Lazily parses request's query component.
  delegate "query", uri

  # Sets request's query component.
  delegate "query=", uri

  private def uri
    (@uri ||= URI.parse(@resource)).not_nil!
  end

  private def ips_from(header)
    if ips = headers[header]? || headers["Http-#{header}"]?
      ips.strip.split(/[,\s]+/)
    else
      [] of String
    end
  end

  private def first_remote_ip_address(ip_addresses)
    ip_addresses.find { |ip| !trusted_proxy?(ip) }
  end

  private def trusted_proxy?(ip)
    ip =~ /\A127\.0\.0\.1\Z|\A(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\.|\A::1\Z|\Afd[0-9a-f]{2}:.+|\Alocalhost\Z|\Aunix\Z|\Aunix:/i
  end

end
