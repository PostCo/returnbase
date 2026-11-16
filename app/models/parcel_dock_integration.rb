# ParcelDock, an older label provider with one facility. Support sets it up at /admin/parcel_dock; merchants have no
# settings page for it. When enabled, label returns get their label from ParcelDock (Shipments::CreateRemoteOrderService).
class ParcelDockIntegration < Integration
  enum :status, { enabled: 10, disabled: 30 }

  def facility
    shop.locations.parcel_dock_facility.first
  end
end
