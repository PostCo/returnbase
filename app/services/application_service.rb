# frozen_string_literal: true

class ApplicationService
  # Raise this for any problem the caller should see. .call turns it into a failed result and
  # .call! lets it propagate, so a service nested in a transaction rolls the whole thing back.
  class Failure < StandardError; end

  Result = Struct.new(:success?, :payload, :errors, :failed?)

  # Entry point for every service: Foo.call(args) builds the service and runs #call.
  def self.call(*args, **kwargs, &block)
    call!(*args, **kwargs, &block)
  rescue Failure, ActiveRecord::RecordInvalid => e
    errors = ActiveModel::Errors.new(self)
    errors.add(:base, e.message)
    Result.new(false, nil, errors, true)
  end

  def self.call!(*args, **kwargs, &block)
    new(*args, **kwargs, &block).call
  end

  # Services end #call with this, so callers always get success?, payload, errors and failed?.
  def result(success:, payload: nil, errors: ActiveModel::Errors.new(self))
    Result.new(success, payload, errors, !success)
  end
end
