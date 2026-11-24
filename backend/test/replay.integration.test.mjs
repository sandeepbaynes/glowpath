import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync, readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createService, validateReplay} from '../service.mjs';
import {createLocalStore} from '../stores.mjs';

// Golden planet-v4 replay produced by make_replay.dart. This test invokes the
// real compiled Dart rules; it never substitutes a permissive score validator.
const proof = JSON.parse(readFileSync(new URL('./valid-replay.json', import.meta.url)));
const validator = process.env.REPLAY_VALIDATOR ||
  fileURLToPath(new URL('../build/replay-validator', import.meta.url));
process.env.REPLAY_VALIDATOR = validator;
const options = {skip: existsSync(validator) ? false : 'Compile backend/build/replay-validator first'};
const fixed = () => new Date(`${proof.period}T12:00:00Z`);

test('real Dart rules accept the fixture and reject incomplete or post-win actions', options, async () => {
  const checked = await validateReplay(proof);
  assert.equal(checked.valid, true);
  assert.equal(checked.moves, proof.actions.length);
  assert.ok(checked.score >= 100 && checked.score <= 200);
  for (const actions of [[], proof.actions.slice(0, -1), [...proof.actions, 0]]) {
    assert.equal((await validateReplay({...proof, actions})).valid, false);
  }
});

test('real Dart rules reject invalid indices, action types and calendar periods', options, async () => {
  for (const change of [
    {index: 3}, {actions: [-1]}, {actions: [25]}, {actions: ['7']},
    {period: '2026-02-30'}, {mode: 'weekly', period: '2026-11-22'},
    {layout: 'planet-v99'},
  ]) {
    assert.equal((await validateReplay({...proof, ...change})).valid, false,
      JSON.stringify(change));
  }
});

test('service derives the score from real replay and stores one best result', options, async () => {
  const store = await createLocalStore(':memory:');
  const api = createService(store, {now: fixed});
  try {
    const pilot = (await api({method: 'POST', path: '/v1/pilots'})).data;
    const checked = await validateReplay(proof);
    for (let attempt = 0; attempt < 2; attempt++) {
      const answer = await api({method: 'POST', path: '/v1/results', token: pilot.token,
        body: {...proof, score: 999999, solved: true}});
      assert.equal(answer.status, 200);
      assert.equal(answer.data.score, checked.score);
    }
    const board = (await api({method: 'GET', path: '/v1/leaderboard/daily', token: pilot.token})).data;
    assert.equal(board.entries.length, 1);
    assert.equal(board.entries[0].routes, 1);
    assert.equal(board.entries[0].moves, proof.actions.length);
    assert.equal(board.entries[0].score, checked.score);
  } finally {
    store.close();
  }
});

test('service excludes assisted, old-layout and stale-period proofs before scoring', options, async () => {
  const store = await createLocalStore(':memory:');
  const api = createService(store, {now: fixed});
  try {
    const pilot = (await api({method: 'POST', path: '/v1/pilots'})).data;
    for (const change of [{assisted: true}, {layout: 'voyage-v3'}, {period: '2026-11-21'}]) {
      assert.equal((await api({method: 'POST', path: '/v1/results', token: pilot.token,
        body: {...proof, ...change}})).status, 400);
    }
    assert.deepEqual((await api({method: 'GET', path: '/v1/leaderboard/daily', token: pilot.token})).data.entries, []);
  } finally {
    store.close();
  }
});


test('strategic v5 replay uses its own generator and cannot be relabeled v4', options, async () => {
  const strategic = JSON.parse(readFileSync(new URL('./valid-strategic-replay.json', import.meta.url)));
  const checked = await validateReplay(strategic);
  assert.equal(checked.valid, true);
  assert.equal(checked.moves, strategic.actions.length);
  assert.equal((await validateReplay({...strategic, layout: 'planet-v4'})).valid, false);
  assert.equal((await validateReplay({...strategic, actions: strategic.actions.slice(0, -1)})).valid, false);
});
