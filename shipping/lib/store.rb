require "time"

# In-memory state of the label service: label requests, the scenario switch and the request log. A restart or a reset starts clean.
class Store
  LOG_LIMIT = 200
  SCENARIOS = %w[normal carrier_failure].freeze

  attr_reader :scenario

  def initialize
    @mutex = Mutex.new
    reset
  end

  def reset
    @mutex.synchronize do
      @scenario = "normal"
      @labels = {}
      @log = []
      @seq = 0
    end
  end

  def scenario=(name)
    @mutex.synchronize { @scenario = name }
  end

  def create(attributes)
    @mutex.synchronize do
      id = "lbl_#{@seq += 1}"
      @labels[id] = attributes.merge(id:, status: "pending", created_at: Time.now.utc.iso8601)
    end
  end

  def find(id) = @mutex.synchronize { @labels[id]&.dup }
  def labels = @mutex.synchronize { @labels.values.map(&:dup) }
  def log = @mutex.synchronize { @log.dup }

  def update(id, attributes)
    @mutex.synchronize { @labels[id].merge!(attributes) }
  end

  def record(direction:, method:, url:, body:, status:)
    entry = { at: Time.now.utc.iso8601, direction:, method:, url:, body: body.to_s[0, 2000], status: }
    @mutex.synchronize do
      @log << entry
      @log.shift while @log.size > LOG_LIMIT
    end
  end
end
