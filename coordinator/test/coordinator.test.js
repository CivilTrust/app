import assert from "node:assert/strict";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import { createCoordinator } from "../src/coordinator.js";

let server;
let baseUrl;

before(async () => {
  server = createServer(createCoordinator());
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve())),
  );
});

const envelope = (value) => ({
  nonce: "bm9uY2U",
  ciphertext: Buffer.from(value).toString("base64url"),
  mac: "bWFj",
});

test("creates, reads and updates an opaque encrypted session", async () => {
  const createResponse = await fetch(`${baseUrl}/v1/sessions`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ encryptedPayload: envelope("v1") }),
  });
  assert.equal(createResponse.status, 201);
  const created = (await createResponse.json()).data;

  const readResponse = await fetch(`${baseUrl}/v1/sessions/${created.id}`, {
    headers: { authorization: `Bearer ${created.participantToken}` },
  });
  assert.equal(readResponse.status, 200);
  assert.equal((await readResponse.json()).data.version, 1);

  const updateResponse = await fetch(`${baseUrl}/v1/sessions/${created.id}`, {
    method: "PUT",
    headers: {
      authorization: `Bearer ${created.participantToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      expectedVersion: 1,
      encryptedPayload: envelope("v2"),
    }),
  });
  assert.equal(updateResponse.status, 200);
  assert.equal((await updateResponse.json()).data.version, 2);
});

test("root and health routes report coordinator readiness", async () => {
  const rootResponse = await fetch(`${baseUrl}/`);
  assert.equal(rootResponse.status, 200);
  assert.equal((await rootResponse.json()).status, "healthy");

  const healthResponse = await fetch(`${baseUrl}/health`);
  assert.equal(healthResponse.status, 200);
  assert.equal((await healthResponse.json()).service, "app-coordinator");
});

test("rejects invalid capabilities and stale writes", async () => {
  const created = (
    await (
      await fetch(`${baseUrl}/v1/sessions`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ encryptedPayload: envelope("state") }),
      })
    ).json()
  ).data;

  const unauthorized = await fetch(`${baseUrl}/v1/sessions/${created.id}`, {
    headers: { authorization: "Bearer wrong" },
  });
  assert.equal(unauthorized.status, 401);

  const conflict = await fetch(`${baseUrl}/v1/sessions/${created.id}`, {
    method: "PUT",
    headers: {
      authorization: `Bearer ${created.ownerToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      expectedVersion: 99,
      encryptedPayload: envelope("conflict"),
    }),
  });
  assert.equal(conflict.status, 409);
});

test("only the owner can finalize a session", async () => {
  const created = (
    await (
      await fetch(`${baseUrl}/v1/sessions`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ encryptedPayload: envelope("state") }),
      })
    ).json()
  ).data;

  const denied = await fetch(`${baseUrl}/v1/sessions/${created.id}/finalize`, {
    method: "POST",
    headers: { authorization: `Bearer ${created.participantToken}` },
  });
  assert.equal(denied.status, 403);

  const accepted = await fetch(`${baseUrl}/v1/sessions/${created.id}/finalize`, {
    method: "POST",
    headers: { authorization: `Bearer ${created.ownerToken}` },
  });
  assert.equal(accepted.status, 200);
  assert.equal((await accepted.json()).data.finalized, true);
});
