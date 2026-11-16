import { useState } from "react";
import { PageHeader } from "@/components/Layout";
import { Card, CardContent } from "@/components/ui/card";
import { ErrorState } from "@/components/ui/empty-state";
import { Label } from "@/components/ui/label";
import { CardSkeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { useToast } from "@/components/ui/toast";
import { api, ApiError } from "@/lib/api";
import type { Shop } from "@/lib/types";
import { useAsync } from "@/lib/use-async";

type Setting = "refund_on_carrier_pickup" | "restock_on_resolve";

const SETTINGS: { key: Setting; id: string; label: string; description: string }[] = [
  {
    key: "refund_on_carrier_pickup",
    id: "refund-on-pickup",
    label: "Refund when the carrier picks up",
    description:
      "Refund prepaid-label returns as soon as the carrier scans the parcel, before it reaches your warehouse. When off, refunds wait until the return is received.",
  },
  {
    key: "restock_on_resolve",
    id: "restock-on-resolve",
    label: "Put items back in stock by default",
    description:
      "Accepted items start ticked to go back in stock when you resolve a return, items a warehouse graded as not restockable start unticked, and automatic resolves use these defaults.",
  },
];

export default function Settings() {
  const toast = useToast();
  const { data: shop, setData, error, retry } = useAsync(() => api<Shop>("/api/shop"), []);
  const [saving, setSaving] = useState<Setting | null>(null);

  const save = async (setting: Setting, checked: boolean) => {
    setSaving(setting);
    try {
      setData(await api<Shop>("/api/shop", { method: "PATCH", body: { [setting]: checked } }));
      toast("Settings saved");
    } catch (e) {
      toast(e instanceof ApiError ? e.message : "Could not save settings", "error");
    } finally {
      setSaving(null);
    }
  };

  return (
    <>
      <PageHeader title="Settings" />
      {error ? (
        <Card>
          <ErrorState title="Couldn't load settings." retry={retry} />
        </Card>
      ) : !shop ? (
        <div role="status" aria-label="Loading settings" className="flex flex-col gap-4">
          <CardSkeleton lines={2} />
          <CardSkeleton lines={2} />
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {SETTINGS.map(({ key, id, label, description }) => (
            <Card key={key}>
              <CardContent className="flex items-start justify-between gap-6">
                <div>
                  <Label htmlFor={id}>{label}</Label>
                  <p className="mt-1 max-w-lg text-muted-foreground">{description}</p>
                </div>
                <Switch id={id} checked={shop[key]} disabled={saving !== null} onCheckedChange={(checked) => save(key, checked)} />
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
