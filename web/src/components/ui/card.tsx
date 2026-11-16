import * as React from "react";
import { cn } from "@/lib/utils";

export function Card({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("rounded-card border bg-card", className)} {...props} />;
}

export function CardHeader({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex min-h-12 flex-col justify-center gap-1 border-b px-4 py-3", className)} {...props} />;
}

export function CardTitle({ className, ...props }: React.ComponentProps<"h2">) {
  return <h2 className={cn("text-sm font-semibold", className)} {...props} />;
}

export function CardDescription({ className, ...props }: React.ComponentProps<"p">) {
  return <p className={cn("text-sm text-muted-foreground", className)} {...props} />;
}

export function CardContent({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("p-4", className)} {...props} />;
}

// Label and value pairs. Wrap each pair's value in <DlItem>.
export function Dl({ className, ...props }: React.ComponentProps<"dl">) {
  return <dl className={cn("grid grid-cols-[7rem_minmax(0,1fr)] gap-x-4 gap-y-2", className)} {...props} />;
}

export function DlItem({ label, children, mono, ...props }: { label: string; children: React.ReactNode; mono?: boolean } & React.ComponentProps<"dd">) {
  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd className={cn("min-w-0 break-words", mono && "font-mono text-[12.5px]")} {...props}>
        {children}
      </dd>
    </>
  );
}
