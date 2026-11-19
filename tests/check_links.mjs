// Check every local link and #anchor in the built site resolves.
// Usage: node tests/check_links.mjs _site
import fs from "fs";
import path from "path";
const root = process.argv[2] || "_site";
const pages = ["index.html", ...fs.readdirSync(path.join(root, "docs")).filter((f) => f.endsWith(".html")).map((f) => "docs/" + f)];
const ids = (file) => new Set([...fs.readFileSync(path.join(root, file), "utf8").matchAll(/id="([^"]+)"/g)].map((m) => m[1]));
let bad = 0, n = 0;
for (const page of pages) {
  const src = fs.readFileSync(path.join(root, page), "utf8");
  for (const [, url] of src.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (/^(https?:|data:|mailto:)/.test(url)) continue;
    n++;
    const [p, hash] = url.split("#");
    let target = p ? path.normalize(path.join(path.dirname(page), p)) : page;
    if (target.endsWith("/") || target === "docs" || target === ".") target = path.join(target, "index.html");
    if (!fs.existsSync(path.join(root, target))) { console.log(`MISSING ${page} -> ${url}`); bad++; continue; }
    if (hash && target.endsWith(".html") && !ids(target).has(hash)) { console.log(`NO ANCHOR ${page} -> ${url}`); bad++; }
  }
}
console.log(`${n} local links checked, ${bad} broken`);
process.exit(bad ? 1 : 0);
