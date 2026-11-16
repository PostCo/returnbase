import { useState } from "react";
import { Controller, useForm, useWatch, type Control } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { ItemDecision, ReturnItem } from "@/lib/types";
import { humanize } from "@/lib/utils";

const schema = z.object({
  decisions: z.array(
    z.object({
      id: z.number(),
      outcome: z.enum(["accepted", "rejected"]),
      restock: z.boolean(),
    }),
  ),
});
type Values = z.infer<typeof schema>;

const startingValues = (items: ReturnItem[]): Values => ({
  decisions: items.map((item) => ({ id: item.id, outcome: "accepted", restock: Boolean(item.restock_default) })),
});

function ItemRow({ item, index, control }: { item: ReturnItem; index: number; control: Control<Values> }) {
  const outcome = useWatch({ control, name: `decisions.${index}.outcome` });

  return (
    <li className="grid grid-cols-[1fr_8rem] items-center gap-x-3 gap-y-2 border-b py-3 first:pt-0 last:border-0 sm:grid-cols-[1fr_8rem_11rem]">
      <div className="min-w-0">
        <div className="font-medium">
          {item.quantity} x {item.name}
        </div>
        <div className="font-mono text-xs text-muted-foreground">{item.sku}</div>
        <div className="text-xs text-muted-foreground">
          {humanize(item.resolution)}
          {item.exchange_sku && ` for ${item.exchange_sku}`}
        </div>
        {item.condition === "not_restockable" && <div className="text-xs text-muted-foreground">The warehouse says it cannot be resold</div>}
      </div>
      <Controller
        control={control}
        name={`decisions.${index}.outcome`}
        render={({ field }) => (
          <Select value={field.value} onValueChange={field.onChange}>
            <SelectTrigger aria-label={`Decision for ${item.name}`}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="accepted">Accept</SelectItem>
              <SelectItem value="rejected">Reject</SelectItem>
            </SelectContent>
          </Select>
        )}
      />
      {outcome === "accepted" && (
        <Controller
          control={control}
          name={`decisions.${index}.restock`}
          render={({ field }) => (
            <label className="col-span-2 flex items-center gap-2 text-sm sm:col-span-1">
              <input type="checkbox" className="size-4 accent-brand" checked={field.value} onChange={(event) => field.onChange(event.target.checked)} />
              Put back in stock
            </label>
          )}
        />
      )}
    </li>
  );
}

export function ResolveDialog({ items, disabled, onResolve }: { items: ReturnItem[]; disabled: boolean; onResolve: (decisions: ItemDecision[]) => Promise<boolean> }) {
  const [open, setOpen] = useState(false);
  const { control, handleSubmit, reset, formState: { isSubmitting } } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: startingValues(items),
  });
  const decisions = useWatch({ control, name: "decisions" });

  const allRejected = decisions.every((decision) => decision.outcome === "rejected");

  const submit = async (values: Values) => {
    const done = await onResolve(values.decisions);
    if (done) setOpen(false);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (next) reset(startingValues(items));
        setOpen(next);
      }}
    >
      <DialogTrigger asChild>
        <Button disabled={disabled}>Resolve</Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Resolve return</DialogTitle>
          <DialogDescription>
            Accept or reject each item. Accepted items are refunded or exchanged as the shopper chose, and go back in stock when ticked. A rejected
            item is not refunded, and a held exchange for it is released.
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit(submit)} className="flex flex-col gap-4">
          <ul className="flex flex-col">
            {items.map((item, index) => (
              <ItemRow key={item.id} item={item} index={index} control={control} />
            ))}
          </ul>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" variant={allRejected ? "destructive" : undefined} loading={isSubmitting}>
              {allRejected ? "Reject return" : "Resolve return"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
