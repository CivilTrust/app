import { createServer } from "node:http";
import { createCoordinator } from "./coordinator.js";
import { coordinatorOptions } from "./cors.js";

const port = Number(process.env.PORT || 8788);
const server = createServer(createCoordinator(coordinatorOptions()));

server.listen(port, "0.0.0.0", () => {
  console.log(`[CivilTrust App Coordinator] listening on http://localhost:${port}`);
});
