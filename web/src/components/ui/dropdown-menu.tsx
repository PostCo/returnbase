import * as React from "react";
import * as MenuPrimitive from "@radix-ui/react-dropdown-menu";
import { Icon } from "@/components/ui/icon";
import { cn } from "@/lib/utils";

export const DropdownMenu = MenuPrimitive.Root;
export const DropdownMenuTrigger = MenuPrimitive.Trigger;
export const DropdownMenuRadioGroup = MenuPrimitive.RadioGroup;

export const DropdownMenuContent = React.forwardRef<
  React.ElementRef<typeof MenuPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof MenuPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <MenuPrimitive.Portal>
    <MenuPrimitive.Content
      ref={ref}
      align="start"
      sideOffset={sideOffset}
      className={cn("z-50 min-w-52 rounded-[10px] border bg-card p-1 shadow-[0_8px_24px_rgb(11_11_15/0.08)]", className)}
      {...props}
    />
  </MenuPrimitive.Portal>
));
DropdownMenuContent.displayName = "DropdownMenuContent";

const itemClass = "relative flex cursor-default items-center gap-2 rounded-md px-2.5 py-2 text-sm outline-hidden select-none data-[disabled]:opacity-45 data-[highlighted]:bg-accent";

export const DropdownMenuItem = React.forwardRef<React.ElementRef<typeof MenuPrimitive.Item>, React.ComponentPropsWithoutRef<typeof MenuPrimitive.Item>>(
  ({ className, ...props }, ref) => <MenuPrimitive.Item ref={ref} className={cn(itemClass, className)} {...props} />,
);
DropdownMenuItem.displayName = "DropdownMenuItem";

// A choice in a group where one value is selected. It shows a check when selected.
export const DropdownMenuRadioItem = React.forwardRef<
  React.ElementRef<typeof MenuPrimitive.RadioItem>,
  React.ComponentPropsWithoutRef<typeof MenuPrimitive.RadioItem>
>(({ className, children, ...props }, ref) => (
  <MenuPrimitive.RadioItem ref={ref} className={cn(itemClass, className)} {...props}>
    {children}
    <MenuPrimitive.ItemIndicator className="ml-auto text-brand">
      <Icon name="check" />
    </MenuPrimitive.ItemIndicator>
  </MenuPrimitive.RadioItem>
));
DropdownMenuRadioItem.displayName = "DropdownMenuRadioItem";
