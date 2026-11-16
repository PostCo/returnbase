import { useState } from "react";
import { useFieldArray, useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { REASONS, type ReturnItem } from "@/lib/types";
import { humanize } from "@/lib/utils";

const schema = z.object({
  items: z
    .array(
      z.object({
        sku: z.string(),
        name: z.string(),
        quantity: z.coerce.number().int().min(1, "At least 1"),
        reason: z.string(),
        resolution: z.enum(["refund", "exchange"]),
        exchange_sku: z.string().nullable(),
      }),
    )
    .min(1, "A return needs at least one item"),
});
type Values = z.infer<typeof schema>;

export function EditItemsDialog({ items, available, onSave }: { items: ReturnItem[]; available: { sku: string; name: string; quantity: number }[]; onSave: (items: Omit<ReturnItem, "id" | "name">[]) => Promise<boolean> }) {
  const [open, setOpen] = useState(false);
  const { register, control, handleSubmit, reset, formState: { errors } } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { items },
  });
  const { fields, remove, append } = useFieldArray({ control, name: "items" });

  const addable = available.filter((a) => !fields.some((f) => f.sku === a.sku));

  const submit = async ({ items }: Values) => {
    const saved = await onSave(items.map(({ name: _name, ...item }) => item));
    if (saved) setOpen(false);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (next) reset({ items });
        setOpen(next);
      }}
    >
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          Edit items
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Edit items</DialogTitle>
          <DialogDescription>Changes apply until the parcel arrives at the warehouse.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit(submit)} className="flex flex-col gap-4">
          {fields.map((field, index) => (
            <div key={field.id} className="grid grid-cols-2 items-center gap-2 sm:grid-cols-[1fr_5rem_9rem_8rem_auto]">
              <span className="col-span-2 truncate text-sm sm:col-span-1">{field.name}</span>
              <Input type="number" min={1} aria-label={`Quantity for ${field.name}`} {...register(`items.${index}.quantity`)} />
              <Controller
                control={control}
                name={`items.${index}.reason`}
                render={({ field: f }) => (
                  <Select value={f.value} onValueChange={f.onChange}>
                    <SelectTrigger aria-label={`Reason for ${field.name}`}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {REASONS.map((reason) => (
                        <SelectItem key={reason} value={reason}>
                          {humanize(reason)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
              <Controller
                control={control}
                name={`items.${index}.resolution`}
                render={({ field: f }) => (
                  <Select value={f.value} onValueChange={f.onChange}>
                    <SelectTrigger aria-label={`Resolution for ${field.name}`}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="refund">Refund</SelectItem>
                      <SelectItem value="exchange" disabled={!field.exchange_sku}>
                        Exchange
                      </SelectItem>
                    </SelectContent>
                  </Select>
                )}
              />
              <Button type="button" variant="ghost" size="sm" onClick={() => remove(index)}>
                Remove
              </Button>
              {errors.items?.[index]?.quantity && (
                <p className="col-span-2 text-xs text-destructive sm:col-span-5">{errors.items[index]?.quantity?.message}</p>
              )}
            </div>
          ))}
          {errors.items?.root && <p className="text-xs text-destructive">{errors.items.root.message}</p>}
          {errors.items?.message && <p className="text-xs text-destructive">{errors.items.message}</p>}
          {addable.length > 0 && (
            <Select
              value=""
              onValueChange={(sku) => {
                const item = addable.find((a) => a.sku === sku);
                if (item) append({ sku: item.sku, name: item.name, quantity: item.quantity, reason: "changed_mind", resolution: "refund", exchange_sku: null });
              }}
            >
              <SelectTrigger aria-label="Add item">
                <SelectValue placeholder="Add item" />
              </SelectTrigger>
              <SelectContent>
                {addable.map((a) => (
                  <SelectItem key={a.sku} value={a.sku}>
                    {a.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
          <DialogFooter>
            <Button type="submit">Save items</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
