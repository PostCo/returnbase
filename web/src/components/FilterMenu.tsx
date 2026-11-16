import { Icon } from "@/components/ui/icon";
import { DropdownMenu, DropdownMenuContent, DropdownMenuRadioGroup, DropdownMenuRadioItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";

type Props = { label: string; value: string; options: { value: string; label: string }[]; onChange: (value: string) => void };

// A filter button that reads "Shipping  All" and opens a menu of choices. The option with value "" clears the filter.
export function FilterMenu({ label, value, options, onChange }: Props) {
  const selected = options.find((option) => option.value === value) ?? options[0];
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="inline-flex h-9 items-center gap-1.5 rounded-control border border-input bg-card px-3 whitespace-nowrap hover:bg-muted">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-medium">{selected.label}</span>
        <Icon name="chevronDown" className="text-muted-foreground" />
      </DropdownMenuTrigger>
      <DropdownMenuContent>
        <DropdownMenuRadioGroup value={selected.value || "none"} onValueChange={(next) => onChange(next === "none" ? "" : next)}>
          {options.map((option) => (
            <DropdownMenuRadioItem key={option.value} value={option.value || "none"}>
              {option.label}
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
