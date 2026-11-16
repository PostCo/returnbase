import { Link, NavLink, Outlet } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Icon, type IconName } from "@/components/ui/icon";
import { useSession } from "@/lib/session";
import { cn } from "@/lib/utils";

const NAV: { to: string; label: string; icon: IconName }[] = [
  { to: "/returns", label: "Returns", icon: "returns" },
  { to: "/locations", label: "Locations", icon: "pin" },
  { to: "/integrations", label: "Integrations", icon: "plug" },
  { to: "/settings", label: "Settings", icon: "settings" },
];

function initials(name: string) {
  return name
    .split(/\s+/)
    .map((word) => word[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
}

// A sidebar on desktop, and a top bar with the nav scrolling sideways on a phone.
export function Layout() {
  const { session, logout } = useSession();
  const shopName = session?.shop.name ?? "";

  return (
    <div className="min-h-screen md:grid md:grid-cols-[232px_minmax(0,1fr)]">
      <aside className="flex flex-wrap items-center gap-x-2 gap-y-1 border-b px-3 pt-2.5 md:sticky md:top-0 md:h-screen md:flex-col md:items-stretch md:flex-nowrap md:gap-4 md:border-r md:border-b-0 md:px-3 md:py-4">
        <div className="flex items-center gap-2 px-2 py-1 text-[15px] font-bold tracking-tight">
          <span className="grid size-[22px] place-items-center rounded-md bg-brand text-xs text-white">R</span>
          Returnbase
        </div>
        <div className="ml-auto flex min-w-0 items-center gap-2 rounded-[10px] border bg-card px-2 py-1.5 font-medium md:ml-0 md:p-2">
          <span className="grid size-6 shrink-0 place-items-center rounded-md bg-[#f1e7da] text-[10.5px] text-[#5a3b22]">{initials(shopName)}</span>
          <span className="truncate" data-testid="shop-name">
            {shopName}
          </span>
        </div>
        <nav className="-mx-3 flex w-full gap-0.5 overflow-x-auto px-3 [scrollbar-width:none] md:mx-0 md:flex-col md:overflow-visible md:px-0">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-2.5 rounded-t-lg px-2.5 py-2 font-medium whitespace-nowrap text-[#45403c] hover:bg-foreground/5 md:rounded-lg md:py-[7px]",
                  isActive && "text-foreground shadow-[inset_0_-2px_0_var(--brand)] hover:bg-transparent md:bg-card md:shadow-[inset_0_0_0_1px_var(--border)] md:hover:bg-card",
                )
              }
            >
              {({ isActive }) => (
                <>
                  <Icon name={item.icon} className={isActive ? "text-brand" : undefined} />
                  {item.label}
                </>
              )}
            </NavLink>
          ))}
          <Button variant="ghost" size="sm" className="my-auto ml-auto md:hidden" onClick={logout}>
            Log out
          </Button>
        </nav>
        <div className="mt-auto hidden flex-col gap-2 border-t px-2 pt-3 text-xs text-muted-foreground md:flex">
          <div className="truncate">{session?.user.email}</div>
          <Button variant="outline" size="sm" onClick={logout}>
            Log out
          </Button>
        </div>
      </aside>
      <main className="mx-auto w-full max-w-[1200px] min-w-0 px-4 pt-4 pb-10 md:mx-0 md:px-8 md:pt-6 md:pb-12">
        <Outlet />
      </main>
    </div>
  );
}

type HeaderProps = {
  title: string;
  // A parent page to go back to, shown above the title.
  back?: { to: string; label: string };
  // A status badge shown beside the title.
  badge?: React.ReactNode;
  // A line of context under the title.
  meta?: React.ReactNode;
  // The page's actions. They fill the width on a phone.
  children?: React.ReactNode;
};

export function PageHeader({ title, back, badge, meta, children }: HeaderProps) {
  return (
    <header data-testid="page-header" className="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between md:gap-4">
      <div className="min-w-0">
        {back && (
          <Link to={back.to} className="mb-1.5 inline-flex items-center gap-1 text-[13px] text-muted-foreground hover:text-foreground">
            <Icon name="arrowLeft" />
            {back.label}
          </Link>
        )}
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-2xl/8 font-semibold tracking-tight">{title}</h1>
          {badge}
        </div>
        {meta && <p className="mt-1 text-[13px] text-muted-foreground">{meta}</p>}
      </div>
      {children && <div className="flex gap-2 max-md:*:flex-1 max-md:*:h-11 md:items-center">{children}</div>}
    </header>
  );
}
