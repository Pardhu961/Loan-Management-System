import { defineConfig } from 'prisma/config';
import 'dotenv/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  datasource: {
    url:
      process.env.DATABASE_URL ||
      process.env.POSTGRES_URL ||
      process.env.PRISMA_DATABASE_URL ||
      process.env.POSTGRES_PRISMA_URL ||
      `postgresql://${process.env.PGUSER || 'postgres'}:${process.env.PGPASSWORD || 'postgres'}@${process.env.PGHOST || 'localhost'}:${process.env.PGPORT || '5432'}/${process.env.PGDATABASE || 'loan_ms_db'}?schema=public`,
  },
});
