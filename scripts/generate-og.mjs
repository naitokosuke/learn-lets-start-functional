// Generate the site-wide Open Graph image (1200x630 PNG) from an
// inline SVG. Same design language as the site: monochrome, flat,
// no shadows, no gradients.
//
//   node scripts/generate-og.mjs
import sharp from "sharp";

const svg = `<svg width="1200" height="630" viewBox="0 0 1200 630" xmlns="http://www.w3.org/2000/svg">
  <rect width="1200" height="630" fill="#0a0a0a"/>
  <rect x="28" y="28" width="1144" height="574" fill="none" stroke="#262626" stroke-width="2"/>

  <text x="96" y="330" font-family="Menlo, Consolas, monospace"
        font-size="240" font-weight="600" fill="#ededed">&#8706;</text>

  <text x="330" y="270" font-family="Helvetica Neue, Helvetica, Arial, sans-serif"
        font-size="64" font-weight="700" fill="#ffffff">Let's Start Functional</text>

  <text x="332" y="330" font-family="Helvetica Neue, Helvetica, Arial, sans-serif"
        font-size="30" fill="#9a9a9a">Build a linear-time regex engine in Idris 2,</text>
  <text x="332" y="374" font-family="Helvetica Neue, Helvetica, Arial, sans-serif"
        font-size="30" fill="#9a9a9a">test-first — and learn functional programming on the way.</text>

  <text x="332" y="452" font-family="Menlo, Consolas, monospace"
        font-size="22" fill="#6e6e6e">matches r s = nullable (foldl (flip deriv) r (unpack s))</text>

  <text x="96" y="546" font-family="Menlo, Consolas, monospace"
        font-size="22" fill="#6e6e6e">lets-start-functional.void.app</text>
</svg>`;

await sharp(Buffer.from(svg), { density: 96 }).png().toFile("public/og.png");
console.log("public/og.png written");
