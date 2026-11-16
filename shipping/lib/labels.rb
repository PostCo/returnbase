# How a label request is shown to the outside: the answer to GET /labels/:id and the body of the callback.
module Labels
  def self.present(label)
    label.slice(:id, :reference, :status, :carrier, :tracking_number, :label_url, :error).compact
  end
end
