export type Shop = { id: number; name: string };

export type ExchangeOption = { sku: string; title: string };
export type OrderItem = {
  sku: string;
  name: string;
  quantity: number;
  price: number;
  currency: string;
  exchange_options: ExchangeOption[];
};
export type ShippingMethod = { kind: "label" | "own_postage"; name: string };
export type Lookup = {
  order: { number: string; customer: string };
  items: OrderItem[];
  shipping_methods: ShippingMethod[];
  reasons: string[];
};

export type ReturnItemInput = {
  sku: string;
  quantity: number;
  reason: string;
  resolution: "refund" | "exchange";
  exchange_sku?: string;
};

export type ReturnStatus = {
  number: string;
  status: string;
  order_number: string;
  can_cancel: boolean;
  shipping: {
    kind: string;
    label_url: string | null;
    tracking_number: string | null;
    label_pending: boolean;
    instructions: string | null;
  };
  items: { name: string; quantity: number; resolution: string; exchange_for: string | null; outcome: "accepted" | "rejected" | null }[];
  refunds: { amount: string }[];
  exchanges: { name: string; status: string }[];
  timeline: { status: string; at: string }[];
};

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, { headers: { "Content-Type": "application/json" }, ...init });
  const body = await response.json();
  if (!response.ok) throw new Error((body.errors ?? ["Something went wrong"]).join(", "));
  return body as T;
}

export const shopperApi = {
  shops: () => request<{ shops: Shop[] }>("/api/shopper/shops"),
  lookup: (shopId: number, orderNumber: string, email: string) =>
    request<Lookup>("/api/shopper/lookup", {
      method: "POST",
      body: JSON.stringify({ shop_id: shopId, order_number: orderNumber, email }),
    }),
  submit: (shopId: number, orderNumber: string, email: string, shippingKind: string, items: ReturnItemInput[]) =>
    request<{ number: string; status: string }>("/api/shopper/returns", {
      method: "POST",
      body: JSON.stringify({ shop_id: shopId, order_number: orderNumber, email, shipping_kind: shippingKind, items }),
    }),
  status: (shopId: string, number: string, email: string) =>
    request<ReturnStatus>(
      `/api/shopper/returns/${encodeURIComponent(number)}?${new URLSearchParams({ shop_id: shopId, email })}`,
    ),
  cancel: (shopId: string, number: string, email: string) =>
    request<ReturnStatus>(`/api/shopper/returns/${encodeURIComponent(number)}/cancel`, {
      method: "POST",
      body: JSON.stringify({ shop_id: shopId, email }),
    }),
};
