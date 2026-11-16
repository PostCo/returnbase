class StoreBox::SendJob < ApplicationJob
  def perform(return_order)
    StoreBox::SendService.call(return_order: return_order)
  end
end
