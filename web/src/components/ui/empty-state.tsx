import { Button } from "@/components/ui/button";
import { Icon, type IconName } from "@/components/ui/icon";

type Props = { title: string; description?: string; children?: React.ReactNode };

function Message({ icon, iconClassName, title, description, children }: Props & { icon: IconName; iconClassName?: string }) {
  return (
    <div className="flex flex-col items-center gap-2 px-4 py-10 text-center">
      <Icon name={icon} className={iconClassName ?? "size-7 text-muted-foreground"} />
      <p className="font-semibold">{title}</p>
      {description && <p className="max-w-sm text-muted-foreground">{description}</p>}
      {children}
    </div>
  );
}

// Nothing to show yet, or nothing matches. Put the next step in children, such as a button that clears the filters.
export function EmptyState({ icon = "inbox", ...props }: Props & { icon?: IconName }) {
  return <Message icon={icon} {...props} />;
}

// A load that failed. Pass retry so the merchant can try again without reloading the page.
export function ErrorState({ title, description = "Check your connection and try again.", retry }: Props & { retry?: () => void }) {
  return (
    <div role="alert">
      <Message icon="alert" iconClassName="size-7 text-danger" title={title} description={description}>
        {retry && (
          <Button variant="outline" size="sm" onClick={retry}>
            Retry
          </Button>
        )}
      </Message>
    </div>
  );
}
