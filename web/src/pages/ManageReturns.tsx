import { useEffect, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { FilterMenu } from "@/components/FilterMenu";
import { PageHeader } from "@/components/Layout";
import { StatusBadge } from "@/components/StatusBadge";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState, ErrorState } from "@/components/ui/empty-state";
import { Icon } from "@/components/ui/icon";
import { SearchInput } from "@/components/ui/input";
import { Pagination } from "@/components/ui/pagination";
import { TableSkeleton } from "@/components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { api } from "@/lib/api";
import { STATUSES, type ReturnSummary } from "@/lib/types";
import { useAsync } from "@/lib/use-async";
import { cn, formatDate, humanize } from "@/lib/utils";
import type { IntegrationSummary } from "@/pages/integrations/types";

const PER_PAGE = 20;
const ALL_TAB = "all";
const SHIPPING_OPTIONS = [
  { value: "", label: "All" },
  { value: "label", label: "Prepaid label" },
  { value: "own_postage", label: "Own postage" },
];
const STORE_BOX_OPTIONS = [
  { value: "", label: "All" },
  { value: "send_failed", label: "StoreBox send failed" },
];

export default function ManageReturns() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const status = params.get("status") ?? "";
  const shipping = params.get("shipping") ?? "";
  const storeBox = params.get("store_box") ?? "";
  const q = params.get("q") ?? "";
  const page = Number(params.get("page") ?? 1);
  const [search, setSearch] = useState(q);

  const update = (changes: Record<string, string>) => {
    const next = new URLSearchParams(params);
    for (const [key, value] of Object.entries({ page: "", ...changes })) {
      if (value) next.set(key, value);
      else next.delete(key);
    }
    setParams(next, { replace: true });
  };

  useEffect(() => {
    if (search === q) return;
    const timer = setTimeout(() => update({ q: search }), 300);
    return () => clearTimeout(timer);
  }, [search]);

  const query = new URLSearchParams(Object.entries({ status, shipping, store_box: storeBox, q }).filter(([, value]) => value));
  const { data, error, pending, retry } = useAsync(
    () => api<{ returns: ReturnSummary[]; total: number }>(`/api/returns?${new URLSearchParams([...query, ["page", String(page)]])}`),
    [status, shipping, storeBox, q, page],
  );
  const { data: integrations } = useAsync(() => api<{ integrations: IntegrationSummary[] }>("/api/integrations"), []);
  const hasStoreBox = integrations?.integrations.some((i) => i.type === "StoreBoxIntegration" && i.status) ?? false;
  const total = data?.total ?? 0;

  const filters = [
    status && humanize(status),
    shipping && SHIPPING_OPTIONS.find((option) => option.value === shipping)?.label,
    storeBox && STORE_BOX_OPTIONS.find((option) => option.value === storeBox)?.label,
    q && `"${q}"`,
  ].filter(Boolean);
  const clearFilters = () => {
    setSearch("");
    setParams({}, { replace: true });
  };

  return (
    <>
      <PageHeader title="Manage returns">
        <Button variant="outline" asChild>
          <a href={`/api/returns/export.csv?${query}`} download>
            <Icon name="download" />
            Export CSV
          </a>
        </Button>
      </PageHeader>

      <Tabs value={status || ALL_TAB} onValueChange={(value) => update({ status: value === ALL_TAB ? "" : value })}>
        <TabsList className="mb-3" aria-label="Status">
          <TabsTrigger value={ALL_TAB}>All</TabsTrigger>
          {STATUSES.map((s) => (
            <TabsTrigger key={s} value={s}>
              {humanize(s)}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <SearchInput
          className="min-w-0 basis-full md:basis-80"
          placeholder="Search return, order or email"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          aria-label="Search returns"
        />
        <FilterMenu label="Shipping" value={shipping} options={SHIPPING_OPTIONS} onChange={(value) => update({ shipping: value })} />
        {(hasStoreBox || storeBox) && (
          <FilterMenu label="StoreBox" value={storeBox} options={STORE_BOX_OPTIONS} onChange={(value) => update({ store_box: value })} />
        )}
      </div>

      <Card>
        {error ? (
          <ErrorState title="Couldn't load returns." retry={retry} />
        ) : data && data.returns.length === 0 ? (
          filters.length > 0 ? (
            <EmptyState icon="search" title="No returns match these filters.">
              <div className="flex flex-wrap justify-center gap-1.5">
                {filters.map((filter) => (
                  <Badge key={String(filter)} className="bg-brand-soft text-brand">
                    {filter}
                  </Badge>
                ))}
              </div>
              <Button variant="outline" size="sm" onClick={clearFilters}>
                Clear filters
              </Button>
            </EmptyState>
          ) : (
            <EmptyState title="No returns yet." description="Returns your shoppers request will show up here." />
          )
        ) : (
          <>
            <Table className={cn("transition-opacity", pending && data && "opacity-60")}>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="max-md:hidden">Order</TableHead>
                  <TableHead>Return</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Customer</TableHead>
                  <TableHead className="max-md:hidden">Shipping</TableHead>
                  <TableHead className="max-md:hidden">Created</TableHead>
                </TableRow>
              </TableHeader>
              {data ? (
                <TableBody>
                  {data.returns.map((r) => (
                    <TableRow
                      key={r.id}
                      className="cursor-pointer"
                      onClick={(e) => !(e.target as HTMLElement).closest("a") && navigate(`/returns/${r.id}`)}
                    >
                      <TableCell className="font-mono text-[12.5px] max-md:hidden">{r.order.number}</TableCell>
                      <TableCell>
                        <Link className="font-mono text-[12.5px] font-medium text-brand hover:underline" to={`/returns/${r.id}`}>
                          {r.number}
                        </Link>
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={r.status} />
                      </TableCell>
                      <TableCell>
                        <div className="font-medium">{r.customer.name}</div>
                        <div className="text-[12.5px] text-muted-foreground">{r.customer.email}</div>
                      </TableCell>
                      <TableCell className="max-md:hidden">
                        <span className="inline-flex items-center gap-1.5 text-[13px] text-[#45403c]">
                          <Icon name={r.shipping_method.kind === "label" ? "card" : "mail"} className="text-muted-foreground" />
                          {r.shipping_method.kind === "label" ? "Prepaid label" : "Own postage"}
                        </span>
                      </TableCell>
                      <TableCell className="whitespace-nowrap max-md:hidden">{formatDate(r.created_at)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              ) : (
                <TableSkeleton columns={6} hiddenOnPhone={[0, 4, 5]} />
              )}
            </Table>
            {data && <Pagination page={page} perPage={PER_PAGE} total={total} noun="returns" onPage={(next) => update({ page: String(next) })} />}
          </>
        )}
      </Card>
    </>
  );
}
