import { cn } from "@/lib/utils";

const PATHS = {
  returns: "M6 3 3 6l3 3M3 6h6a4 4 0 0 1 0 8H7",
  pin: "M8 14s4.5-3.6 4.5-7a4.5 4.5 0 0 0-9 0c0 3.4 4.5 7 4.5 7ZM8 8.4a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z",
  plug: "M6 2v3M10 2v3M4.5 5h7v2.5a3.5 3.5 0 0 1-7 0V5ZM8 11v3",
  settings: "M3 5h6M12 5h1M3 11h1M7 11h6M10.5 3v4M5.5 9v4",
  search: "M7 11.5a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9ZM10.5 10.5l3 3",
  chevronDown: "m4 6 4 4 4-4",
  download: "M8 2v8M5 7l3 3 3-3M3 13h10",
  alert: "M8 14A6 6 0 1 0 8 2a6 6 0 0 0 0 12ZM8 5v3.5M8 10.8v.1",
  arrowLeft: "M13 8H3M7 4 3 8l4 4",
  card: "M2.5 4.5h11v7h-11ZM2.5 7h11",
  mail: "M2.5 4h11v8h-11ZM3 4.5l5 4 5-4",
  check: "m3.5 8.5 3 3 6-7",
  inbox: "M2 9l1.5-5h9L14 9M2 9v4h12V9M2 9h3.5l1 1.5h3L10.5 9H14",
  spinner: "M8 2a6 6 0 1 0 6 6",
} as const;

export type IconName = keyof typeof PATHS;

// A 16px line icon that takes the colour of the text around it. Add a path to PATHS for a new one.
export function Icon({ name, className }: { name: IconName; className?: string }) {
  return (
    <svg
      viewBox="0 0 16 16"
      aria-hidden
      className={cn("size-4 shrink-0 fill-none stroke-current", className)}
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={PATHS[name]} />
    </svg>
  );
}
