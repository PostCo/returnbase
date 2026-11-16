import type { StoreBoxReturnInfo } from "@/pages/integrations/types";

export type ReturnStatus =
  | "submitted"
  | "approved"
  | "rejected"
  | "in_transit"
  | "received"
  | "resolved"
  | "cancelled";

export type ShippingKind = "label" | "own_postage";

export type ReturnSummary = {
  id: number;
  number: string;
  status: ReturnStatus;
  created_at: string;
  customer: { name: string; email: string };
  order: { number: string };
  shipping_method: { kind: ShippingKind; name: string };
};

export type ReturnItem = {
  id: number;
  sku: string;
  name: string;
  quantity: number;
  reason: string;
  resolution: "refund" | "exchange";
  exchange_sku: string | null;
  condition?: "restockable" | "not_restockable" | null;
  outcome?: "accepted" | "rejected" | null;
  restock?: boolean | null;
  restock_default?: boolean;
};

export type ItemDecision = { id: number; outcome: "accepted" | "rejected"; restock: boolean };

export type ReturnAction = "approve" | "reject" | "receive" | "resolve" | "edit_items" | "cancel" | "move";

export type ReturnDetail = ReturnSummary & {
  location: { id: number; name: string; address: string | null };
  shipment: { status: string; label_url: string | null; tracking_number: string | null; error: string | null } | null;
  items: ReturnItem[];
  available_items: { sku: string; name: string; quantity: number }[];
  refunds: { amount: number; currency: string }[];
  exchanges: { sku: string; status: string }[];
  timeline: { kind: string; data: Record<string, unknown>; created_at: string }[];
  allowed_actions: ReturnAction[];
  store_box: StoreBoxReturnInfo | null;
};

export type Shop = { id: number; name: string; currency: string; refund_on_carrier_pickup: boolean; restock_on_resolve: boolean };
export type Location = { id: number; name: string; city: string | null; address: string | null; archived: boolean; default: boolean };
export type Session = { user: { email: string }; shop: { id: number; name: string } };

export const STATUSES: ReturnStatus[] = [
  "submitted",
  "approved",
  "in_transit",
  "received",
  "resolved",
  "rejected",
  "cancelled",
];
export const REASONS = ["too_small", "too_large", "damaged", "not_as_described", "changed_mind"];
