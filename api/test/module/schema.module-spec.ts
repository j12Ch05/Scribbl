import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client';

describe('database schema (module)', () => {
  const prisma = new PrismaClient({
    adapter: new PrismaPg({
      connectionString: process.env.DATABASE_URL!,
      max: 2,
    }),
  });
  afterAll(() => prisma.$disconnect());

  it('has the 12 seeded tags', async () => {
    const r = await prisma.$queryRaw<
      { n: number }[]
    >`select count(*)::int as n from tags`;
    expect(r[0].n).toBe(12);
  });

  it('keeps the three partial unique indexes with their WHERE', async () => {
    const r = await prisma.$queryRaw<{ indexdef: string }[]>`
        select indexdef from pg_indexes where schemaname = 'public'
        and indexname in ('one_active_session_per_user','one_active_subscription','one_pending_invite_per_email')`;

    expect(r).toHaveLength(3);
    r.forEach((i) => expect(i.indexdef).toContain(' WHERE '));
  });

  it('keeps the triggers and functions', async () => {
    const t = await prisma.$queryRaw<{ n: number }[]>`
        select count(*)::int as n from pg_trigger where tgname in
        ('users_purge_stamp','workspaces_purge_stamp','notes_purge_stamp','events_purge_stamp','events_set_end','sessions_release_locks')`;

    expect(t[0].n).toBe(6);

    const f = await prisma.$queryRaw<{ n: number }[]>`
        select count(*)::int as n from pg_proc where proname in
        ('acquire_note_lock','take_over_note_lock','pick_mail_account','stamp_purge_after')`;

    expect(f[0].n).toBe(4);
  });
});
