// Shift all server-local "today"-keyed rows back N days to simulate the passage of time.
import { DatabaseSync } from 'node:sqlite';
const days = parseInt(process.argv[2] || '1', 10);
const db = new DatabaseSync(process.env.DB_PATH);
const cols = [
  ['checkins', 'claimDate'], ['wheel_spins', 'spinDate'], ['ad_rewards', 'claimDate'],
  ['mission_claims', 'claimDate'], ['chest_claims', 'chestDate'], ['watch_time_daily', 'watchDate'],
  ['watch_events', 'eventDate'], ['watch_progress', 'eventDate'], ['user_daily_events', 'eventDate'],
  ['share_events', 'eventDate'],
];
for (const [t, c] of cols) {
  try { const r = db.prepare(`UPDATE ${t} SET ${c} = date(${c}, '-${days} days')`).run(); console.log(t, 'shifted rows:', r.changes); }
  catch (e) { console.log(t, 'skip:', e.message); }
}
db.close();
