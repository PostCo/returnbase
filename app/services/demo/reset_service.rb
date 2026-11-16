require "net/http"

module Demo
  # Puts the whole demo back to its fresh state: the database, the three fake vendors, the label service and Mailpit.
  class ResetService < ApplicationService
    KEPT_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    OUTSIDE = [
      ["Fake vendors", Net::HTTP::Post, -> { "#{ENV.fetch("VENDORS_URL", "http://vendors:4100")}/reset" }],
      ["Label service", Net::HTTP::Post, -> { "#{ENV.fetch("SHIPPING_URL", "http://shipping:4300")}/admin/reset" }],
      ["Mailpit", Net::HTTP::Delete, -> { "#{ENV.fetch("MAILPIT_URL", "http://mailpit:8125")}/api/v1/messages" }],
    ].freeze

    def self.request(method, url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 10) do |http|
        http.request(method.new(uri))
      end
      raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
    rescue SystemCallError, Timeout::Error, SocketError => e
      raise e.message
    end

    # No RESTART IDENTITY: new ids never match a job still queued for an old record, so a stale job fails to load its record.
    def call
      connection = ActiveRecord::Base.connection
      tables = connection.tables.reject { |table| KEPT_TABLES.include?(table) || table.start_with?("solid_queue_") }
      connection.execute("TRUNCATE TABLE #{tables.map { |table| connection.quote_table_name(table) }.join(", ")} CASCADE")
      # The seeds define constants, so a second load in one process would warn about each of them.
      silence_warnings { Rails.application.load_seed }

      result(success: true, payload: { shops: Shop.count, returns: ReturnOrder.count, outside: clear_outside_services })
    end

    private

    def clear_outside_services
      OUTSIDE.map do |name, method, url|
        self.class.request(method, url.call)
        [name, nil]
      rescue StandardError => e
        [name, e.message]
      end
    end
  end
end
