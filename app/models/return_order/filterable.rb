module ReturnOrder::Filterable
  extend ActiveSupport::Concern

  class_methods do
    def filter_by(filters)
      scope = all
      scope = scope.where(status: filters[:status]) if filters[:status].present?
      scope = scope.joins(:shipping_method).where(shipping_methods: { kind: filters[:shipping] }) if filters[:shipping].present?
      scope = scope.store_box_send_failed if filters[:store_box] == "send_failed"
      scope = scope.search(filters[:q]) if filters[:q].present?
      scope
    end

    def search(term)
      like = "%#{sanitize_sql_like(term.strip)}%"
      joins(:order, :customer).where("return_orders.number ILIKE :q OR orders.number ILIKE :q OR customers.email ILIKE :q", q: like)
    end
  end
end
