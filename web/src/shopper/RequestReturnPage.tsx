import { FormEvent, useState } from "react";
import { Choice, Steps, Stepper } from "./components";
import { Lookup, ReturnItemInput, Shop, shopperApi } from "./api";

type Selection = { selected: boolean; quantity: number; reason: string; resolution: "refund" | "exchange"; exchangeSku: string };
type Props = { shops: Shop[]; shopId: number; onShopChange: (id: number) => void };

const STEPS = ["Order", "Items", "Send back"];
const words = (value: string) => value.replace(/_/g, " ");

export function RequestReturnPage({ shops, shopId, onShopChange }: Props) {
  const [step, setStep] = useState(1);
  const [orderNumber, setOrderNumber] = useState("");
  const [email, setEmail] = useState("");
  const [lookup, setLookup] = useState<Lookup | null>(null);
  const [selections, setSelections] = useState<Record<string, Selection>>({});
  const [shippingKind, setShippingKind] = useState("label");
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState<string | null>(null);

  async function findOrder(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      const found = await shopperApi.lookup(shopId, orderNumber, email);
      setLookup(found);
      setSelections(
        Object.fromEntries(
          found.items.map((item) => [
            item.sku,
            { selected: false, quantity: 1, reason: found.reasons[0], resolution: "refund", exchangeSku: item.exchange_options[0]?.sku ?? "" },
          ]),
        ),
      );
      setStep(2);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  function update(sku: string, change: Partial<Selection>) {
    setSelections((current) => ({ ...current, [sku]: { ...current[sku], ...change } }));
  }

  const chosen = lookup ? lookup.items.filter((item) => selections[item.sku]?.selected) : [];

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (step === 2) return setStep(3);
    setError(null);
    const items: ReturnItemInput[] = chosen.map((item) => {
      const s = selections[item.sku];
      return {
        sku: item.sku,
        quantity: s.quantity,
        reason: s.reason,
        resolution: s.resolution,
        exchange_sku: s.resolution === "exchange" ? s.exchangeSku : undefined,
      };
    });
    try {
      const created = await shopperApi.submit(shopId, orderNumber, email, shippingKind, items);
      setSubmitted(created.number);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const errorLine = error && (
    <p className="error" role="alert">
      {error}
    </p>
  );

  if (submitted) {
    const statusUrl = `/shopper/status?${new URLSearchParams({ shop: String(shopId), number: submitted, email })}`;
    return (
      <section className="card centered" data-testid="return-submitted">
        <div className="done-mark" aria-hidden="true">
          ✓
        </div>
        <h2>
          Return <strong>{submitted}</strong> is submitted.
        </h2>
        <p>We sent a confirmation to {email}.</p>
        <a className="button ghost" href={statusUrl}>
          See its status
        </a>
      </section>
    );
  }

  return (
    <>
      <Steps labels={STEPS} current={step} />

      {step === 1 && (
        <form onSubmit={findOrder} className="card" data-testid="lookup-form">
          <h2>Start a return</h2>
          {errorLine}
          <label className="field">
            Shop
            <select value={shopId} onChange={(e) => onShopChange(Number(e.target.value))}>
              {shops.map((shop) => (
                <option key={shop.id} value={shop.id}>
                  {shop.name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Order number
            <input value={orderNumber} onChange={(e) => setOrderNumber(e.target.value)} placeholder="#1001" required />
          </label>
          <label className="field">
            Email on the order
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </label>
          <button className="button" type="submit">
            Find my order
          </button>
        </form>
      )}

      {lookup && step > 1 && (
        <form onSubmit={submit} className="card" data-testid="return-form">
          <div className="order-line">
            <span>
              Order {lookup.order.number} · {email}
            </span>
            <button className="link" type="button" onClick={() => setStep(1)}>
              Change
            </button>
          </div>
          {errorLine}

          {step === 2 && (
            <>
              <h2>Hello {lookup.order.customer}</h2>
              {lookup.items.map((item) => {
                const s = selections[item.sku];
                return (
                  <fieldset key={item.sku} className="line">
                    <Choice type="checkbox" className="item" checked={s.selected} onChange={(selected) => update(item.sku, { selected })}>
                      <svg viewBox="0 0 20 20" aria-hidden="true">
                        <path d="M7 3 3 5l1.5 3L6 7.5V17h8V7.5l1.5.5L17 5l-4-2c0 1.1-1.3 2-3 2S7 4.1 7 3z" />
                      </svg>
                      <span className="name">
                        {item.name}
                        <small>
                          {item.sku} · ordered {item.quantity}
                        </small>
                      </span>
                      <span className="tick" aria-hidden="true" />
                    </Choice>
                    {s.selected && (
                      <>
                        <div className="question">
                          <span className="legend">Quantity</span>
                          <Stepper value={s.quantity} max={item.quantity} label="Quantity" onChange={(quantity) => update(item.sku, { quantity })} />
                        </div>
                        <fieldset className="question">
                          <legend>Reason</legend>
                          <div className="chips">
                            {lookup.reasons.map((reason) => (
                              <Choice key={reason} type="radio" className="chip" name={`${item.sku}-reason`} checked={s.reason === reason} onChange={() => update(item.sku, { reason })}>
                                {words(reason)}
                              </Choice>
                            ))}
                          </div>
                        </fieldset>
                        <fieldset className="question">
                          <legend>I would like</legend>
                          <div className="chips">
                            <Choice type="radio" className="chip" name={`${item.sku}-resolution`} checked={s.resolution === "refund"} onChange={() => update(item.sku, { resolution: "refund" })}>
                              A refund
                            </Choice>
                            {item.exchange_options.length > 0 && (
                              <Choice type="radio" className="chip" name={`${item.sku}-resolution`} checked={s.resolution === "exchange"} onChange={() => update(item.sku, { resolution: "exchange" })}>
                                An exchange
                              </Choice>
                            )}
                          </div>
                        </fieldset>
                        {s.resolution === "exchange" && (
                          <div className="question">
                            <label className="field">
                              Exchange for
                              <select value={s.exchangeSku} onChange={(e) => update(item.sku, { exchangeSku: e.target.value })}>
                                {item.exchange_options.map((option) => (
                                  <option key={option.sku} value={option.sku}>
                                    {option.title}
                                  </option>
                                ))}
                              </select>
                            </label>
                          </div>
                        )}
                      </>
                    )}
                  </fieldset>
                );
              })}
              <button className="button" type="submit" disabled={chosen.length === 0}>
                Continue
              </button>
            </>
          )}

          {step === 3 && (
            <>
              <fieldset className="question first">
                <legend className="title">How will you send it back?</legend>
                {lookup.shipping_methods.map((method) => (
                  <Choice key={method.kind} type="radio" className="option" name="shipping" checked={shippingKind === method.kind} onChange={() => setShippingKind(method.kind)}>
                    <i className="dot" />
                    <b>{method.name}</b>
                  </Choice>
                ))}
              </fieldset>
              <div className="summary">
                <ul>
                  {chosen.map((item) => (
                    <li key={item.sku}>
                      {selections[item.sku].quantity} x {item.name}, {selections[item.sku].resolution}
                    </li>
                  ))}
                </ul>
              </div>
              <button className="button" type="submit">
                Submit return
              </button>
              <button className="link" type="button" onClick={() => setStep(2)}>
                Back
              </button>
            </>
          )}
        </form>
      )}
    </>
  );
}

