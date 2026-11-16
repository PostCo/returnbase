module Api
  module Shopper
    class OrdersController < BaseController
      def lookup
        order = find_order
        location = shop.return_location
        render json: {
          order: { number: order.number, customer: order.customer.name },
          items: order.line_items.includes(variant: :product).map { |line| line_json(line, location) },
          shipping_methods: shop.shipping_methods.map { |method| { kind: method.kind, name: method.name } },
          reasons: ReturnItem.reasons.keys,
        }
      end

      private

      def line_json(line, location)
        variant = line.variant
        siblings = variant.product.variants.where.not(id: variant.id)
        in_stock = siblings.joins(:inventory_levels).where(inventory_levels: { location_id: location.id }).where("inventory_levels.available > 0")
        {
          sku: variant.sku, name: variant.display_name, quantity: line.quantity,
          price: line.price.to_f, currency: line.currency,
          exchange_options: in_stock.map { |option| { sku: option.sku, title: option.title } },
        }
      end
    end
  end
end
