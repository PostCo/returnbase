# The return detail JSON shared by the merchant dashboard and the action endpoints.
class ReturnOrderDetailSerializer
  def initialize(return_order)
    @return_order = return_order
  end

  def as_json(*)
    ro = @return_order
    {
      id: ro.id, number: ro.number, status: ro.status, created_at: ro.created_at,
      customer: { name: ro.customer.name, email: ro.customer.email },
      order: { number: ro.order.number },
      location: { id: ro.location_id, name: ro.location.name, address: ro.location.address },
      shipping_method: { kind: ro.shipping_method.kind, name: ro.shipping_method.name },
      shipment: shipment_json(ro.shipment),
      items: ro.items.includes(:variant, :exchange_variant).map { |item| item_json(item) },
      available_items: available_items(ro),
      refunds: ro.refunds.map { |refund| { amount: refund.amount.to_f, currency: refund.currency } },
      exchanges: ro.exchanges.includes(:variant).map { |exchange| { sku: exchange.variant.sku, status: exchange.status } },
      timeline: ro.timeline_events.map { |event| { kind: event.kind, data: event.data, created_at: event.created_at } },
      allowed_actions: allowed_actions(ro),
      store_box: store_box_json(ro),
    }
  end

  private

  # Shown on the return once Returnbase has tried to send it to StoreBox, whether or not that worked.
  def store_box_json(ro)
    sent = ro.store_box_return
    attempts = ro.store_box_send_attempts.order(:created_at)
    return if sent.nil? && attempts.empty?

    integration = ro.shop.store_box_integration
    {
      status: ro.store_box_status, remote_id: sent&.remote_id, warehouse_id: sent&.warehouse_id, sent_at: sent&.created_at,
      results: sent&.results || [], action: sent&.action, integration_status: integration&.status,
      failed_attempts: attempts.map { |attempt| { error: attempt.error, created_at: attempt.created_at } },
      can_retry: sent.nil? && integration.present? && integration.active?,
    }
  end

  def shipment_json(shipment)
    return unless shipment

    { status: shipment.status, label_url: shipment.label_url, tracking_number: shipment.tracking_number, error: shipment.error }
  end

  def item_json(item)
    {
      id: item.id, sku: item.variant.sku, name: item.variant.display_name, quantity: item.quantity,
      reason: item.reason, resolution: item.resolution, exchange_sku: item.exchange_variant&.sku, condition: item.condition,
      outcome: item.outcome, restock: item.restock, restock_default: item.restock_default,
    }
  end

  def available_items(ro)
    returned = ro.items.map(&:variant_id)
    ro.order.line_items.includes(:variant).where.not(variant_id: returned).map do |line|
      { sku: line.variant.sku, name: line.variant.display_name, quantity: line.quantity }
    end
  end

  def allowed_actions(ro)
    actions = []
    actions << "approve" if ro.can_approve?
    actions << "reject" if ro.can_reject?
    actions << "receive" if ro.can_receive?
    actions << "resolve" if ro.can_resolve?
    actions << "edit_items" if ro.editable?
    actions << "cancel" if ro.can_cancel?
    actions << "move" if ro.movable?
    actions
  end
end
