export interface SectionOption {
  number: number;
  name: string;
  thesis: string;
  range: "restrained" | "balanced" | "expressive";
}

export const sectionOptions: SectionOption[] = [
  {
    number: 1,
    name: "Quiet statement",
    range: "restrained",
    thesis: "The least designed treatment: one centered promise, two factual sentences, and generous space.",
  },
  {
    number: 2,
    name: "Split reassurance",
    range: "restrained",
    thesis: "Pairs a fixed heading with four ruled proof rows so the section scans without becoming a card grid.",
  },
  {
    number: 3,
    name: "Product ledger",
    range: "restrained",
    thesis: "Treats speed, ownership, and privacy like a transparent product specification rather than marketing.",
  },
  {
    number: 4,
    name: "Local flow",
    range: "restrained",
    thesis: "Makes the local capture path visible, then puts storage and ownership facts directly underneath it.",
  },
  {
    number: 5,
    name: "One strong statement",
    range: "restrained",
    thesis: "Uses one large paragraph as the visual event, with the sharper privacy details acting as a coda.",
  },
  {
    number: 6,
    name: "Quiet proof column",
    range: "balanced",
    thesis: "An asymmetric two-column composition with compact proof pairs and an early history explanation.",
  },
  {
    number: 7,
    name: "One local path",
    range: "balanced",
    thesis: "A continuous line follows pixels to clipboard text while visibly ending before any cloud handoff.",
  },
  {
    number: 8,
    name: "Small-app statement",
    range: "balanced",
    thesis: "Leads with the verified 3.9 MB download size, connecting physical lightness to focused behavior.",
  },
  {
    number: 9,
    name: "Stays and leaves",
    range: "balanced",
    thesis: "A boundary-oriented comparison shows what stays on the Mac and what never enters the product.",
  },
  {
    number: 10,
    name: "Open, local footnote",
    range: "balanced",
    thesis: "Three spacious headline facts provide rhythm; one precise footnote carries the privacy detail.",
  },
  {
    number: 11,
    name: "Three-part proof",
    range: "expressive",
    thesis: "A deliberately direct three-column answer to the heading, with history promoted immediately below.",
  },
  {
    number: 12,
    name: "Screen in, text out",
    range: "expressive",
    thesis: "A visual input-output transformation uses an intentionally empty screenshot-storage field as the proof.",
  },
  {
    number: 13,
    name: "Privacy ledger",
    range: "expressive",
    thesis: "Separates always-on guarantees from the one optional persistence boundary, with a useful disclosure.",
  },
  {
    number: 14,
    name: "Small download, full promise",
    range: "expressive",
    thesis: "Stacks large factual claims like a compact manifesto, with the download size as a quiet signature.",
  },
  {
    number: 15,
    name: "The privacy refusal",
    range: "expressive",
    thesis: "Defines the product through three confident refusals, then reveals the positive guarantees on interaction.",
  },
];

export function sectionOptionHref(option: SectionOption): string {
  return `/section-options/option-${option.number}/`;
}
