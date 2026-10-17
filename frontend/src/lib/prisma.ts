import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';

/**
 * Parses connection_limit from DATABASE_URL if present.
 * node-postgres does not natively parse connection_limit from query parameters,
 * so we extract it manually to respect configured connection boundaries.
 */
function getConnectionLimit(urlStr?: string): number | undefined {
  if (!urlStr) return undefined;
  try {
    const url = new URL(urlStr);
    const limit = url.searchParams.get('connection_limit');
    if (limit) {
      const parsed = parseInt(limit, 10);
      if (!isNaN(parsed) && parsed > 0) return parsed;
    }
  } catch {
    const match = urlStr.match(/[?&]connection_limit=(\d+)/i);
    if (match && match[1]) {
      const parsed = parseInt(match[1], 10);
      if (!isNaN(parsed) && parsed > 0) return parsed;
    }
  }
  return undefined;
}

// Support multiple cloud environment variable conventions (Vercel, Prisma Postgres, Neon)
let connectionString =
  process.env.DATABASE_URL ||
  process.env.POSTGRES_URL ||
  process.env.PRISMA_DATABASE_URL ||
  process.env.POSTGRES_PRISMA_URL;

// Auto-detect if this is the Prisma Cloud free-tier direct role ('prisma_migration')
const isMigrationRole = Boolean(connectionString && connectionString.includes('prisma_migration'));

// Auto-append connection_limit=1 if this is the single-connection migration role
if (connectionString && isMigrationRole && !connectionString.includes('connection_limit')) {
  const separator = connectionString.includes('?') ? '&' : '?';
  connectionString = `${connectionString}${separator}connection_limit=1`;
}

const parsedLimit = getConnectionLimit(connectionString);

// Conservative connection cap:
// - If the user is 'prisma_migration' (Prisma Cloud free tier), hardcap to 1 connection.
//   This automatically fixes the "too many connections for role prisma_migration" error
//   even if the variable cannot be modified in Vercel!
// - Uses explicit connection_limit / PGMAX_CONNECTIONS if provided
// - Defaults to 3 in development, 10 in production
const maxConnections =
  isMigrationRole
    ? 1
    : parsedLimit ??
      (process.env.PGMAX_CONNECTIONS
        ? parseInt(process.env.PGMAX_CONNECTIONS, 10)
        : process.env.NODE_ENV === 'production'
        ? 10
        : 3);

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
  pool: Pool | undefined;
};

// Singleton pg.Pool: Reused across Next.js module re-evaluations and hot reloads
const pool =
  globalForPrisma.pool ??
  (connectionString
    ? new Pool({
        connectionString,
        max: maxConnections,
        idleTimeoutMillis: 10000,
        connectionTimeoutMillis: 5000,
      })
    : new Pool({
        host: process.env.PGHOST || 'localhost',
        port: parseInt(process.env.PGPORT || '5432', 10),
        user: process.env.PGUSER || 'postgres',
        password: process.env.PGPASSWORD || 'postgres',
        database: process.env.PGDATABASE || 'loan_ms_db',
        max: maxConnections,
        idleTimeoutMillis: 10000,
        connectionTimeoutMillis: 5000,
      }));

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.pool = pool;
}

const adapter = new PrismaPg(pool);

// Singleton PrismaClient
export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    adapter,
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

export { pool };
export default prisma;
