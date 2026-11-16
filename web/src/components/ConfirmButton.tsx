import { useState } from "react";
import { Button, type ButtonProps } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Tooltip } from "@/components/ui/tooltip";

type Props = {
  label: string;
  title: string;
  description: React.ReactNode;
  confirmLabel: string;
  variant?: ButtonProps["variant"];
  disabled?: boolean;
  // Shown on hover when the button is disabled, so the merchant knows what to do first.
  disabledReason?: string;
  onConfirm: () => Promise<boolean>;
};

// A button that asks first. The dialog stays open if onConfirm reports a failure.
export function ConfirmButton({ label, title, description, confirmLabel, variant, disabled, disabledReason, onConfirm }: Props) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const confirm = async () => {
    setBusy(true);
    const done = await onConfirm();
    setBusy(false);
    if (done) setOpen(false);
  };

  const trigger = (
    <DialogTrigger asChild>
      <Button variant={variant} disabled={disabled}>
        {label}
      </Button>
    </DialogTrigger>
  );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      {disabled && disabledReason ? (
        <Tooltip content={disabledReason}>
          <span className="inline-flex">{trigger}</span>
        </Tooltip>
      ) : (
        trigger
      )}
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription asChild>
            <div>{description}</div>
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline">Cancel</Button>
          </DialogClose>
          <Button variant={variant} loading={busy} onClick={confirm}>
            {busy ? "Working..." : confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
