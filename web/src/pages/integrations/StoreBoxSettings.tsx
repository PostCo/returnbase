import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { Link } from "react-router-dom";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ConfirmButton } from "@/components/ConfirmButton";
import { PageHeader } from "@/components/Layout";
import { Alert } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ErrorState } from "@/components/ui/empty-state";
import { Icon } from "@/components/ui/icon";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { CardSkeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useToast } from "@/components/ui/toast";
import { api, ApiError } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { cn } from "@/lib/utils";
import { IntegrationStatusBadge } from "./cards";
import { ACTIONS, RESULTS, type StoreBoxIntegration, type StoreBoxWarehouse } from "./types";

const BASE = "/api/store_box_integration";
const NOT_SENT = "none";

type ChangeHandler = (integration: StoreBoxIntegration) => void;

function errorText(e: unknown) {
  return e instanceof ApiError && e.errors.length ? e.errors.join(" ") : "Something went wrong. Try again.";
}

export default function StoreBoxSettings() {
  const { data, setData, error, retry } = useAsync(
    () =>
      api<StoreBoxIntegration>(BASE)
        .then((integration) => ({ integration }))
        .catch((e) => {
          if (e instanceof ApiError && e.status === 404) return { integration: null };
          throw e;
        }),
    [],
  );
  const show = (integration: StoreBoxIntegration) => setData({ integration });
  const integration = data?.integration;

  return (
    <>
      <PageHeader
        title="StoreBox"
        back={{ to: "/integrations", label: "Integrations" }}
        badge={integration && <IntegrationStatusBadge status={integration.status} />}
      >
        {integration && <ActivationButton integration={integration} onChange={show} />}
      </PageHeader>

      {error ? (
        <Card>
          <ErrorState title="Couldn't load StoreBox settings." retry={retry} />
        </Card>
      ) : !data ? (
        <div role="status" aria-label="Loading StoreBox settings" className="flex flex-col gap-4">
          <CardSkeleton lines={2} />
          <CardSkeleton lines={4} />
          <CardSkeleton lines={4} />
        </div>
      ) : integration ? (
        <div className="flex flex-col gap-4">
          <StatusNotice integration={integration} />
          <ReadinessCard integration={integration} />
          <MappingsForm integration={integration} onChange={show} />
          <CredentialsCard integration={integration} onChange={show} />
        </div>
      ) : (
        <ConnectCard onConnected={show} />
      )}
    </>
  );
}

function ActivationButton({ integration, onChange }: { integration: StoreBoxIntegration; onChange: ChangeHandler }) {
  const toast = useToast();
  const post = async (action: "activate" | "deactivate", message: string) => {
    try {
      onChange(await api<StoreBoxIntegration>(`${BASE}/${action}`, { method: "POST" }));
      toast(message);
      return true;
    } catch (e) {
      toast(errorText(e), "error");
      return false;
    }
  };

  if (integration.status === "active") {
    return (
      <ConfirmButton
        label="Deactivate"
        variant="destructive"
        title="Deactivate StoreBox?"
        confirmLabel="Deactivate"
        description={
          <>
            <p>New returns stop going to StoreBox, and Returnbase stops checking StoreBox for updates.</p>
            {integration.open_returns > 0 && (
              <p className="mt-2">
                Returns already at StoreBox stay on their return pages for you to finish by hand ({integration.open_returns} open now).
              </p>
            )}
          </>
        }
        onConfirm={() => post("deactivate", "StoreBox deactivated")}
      />
    );
  }
  return (
    <ConfirmButton
      label="Activate"
      disabled={!integration.readiness.ready}
      disabledReason="Finish the setup checklist first."
      title="Activate StoreBox?"
      confirmLabel="Activate"
      description="From now on, approved returns at the mapped locations go to StoreBox, and Returnbase acts on StoreBox's inspection results. Activating sends nothing by itself."
      onConfirm={() => post("activate", "StoreBox is active")}
    />
  );
}

function StatusNotice({ integration }: { integration: StoreBoxIntegration }) {
  const { status, readiness, open_returns } = integration;
  const [tone, message] =
    status === "active"
      ? ["success", "StoreBox is active. Approved returns at mapped locations go to StoreBox, and Returnbase checks StoreBox for updates every minute."]
      : status === "disabled"
        ? ["warning", `StoreBox is deactivated. Nothing new is sent, and Returnbase no longer checks StoreBox.${open_returns > 0 ? ` Finish the returns sent earlier by hand (${open_returns} open).` : ""}`]
        : readiness.ready
          ? ["warning", "Setup is complete. StoreBox stays off until you activate it."]
          : ["warning", "StoreBox is connected but not active. Finish the checklist, then activate it."];

  return <Alert variant={tone === "success" ? "success" : "warning"}>{message}</Alert>;
}

function ReadinessCard({ integration }: { integration: StoreBoxIntegration }) {
  const { checks } = integration.readiness;
  return (
    <Card>
      <CardHeader>
        <CardTitle>Setup checklist</CardTitle>
        <CardDescription>
          {checks.filter((check) => check.done).length} of {checks.length} done
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ul className="space-y-2" data-testid="readiness">
          {checks.map((check) => (
            <li key={check.key} className="flex items-center gap-2">
              <span
                aria-hidden
                className={cn(
                  "flex size-5 items-center justify-center rounded-full",
                  check.done ? "bg-success-soft text-success" : "border border-input",
                )}
              >
                {check.done && <Icon name="check" className="size-3.5" />}
              </span>
              <span className={check.done ? undefined : "text-muted-foreground"}>{check.label}</span>
              <span className="sr-only">{check.done ? "(done)" : "(not done)"}</span>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}

const mappingSchema = z.object({
  location_mappings: z.array(z.object({ location_id: z.number(), warehouse_id: z.string() })),
  result_mappings: z.array(z.object({ result: z.string(), action: z.string(), restock: z.boolean() })),
});
type MappingValues = z.infer<typeof mappingSchema>;

function toValues(integration: StoreBoxIntegration): MappingValues {
  return {
    location_mappings: integration.location_mappings.map((m) => ({ location_id: m.location_id, warehouse_id: m.warehouse_id ?? NOT_SENT })),
    result_mappings: integration.result_mappings.map((m) => ({ result: m.result, action: m.action ?? "", restock: m.restock })),
  };
}

function MappingsForm({ integration, onChange }: { integration: StoreBoxIntegration; onChange: ChangeHandler }) {
  const toast = useToast();
  const warehouses = useAsync(() => api<{ warehouses: StoreBoxWarehouse[] }>(`${BASE}/warehouses`), []);
  const [saveError, setSaveError] = useState<string | null>(null);
  const {
    control,
    handleSubmit,
    reset,
    formState: { isDirty, isSubmitting },
  } = useForm<MappingValues>({ resolver: zodResolver(mappingSchema), defaultValues: toValues(integration) });

  useEffect(() => reset(toValues(integration)), [integration]);

  const save = async (values: MappingValues) => {
    setSaveError(null);
    const body = {
      location_mappings: values.location_mappings.map((m) => ({ ...m, warehouse_id: m.warehouse_id === NOT_SENT ? "" : m.warehouse_id })),
      result_mappings: values.result_mappings,
    };
    try {
      const next = await api<StoreBoxIntegration>(BASE, { method: "PATCH", body });
      onChange(next);
      toast(next.status === "active" ? "Settings saved" : "Settings saved. StoreBox stays off until you activate it.");
    } catch (e) {
      setSaveError(errorText(e));
    }
  };

  return (
    <form onSubmit={handleSubmit(save)} className="flex flex-col gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Locations</CardTitle>
          <CardDescription>
            Choose which return locations StoreBox serves and the StoreBox warehouse each one sends to. Returns at other locations are not sent.
          </CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          {warehouses.error && (
            <Alert variant="danger" className="m-4">
              Could not load StoreBox warehouses: {warehouses.error}
            </Alert>
          )}
          {integration.location_mappings.length === 0 ? (
            <p className="p-4 text-muted-foreground">
              This shop has no return locations yet. Add one under{" "}
              <Link to="/locations" className="text-brand hover:underline">
                Locations
              </Link>
              .
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Return location</TableHead>
                  <TableHead className="md:w-80">StoreBox warehouse</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {integration.location_mappings.map((location, index) => (
                  <TableRow key={location.location_id}>
                    <TableCell>
                      <div className="font-medium">{location.name}</div>
                      <div className="text-xs text-muted-foreground">{location.city}</div>
                    </TableCell>
                    <TableCell>
                      <Controller
                        control={control}
                        name={`location_mappings.${index}.warehouse_id`}
                        render={({ field }) => (
                          <Select value={field.value} onValueChange={field.onChange} disabled={!warehouses.data}>
                            <SelectTrigger aria-label={`StoreBox warehouse for ${location.name}`}>
                              <SelectValue placeholder="Loading warehouses..." />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value={NOT_SENT}>Not sent to StoreBox</SelectItem>
                              {warehouses.data?.warehouses.map((warehouse) => (
                                <SelectItem key={warehouse.id} value={warehouse.id}>
                                  {warehouse.name} ({warehouse.country})
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )}
                      />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Inspection results</CardTitle>
          <CardDescription>
            StoreBox grades every item it inspects. Choose what Returnbase does for each result, and whether those items go back into stock
            when the return is resolved (if your shop restocks on resolve). When items in one return get different results, the more careful
            action wins.
          </CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>StoreBox result</TableHead>
                <TableHead className="md:w-80">Returnbase action</TableHead>
                <TableHead className="w-32">Back in stock</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {integration.result_mappings.map(({ result }, index) => (
                <TableRow key={result}>
                  <TableCell>
                    <div className="font-medium">{RESULTS[result].label}</div>
                    <div className="text-xs text-muted-foreground">{RESULTS[result].description}</div>
                  </TableCell>
                  <TableCell>
                    <Controller
                      control={control}
                      name={`result_mappings.${index}.action`}
                      render={({ field }) => (
                        <Select value={field.value} onValueChange={field.onChange}>
                          <SelectTrigger aria-label={`Action for ${RESULTS[result].label}`}>
                            <SelectValue placeholder="Choose an action" />
                          </SelectTrigger>
                          <SelectContent>
                            {Object.entries(ACTIONS).map(([action, label]) => (
                              <SelectItem key={action} value={action}>
                                {label}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </TableCell>
                  <TableCell>
                    <Controller
                      control={control}
                      name={`result_mappings.${index}.restock`}
                      render={({ field }) => (
                        <Switch
                          checked={field.value}
                          onCheckedChange={field.onChange}
                          aria-label={`Back in stock for ${RESULTS[result].label}`}
                        />
                      )}
                    />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-center justify-end gap-3">
        {saveError && <p className="text-sm text-destructive">{saveError}</p>}
        <Button type="button" variant="outline" disabled={!isDirty || isSubmitting} onClick={() => reset(toValues(integration))}>
          Discard changes
        </Button>
        <Button type="submit" disabled={!isDirty} loading={isSubmitting}>
          {isSubmitting ? "Saving..." : "Save settings"}
        </Button>
      </div>
    </form>
  );
}

const keySchema = z.object({ api_key: z.string().trim().min(1, "Enter your StoreBox API key") });
type KeyValues = z.infer<typeof keySchema>;

// Returns an error message to show under the field, or null when the key was saved.
function ApiKeyForm({ submitLabel, onSubmit }: { submitLabel: string; onSubmit: (apiKey: string) => Promise<string | null> }) {
  const {
    register,
    handleSubmit,
    setError,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<KeyValues>({ resolver: zodResolver(keySchema), defaultValues: { api_key: "" } });

  const submit = async ({ api_key }: KeyValues) => {
    const failure = await onSubmit(api_key);
    if (failure) setError("api_key", { message: failure });
    else reset();
  };

  return (
    <form onSubmit={handleSubmit(submit)} className="flex flex-col gap-2">
      <Label htmlFor={`api-key-${submitLabel}`}>API key</Label>
      <div className="flex flex-col gap-2 sm:flex-row">
        <Input id={`api-key-${submitLabel}`} type="password" autoComplete="off" className="sm:max-w-sm" {...register("api_key")} />
        <Button type="submit" loading={isSubmitting}>
          {isSubmitting ? "Checking with StoreBox..." : submitLabel}
        </Button>
      </div>
      {errors.api_key && <p className="text-sm text-destructive">{errors.api_key.message}</p>}
    </form>
  );
}

function ConnectCard({ onConnected }: { onConnected: ChangeHandler }) {
  const connect = async (apiKey: string) => {
    try {
      onConnected(await api<StoreBoxIntegration>(BASE, { method: "POST", body: { api_key: apiKey } }));
      return null;
    } catch (e) {
      return errorText(e);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Connect StoreBox</CardTitle>
        <CardDescription>
          Paste the API key from your StoreBox account. Returnbase checks it with StoreBox before saving. Nothing goes to StoreBox until you
          finish setup and activate it.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ApiKeyForm submitLabel="Connect" onSubmit={connect} />
      </CardContent>
    </Card>
  );
}

function CredentialsCard({ integration, onChange }: { integration: StoreBoxIntegration; onChange: ChangeHandler }) {
  const toast = useToast();
  const replace = async (apiKey: string) => {
    try {
      onChange(await api<StoreBoxIntegration>(`${BASE}/credentials`, { method: "PATCH", body: { api_key: apiKey } }));
      toast("API key replaced");
      return null;
    } catch (e) {
      return errorText(e);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>API key</CardTitle>
        <CardDescription>
          Current key {integration.api_key_hint}. A new key is checked with StoreBox first. Your settings and activation stay as they are.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ApiKeyForm submitLabel="Replace key" onSubmit={replace} />
      </CardContent>
    </Card>
  );
}
