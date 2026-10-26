export function parseAllowedOrigins(value) {
  if (value == null || !value.trim()) return null;
  return new Set(value.split(",").map((entry) => {
    const origin = entry.trim();
    const url = new URL(origin);
    if (!["http:", "https:"].includes(url.protocol) || url.origin !== origin ||
        url.username || url.password) {
      throw new Error("ALLOWED_ORIGINS must contain exact HTTP(S) origins without paths");
    }
    return origin;
  }));
}

export function corsPolicy(request, allowedOrigins) {
  const origin = request.headers.origin;
  const headers = { vary: "Origin" };
  if (!origin) return { allowed: true, headers };
  const local = /^http:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(origin);
  const allowed = allowedOrigins ? allowedOrigins.has(origin) : local;
  if (!allowed) return { allowed: false, headers };
  return { allowed: true, headers: {
    ...headers,
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET, POST, PUT, DELETE, OPTIONS",
    "access-control-allow-headers": "Authorization, Content-Type",
    "access-control-max-age": "300",
  } };
}

export function coordinatorOptions(env = process.env) {
  const allowedOrigins = parseAllowedOrigins(env.ALLOWED_ORIGINS);
  if (env.APP_ENV === "staging" &&
      (!allowedOrigins || [...allowedOrigins].some((value) => !value.startsWith("https://")))) {
    throw new Error("Staging requires explicit HTTPS ALLOWED_ORIGINS");
  }
  return { allowedOrigins };
}
