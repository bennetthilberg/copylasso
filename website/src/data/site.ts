export const site = {
  name: "CopyLasso",
  version: "0.3.0",
  versionLabel: "v0.3.0",
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
    name: "Crosshair Stage",
    href: "/design-options/option-1/",
    thesis: "Make the capture action understandable within the first viewport.",
  },
  {
    number: 2,
    name: "Three-Beat Rail",
    href: "/design-options/option-2/",
    thesis: "Explain the product as a simple three-step mechanism.",
  },
  {
    number: 3,
    name: "Desktop Canvas",
    href: "/design-options/option-3/",
    thesis: "Let users recognize the native screen-selection moment immediately.",
  },
  {
    number: 4,
    name: "Privacy Receipt",
    href: "/design-options/option-4/",
    thesis: "Make privacy and data boundaries the primary conversion proof.",
  },
  {
    number: 5,
    name: "Shortcut Console",
    href: "/design-options/option-5/",
    thesis: "Position CopyLasso as a one-keystroke Mac utility for repeatable capture.",
  },
  {
    number: 6,
    name: "Copy Sheet",
    href: "/design-options/option-6/",
    thesis: "Show the transformation from visible text to clipboard with almost no chrome.",
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
