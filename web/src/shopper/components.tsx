import { ReactNode } from "react";

export function Steps({ labels, current }: { labels: string[]; current: number }) {
  return (
    <ol className="steps" aria-label="Progress">
      {labels.map((label, index) => (
        <li key={label} className={index + 1 < current ? "done" : index + 1 === current ? "current" : ""} aria-current={index + 1 === current ? "step" : undefined}>
          <i />
          {label}
        </li>
      ))}
    </ol>
  );
}

type ChoiceProps = {
  type: "radio" | "checkbox";
  name?: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  className: "chip" | "option" | "item";
  children: ReactNode;
};

// A radio or checkbox drawn as a chip, an option card or an item card.
export function Choice({ type, name, checked, onChange, className, children }: ChoiceProps) {
  return (
    <label className={`choice ${className}`}>
      <input type={type} name={name} checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span>{children}</span>
    </label>
  );
}

export function Stepper({ value, max, label, onChange }: { value: number; max: number; label: string; onChange: (value: number) => void }) {
  return (
    <div className="stepper" role="group" aria-label={label}>
      <button type="button" aria-label="One less" disabled={value <= 1} onClick={() => onChange(value - 1)}>
        −
      </button>
      <output>
        {value} of {max}
      </output>
      <button type="button" aria-label="One more" disabled={value >= max} onClick={() => onChange(value + 1)}>
        +
      </button>
    </div>
  );
}

