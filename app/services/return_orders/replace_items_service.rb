# Replaces a return's items from SKUs, as the shopper form and the merchant edit both send them.
class ReturnOrders::ReplaceItemsService < ApplicationService
  def initialize(return_order:, items:)
    @return_order = return_order
    @items = Array(items)
  end

  def call
    raise Failure, "Choose at least one item to return" if items.empty?

    return_order.items.destroy_all
    items.each { |attributes| build_item(attributes.to_h.with_indifferent_access) }
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order, :items

  def build_item(attributes)
    line = return_order.order.line_items.joins(:variant).find_by(variants: { sku: attributes[:sku] })
    raise Failure, "#{attributes[:sku]} is not on order #{return_order.order.number}" unless line

    quantity = attributes[:quantity].to_i
    raise Failure, "Return between 1 and #{line.quantity} of #{attributes[:sku]}" unless quantity.between?(1, line.quantity)
    raise Failure, "Choose a reason for #{attributes[:sku]}" unless ReturnItem.reasons.key?(attributes[:reason])
    raise Failure, "Choose refund or exchange for #{attributes[:sku]}" unless ReturnItem.resolutions.key?(attributes[:resolution])

    return_order.items.create!(
      order_line_item: line, variant: line.variant, quantity: quantity,
      reason: attributes[:reason], resolution: attributes[:resolution],
      exchange_variant: exchange_variant(line, attributes),
    )
  end

  def exchange_variant(line, attributes)
    return unless attributes[:resolution] == "exchange"

    line.variant.product.variants.where.not(id: line.variant_id).find_by(sku: attributes[:exchange_sku]) ||
      raise(Failure, "Choose what to exchange #{attributes[:sku]} for")
  end
end
