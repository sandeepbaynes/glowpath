export async function createNeonStore(url) {
 const {neon}=await import('@neondatabase/serverless'); const sql=neon(url);
 return {
  async addPilot(p) { await sql`INSERT INTO pilots(id,token_hash,name) VALUES(${p.id},${p.tokenHash},${p.name})`; },
  async findPilot(h) { return (await sql`SELECT id,name FROM pilots WHERE token_hash=${h}`)[0]; },
  async deletePilot(id) { await sql`DELETE FROM pilots WHERE id=${id}`; },
  async saveResult(r) { await sql`INSERT INTO results(pilot_id,mode,period,route,score,moves) VALUES(${r.pilotId},${r.mode},${r.period},${r.route},${r.score},${r.moves}) ON CONFLICT(pilot_id,mode,period,route) DO UPDATE SET score=EXCLUDED.score,moves=EXCLUDED.moves WHERE EXCLUDED.score > results.score OR (EXCLUDED.score = results.score AND EXCLUDED.moves < results.moves)`; },
  async leaders(mode,period) { return sql`SELECT p.id,p.name,sum(r.score)::int AS score,count(*)::int AS routes,sum(r.moves)::int AS moves FROM results r JOIN pilots p ON p.id=r.pilot_id WHERE r.mode=${mode} AND r.period=${period} GROUP BY p.id,p.name ORDER BY score DESC,routes DESC,moves ASC,p.id ASC LIMIT 50`; }
 };
}
export async function createLocalStore(filename) {
 const {DatabaseSync}=await import('node:sqlite'); const db=new DatabaseSync(filename);
 db.exec('PRAGMA foreign_keys=ON; CREATE TABLE IF NOT EXISTS pilots(id TEXT PRIMARY KEY, token_hash TEXT UNIQUE, name TEXT); CREATE TABLE IF NOT EXISTS results(pilot_id TEXT REFERENCES pilots(id) ON DELETE CASCADE, mode TEXT, period TEXT, route INTEGER, score INTEGER, moves INTEGER, PRIMARY KEY(pilot_id,mode,period,route));');
 return {
  async addPilot(p) { db.prepare('INSERT INTO pilots VALUES(?,?,?)').run(p.id,p.tokenHash,p.name); },
  async findPilot(h) { return db.prepare('SELECT id,name FROM pilots WHERE token_hash=?').get(h); },
  async deletePilot(id) { db.prepare('DELETE FROM pilots WHERE id=?').run(id); },
  async saveResult(r) { db.prepare('INSERT INTO results VALUES(?,?,?,?,?,?) ON CONFLICT(pilot_id,mode,period,route) DO UPDATE SET score=excluded.score,moves=excluded.moves WHERE excluded.score>results.score OR (excluded.score=results.score AND excluded.moves<results.moves)').run(r.pilotId,r.mode,r.period,r.route,r.score,r.moves); },
  async leaders(mode,period) { return db.prepare('SELECT p.id,p.name,sum(r.score) AS score,count(*) AS routes,sum(r.moves) AS moves FROM results r JOIN pilots p ON p.id=r.pilot_id WHERE r.mode=? AND r.period=? GROUP BY p.id,p.name ORDER BY score DESC,routes DESC,moves ASC,p.id ASC LIMIT 50').all(mode,period); },
  close() { db.close(); }
 };
}
