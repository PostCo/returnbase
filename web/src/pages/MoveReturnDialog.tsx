import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import type { Location, ReturnDetail } from "@/lib/types";
import { useAsync } from "@/lib/use-async";

type Props = { ret: ReturnDetail; disabled: boolean; loading: boolean; onMove: (locationId: number) => Promise<boolean> };

export function MoveReturnDialog({ ret, disabled, loading, onMove }: Props) {
  const [open, setOpen] = useState(false);
  const [locationId, setLocationId] = useState("");
  const { data, error, retry } = useAsync(() => api<{ locations: Location[] }>("/api/locations"), []);
  const targets = data?.locations.filter((location) => !location.archived && location.id !== ret.location.id) ?? [];

  const move = async () => {
    if (await onMove(Number(locationId))) setOpen(false);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" disabled={disabled}>
          Move
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Move return {ret.number}</DialogTitle>
          <DialogDescription>
            {ret.shipping_method.kind === "label"
              ? "Exchange stock is held at the new location, and an approved return gets a new prepaid label by email."
              : "Exchange stock is held at the new location, and an approved return's shopper is emailed the new posting address."}
          </DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-1.5">
          <Label>New location</Label>
          {error ? (
            <p role="alert" className="text-sm text-danger">
              Couldn't load locations.{" "}
              <button type="button" className="underline" onClick={retry}>
                Retry
              </button>
            </p>
          ) : !data ? (
            <Skeleton className="h-9 w-full rounded-control" />
          ) : targets.length === 0 ? (
            <p className="text-sm text-muted-foreground">There is no other active location to move this return to.</p>
          ) : (
            <Select value={locationId} onValueChange={setLocationId}>
              <SelectTrigger aria-label="New location">
                <SelectValue placeholder="Choose a location" />
              </SelectTrigger>
              <SelectContent>
                {targets.map((location) => (
                  <SelectItem key={location.id} value={String(location.id)}>
                    {location.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        </div>
        <DialogFooter>
          <Button disabled={!locationId} loading={loading} onClick={move}>
            Move return
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
