import { Alert } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, Dl, DlItem } from "@/components/ui/card";
import { formatDateTime } from "@/lib/utils";
import { ACTIONS, RESULTS, type StoreBoxResult, type StoreBoxReturnInfo } from "./types";

type Variant = React.ComponentProps<typeof Badge>["variant"];

const STATUSES: Record<StoreBoxReturnInfo["status"], { label: string; variant: Variant }> = {
  send_failed: { label: "Send failed", variant: "danger" },
  pending: { label: "Expected at StoreBox", variant: "info" },
  received: { label: "Received by StoreBox", variant: "info" },
  inspected: { label: "Inspected", variant: "success" },
};

const RESULT_VARIANTS: Record<StoreBoxResult, Variant> = { restock: "success", damaged: "warning", wrong_item: "danger" };

// The warehouse panel on a return: where it was sent, what the warehouse found, and what Returnbase did about it.
export function StoreBoxReturnPanel({ info, busy, onRetry }: { info: StoreBoxReturnInfo; busy: boolean; onRetry: () => void }) {
  const status = STATUSES[info.status];
  const failures = info.failed_attempts;
  const lastFailure = failures[failures.length - 1];

  return (
    <Card data-testid="store-box-panel">
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle>StoreBox</CardTitle>
        <Badge variant={status.variant} dot>
          {status.label}
        </Badge>
      </CardHeader>
      <CardContent className="space-y-3">
        {info.status === "send_failed" ? (
          <>
            <Alert variant="danger">
              Returnbase could not send this return to StoreBox
              {failures.length > 1 ? ` (${failures.length} attempts)` : ""}. Last error: {lastFailure?.error}
            </Alert>
            {info.can_retry ? (
              <Button size="sm" disabled={busy} loading={busy} onClick={onRetry}>
                {busy ? "Sending..." : "Retry send"}
              </Button>
            ) : (
              <p className="text-muted-foreground">StoreBox is not active, so this return cannot be sent. Finish it by hand.</p>
            )}
          </>
        ) : (
          <>
            <Dl>
              <DlItem label="StoreBox return" mono>
                {info.remote_id}
              </DlItem>
              <DlItem label="Warehouse" mono>
                {info.warehouse_id}
              </DlItem>
              <DlItem label="Sent">
                {info.sent_at && formatDateTime(info.sent_at)}
                {failures.length > 0 && ` after ${failures.length} failed ${failures.length === 1 ? "attempt" : "attempts"}`}
              </DlItem>
            </Dl>
            {info.results.length > 0 && (
              <ul className="grid gap-2">
                {info.results.map((item) => (
                  <li key={item.sku} className="flex items-center justify-between gap-2 rounded-control border px-3 py-2">
                    <span className="font-mono text-[12.5px]">
                      {item.sku} x{item.quantity}
                    </span>
                    <Badge variant={RESULT_VARIANTS[item.result]} className="h-5 rounded-md">
                      {RESULTS[item.result]?.label ?? item.result}
                    </Badge>
                  </li>
                ))}
              </ul>
            )}
            {info.action && (
              <Alert variant={info.action === "resolve" ? "success" : "warning"}>
                Action: <span className="font-semibold">{ACTIONS[info.action]}</span>
              </Alert>
            )}
          </>
        )}
        {info.integration_status === "disabled" && info.status !== "inspected" && info.status !== "send_failed" && (
          <Alert variant="warning">StoreBox is deactivated, so Returnbase no longer checks it for updates. Finish this return by hand.</Alert>
        )}
      </CardContent>
    </Card>
  );
}
