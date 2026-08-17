export const site = {
  name: "CopyLasso",
  version: "0.3.0",
  requirements: "macOS 14+ · Apple silicon + Intel",
  shortcut: "⇧⌘2",
  githubUrl: "https://github.com/bennetthilberg/copylasso",
  email: "me@bennetthilberg.com",
  downloadHref: "#download",
  downloadLabel: "Download CopyLasso 0.3.0",
};

export const directions = [
  {
    number: 1,
    name: "Paper Window",
    href: "/design-options/option-1/",
    thesis: "A quiet document window turns a spreadsheet capture into a clean clipboard result.",
  },
  {
    number: 2,
    name: "Proof Strip",
    href: "/design-options/option-2/",
    thesis: "Three visual proof moments show QR, language, and code recognition without feature-card clutter.",
  },
  {
    number: 3,
    name: "Margin Note",
    href: "/design-options/option-3/",
    thesis: "A generous reading column and a blue margin note frame the before-and-after capture story.",
  },
  {
    number: 4,
    name: "Blue Line",
    href: "/design-options/option-4/",
    thesis: "One restrained blue route carries the eye from screen pixels through recognition to clipboard.",
  },
  {
    number: 5,
    name: "Clipboard First",
    href: "/design-options/option-5/",
    thesis: "The clean clipboard result is the hero object; source pixels sit behind it as context.",
  },
  {
    number: 6,
    name: "Window Within",
    href: "/design-options/option-6/",
    thesis: "A restrained light Mac-like window makes the capture gesture immediately legible.",
  },
  {
    number: 7,
    name: "Still Frame",
    href: "/design-options/option-7/",
    thesis: "A tactile street-sign-like still proves CopyLasso can read text that is not selectable.",
  },
  {
    number: 8,
    name: "Split Screen",
    href: "/design-options/option-8/",
    thesis: "What you see and what you get stay side by side so the value is clear at a glance.",
  },
  {
    number: 9,
    name: "Quiet Catalog",
    href: "/design-options/option-9/",
    thesis: "Large visual specimens show the range of readable things instead of repeating feature copy.",
  },
  {
    number: 10,
    name: "One Gesture",
    href: "/design-options/option-10/",
    thesis: "One oversized hero gesture and only the essential proof keep the page almost weightless.",
  },
];

export const features = [
  {
    title: "Text from pixels",
    body: "Select a region of the screen and turn visible text into plain clipboard text.",
  },
  {
    title: "Runs on your Mac",
    body: "Apple Vision recognizes the selection locally, without cloud OCR or an account.",
  },
  {
    title: "Codes included",
    body: "Recognizes QR, Code 128, Data Matrix, PDF417, and Aztec codes as inert plain text.",
  },
  {
    title: "Your choice of languages",
    body: "Choose and prioritize the languages available to Apple Vision on your Mac.",
  },
  {
    title: "History is optional",
    body: "If enabled, successful output is encrypted locally. Screenshots are never stored.",
  },
  {
    title: "A small utility",
    body: "It lives in the menu bar, stays out of the Dock, and keeps the shortcut configurable.",
  },
];

export const privacyFacts = [
  "Screenshots and HUD previews are never logged, saved, or uploaded.",
  "Capture and recognition happen locally on the Mac.",
  "There is no account, cloud OCR, analytics, or telemetry.",
  "Capture History is off by default and encrypted locally when you opt in.",
];

export const compatibilityFacts = [
  "macOS 14 or newer",
  "Apple silicon and Intel",
  "Screen Recording permission for region capture",
  "MIT licensed and open source",
];
