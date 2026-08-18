export interface FontOption {
  number: number;
  slug: string;
  name: string;
  shortName: string;
  family: string;
  stack: string;
  googleQuery?: string;
  thesis: string;
}

const systemScriptFallbacks =
  '"PingFang SC", "Hiragino Sans", "Geeza Pro", "Helvetica Neue", -apple-system, BlinkMacSystemFont, sans-serif';

export const fontOptions: FontOption[] = [
  {
    number: 1,
    slug: "avenir-next",
    name: "Avenir Next (current)",
    shortName: "Avenir Next",
    family: "Avenir Next",
    stack: '"Avenir Next", "Helvetica Neue", -apple-system, BlinkMacSystemFont, sans-serif',
    thesis: "The current calm, humanist baseline: familiar on macOS, polished without looking ornamental.",
  },
  {
    number: 2,
    slug: "inter",
    name: "Inter",
    shortName: "Inter",
    family: "Inter",
    stack: `"Inter", ${systemScriptFallbacks}`,
    googleQuery: "Inter:wght@400;500;600;700",
    thesis: "A neutral interface workhorse with compact shapes and exceptionally clear small text.",
  },
  {
    number: 3,
    slug: "manrope",
    name: "Manrope",
    shortName: "Manrope",
    family: "Manrope",
    stack: `"Manrope", ${systemScriptFallbacks}`,
    googleQuery: "Manrope:wght@400;500;600;700",
    thesis: "A geometric option that gives the large headings more personality while keeping body copy restrained.",
  },
  {
    number: 4,
    slug: "figtree",
    name: "Figtree",
    shortName: "Figtree",
    family: "Figtree",
    stack: `"Figtree", ${systemScriptFallbacks}`,
    googleQuery: "Figtree:wght@400;500;600;700",
    thesis: "A softly rounded contemporary sans that feels approachable without turning playful.",
  },
  {
    number: 5,
    slug: "dm-sans",
    name: "DM Sans",
    shortName: "DM Sans",
    family: "DM Sans",
    stack: `"DM Sans", ${systemScriptFallbacks}`,
    googleQuery: "DM+Sans:wght@400;500;600;700",
    thesis: "A compact modern face that makes the page feel crisp and product-led.",
  },
  {
    number: 6,
    slug: "ibm-plex-sans",
    name: "IBM Plex Sans",
    shortName: "IBM Plex",
    family: "IBM Plex Sans",
    stack: `"IBM Plex Sans", ${systemScriptFallbacks}`,
    googleQuery: "IBM+Plex+Sans:wght@400;500;600;700",
    thesis: "A technical humanist face with visible character, well suited to an open-source Mac utility.",
  },
  {
    number: 7,
    slug: "source-sans-3",
    name: "Source Sans 3",
    shortName: "Source Sans",
    family: "Source Sans 3",
    stack: `"Source Sans 3", ${systemScriptFallbacks}`,
    googleQuery: "Source+Sans+3:wght@400;500;600;700",
    thesis: "An editorial utility face that prioritizes long-form readability and an unforced tone.",
  },
  {
    number: 8,
    slug: "plus-jakarta-sans",
    name: "Plus Jakarta Sans",
    shortName: "Plus Jakarta",
    family: "Plus Jakarta Sans",
    stack: `"Plus Jakarta Sans", ${systemScriptFallbacks}`,
    googleQuery: "Plus+Jakarta+Sans:wght@400;500;600;700",
    thesis: "A polished geometric direction with distinctive headings and a slightly more designed feel.",
  },
  {
    number: 9,
    slug: "public-sans",
    name: "Public Sans",
    shortName: "Public Sans",
    family: "Public Sans",
    stack: `"Public Sans", ${systemScriptFallbacks}`,
    googleQuery: "Public+Sans:wght@400;500;600;700",
    thesis: "A pragmatic, civic-feeling sans that emphasizes clarity, trust, and plainspoken utility.",
  },
  {
    number: 10,
    slug: "noto-sans",
    name: "Noto Sans",
    shortName: "Noto Sans",
    family: "Noto Sans",
    stack: `"Noto Sans", ${systemScriptFallbacks}`,
    googleQuery: "Noto+Sans:wght@400;500;600;700",
    thesis: "A globally minded workhorse whose companion families make the multilingual specimen feel intentional.",
  },
];

export const scriptFontUrls = [
  `https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;600;700&text=${encodeURIComponent("你好")}&display=swap`,
  `https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;500;600;700&text=${encodeURIComponent("こんにちは")}&display=swap`,
  `https://fonts.googleapis.com/css2?family=Noto+Sans+Arabic:wght@400;500;600;700&text=${encodeURIComponent("مرحبا")}&display=swap`,
];

export function fontOptionHref(option: FontOption): string {
  return `/font-options/option-${option.number}/`;
}

