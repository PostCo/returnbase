export type IntegrationSummary = { type: string; status: string | null };

export type StoreBoxStatus = "connected" | "active" | "disabled";
export type StoreBoxResult = "restock" | "damaged" | "wrong_item";
export type StoreBoxAction = "resolve" | "manual_review";

export type StoreBoxIntegration = {
  id: number;
  status: StoreBoxStatus;
  api_key_hint: string;
  readiness: { ready: boolean; checks: { key: string; label: string; done: boolean }[] };
  location_mappings: { location_id: number; name: string; city: string | null; warehouse_id: string | null }[];
  result_mappings: { result: StoreBoxResult; action: StoreBoxAction | null; restock: boolean }[];
  open_returns: number;
};

export type StoreBoxWarehouse = { id: string; name: string; country: string };

export type StoreBoxReturnInfo = {
  status: "send_failed" | "pending" | "received" | "inspected";
  remote_id: string | null;
  warehouse_id: string | null;
  sent_at: string | null;
  results: { sku: string; quantity: number; result: StoreBoxResult }[];
  action: StoreBoxAction | null;
  integration_status: StoreBoxStatus | null;
  failed_attempts: { error: string; created_at: string }[];
  can_retry: boolean;
};

export const RESULTS: Record<StoreBoxResult, { label: string; description: string }> = {
  restock: { label: "Restock", description: "The item can be sold again" },
  damaged: { label: "Damaged", description: "The item cannot be sold as new" },
  wrong_item: { label: "Wrong item", description: "Not the item the shopper said they sent" },
};

export const ACTIONS: Record<StoreBoxAction, string> = {
  resolve: "Resolve (refund or exchange)",
  manual_review: "Leave for manual review",
};
