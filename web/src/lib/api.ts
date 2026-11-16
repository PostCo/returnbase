export class ApiError extends Error {
  constructor(
    public status: number,
    public errors: string[],
  ) {
    super(errors[0] ?? `Request failed (${status})`);
  }
}

let onUnauthorized: () => void = () => {};

export function setUnauthorizedHandler(handler: () => void) {
  onUnauthorized = handler;
}

type Options = { method?: string; body?: unknown };

export async function api<T>(path: string, { method = "GET", body }: Options = {}): Promise<T> {
  const response = await fetch(path, {
    method,
    credentials: "same-origin",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (response.status === 401 && path !== "/api/session") onUnauthorized();
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new ApiError(response.status, payload.errors ?? []);
  }
  return response.status === 204 ? (undefined as T) : response.json();
}
