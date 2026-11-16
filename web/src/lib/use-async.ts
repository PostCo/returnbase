import { useCallback, useEffect, useState } from "react";

// Loads data when deps change. data stays null until the first load, pending is true while any request runs
// (so a page can dim old rows while new ones load), and retry runs the request again after an error.
export function useAsync<T>(load: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(true);
  const [attempt, setAttempt] = useState(0);
  const run = useCallback(load, deps);
  const retry = useCallback(() => setAttempt((n) => n + 1), []);

  useEffect(() => {
    let current = true;
    setError(null);
    setPending(true);
    run()
      .then((value) => current && setData(value))
      .catch((e: Error) => current && setError(e.message))
      .finally(() => current && setPending(false));
    return () => {
      current = false;
    };
  }, [run, attempt]);

  return { data, setData, error, pending, retry };
}
