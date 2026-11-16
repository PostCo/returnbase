import { PageHeader } from "@/components/Layout";
import { Card } from "@/components/ui/card";
import { EmptyState, ErrorState } from "@/components/ui/empty-state";
import { CardSkeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { IntegrationCardFor } from "./cards";
import type { IntegrationSummary } from "./types";

export default function IntegrationsPage() {
  const { data, error, retry } = useAsync(() => api<{ integrations: IntegrationSummary[] }>("/api/integrations"), []);

  return (
    <>
      <PageHeader title="Integrations" />
      {error ? (
        <Card>
          <ErrorState title="Couldn't load integrations." retry={retry} />
        </Card>
      ) : !data ? (
        <div role="status" aria-label="Loading integrations" className="grid gap-4 md:grid-cols-2">
          <CardSkeleton className="h-36" />
          <CardSkeleton className="h-36" />
        </div>
      ) : data.integrations.length === 0 ? (
        <Card>
          <EmptyState title="No integrations available." description="Integrations you can connect will be listed here." />
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {data.integrations.map((integration) => (
            <IntegrationCardFor key={integration.type} integration={integration} />
          ))}
        </div>
      )}
    </>
  );
}
