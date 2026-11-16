import * as React from "react";
import { Icon } from "@/components/ui/icon";
import { cn } from "@/lib/utils";

export const Input = React.forwardRef<HTMLInputElement, React.ComponentProps<"input">>(({ className, type, ...props }, ref) => (
  <input
    type={type}
    ref={ref}
    className={cn(
      "flex h-9 w-full rounded-control border border-input bg-card px-3 text-sm placeholder:text-[#9a948f] disabled:cursor-not-allowed disabled:opacity-50",
      className,
    )}
    {...props}
  />
));
Input.displayName = "Input";

// An input with a magnifier, for filtering a list.
export const SearchInput = React.forwardRef<HTMLInputElement, React.ComponentProps<"input">>(({ className, ...props }, ref) => (
  <div className={cn("relative", className)}>
    <Icon name="search" className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted-foreground" />
    <Input ref={ref} className="pl-9" {...props} />
  </div>
));
SearchInput.displayName = "SearchInput";
