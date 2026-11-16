import { Button } from "@/components/ui/button";

type Props = { page: number; perPage: number; total: number; noun: string; onPage: (page: number) => void };

// A footer for a card with a paged table: "Showing 1-20 of 40 returns" with Previous and Next.
export function Pagination({ page, perPage, total, noun, onPage }: Props) {
  const lastPage = Math.max(1, Math.ceil(total / perPage));
  const from = total === 0 ? 0 : (page - 1) * perPage + 1;
  const to = Math.min(page * perPage, total);

  return (
    <div className="flex items-center justify-between gap-2 border-t px-4 py-2.5 text-[13px] text-muted-foreground">
      <span>
        Showing {from}–{to} of {total} {noun}
      </span>
      <div className="flex gap-2">
        <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => onPage(page - 1)}>
          Previous
        </Button>
        <Button variant="outline" size="sm" disabled={page >= lastPage} onClick={() => onPage(page + 1)}>
          Next
        </Button>
      </div>
    </div>
  );
}
