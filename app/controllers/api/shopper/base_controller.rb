module Api
  module Shopper
    # Shoppers have no login. The order number and the email on the order are the credentials.
    class BaseController < ApplicationController
      rescue_from(ActiveRecord::RecordNotFound) do
        render json: { errors: ["We could not find that. Check the order number and email."] }, status: :not_found
      end

      private

      def shop
        @shop ||= Shop.find(params[:shop_id])
      end

      def customer_email
        params[:email].to_s.strip.downcase
      end

      def find_order
        number = params[:order_number].to_s.strip
        number = "#" + number unless number.start_with?("#")
        shop.orders.joins(:customer).find_by!(number: number, customers: { email: customer_email })
      end
    end
  end
end
