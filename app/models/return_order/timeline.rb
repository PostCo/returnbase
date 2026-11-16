module ReturnOrder::Timeline
  extend ActiveSupport::Concern

  included do
    has_many :timeline_events, -> { order(:created_at, :id) }, dependent: :destroy

    after_create { record_event(:submitted) }
    after_update(if: :saved_change_to_status?) do
      record_event(:status_changed, from: status_before_last_save, to: status)
    end
  end

  def record_event(kind, **data)
    timeline_events.create!(kind: kind, data: data)
  end
end
