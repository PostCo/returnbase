import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const alertVariants = cva("rounded-control border px-3 py-2.5 text-sm", {
  variants: {
    variant: {
      info: "border-info/20 bg-info-soft text-info",
      success: "border-success/20 bg-success-soft text-success",
      warning: "border-warning/25 bg-warning-soft text-warning",
      danger: "border-danger/20 bg-danger-soft text-danger",
    },
  },
  defaultVariants: { variant: "info" },
});

export interface AlertProps extends React.ComponentProps<"div">, VariantProps<typeof alertVariants> {}

// A message about the page or a record. Danger alerts are announced at once, the rest politely.
export function Alert({ className, variant, ...props }: AlertProps) {
  return <div role={variant === "danger" ? "alert" : "status"} className={cn(alertVariants({ variant }), className)} {...props} />;
}
