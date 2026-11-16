import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { api, setUnauthorizedHandler } from "@/lib/api";
import type { Session } from "@/lib/types";

type SessionState = {
  session: Session | null | undefined;
  setSession: (session: Session | null) => void;
  logout: () => Promise<void>;
};

const SessionContext = createContext<SessionState | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null | undefined>(undefined);

  useEffect(() => {
    setUnauthorizedHandler(() => setSession(null));
    api<Session>("/api/me")
      .then(setSession)
      .catch(() => setSession(null));
  }, []);

  const logout = async () => {
    await api("/api/session", { method: "DELETE" });
    setSession(null);
  };

  return <SessionContext.Provider value={{ session, setSession, logout }}>{children}</SessionContext.Provider>;
}

export function useSession() {
  const context = useContext(SessionContext);
  if (!context) throw new Error("useSession needs a SessionProvider");
  return context;
}
