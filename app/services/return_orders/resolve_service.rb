# Decides each item (accepted or rejected, and for an accepted item whether it goes back in stock), then settles the return.
# Without decisions every item is accepted with its default restock choice. A return with no accepted item ends rejected.
class ReturnOrders::ResolveService < ApplicationService
  OUTCOMES = ReturnItem.outcomes.keys.freeze

  def initialize(return_order:, decisions: nil)
    @return_order = return_order
    @decisions = decisions
  end

  def call
    raise Failure, "Only received returns can be resolved" unless return_order.can_resolve?

    items = return_order.items.includes(:variant, :order_line_item).to_a
    chosen = choices(items)
    ReturnOrder.transaction do
      items.each { |item| item.update!(chosen.fetch(item.id)) }
      return_order.record_event(:items_decided, accepted: lines(items.select(&:accepted?), restock: true), rejected: lines(items.select(&:rejected?)))
      items.any?(&:accepted?) ? settle : release
    end
    ReturnMailer.rejected(return_order).deliver_now if return_order.rejected?
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order, :decisions

  def settle
    return_order.resolve!
    ReturnOrders::RefundService.call!(return_order: return_order)
    ReturnOrders::RestockService.call!(return_order: return_order)
    ReturnOrders::FulfilExchangesService.call!(return_order: return_order)
  end

  def release
    return_order.reject!
    return_order.exchanges.destroy_all
  end

  def choices(items)
    return items.to_h { |item| [item.id, { outcome: :accepted, restock: item.restock_default }] } if decisions.blank?

    by_id = decisions.map { |decision| decision.to_h.with_indifferent_access }.group_by { |decision| decision[:item_id].to_i }
    unless by_id.keys.sort == items.map(&:id).sort && by_id.values.all? { |group| group.one? }
      raise Failure, "Decide each item of the return exactly once"
    end

    items.to_h { |item| [item.id, choice(item, by_id.fetch(item.id).first)] }
  end

  def choice(item, decision)
    raise Failure, "Choose accepted or rejected for #{item.variant.sku}" unless OUTCOMES.include?(decision[:outcome].to_s)
    return { outcome: :rejected, restock: false } if decision[:outcome].to_s == "rejected"

    restock = ActiveModel::Type::Boolean.new.cast(decision[:restock])
    { outcome: :accepted, restock: restock.nil? ? item.restock_default : restock }
  end

  def lines(items, restock: false)
    items.map do |item|
      line = { sku: item.variant.sku, quantity: item.quantity }
      restock ? line.merge(restock: item.restock) : line
    end
  end
end
