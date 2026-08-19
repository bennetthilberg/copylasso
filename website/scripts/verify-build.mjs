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

assert.equal(index.split(downloadUrl).length - 1, 2, "Both download buttons must use the release DMG.");
assert(!index.includes('href="#download"'), "Download buttons must not link to the page section.");
assert(index.includes('href="/favicon.png"'), "The page must link to the favicon.");
assert(existsSync(new URL("favicon.png", dist)), "The favicon must be included in the build.");

for (const relic of ["design-options", "font-options", "section-options"]) {
  assert(!index.includes(relic), `The public page must not include ${relic}.`);
}

const robots = readFileSync(new URL("robots.txt", dist), "utf8");
assert(!robots.includes("Disallow:"), "The production site must not retain design-lab exclusions.");

const customDomain = readFileSync(new URL("CNAME", dist), "utf8").trim();
assert.equal(customDomain, "copylasso.com", "The Pages artifact must include the custom domain.");

console.log("Website build verified.");
