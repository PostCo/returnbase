// A shop's name and colours for the shopper pages. The shop list only carries a name, so the colours are picked here by name.
export type Theme = {
  accent: string;
  accentInk: string;
  canvas: string;
  paper: string;
  edge: string;
  ink: string;
  muted: string;
  soft: string;
  track: string;
  disabled: string;
};

const themes: Record<string, Theme> = {
  "Kopi Threads": { accent: "#4a2a17", accentInk: "#fff6ea", canvas: "#f3eadd", paper: "#fffcf7", edge: "#decdb7", ink: "#2b1b10", muted: "#7a5b45", soft: "#f6eee3", track: "#e0d0bc", disabled: "#c4b3a0" },
  "Lumen Home": { accent: "#1f3a5f", accentInk: "#f4f8ff", canvas: "#e9eef5", paper: "#fbfcfe", edge: "#c9d5e4", ink: "#14233a", muted: "#51647e", soft: "#eef3f9", track: "#d3ddea", disabled: "#aebbcc" },
  "Harbour & Pine": { accent: "#1f4d3a", accentInk: "#f1faf4", canvas: "#e8efe9", paper: "#fbfdfb", edge: "#c7d8cc", ink: "#15291f", muted: "#4c6656", soft: "#edf4ef", track: "#d0ded4", disabled: "#a9bdaf" },
};

const plain: Theme = { accent: "#27272a", accentInk: "#fafafa", canvas: "#f4f4f5", paper: "#ffffff", edge: "#d4d4d8", ink: "#18181b", muted: "#52525b", soft: "#f4f4f5", track: "#d4d4d8", disabled: "#a1a1aa" };

export function themeFor(shopName: string | undefined): Theme {
  return (shopName && themes[shopName]) || plain;
}

export function themeVars(theme: Theme): Record<string, string> {
  return {
    "--accent": theme.accent,
    "--accent-ink": theme.accentInk,
    "--canvas": theme.canvas,
    "--paper": theme.paper,
    "--edge": theme.edge,
    "--ink": theme.ink,
    "--muted": theme.muted,
    "--soft": theme.soft,
    "--track": theme.track,
    "--disabled": theme.disabled,
  };
}

