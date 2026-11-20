import { readFileSync } from "node:fs";
import { Script } from "node:vm";

const pagePath = new URL("../From/Russia/Russia.html", import.meta.url);
const html = readFileSync(pagePath, "utf8");
const blocks = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
    .filter(([, attributes]) => {
        if (/\bsrc\s*=/i.test(attributes)) return false;
        if (/\btype\s*=\s*["'](?:application\/json|application\/ld\+json)/i.test(attributes)) return false;
        return true;
    });

if (blocks.length === 0) {
    throw new Error("No inline JavaScript blocks found in From/Russia/Russia.html");
}

blocks.forEach(([, , source], index) => {
    new Script(source, {
        filename: "From/Russia/Russia.html:inline-script-" + (index + 1),
    });
});

process.stdout.write("Validated " + blocks.length + " inline JavaScript block(s) in Russia.html\n");
