module Api
  class ShopsController < BaseController
    def show
      render json: shop_json
    end

    def update
      current_shop.update!(params.permit(:refund_on_carrier_pickup, :restock_on_resolve))
      render json: shop_json
    end

    private

    def shop_json
      current_shop.slice(:id, :name, :currency, :refund_on_carrier_pickup, :restock_on_resolve)
    end
  end
end
