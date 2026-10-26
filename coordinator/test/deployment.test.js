import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, dirname, basename, resolve } from "node:path";
import { test } from "node:test";
import { createCoordinator } from "../src/coordinator.js";
import { parseAllowedOrigins, coordinatorOptions } from "../src/cors.js";
import { createDemoHandler } from "../src/demo-handler.js";

test("staging requires explicit HTTPS origins; invalid origins are rejected", () => {
  assert.throws(() => coordinatorOptions({ APP_ENV: "staging" }));
  for (const value of ["*", "https://demo.test/", "https://demo.test?q=token", "null", "https://a:b@demo.test"]) {
    assert.throws(() => parseAllowedOrigins(value));
  }
  assert.throws(() => coordinatorOptions({ APP_ENV: "staging", ALLOWED_ORIGINS: "http://demo.test" }));
  assert.deepEqual([...coordinatorOptions({ APP_ENV: "staging", ALLOWED_ORIGINS: "https://demo.test" }).allowedOrigins], ["https://demo.test"]);
});

test("demo serves only compiled assets and coordinator with exact CORS", async () => {
  const root = await mkdtemp(join(tmpdir(), "civiltrust-demo-"));
  const webRoot = join(root, "web");
  await mkdir(webRoot);
  await writeFile(join(webRoot, "index.html"), "demo-public-build");
  await writeFile(join(root, "private.txt"), "outside-build-secret");
  const server = createServer(createDemoHandler({ webRoot,
    coordinator: createCoordinator({ allowedOrigins: new Set(["https://demo.test"]) }),
  }));
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const index = await fetch(base);
    assert.equal(await index.text(), "demo-public-build");
    assert.equal(index.headers.get("referrer-policy"), "no-referrer");
    for (const path of ["/private.txt", "/%2e%2e%2fprivate.txt", "/%2e%2e%5cprivate.txt", "/.git/config", "/%00"]) {
      assert.equal((await fetch(base + path)).status, 404, path);
    }
    assert.equal((await fetch(base, { method: "POST" })).status, 405);
    const health = await fetch(`${base}/coordinator/health`, { headers: { origin: "https://demo.test" } });
    assert.equal((await health.json()).service, "app-coordinator");
    assert.equal(health.headers.get("access-control-allow-origin"), "https://demo.test");
    const allowed = await fetch(`${base}/coordinator/v1/sessions`, { method: "OPTIONS", headers: {
      origin: "https://demo.test", "access-control-request-method": "PUT",
      "access-control-request-headers": "authorization,content-type",
    } });
    assert.equal(allowed.status, 204);
    const denied = await fetch(`${base}/coordinator/v1/sessions`, { method: "POST", headers: {
      origin: "https://evil.test", "content-type": "application/json",
    }, body: "{}" });
    assert.equal(denied.status, 403);
    assert.equal(denied.headers.get("access-control-allow-origin"), null);
    const badHeader = await fetch(`${base}/coordinator/health`, { method: "OPTIONS", headers: {
      origin: "https://demo.test", "access-control-request-method": "GET", "access-control-request-headers": "x-unexpected",
    } });
    assert.equal(badHeader.status, 403);
  } finally {
    await new Promise((done) => server.close(done));
    if (dirname(resolve(root)) !== resolve(tmpdir()) || !basename(root).startsWith("civiltrust-demo-")) {
      throw new Error("Unexpected test cleanup directory");
    }
    await rm(root, { recursive: true, force: true });
  }
});

test("public mock coordinator bounds sessions and reclaims expired entries", async () => {
  let now = Date.now();
  const server = createServer(createCoordinator({ now: () => now, maxSessions: 1 }));
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  const base = `http://127.0.0.1:${server.address().port}`;
  const create = () => fetch(`${base}/v1/sessions`, { method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ encryptedPayload: { nonce: "n", ciphertext: "c", mac: "m" }, ttlSeconds: 60 }),
  });
  try {
    assert.equal((await create()).status, 201);
    assert.equal((await create()).status, 503);
    now += 61000;
    assert.equal((await create()).status, 201);
    const evil = await fetch(`${base}/health`, { headers: { origin: "http://other.test" } });
    assert.equal(evil.status, 403);
    const local = await fetch(`${base}/health`, { headers: { origin: "http://localhost:12345" } });
    assert.equal(local.status, 200);
  } finally { await new Promise((done) => server.close(done)); }
});
