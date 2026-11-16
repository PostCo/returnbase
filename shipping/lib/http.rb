require "json"
require "net/http"

module Http
  # Returns [status, parsed body]. A network failure comes back as status 0, and a body that is not JSON as an empty hash.
  def self.post_json(url, body, headers = {})
    uri = URI(url)
    request = Net::HTTP::Post.new(uri, { "Content-Type" => "application/json" }.merge(headers))
    request.body = body.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 10) do |http|
      http.request(request)
    end
    [response.code.to_i, parse(response.body)]
  rescue SystemCallError, Timeout::Error, SocketError => e
    [0, { "error" => { "message" => e.message } }]
  end

  def self.parse(text)
    JSON.parse(text)
  rescue JSON::ParserError
    {}
  end
end
