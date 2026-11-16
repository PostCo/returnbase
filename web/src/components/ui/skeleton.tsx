import { Card } from "@/components/ui/card";
import { TableBody, TableCell, TableRow } from "@/components/ui/table";
import { cn } from "@/lib/utils";

// A grey placeholder bar. Give it a size with classes, such as "h-3 w-24".
export function Skeleton({ className }: { className?: string }) {
  return <span aria-hidden className={cn("rb-skeleton block h-2.5 rounded-full", className)} />;
}

const WIDTHS = ["w-16", "w-24", "w-32", "w-20", "w-28", "w-24"];

// Placeholder rows for a table that is loading. Pass the number of columns the real table has, and the
// indexes of columns the real table hides on a phone so the placeholder matches.
export function TableSkeleton({ columns, rows = 5, hiddenOnPhone = [] }: { columns: number; rows?: number; hiddenOnPhone?: number[] }) {
  return (
    <TableBody aria-busy aria-label="Loading">
      {Array.from({ length: rows }, (_, row) => (
        <TableRow key={row} className="hover:bg-transparent">
          {Array.from({ length: columns }, (_, column) => (
            <TableCell key={column} className={cn("py-4", hiddenOnPhone.includes(column) && "max-md:hidden")}>
              <Skeleton className={WIDTHS[(row + column) % WIDTHS.length]} />
            </TableCell>
          ))}
        </TableRow>
      ))}
    </TableBody>
  );
}


// A card-shaped placeholder for a page section that is loading.
export function CardSkeleton({ className, lines = 3 }: { className?: string; lines?: number }) {
  return (
    <Card className={cn("space-y-3 p-4", className)}>
      <Skeleton className="w-28" />
      {Array.from({ length: lines }, (_, line) => (
        <Skeleton key={line} className={line === lines - 1 ? "w-3/4" : "w-full"} />
      ))}
    </Card>
  );
}
