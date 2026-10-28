import { createServer } from "node:http";
import { createCoordinator } from "./coordinator.js";
import { coordinatorOptions } from "./cors.js";
import { SqliteSessionStore } from './session-store.js';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT || 8788);
const store = new SqliteSessionStore(process.env.COORDINATOR_DB_PATH || fileURLToPath(new URL('../../.demo/coordinator.sqlite', import.meta.url)));
const server = createServer(createCoordinator({ ...coordinatorOptions(), store }));

server.listen(port, "0.0.0.0", () => {
  console.log(`[CivilTrust App Coordinator] listening on http://localhost:${port}`);
});
