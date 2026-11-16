# Switches StoreBox off. New returns stop going to StoreBox and polling stops. Returns already sent keep their
# StoreBox::Return, so the merchant still sees them and finishes them by hand.
class StoreBoxIntegration::DeactivateForm
  include ActiveModel::Validations

  def initialize(integration)
    @integration = integration
  end

  def submit
    @integration.disabled!
    true
  end
end
