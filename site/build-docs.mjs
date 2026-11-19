// Turn docs/*.md into site pages. The same Markdown reads fine on GitHub;
// here we add navigation, heading anchors, and rewrite .md links to .html.
// Usage: node site/build-docs.mjs <out dir>   (run from the repo root)
import { marked } from "marked";
import fs from "fs";
import path from "path";

const OUT = path.join(process.argv[2] || "_site", "docs");
const SRC = "docs";
const PAGES = [
  ["README.md", "Overview"],
  ["measuring.md", "Measuring"],
  ["door-mount.md", "Door mount"],
  ["hardware.md", "Hardware"],
  ["printing.md", "Printing"],
  ["assembly.md", "Assembly"],
  ["troubleshooting.md", "Troubleshooting"],
  ["parameters.md", "Parameters"],
  ["design.md", "Design notes"],
];
const FLOW = PAGES.slice(0, 6).map((p) => p[0]);  // the step-by-step path, for prev/next
const html = (f) => (f === "README.md" ? "index.html" : f.replace(/\.md$/, ".html"));
// GitHub-style heading ids, so links like assembly.md#7-mount-the-door work in both places
const slug = (t) => t.toLowerCase().replace(/<[^>]+>/g, "").replace(/&[a-z]+;/g, "").replace(/[^\w\s-]/g, "").trim().replace(/\s+/g, "-");

fs.mkdirSync(path.join(OUT, "img"), { recursive: true });
for (const f of fs.readdirSync(path.join(SRC, "img"))) fs.copyFileSync(path.join(SRC, "img", f), path.join(OUT, "img", f));

for (const [file, label] of PAGES) {
  let body = marked.parse(fs.readFileSync(path.join(SRC, file), "utf8"));
  body = body
    .replace(/<h([1-4])>(.*?)<\/h\1>/g, (_, n, t) => `<h${n} id="${slug(t)}">${t}</h${n}>`)
    .replace(/href="(?!https?:)([^"#]+)\.md(#[^"]*)?"/g, (_, p, h = "") => `href="${html(p + ".md")}${h}"`)
    .replace(/href="\.\.\/LICENSE"/g, 'href="../LICENSE"')
    .replace(/<table>/g, '<div class="tablewrap"><table>').replace(/<\/table>/g, "</table></div>");
  const title = (body.match(/<h1[^>]*>(.*?)<\/h1>/) || [, label])[1].replace(/<[^>]+>/g, "");
  const nav = PAGES.map(([f, l]) => `<a href="${html(f)}"${f === file ? ' aria-current="page"' : ""}>${l}</a>`).join("");
  const i = FLOW.indexOf(file);
  const pager = i < 0 ? "" : `<nav class="pager">${i > 0 ? `<a href="${html(FLOW[i - 1])}">← ${PAGES[i - 1][1]}</a>` : "<span></span>"}${
    i < FLOW.length - 1 ? `<a href="${html(FLOW[i + 1])}">${PAGES[i + 1][1]} →</a>` : `<a href="../">Open the generator →</a>`}</nav>`;
  fs.writeFileSync(path.join(OUT, html(file)), `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · PullGrid docs</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 34 34%22%3E%3Crect width=%2234%22 height=%2234%22 rx=%227%22 fill=%22%231f1e1b%22/%3E%3Cpath d=%22M9 6v22M17 6v22M25 6v22%22 stroke=%22%23f3f0e8%22 stroke-width=%224%22/%3E%3C/svg%3E">
<link rel="stylesheet" href="docs.css">
</head>
<body>
<header class="top"><a class="brand" href="../"><span class="logo" aria-hidden="true"></span><b>PullGrid</b></a><a class="cta" href="../">Open the generator</a></header>
<div class="wrap">
<nav class="side" aria-label="Docs">${nav}</nav>
<main>${body}${pager}</main>
</div>
<footer><b>PullGrid by Phorbie Designs</b> · <a href="https://github.com/Phorbie/PullGrid/tree/main/docs/${file}">Edit this page on GitHub</a> · <a href="../LICENSE">CC BY-SA 4.0</a></footer>
</body>
</html>
`);
}
fs.copyFileSync("site/docs.css", path.join(OUT, "docs.css"));
console.log(`docs: ${PAGES.length} pages → ${OUT}`);
