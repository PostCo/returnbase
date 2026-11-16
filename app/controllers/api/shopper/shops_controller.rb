module Api
  module Shopper
    class ShopsController < BaseController
      def index
        render json: { shops: Shop.order(:id).map { |shop| { id: shop.id, name: shop.name } } }
      end
    end
  end
end
