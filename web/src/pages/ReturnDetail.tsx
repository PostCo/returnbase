import { useState } from "react";
import { useParams } from "react-router-dom";
import { PageHeader } from "@/components/Layout";
import { StatusBadge } from "@/components/StatusBadge";
import { Alert } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { ConfirmButton } from "@/components/ConfirmButton";
import { Card, CardContent, CardHeader, CardTitle, Dl, DlItem } from "@/components/ui/card";
import { ErrorState } from "@/components/ui/empty-state";
import { Icon } from "@/components/ui/icon";
import { CardSkeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useToast } from "@/components/ui/toast";
import { api, ApiError } from "@/lib/api";
import type { ItemDecision, ReturnAction, ReturnDetail as Detail } from "@/lib/types";
import { useAsync } from "@/lib/use-async";
import { cn, formatDate, formatDateTime, formatMoney, humanize } from "@/lib/utils";
import { EditItemsDialog } from "@/pages/EditItemsDialog";
import { MoveReturnDialog } from "@/pages/MoveReturnDialog";
import { ResolveDialog } from "@/pages/ResolveDialog";
import { StoreBoxReturnPanel } from "@/pages/integrations/StoreBoxReturnPanel";

const ACTIONS: { action: Extract<ReturnAction, "approve" | "receive">; label: string }[] = [
  { action: "approve", label: "Approve" },
  { action: "receive", label: "Mark received" },
];

type StockLine = { sku: string; quantity: number; available?: number };

const stockList = (lines: StockLine[]) =>
  lines.map((line) => `${line.quantity} x ${line.sku}${line.available === undefined ? "" : ` (${line.available} available)`}`).join(", ");

function decidedText({ accepted, rejected }: { accepted: StockLine[]; rejected: StockLine[] }) {
  const parts = [];
  if (accepted.length) parts.push(`Accepted ${stockList(accepted)}`);
  if (rejected.length) parts.push(`Rejected ${stockList(rejected)}`);
  return parts.join("; ");
}

function restockedText({ restocked, skipped }: { restocked: StockLine[]; skipped: StockLine[] }) {
  const parts = [restocked.length ? `Restocked ${stockList(restocked)}` : "Nothing restocked"];
  if (skipped.length) parts.push(`not restocked: ${stockList(skipped)}`);
  return parts.join("; ");
}

function describe(event: Detail["timeline"][number], currency: string) {
  const { kind, data } = event;
  switch (kind) {
    case "submitted":
      return "Return submitted";
    case "status_changed":
      return `Status changed from ${humanize(String(data.from))} to ${humanize(String(data.to))}`;
    case "shipment_created":
      return `Shipment created (tracking ${data.tracking_number})`;
    case "label_requested":
      return "Label requested";
    case "label_failed":
      return `Label failed: ${data.error}`;
    case "exchange_reserved":
      return `Exchange reserved (quantity ${data.quantity})`;
    case "refunded":
      return `Refund of ${formatMoney(Number(data.amount_cents) / 100, currency)} issued`;
    case "moved":
      return `Moved from ${data.from} to ${data.to}`;
    case "cancelled":
      return `Cancelled by the ${data.cancelled_by}`;
    case "items_decided":
      return decidedText(data as { accepted: StockLine[]; rejected: StockLine[] });
    case "restocked":
      return restockedText(data as { restocked: StockLine[]; skipped: StockLine[] });
    case "sent_to_warehouse":
      return `Sent to ${data.warehouse} (${data.remote_id})`;
    case "warehouse_send_failed":
      return `Could not send to ${data.warehouse}: ${data.error}`;
    case "warehouse_inspected":
      return `${data.warehouse} inspected the items (${(data.results as string[]).map(humanize).join(", ")}): ${
        data.action === "resolve" ? "resolved automatically" : "left for manual review"
      }`;
    default:
      return humanize(kind);
  }
}

const BACK = { to: "/returns", label: "Returns" };

function LoadingDetail() {
  return (
    <div role="status" aria-label="Loading return">
      <PageHeader title="Return" back={BACK} />
      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="flex flex-col gap-4">
          <CardSkeleton className="h-44" />
          <CardSkeleton className="h-28" />
        </div>
        <div className="flex flex-col gap-4">
          <CardSkeleton className="h-28" />
          <CardSkeleton className="h-56" lines={5} />
        </div>
      </div>
    </div>
  );
}

export default function ReturnDetail() {
  const { id } = useParams();
  const toast = useToast();
  const { data: ret, setData, error, retry } = useAsync(() => api<Detail>(`/api/returns/${id}`), [id]);
  const { data: shop } = useAsync(() => api<{ currency: string }>("/api/shop"), []);
  const [busy, setBusy] = useState<string | null>(null);
  const currency = shop?.currency ?? "USD";

  const run = async (path: string, method: string, body?: unknown, success?: string) => {
    setBusy(path);
    try {
      setData(await api<Detail>(`/api/returns/${id}/${path}`, { method, body }));
      toast(success ?? "Return updated");
      return true;
    } catch (e) {
      toast(e instanceof ApiError && e.errors.length ? e.errors.join(", ") : "Something went wrong", "error");
      return false;
    } finally {
      setBusy(null);
    }
  };

  const retryStoreBox = async () => {
    if (!(await run("send_to_store_box", "POST", undefined, "Sent to StoreBox"))) setData(await api<Detail>(`/api/returns/${id}`));
  };

  const requestLabelAgain = () => run("request_label", "POST", undefined, "Label requested");

  if (error) {
    return (
      <>
        <PageHeader title="Return" back={BACK} />
        <Card>
          <ErrorState title="Couldn't load this return." retry={retry} />
        </Card>
      </>
    );
  }
  if (!ret) return <LoadingDetail />;

  const kindLabel = ret.shipping_method.kind === "label" ? "Prepaid label" : "Own postage";

  return (
    <>
      <PageHeader
        title={`Return ${ret.number}`}
        back={BACK}
        badge={<StatusBadge status={ret.status} />}
        meta={`Order ${ret.order.number} · ${ret.customer.name} · Created ${formatDate(ret.created_at)}`}
      >
        {ACTIONS.filter(({ action }) => ret.allowed_actions.includes(action)).map(({ action, label }) => (
          <Button key={action} disabled={busy !== null} loading={busy === action} onClick={() => run(action, "POST", undefined, `${label} done`)}>
            {label}
          </Button>
        ))}
        {ret.allowed_actions.includes("reject") && (
          <ConfirmButton
            label="Reject"
            title={`Reject return ${ret.number}?`}
            description={
              ret.status === "received"
                ? "Every item is rejected, held exchange stock is released and the shopper is emailed. This cannot be undone."
                : "The shopper is emailed. This cannot be undone."
            }
            confirmLabel="Reject return"
            variant="destructive"
            disabled={busy !== null}
            onConfirm={() => run("reject", "POST", undefined, "Return rejected")}
          />
        )}
        {ret.allowed_actions.includes("resolve") && (
          <ResolveDialog
            items={ret.items}
            disabled={busy !== null}
            onResolve={(items) =>
              run("resolve", "POST", { items }, items.every((item) => item.outcome === "rejected") ? "Return rejected" : "Return resolved")
            }
          />
        )}
        {ret.allowed_actions.includes("move") && (
          <MoveReturnDialog
            ret={ret}
            disabled={busy !== null}
            loading={busy === "move"}
            onMove={(locationId) => run("move", "POST", { location_id: locationId }, "Return moved")}
          />
        )}
        {ret.allowed_actions.includes("cancel") && (
          <ConfirmButton
            label="Cancel return"
            title={`Cancel return ${ret.number}?`}
            description="The shopper is emailed and told not to send the parcel. Held exchange stock is released. This cannot be undone."
            confirmLabel="Cancel return"
            variant="destructive"
            disabled={busy !== null}
            onConfirm={() => run("cancel", "POST", undefined, "Return cancelled")}
          />
        )}
      </PageHeader>

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="flex min-w-0 flex-col gap-4">
          {ret.store_box && <StoreBoxReturnPanel info={ret.store_box} busy={busy !== null} onRetry={retryStoreBox} />}

          <Card>
            <CardHeader className="flex-row items-center justify-between">
              <CardTitle>Items</CardTitle>
              {ret.allowed_actions.includes("edit_items") && (
                <EditItemsDialog items={ret.items} available={ret.available_items} onSave={(items) => run("items", "PATCH", { items }, "Items updated")} />
              )}
            </CardHeader>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead>Item</TableHead>
                  <TableHead>Qty</TableHead>
                  <TableHead className="max-md:hidden">Reason</TableHead>
                  <TableHead>Resolution</TableHead>
                  <TableHead>Outcome</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {ret.items.map((item) => (
                  <TableRow key={item.id} className="hover:bg-transparent">
                    <TableCell>
                      <div className="font-medium">{item.name}</div>
                      <div className="font-mono text-xs text-muted-foreground">{item.sku}</div>
                      <div className="text-xs text-muted-foreground md:hidden">{humanize(item.reason)}</div>
                      {item.condition && <div className="text-xs text-muted-foreground">{humanize(item.condition)}</div>}
                    </TableCell>
                    <TableCell>{item.quantity}</TableCell>
                    <TableCell className="max-md:hidden">{humanize(item.reason)}</TableCell>
                    <TableCell>
                      {humanize(item.resolution)}
                      {item.exchange_sku && <span className="text-muted-foreground"> for {item.exchange_sku}</span>}
                    </TableCell>
                    <TableCell>
                      {item.outcome ? humanize(item.outcome) : <span className="text-muted-foreground">Not decided</span>}
                      {item.outcome === "accepted" && item.restock != null && (
                        <div className="text-xs text-muted-foreground">{item.restock ? "Back in stock" : "Not put back in stock"}</div>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Refunds and exchanges</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1">
              {ret.refunds.map((refund, index) => (
                <div key={index}>Refunded {formatMoney(refund.amount, refund.currency)}</div>
              ))}
              {ret.exchanges.map((exchange, index) => (
                <div key={index}>
                  Exchange {exchange.sku} ({exchange.status})
                </div>
              ))}
              {ret.refunds.length === 0 && ret.exchanges.length === 0 && (
                <div className="text-muted-foreground">Nothing refunded or exchanged yet.</div>
              )}
            </CardContent>
          </Card>
        </div>

        <div className="flex min-w-0 flex-col gap-4">
          <Card>
            <CardHeader>
              <CardTitle>Customer and order</CardTitle>
            </CardHeader>
            <CardContent>
              <Dl>
                <DlItem label="Customer">{ret.customer.name}</DlItem>
                <DlItem label="Email">{ret.customer.email}</DlItem>
                <DlItem label="Order" mono>
                  {ret.order.number}
                </DlItem>
                <DlItem label="Return location" data-testid="return-location">
                  {ret.location.name}
                </DlItem>
                {ret.location.address && <DlItem label="Address">{ret.location.address}</DlItem>}
              </Dl>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex-row items-center justify-between">
              <CardTitle>Shipment</CardTitle>
              {ret.shipment?.label_url && (
                <a className="font-medium text-brand hover:underline" href={ret.shipment.label_url} target="_blank" rel="noreferrer">
                  Open label
                </a>
              )}
            </CardHeader>
            <CardContent className="space-y-3">
              <Dl>
                <DlItem label="Method">
                  <span className="inline-flex items-center gap-1.5">
                    <Icon name={ret.shipping_method.kind === "label" ? "card" : "mail"} className="text-muted-foreground" />
                    {kindLabel}
                  </span>
                </DlItem>
                {ret.shipment && (
                  <>
                    <DlItem label="Status" data-testid="shipment-status">
                      {ret.shipment.status === "pending" ? "Label requested" : humanize(ret.shipment.status)}
                    </DlItem>
                    {ret.shipment.status !== "pending" && ret.shipment.status !== "label_failed" && (
                      <DlItem label="Tracking" mono data-testid="shipment-tracking">
                        {ret.shipment.tracking_number ?? "none"}
                      </DlItem>
                    )}
                  </>
                )}
              </Dl>
              {!ret.shipment && <div className="text-muted-foreground">No shipment yet.</div>}
              {ret.shipment?.error && <Alert variant="danger">{ret.shipment.error}</Alert>}
              {ret.shipment?.status === "label_failed" && (
                <Button variant="outline" size="sm" disabled={busy !== null} loading={busy === "request_label"} onClick={requestLabelAgain}>
                  Request label again
                </Button>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Timeline</CardTitle>
            </CardHeader>
            <CardContent>
              <ol data-testid="timeline">
                {ret.timeline.map((event, index) => {
                  const last = index === ret.timeline.length - 1;
                  return (
                    <li key={index} className="relative pb-3.5 pl-5 last:pb-0">
                      <span aria-hidden className={cn("absolute top-1.5 left-[3px] size-[7px] rounded-full", last ? "bg-brand" : "bg-[#c9c3bd]")} />
                      {!last && <span aria-hidden className="absolute top-4 -bottom-0.5 left-1.5 w-px bg-input" />}
                      <div>{describe(event, currency)}</div>
                      <div className="text-xs text-muted-foreground">{formatDateTime(event.created_at)}</div>
                    </li>
                  );
                })}
              </ol>
            </CardContent>
          </Card>
        </div>
      </div>
    </>
  );
}
