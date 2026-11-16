import { useEffect, useState } from "react";
import { ReturnStatus, shopperApi } from "./api";

export function StatusPage() {
  const query = new URLSearchParams(window.location.search);
  const [status, setStatus] = useState<ReturnStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const formUrl = `/shopper?${new URLSearchParams({ shop: query.get("shop") ?? "" })}`;

  useEffect(() => {
    shopperApi
      .status(query.get("shop") ?? "", query.get("number") ?? "", query.get("email") ?? "")
      .then(setStatus)
      .catch((e: Error) => setError(e.message));
  }, []);

  const cancel = async () => {
    if (!window.confirm("Cancel this return? You will not need to send the parcel.")) return;
    try {
      setStatus(await shopperApi.cancel(query.get("shop") ?? "", query.get("number") ?? "", query.get("email") ?? ""));
    } catch (e) {
      setError((e as Error).message);
    }
  };

  if (error)
    return (
      <>
        <p className="error card" role="alert">
          {error}
        </p>
        <a className="link" href={formUrl}>
          Back to the return form
        </a>
      </>
    );
  if (!status) return <p className="card">Loading...</p>;

  return (
    <section className="card" data-testid="return-status">
      <h2>Return {status.number}</h2>
      <p className="status-line">
        For order {status.order_number}:{" "}
        <strong className="status-pill" data-testid="status">
          {status.status.replace(/_/g, " ")}
        </strong>
      </p>
      <ul className="plain-list">
        {status.items.map((item) => (
          <li key={item.name}>
            {item.quantity} x {item.name}, {item.resolution}
            {item.exchange_for ? ` for ${item.exchange_for}` : ""}
            {item.outcome ? ` (${item.outcome === "accepted" ? "Accepted" : "Not accepted"})` : ""}
          </li>
        ))}
      </ul>
      {status.shipping.label_pending && <p className="note">Your prepaid label is on its way. We will email it to you.</p>}
      {status.shipping.label_url && (
        <p className="note">
          <a href={status.shipping.label_url}>Print your prepaid label</a> (tracking {status.shipping.tracking_number})
        </p>
      )}
      {status.shipping.instructions && <p className="note">{status.shipping.instructions}</p>}
      {status.refunds.map((refund) => (
        <p className="note" key={refund.amount}>
          Refunded {refund.amount}
        </p>
      ))}
      {status.exchanges.map((exchange) => (
        <p className="note" key={exchange.name}>
          Replacement {exchange.name}: {exchange.status}
        </p>
      ))}
      {status.can_cancel && (
        <button className="button ghost danger" type="button" onClick={cancel}>
          Cancel this return
        </button>
      )}
      <a className="link" href={formUrl}>
        Back to the return form
      </a>
      <ol className="timeline">
        {status.timeline.map((entry) => (
          <li key={entry.at + entry.status}>
            <b>{entry.status.replace(/_/g, " ")}</b>
            <small>{new Date(entry.at).toLocaleString()}</small>
          </li>
        ))}
      </ol>
    </section>
  );
}

