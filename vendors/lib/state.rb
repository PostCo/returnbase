require "time"

class State
  NAMES = %i[storebox parceldock quickpost].freeze
  LOG_LIMIT = 200

  attr_reader :data, :scenario, :log

  def self.for(name) = REGISTRY.fetch(name)
  def self.reset_all = REGISTRY.each_value(&:reset)

  def initialize
    @mutex = Mutex.new
    reset
  end

  def synchronize(&) = @mutex.synchronize(&)

  def reset
    synchronize do
      @scenario = "normal"
      @data = {}
      @log = []
      @seq = 0
    end
  end

  def scenario=(name)
    synchronize { @scenario = name }
  end

  def next_seq = @seq += 1

  def record(direction:, method:, path:, body:, status:, query: "")
    entry = { at: Time.now.utc.iso8601, direction:, method:, path:, query:, body: body.to_s[0, 2000], status: }
    synchronize do
      @log << entry
      @log.shift while @log.size > LOG_LIMIT
    end
  end

  REGISTRY = NAMES.to_h { |name| [name, new] }.freeze
end
