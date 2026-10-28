import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { corsPolicy } from "./cors.js";
import { MemorySessionStore } from './session-store.js';
import { createWorkspaceCoordinator } from './workspace-coordinator.js';

const JSON_LIMIT_BYTES = 2 * 1024 * 1024;
const DEFAULT_TTL_SECONDS = 24 * 60 * 60;
const MAX_TTL_SECONDS = 7 * 24 * 60 * 60;

function json(response, status, payload, extraHeaders = {}) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    ...extraHeaders,
  });
  response.end(JSON.stringify(payload));
}

async function readJson(request) {
  const chunks = [];
  let length = 0;
  for await (const chunk of request) {
    length += chunk.length;
    if (length > JSON_LIMIT_BYTES) {
      const error = new Error("Payload is too large");
      error.statusCode = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
  } catch {
    const error = new Error("Body must be valid JSON");
    error.statusCode = 400;
    throw error;
  }
}

function tokenHash(token) {
  return createHash("sha256").update(token, "utf8").digest();
}

function hasToken(expectedHash, token) {
  if (!token) return false;
  const actualHash = tokenHash(token);
  return (
    actualHash.length === expectedHash.length &&
    timingSafeEqual(actualHash, expectedHash)
  );
}

function bearerToken(request) {
  const value = request.headers.authorization;
  return value?.startsWith("Bearer ") ? value.slice(7) : null;
}

function randomToken(bytes = 32) {
  return randomBytes(bytes).toString("base64url");
}

function validEnvelope(value) {
  return (
    value &&
    typeof value === "object" &&
    typeof value.nonce === "string" &&
    typeof value.ciphertext === "string" &&
    typeof value.mac === "string"
  );
}

export function createCoordinator({ now = () => Date.now(), allowedOrigins = null, maxSessions = 200, store = new MemorySessionStore() } = {}) {
  const sessions = store;

  function findSession(id) {
    const session = sessions.get(id);
    if (!session) return null;
    if (session.expiresAt <= now()) {
      sessions.delete(id);
      return null;
    }
    return session;
  }

  const legacy = async function coordinatorHandler(request, response) {
    const policy = corsPolicy(request, allowedOrigins);
    const headers = policy.headers;
    if (!policy.allowed) {
      json(response, 403, { error: "Origin is not allowed" }, headers);
      return;
    }
    if (request.method === "OPTIONS") {
      const method = request.headers["access-control-request-method"];
      const requestedHeaders = (request.headers["access-control-request-headers"] ?? "")
        .split(",").map((value) => value.trim().toLowerCase()).filter(Boolean);
      if ((method && !["GET", "POST", "PUT", "DELETE"].includes(method)) ||
          requestedHeaders.some((value) => !["authorization", "content-type"].includes(value))) {
        json(response, 403, { error: "Preflight is not allowed" }, headers);
        return;
      }
      response.writeHead(204, headers);
      response.end();
      return;
    }

    const url = new URL(request.url, "http://localhost");
    if (request.method === "GET" && url.pathname === "/health") {
      json(response, 200, { status: "healthy", service: "app-coordinator" }, headers);
      return;
    }
    if (request.method === "GET" && url.pathname === "/") {
      json(response, 200, {
        status: "healthy",
        service: "app-coordinator",
        health: "/health",
        sessions: "/v1/sessions",
      }, headers);
      return;
    }

    try {
      if (request.method === "POST" && url.pathname === "/v1/sessions") {
        // Public demo has bounded storage; expired sessions are
        // reclaimed without retaining or logging capabilities/payloads.
        for (const id of sessions.keys()) findSession(id);
        if (sessions.size >= maxSessions) {
          json(response, 503, { error: "Demo session capacity reached; try again after expiry" }, headers);
          return;
        }
        const body = await readJson(request);
        if (!validEnvelope(body.encryptedPayload)) {
          json(response, 400, { error: "encryptedPayload is required" }, headers);
          return;
        }
        const ttlSeconds = Math.min(
          Math.max(Number(body.ttlSeconds) || DEFAULT_TTL_SECONDS, 60),
          MAX_TTL_SECONDS,
        );
        const id = randomToken(18);
        const ownerToken = randomToken();
        const participantToken = randomToken();
        const session = {
          id,
          ownerTokenHash: tokenHash(ownerToken),
          participantTokenHash: tokenHash(participantToken),
          encryptedPayload: body.encryptedPayload,
          version: 1,
          finalized: false,
          createdAt: now(),
          expiresAt: now() + ttlSeconds * 1000,
        };
        sessions.set(id, session);
        json(response, 201, {
          data: {
            id,
            ownerToken,
            participantToken,
            version: session.version,
            expiresAt: session.expiresAt,
          },
        }, headers);
        return;
      }

      const match = url.pathname.match(/^\/v1\/sessions\/([^/]+)(?:\/(finalize))?$/);
      if (!match) {
        json(response, 404, { error: "Route not found" }, headers);
        return;
      }

      const [, id, action] = match;
      const session = findSession(id);
      if (!session) {
        json(response, 404, { error: "Session not found or expired" }, headers);
        return;
      }
      if (session.workflowProfile) {
        json(response, 404, { error: 'Use the versioned workflow endpoint' }, headers);
        return;
      }

      const token = bearerToken(request);
      const isOwner = hasToken(session.ownerTokenHash, token);
      const isParticipant = hasToken(session.participantTokenHash, token);
      if (!isOwner && !isParticipant) {
        json(response, 401, { error: "Invalid session capability" }, headers);
        return;
      }

      if (request.method === "GET" && !action) {
        json(response, 200, {
          data: {
            id: session.id,
            encryptedPayload: session.encryptedPayload,
            version: session.version,
            finalized: session.finalized,
            expiresAt: session.expiresAt,
          },
        }, headers);
        return;
      }

      if (request.method === "PUT" && !action) {
        if (session.finalized) {
          json(response, 409, { error: "Session is already finalized" }, headers);
          return;
        }
        const body = await readJson(request);
        if (!validEnvelope(body.encryptedPayload)) {
          json(response, 400, { error: "encryptedPayload is required" }, headers);
          return;
        }
        if (body.expectedVersion !== session.version) {
          json(response, 409, {
            error: "Version conflict",
            currentVersion: session.version,
          }, headers);
          return;
        }
        session.encryptedPayload = body.encryptedPayload;
        session.version += 1;
        if (!sessions.set(id, session, body.expectedVersion)) {
          json(response, 409, { error: 'Version conflict' }, headers); return;
        }
        json(response, 200, { data: { version: session.version } }, headers);
        return;
      }

      if (request.method === "POST" && action === "finalize") {
        if (!isOwner) {
          json(response, 403, { error: "Only the owner can finalize" }, headers);
          return;
        }
        session.finalized = true;
        session.version += 1;
        if (!sessions.set(id, session, session.version - 1)) {
          json(response, 409, { error: 'Version conflict' }, headers); return;
        }
        json(response, 200, { data: { version: session.version, finalized: true } }, headers);
        return;
      }

      if (request.method === "DELETE" && !action) {
        if (!isOwner) {
          json(response, 403, { error: "Only the owner can delete" }, headers);
          return;
        }
        sessions.delete(id);
        response.writeHead(204, headers);
        response.end();
        return;
      }

      json(response, 405, { error: "Method not allowed" }, headers);
    } catch (error) {
      json(response, error.statusCode ?? 500, {
        error: error.statusCode ? error.message : "Internal server error",
      }, headers);
    }
  };
  return createWorkspaceCoordinator({ store: sessions, legacy, now, allowedOrigins, maxSessions });
}
