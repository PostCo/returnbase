import { Badge } from "@/components/ui/badge";
import type { ReturnStatus } from "@/lib/types";
import { humanize } from "@/lib/utils";

const VARIANTS: Record<ReturnStatus, React.ComponentProps<typeof Badge>["variant"]> = {
  submitted: "warning",
  approved: "info",
  in_transit: "info",
  received: "info",
  resolved: "success",
  rejected: "danger",
  cancelled: "default",
};

export function StatusBadge({ status }: { status: ReturnStatus }) {
  return (
    <Badge variant={VARIANTS[status]} dot>
      {humanize(status)}
    </Badge>
  );
}
