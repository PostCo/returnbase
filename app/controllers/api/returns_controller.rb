require "csv"

module Api
  class ReturnsController < BaseController
    PER_PAGE = 20

    def index
      scope = filtered_returns
      page = [params[:page].to_i, 1].max
      returns = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE)

      render json: {
        returns: returns.map { |return_order| ReturnOrderSummarySerializer.new(return_order).as_json },
        total: scope.count,
        page: page,
      }
    end

    def show
      render json: ReturnOrderDetailSerializer.new(find_return).as_json
    end

    def export
      send_data export_csv(filtered_returns), type: "text/csv", filename: "returns.csv"
    end

    def approve = act(ReturnOrders::ApproveService)
    def reject = act(ReturnOrders::RejectService)
    def receive = act(ReturnOrders::ReceiveService)
    def resolve = act(ReturnOrders::ResolveService, decisions: decisions)
    def cancel = act(ReturnOrders::CancelService, cancelled_by: :merchant)
    def send_to_store_box = act(StoreBox::SendService)
    def request_label = act(Shipments::RetryLabelService)
    def move = act(ReturnOrders::MoveService, location: current_shop.locations.find(params[:location_id]))

    def items
      act(ReturnOrders::UpdateItemsService, items: params.permit(items: %i[sku quantity reason resolution exchange_sku])[:items])
    end

    private

    def decisions
      params.permit(items: %i[id outcome restock])[:items]&.map { |item| { item_id: item[:id], outcome: item[:outcome], restock: item[:restock] } }
    end

    def find_return
      current_shop.return_orders.find(params[:id])
    end

    def act(service, **options)
      return_order = find_return
      outcome = service.call(return_order: return_order, **options)
      if outcome.success?
        render json: ReturnOrderDetailSerializer.new(return_order.reload).as_json
      else
        render json: { errors: outcome.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def filtered_returns
      current_shop.return_orders
        .includes(:customer, :order, :shipping_method, :store_box_return, :store_box_send_attempts)
        .filter_by(params.permit(:status, :shipping, :store_box, :q))
        .order(created_at: :desc, id: :desc)
    end

    def export_csv(returns)
      CSV.generate do |csv|
        csv << ["Order", "Return", "Status", "Customer", "Email", "Shipping type", "StoreBox status", "Created", "Items"]
        returns.includes(:items).each do |r|
          csv << [r.order.number, r.number, r.status, r.customer.name, r.customer.email, r.shipping_method.kind, r.store_box_status, r.created_at.iso8601, outcomes(r)]
        end
      end
    end

    def outcomes(return_order)
      counts = return_order.items.map(&:outcome).tally
      ReturnItem.outcomes.keys.filter_map { |outcome| "#{counts[outcome]} #{outcome}" if counts[outcome] }.join(", ")
    end
  end
end
