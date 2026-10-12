// PostgreSQL is opt-in via DATABASE_URL. The original SQLite backend is
// retained for local development and for a rollback while migration is tested.
if (process.env.DATABASE_URL) {
  await import('./pg-server.mjs');
} else {
  await import('./sqlite-server.mjs');
}
