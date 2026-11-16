require "net/http"

# JSON over HTTP for the vendor clients. A subclass passes its base URL and auth header and adds one method per endpoint.
class VendorClient
  class Error < StandardError
    attr_reader :status

    def initialize(message = nil, status: nil)
      super(message)
      @status = status
    end
  end

  def initialize(base_url:, headers:)
    @base_url = base_url
    @headers = headers
  end

  private

  def get(path)
    request(Net::HTTP::Get, path)
  end

  def post(path, body)
    request(Net::HTTP::Post, path, body)
  end

  def request(method, path, body = nil)
    uri = URI("#{@base_url}#{path}")
    request = method.new(uri, { "Content-Type" => "application/json", "Accept" => "application/json" }.merge(@headers))
    request.body = body.to_json if body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 10) do |http|
      http.request(request)
    end
    raise Error.new(error_message(response), status: response.code.to_i) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SystemCallError, Timeout::Error, SocketError => e
    raise Error, e.message
  end

  def error_message(response)
    error = JSON.parse(response.body)["error"] || {}
    [error["message"] || "HTTP #{response.code}", *error["details"]].join(" ")
  rescue JSON::ParserError
    "HTTP #{response.code}"
  end
end
