import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { access } from "node:fs/promises";
import { createCoordinator } from "./coordinator.js";
import { coordinatorOptions } from "./cors.js";
import { createDemoHandler } from "./demo-handler.js";
import { SqliteSessionStore } from './session-store.js';

const webRoot = fileURLToPath(new URL("../../build/web/", import.meta.url));
await access(new URL("../../build/web/index.html", import.meta.url));
const server = createServer(createDemoHandler({
  webRoot,
  coordinator: createCoordinator({ ...coordinatorOptions(), store: new SqliteSessionStore(
    process.env.COORDINATOR_DB_PATH || fileURLToPath(new URL('../../.demo/coordinator.sqlite', import.meta.url))) }),
}));
const port = Number(process.env.PORT || 8790);
server.listen(port, "127.0.0.1", () => {
  console.log(`CivilTrust mock demo listening on loopback port ${port}`);
});
