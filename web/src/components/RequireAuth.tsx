import { Navigate, Outlet } from "react-router-dom";
import { Skeleton } from "@/components/ui/skeleton";
import { useSession } from "@/lib/session";

export function RequireAuth() {
  const { session } = useSession();
  if (session === undefined) {
    return (
      <div role="status" aria-label="Loading" className="grid min-h-screen place-items-center">
        <Skeleton className="w-32" />
      </div>
    );
  }
  if (session === null) return <Navigate to="/login" replace />;
  return <Outlet />;
}
