require "test_helper"

class StoreBoxTest < ActiveSupport::TestCase
  include ReturnFixtures
  include ActiveJob::TestHelper

  class FakeStoreBox
    attr_accessor :failure
    attr_reader :created, :remote

    def initialize
      @created = []
      @remote = {}
    end

    def account
      raise VendorClient::Error.new("The API key is missing or invalid.", status: 401) if failure == :unauthorized

      { "account" => { "id" => "acct_demo" } }
    end

    def warehouses
      [{ "id" => "wh_rtm" }, { "id" => "wh_lds" }]
    end

    def create_return(reference:, warehouse_id:, items:)
      raise VendorClient::Error.new("StoreBox is temporarily unavailable.", status: 503) if failure == :unavailable

      created << { reference: reference, warehouse_id: warehouse_id, items: items }
      { "id" => "sbr_#{created.size}", "status" => "pending" }
    end

    def find_return(id)
      remote.fetch(id)
    end
  end

  setup { @store_box = FakeStoreBox.new }

  test "connecting checks the key, saving mappings never activates, and a replaced key keeps StoreBox active" do
    build_return(kind: :own_postage)
    with_store_box do
      @store_box.failure = :unauthorized
      form = StoreBoxIntegration::CreateForm.new(@shop, { api_key: "wrong" })
      assert_not form.submit
      assert_equal ["StoreBox did not accept this API key"], form.errors.full_messages

      @store_box.failure = nil
      assert StoreBoxIntegration::CreateForm.new(@shop, { api_key: "sb_test_key" }).submit
      integration = @shop.reload.store_box_integration
      assert_not StoreBoxIntegration::ActivateForm.new(integration).submit

      mappings = {
        location_mappings: [{ location_id: @location.id, warehouse_id: "wh_rtm" }],
        result_mappings: StoreBox::ResultMapping::RESULTS.map { |result| { result: result, action: "manual_review" } },
      }
      assert StoreBoxIntegration::UpdateForm.new(integration, mappings).submit
      assert integration.reload.connected?
      assert StoreBoxIntegration::ReadinessService.new(integration).call.ready?

      assert StoreBoxIntegration::ActivateForm.new(integration).submit
      assert StoreBoxIntegration::UpdateCredentialsForm.new(integration, { api_key: "sb_new_key" }).submit
      assert integration.reload.active?
      assert_equal "sb_new_key", integration.api_key
    end
  end

  test "an approved own-postage return is sent, received when StoreBox has it and resolved when graded restock" do
    build_return(kind: :own_postage)
    active_store_box
    with_store_box do
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      sent = @return_order.reload.store_box_return
      assert_equal [{ reference: "R1001", warehouse_id: "wh_rtm", items: [{ sku: "TEE-S", quantity: 1, reason: "too_small" }] }], @store_box.created

      @store_box.remote[sent.remote_id] = { "status" => "received", "items" => [] }
      StoreBox::PollJob.perform_now
      assert @return_order.reload.received?

      @store_box.remote[sent.remote_id] = { "status" => "inspected", "items" => [{ "sku" => "TEE-S", "quantity" => 1, "result" => "restock" }] }
      StoreBox::PollJob.perform_now
      assert @return_order.reload.resolved?
      assert_equal [2000], @return_order.refunds.map(&:amount_cents)
    end
  end

  test "a damaged item leaves the return received for manual review" do
    build_return(kind: :own_postage)
    active_store_box
    with_store_box do
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      @store_box.remote["sbr_1"] = { "status" => "inspected", "items" => [{ "sku" => "TEE-S", "quantity" => 1, "result" => "damaged" }] }
      StoreBox::PollJob.perform_now

      assert @return_order.reload.received?
      assert_equal "manual_review", @return_order.store_box_return.action
      assert_empty @return_order.refunds
    end
  end

  test "StoreBox grades set each item's condition from the result mapping, and resolving restocks only the restockable" do
    build_return(kind: :own_postage, restock: true)
    active_store_box
    with_store_box do
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      @store_box.remote["sbr_1"] = { "status" => "inspected", "items" => [{ "sku" => "TEE-S", "quantity" => 1, "result" => "damaged" }] }
      StoreBox::PollJob.perform_now
      assert_equal ["not_restockable"], @return_order.reload.items.map(&:condition)

      assert ReturnOrders::ResolveService.call(return_order: @return_order).success?
      assert_empty @small.inventory_levels
      assert_equal [{ "sku" => "TEE-S", "quantity" => 1 }], @return_order.timeline_events.restocked.sole.data["skipped"]
    end
  end

  test "an item graded restock is restockable and goes back into stock on the automatic resolve" do
    build_return(kind: :own_postage, restock: true)
    active_store_box
    with_store_box do
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      @store_box.remote["sbr_1"] = { "status" => "inspected", "items" => [{ "sku" => "TEE-S", "quantity" => 1, "result" => "restock" }] }
      StoreBox::PollJob.perform_now

      assert_equal ["restockable"], @return_order.reload.items.map(&:condition)
      assert_equal 1, @small.inventory_levels.find_by!(location: @location).available
    end
  end

  test "saving result mappings keeps the restock flag, and a missing flag takes the result's default" do
    build_return(kind: :own_postage)
    integration = active_store_box
    mappings = [
      { result: "restock", action: "resolve", restock: false },
      { result: "damaged", action: "manual_review" },
    ]
    with_store_box { assert StoreBoxIntegration::UpdateForm.new(integration, { result_mappings: mappings }).submit }

    assert_equal({ "restock" => false, "damaged" => false, "wrong_item" => false }, integration.result_mappings.reload.to_h { |m| [m.result, m.restock] })
    serialized = StoreBoxIntegrationSerializer.new(integration.reload).as_json[:result_mappings]
    assert_equal false, serialized.find { |m| m[:result] == "restock" }[:restock]
  end

  test "a failed send stays on the return until a retry sends it" do
    build_return(kind: :own_postage)
    active_store_box
    with_store_box do
      @store_box.failure = :unavailable
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      assert @return_order.reload.approved?
      assert_equal "send_failed", @return_order.store_box_status
      assert_equal [@return_order], ReturnOrder.store_box_send_failed.to_a

      @store_box.failure = nil
      assert StoreBox::SendService.call(return_order: @return_order).success?
      assert_equal "pending", @return_order.reload.store_box_status
      assert_empty ReturnOrder.store_box_send_failed
    end
  end

  test "a label return is sent once it has its label, and pickup does not refund it before inspection" do
    build_return(kind: :label, refund_on_pickup: true)
    active_store_box
    with_store_box do
      perform_enqueued_jobs { approve_with_label }
      assert @return_order.reload.store_box_return

      Shipments::PickedUpService.call(tracking_number: @return_order.shipment.tracking_number)
      assert @return_order.reload.in_transit?
      assert_empty @return_order.refunds
    end
  end

  test "an own-postage return approved before activation is not sent" do
    build_return(kind: :own_postage)
    active_store_box.connected!
    with_store_box do
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      assert_empty @store_box.created
      assert_nil @return_order.reload.store_box_status
    end
  end

  test "after deactivation a sent return is no longer polled and stays for the merchant" do
    build_return(kind: :own_postage)
    integration = active_store_box
    with_store_box do
      perform_enqueued_jobs { ReturnOrders::ApproveService.call(return_order: @return_order) }
      assert StoreBoxIntegration::DeactivateForm.new(integration).submit
      @store_box.remote["sbr_1"] = { "status" => "received", "items" => [] }
      StoreBox::PollJob.perform_now

      assert @return_order.reload.approved?
      assert @return_order.store_box_return.pending?
    end
  end

  private

  def with_store_box(&block)
    StoreBoxClient.stub(:new, @store_box, &block)
  end

  def active_store_box
    integration = @shop.create_store_box_integration!(api_key: "sb_test_key", status: :active)
    integration.location_mappings.create!(location: @location, warehouse_id: "wh_rtm")
    @location.update!(store_box_warehouse: true)
    { "restock" => "resolve", "damaged" => "manual_review", "wrong_item" => "manual_review" }.each do |result, action|
      integration.result_mappings.create!(result: result, action: action, restock: StoreBox::ResultMapping.default_restock(result))
    end
    @return_order.reload
    integration
  end
end
