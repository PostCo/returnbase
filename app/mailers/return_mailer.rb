class ReturnMailer < ApplicationMailer
  def submitted(return_order)
    prepare(return_order, "We received your return #{return_order.number}")
  end

  def approved(return_order)
    prepare(return_order, "Your return #{return_order.number} is approved")
  end

  def label_ready(return_order)
    prepare(return_order, "Your prepaid label for return #{return_order.number}")
  end

  def refunded(return_order)
    prepare(return_order, "Your refund for return #{return_order.number}")
  end

  def exchanged(return_order)
    prepare(return_order, "Your exchange for return #{return_order.number} is on its way")
  end

  def rejected(return_order)
    prepare(return_order, "Your return #{return_order.number} was not accepted")
  end

  def moved(return_order)
    prepare(return_order, "Where to post your return #{return_order.number} has changed")
  end

  def cancelled(return_order)
    prepare(return_order, "Your return #{return_order.number} is cancelled")
  end

  private

  def prepare(return_order, subject)
    @return_order = return_order
    @shipment = return_order.shipment
    @status_url = status_url(return_order)
    mail(to: return_order.customer.email, subject: subject)
  end

  def status_url(return_order)
    base = ENV.fetch("SHOPPER_URL", "http://localhost:5180")
    query = { shop: return_order.shop_id, number: return_order.number, email: return_order.customer.email }.to_query
    "#{base}/shopper/status?#{query}"
  end
end
