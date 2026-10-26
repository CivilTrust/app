import { createReadStream } from "node:fs";
import { realpath, stat } from "node:fs/promises";
import { resolve, sep, extname } from "node:path";

const types = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".json": "application/json", ".wasm": "application/wasm", ".css": "text/css",
  ".png": "image/png", ".ico": "image/x-icon", ".svg": "image/svg+xml",
  ".ttf": "font/ttf", ".otf": "font/otf", ".woff2": "font/woff2",
};

export function createDemoHandler({ webRoot, coordinator }) {
  const root = resolve(webRoot);
  return async (request, response) => {
    // Serve only build/web, never workspace files. No access logs: request
    // URLs can contain capability-bearing data in misconfigured clients.
    response.setHeader("referrer-policy", "no-referrer");
    response.setHeader("x-content-type-options", "nosniff");
    response.setHeader("cache-control", "no-store");
    try {
      const url = new URL(request.url, "http://localhost");
      if (url.pathname === "/coordinator" || url.pathname.startsWith("/coordinator/")) {
        request.url = (url.pathname.slice("/coordinator".length) || "/") + url.search;
        await coordinator(request, response);
        return;
      }
      if (!["GET", "HEAD"].includes(request.method)) {
        response.writeHead(405, { allow: "GET, HEAD" }).end();
        return;
      }
      const pathname = decodeURIComponent(url.pathname);
      if (pathname.includes("\\") || pathname.includes("\0") ||
          pathname.split("/").some((part) => part.startsWith("."))) {
        response.writeHead(404).end();
        return;
      }
      const candidate = await realpath(resolve(root, `.${pathname === "/" ? "/index.html" : pathname}`));
      const actualRoot = await realpath(root);
      if (!candidate.startsWith(actualRoot + sep)) {
        response.writeHead(404).end();
        return;
      }
      const file = await stat(candidate);
      if (!file.isFile()) { response.writeHead(404).end(); return; }
      response.writeHead(200, {
        "content-type": types[extname(candidate)] ?? "application/octet-stream",
        "content-length": file.size,
      });
      if (request.method === "HEAD") { response.end(); return; }
      const stream = createReadStream(candidate);
      stream.on("error", () => response.destroy());
      stream.pipe(response);
    } catch {
      if (!response.headersSent) response.writeHead(404);
      response.end();
    }
  };
}
