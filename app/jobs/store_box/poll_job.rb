# Runs every minute (config/recurring.yml). StoreBox sends no webhooks, so this is how Returnbase hears about returns.
# Only active integrations are polled: a deactivated one leaves its returns for the merchant to finish by hand.
class StoreBox::PollJob < ApplicationJob
  def perform
    StoreBoxIntegration.active.find_each do |integration|
      integration.returns.open.find_each do |store_box_return|
        outcome = StoreBox::PollService.call(store_box_return: store_box_return)
        Rails.logger.warn(outcome.errors.full_messages.to_sentence) if outcome.failed?
      end
    end
  end
end
