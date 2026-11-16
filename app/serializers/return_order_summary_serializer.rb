class ReturnOrderSummarySerializer
  def initialize(return_order)
    @return_order = return_order
  end

  def as_json(*)
    r = @return_order
    {
      id: r.id,
      number: r.number,
      status: r.status,
      created_at: r.created_at,
      customer: { name: r.customer.name, email: r.customer.email },
      order: { number: r.order.number },
      shipping_method: { kind: r.shipping_method.kind, name: r.shipping_method.name },
    }
  end
end
