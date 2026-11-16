module Api
  module Shopper
    class ReturnsController < BaseController
      def create
        order = find_order
        shipping_method = shop.shipping_methods.find_by!(kind: params[:shipping_kind].to_s)
        items = params.permit(items: %i[sku quantity reason resolution exchange_sku])[:items]
        outcome = ReturnOrders::SubmitService.call(order: order, shipping_method: shipping_method, items: items)
        if outcome.success?
          render json: { number: outcome.payload.number, status: outcome.payload.status }, status: :created
        else
          render json: { errors: outcome.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        render json: status_json(find_return)
      end

      def cancel
        return_order = find_return
        outcome = ReturnOrders::CancelService.call(return_order: return_order, cancelled_by: :shopper)
        if outcome.success?
          render json: status_json(return_order.reload)
        else
          render json: { errors: outcome.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def find_return
        shop.return_orders.joins(:customer).find_by!(number: params[:number], customers: { email: customer_email })
      end

      def status_json(ro)
        shipment = ro.shipment
        {
          number: ro.number, status: ro.status, order_number: ro.order.number, can_cancel: ro.can_cancel?,
          shipping: {
            kind: ro.shipping_method.kind, label_url: shipment&.label_url, tracking_number: shipment&.tracking_number,
            label_pending: shipment.present? && (shipment.pending? || shipment.label_failed?),
            instructions: (ro.posting_instructions if ro.own_postage? && ro.approved?),
          },
          items: ro.items.includes(:variant, :exchange_variant).map do |item|
            { name: item.variant.display_name, quantity: item.quantity, resolution: item.resolution, exchange_for: item.exchange_variant&.display_name, outcome: item.outcome }
          end,
          refunds: ro.refunds.map { |refund| { amount: refund.amount.format } },
          exchanges: ro.exchanges.includes(:variant).map { |exchange| { name: exchange.variant.display_name, status: exchange.status } },
          timeline: ro.timeline_events.where(kind: :status_changed).map { |event| { status: event.data["to"], at: event.created_at } },
        }
      end
    end
  end
end
