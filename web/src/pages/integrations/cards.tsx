import { Link } from "react-router-dom";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { IntegrationSummary } from "./types";

type CardProps = { integration: IntegrationSummary };

const STATUS_BADGES: Record<string, { label: string; variant: React.ComponentProps<typeof Badge>["variant"] }> = {
  connected: { label: "Connected, not active", variant: "warning" },
  active: { label: "Active", variant: "success" },
  enabled: { label: "Enabled", variant: "success" },
  disabled: { label: "Deactivated", variant: "default" },
};

export function IntegrationStatusBadge({ status }: { status: string | null }) {
  const badge = status ? STATUS_BADGES[status] : undefined;
  return (
    <Badge variant={badge?.variant ?? "outline"} dot>
      {badge?.label ?? "Not connected"}
    </Badge>
  );
}

function IntegrationCard({ name, description, status, children }: { name: string; description: string; status: string | null; children: React.ReactNode }) {
  return (
    <Card data-testid={`integration-${name}`}>
      <CardHeader className="flex-row items-start justify-between gap-4 border-b-0 pb-0">
        <div className="flex flex-col gap-1">
          <CardTitle>{name}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </div>
        <IntegrationStatusBadge status={status} />
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}

function StoreBoxCard({ integration }: CardProps) {
  return (
    <IntegrationCard
      name="StoreBox"
      description="Send approved returns to your StoreBox warehouse. StoreBox receives and inspects them, and Returnbase acts on what it finds."
      status={integration.status}
    >
      <Button asChild variant={integration.status ? "outline" : "default"}>
        <Link to="/integrations/store-box">{integration.status ? "Manage" : "Set up"}</Link>
      </Button>
    </IntegrationCard>
  );
}

function ParcelDockCard({ integration }: CardProps) {
  return (
    <IntegrationCard
      name="ParcelDock"
      description="Buy prepaid return labels from ParcelDock and send those returns to its facility."
      status={integration.status}
    >
      <p className="text-muted-foreground">
        {integration.status ? "Returnbase support manages this integration. Contact support to change it." : "Contact support to set up ParcelDock."}
      </p>
    </IntegrationCard>
  );
}

function ComingSoonCard({ integration }: CardProps) {
  const name = integration.type.replace(/Integration$/, "");
  return (
    <IntegrationCard name={name} description={`${name} is coming soon.`} status={null}>
      <Button variant="outline" disabled>
        Coming soon
      </Button>
    </IntegrationCard>
  );
}

// One card per type the server lists in Api::IntegrationsController::AVAILABLE_TYPES. A type missing here shows as coming soon.
const CARDS: Record<string, React.ComponentType<CardProps>> = {
  StoreBoxIntegration: StoreBoxCard,
  ParcelDockIntegration: ParcelDockCard,
};

export function IntegrationCardFor({ integration }: CardProps) {
  const IntegrationTypeCard = CARDS[integration.type] ?? ComingSoonCard;
  return <IntegrationTypeCard integration={integration} />;
}
