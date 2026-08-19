import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";

const dist = new URL("../dist/", import.meta.url);
const htmlFiles = readdirSync(dist, { recursive: true })
  .map(String)
  .filter((file) => file.endsWith(".html"))
  .sort();

assert.deepEqual(htmlFiles, ["index.html"], "The website must build one public HTML page.");

const index = readFileSync(new URL("index.html", dist), "utf8");
const downloadUrl =
  "https://github.com/bennetthilberg/copylasso/releases/download/v0.3.1/CopyLasso-0.3.1.dmg";

assert.equal(index.split(downloadUrl).length - 1, 4, "Every responsive download button must use the release DMG.");
assert(!index.includes('href="#download"'), "Download buttons must not link to the page section.");
assert(index.includes('href="/favicon.png"'), "The page must link to the favicon.");
assert(existsSync(new URL("favicon.png", dist)), "The favicon must be included in the build.");
assert(
  index.includes('property="og:image" content="https://copylasso.com/images/copylasso-social-card.png"'),
  "The page must declare the social sharing image.",
);
assert(
  index.includes('name="twitter:card" content="summary_large_image"'),
  "The page must request a large social sharing card.",
);
assert(
  existsSync(new URL("images/copylasso-social-card.png", dist)),
  "The social sharing image must be included in the build.",
);

function assertActionOrder(groupClass, firstLabel, secondLabel) {
  const match = index.match(new RegExp(`<div class="${groupClass}"[^>]*>([\\s\\S]*?)</div>`));
  assert(match, `The page must include ${groupClass}.`);
  assert(
    match[1].indexOf(firstLabel) < match[1].indexOf(secondLabel),
    `${firstLabel} must precede ${secondLabel} in ${groupClass}.`,
  );
}

assertActionOrder("hero-actions hero-actions-desktop", "View source on GitHub", "Download CopyLasso");
assertActionOrder("hero-actions hero-actions-mobile", "Download CopyLasso", "View source on GitHub");
assertActionOrder("closing-actions closing-actions-desktop", "View source on GitHub", "Download CopyLasso");
assertActionOrder("closing-actions closing-actions-mobile", "Download CopyLasso", "View source on GitHub");

assert(!index.includes("One short path, all on your Mac."), "The removed local-path tagline must stay absent.");
assert(
  index.includes("Screenshots are never stored. Capture History is off by default"),
  "The screenshot and Capture History statements must remain separate sentences.",
);

for (const relic of ["design-options", "font-options", "section-options"]) {
  assert(!index.includes(relic), `The public page must not include ${relic}.`);
}

const robots = readFileSync(new URL("robots.txt", dist), "utf8");
assert(!robots.includes("Disallow:"), "The production site must not retain design-lab exclusions.");

const customDomain = readFileSync(new URL("CNAME", dist), "utf8").trim();
assert.equal(customDomain, "copylasso.com", "The Pages artifact must include the custom domain.");

console.log("Website build verified.");
