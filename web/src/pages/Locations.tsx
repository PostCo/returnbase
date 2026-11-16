import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { ConfirmButton } from "@/components/ConfirmButton";
import { PageHeader } from "@/components/Layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { EmptyState, ErrorState } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { TableSkeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { useToast } from "@/components/ui/toast";
import { api, ApiError } from "@/lib/api";
import type { Location } from "@/lib/types";
import { useAsync } from "@/lib/use-async";

const schema = z.object({ name: z.string().trim().min(1, "Enter a name"), city: z.string(), address: z.string() });
type Values = z.infer<typeof schema>;

function EditLocationDialog({ location, onSave }: { location: Location; onSave: (values: Values) => Promise<boolean> }) {
  const [open, setOpen] = useState(false);
  const values = { name: location.name, city: location.city ?? "", address: location.address ?? "" };
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: values });

  const submit = async (next: Values) => {
    if (await onSave(next)) setOpen(false);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (next) reset(values);
        setOpen(next);
      }}
    >
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" aria-label={"Edit " + location.name}>
          Edit
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit {location.name}</DialogTitle>
          <DialogDescription>The address is what shoppers are told when they post their own parcel.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit(submit)} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="location-name">Name</Label>
            <Input id="location-name" {...register("name")} />
            {errors.name && <p className="text-xs text-danger">{errors.name.message}</p>}
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="location-city">City</Label>
            <Input id="location-city" {...register("city")} />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="location-address">Address</Label>
            <Input id="location-address" {...register("address")} />
          </div>
          <DialogFooter>
            <Button type="submit" loading={isSubmitting}>
              Save location
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function LocationBadges({ location }: { location: Location }) {
  return (
    <div className="flex flex-wrap gap-1">
      {location.default && <Badge variant="info">Default</Badge>}
      {location.archived ? <Badge variant="warning">Archived</Badge> : <Badge variant="success">Active</Badge>}
    </div>
  );
}

export default function Locations() {
  const toast = useToast();
  const { data, setData, error, retry } = useAsync(() => api<{ locations: Location[] }>("/api/locations"), []);

  const run = async (id: number, path: string, method: string, body: unknown, success: string) => {
    try {
      setData(await api<{ locations: Location[] }>("/api/locations/" + id + path, { method, body }));
      toast(success);
      return true;
    } catch (e) {
      toast(e instanceof ApiError && e.errors.length ? e.errors.join(", ") : "Something went wrong", "error");
      return false;
    }
  };

  return (
    <>
      <PageHeader title="Return locations" />
      <Card>
        {error ? (
          <ErrorState title="Couldn't load locations." retry={retry} />
        ) : data && data.locations.length === 0 ? (
          <EmptyState icon="pin" title="No return locations yet." description="Return locations will appear here once your shop has one." />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead>Name</TableHead>
                <TableHead className="max-md:hidden">City</TableHead>
                <TableHead className="max-md:hidden">Address</TableHead>
                <TableHead className="max-md:hidden">State</TableHead>
                <TableHead>
                  <span className="sr-only">Actions</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            {data ? (
              <TableBody>
                {data.locations.map((location) => (
                  <TableRow key={location.id} data-testid={"location-" + location.id}>
                    <TableCell className="font-medium">
                      {location.name}
                      <div className="font-normal text-muted-foreground md:hidden">{[location.city, location.address].filter(Boolean).join(", ")}</div>
                      <div className="mt-1.5 md:hidden">
                        <LocationBadges location={location} />
                      </div>
                    </TableCell>
                    <TableCell className="max-md:hidden">{location.city}</TableCell>
                    <TableCell className="max-md:hidden">{location.address}</TableCell>
                    <TableCell className="max-md:hidden">
                      <LocationBadges location={location} />
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-wrap justify-end gap-2 max-md:min-w-24">
                        <EditLocationDialog location={location} onSave={(values) => run(location.id, "", "PATCH", values, "Location saved")} />
                        {!location.archived && !location.default && (
                          <Button variant="outline" size="sm" onClick={() => run(location.id, "/make_default", "POST", undefined, location.name + " is now the default")}>
                            Make default
                          </Button>
                        )}
                        {!location.archived && !location.default && (
                          <ConfirmButton
                            label="Archive"
                            title={"Archive " + location.name + "?"}
                            description="New returns and moves can no longer use it. Returns already there keep it."
                            confirmLabel="Archive"
                            onConfirm={() => run(location.id, "/archive", "POST", undefined, "Location archived")}
                          />
                        )}
                        {location.archived && (
                          <ConfirmButton
                            label="Unarchive"
                            title={"Unarchive " + location.name + "?"}
                            description="It can be chosen as a default and as a move target again."
                            confirmLabel="Unarchive"
                            onConfirm={() => run(location.id, "/unarchive", "POST", undefined, "Location unarchived")}
                          />
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            ) : (
              <TableSkeleton columns={5} hiddenOnPhone={[1, 2, 3]} />
            )}
          </Table>
        )}
      </Card>
    </>
  );
}
