// Artillery hook: assigns each virtual-user scenario a random pre-provisioned
// test user (token + wallet id), so concurrent VUs behave like distinct real
// users instead of hammering the DB as a single session.
import { readFileSync } from "node:fs";

const { users } = JSON.parse(
  readFileSync(new URL("./test_users.json", import.meta.url), "utf-8")
);

if (users.length === 0) {
  throw new Error("test_users.json has no users — run `npm run provision` first.");
}

export function pickTestUser(context, events, done) {
  const u = users[Math.floor(Math.random() * users.length)];
  context.vars.token = u.accessToken;
  context.vars.userId = u.userId;
  context.vars.walletId = u.walletId;
  return done();
}
