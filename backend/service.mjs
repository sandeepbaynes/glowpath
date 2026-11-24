import {randomBytes, createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
export const hash = v => createHash('sha256').update(v).digest('hex');
export function periodFor(mode, now = new Date()) {
  const day = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  if (mode === 'weekly') day.setUTCDate(day.getUTCDate() - (day.getUTCDay() + 6) % 7);
  return day.toISOString().slice(0, 10);
}
export function validateReplay(body) {
  return new Promise(resolve => {
    const child = spawn(process.env.REPLAY_VALIDATOR || './build/replay-validator', [], {stdio:['pipe','pipe','ignore']});
    let output = ''; let done = false;
    const finish = result => { if (!done) { done = true; clearTimeout(timer); resolve(result); } };
    const timer = setTimeout(() => { child.kill('SIGKILL'); finish({valid:false}); }, 3000);
    child.on('error', () => finish({valid:false}));
    child.stdout.on('data', chunk => { output += chunk; if(output.length > 4096) child.kill(); });
    child.on('close', () => { try { finish(JSON.parse(output)); } catch { finish({valid:false}); } });
    child.stdin.on('error', () => {});
    child.stdin.end(JSON.stringify(body));
  });
}
export function createService(store, {validator=validateReplay, now=()=>new Date()} = {}) {
  return async ({method, path, token, body={}}) => {
    const result = (status, data) => ({status, data});
    if (method === 'GET' && path === '/health') return result(200,{status:'ok', rules:'planet-v5', supportedRules:['planet-v4','planet-v5']});
    if (method === 'POST' && path === '/v1/pilots') {
      const id=randomBytes(16).toString('hex'), secret=randomBytes(32).toString('hex');
      const name=`Pilot ${id.slice(0,6).toUpperCase()}`;
      await store.addPilot({id, tokenHash:hash(secret), name});
      return result(201, {id,token:secret,name});
    }
    if (!token || !/^[a-f0-9]{64}$/.test(token)) return result(401,{error:'Join the flight league first.'});
    const pilot=await store.findPilot(hash(token));
    if (!pilot) return result(401,{error:'Pilot session expired. Join again.'});
    if (method === 'DELETE' && path === '/v1/pilots/me') {
      await store.deletePilot(pilot.id); return result(200,{deleted:true});
    }
    if (method === 'POST' && path === '/v1/results') {
      if (!['daily','weekly'].includes(body.mode) || body.period !== periodFor(body.mode,now()) ||
          !['planet-v4','planet-v5'].includes(body.layout) || !Array.isArray(body.actions) || body.actions.length > 500 ||
          body.assisted !== false) return result(400,{error:'Only current, unassisted challenge routes qualify.'});
      const proof=await validator(body);
      if (!proof.valid || !Number.isInteger(proof.score) || proof.score<0 || proof.score>200 ||
          !Number.isInteger(proof.moves) || proof.moves<1 || proof.moves>500) return result(422,{error:'The route could not be verified.'});
      await store.saveResult({pilotId:pilot.id,mode:body.mode,period:body.period,route:body.index,score:proof.score,moves:proof.moves});
      return result(200,{accepted:true,score:proof.score});
    }
    if (method === 'GET' && /^\/v1\/leaderboard\/(daily|weekly)$/.test(path)) {
      const mode=path.split('/').at(-1), period=periodFor(mode,now());
      return result(200,{mode,period,entries:await store.leaders(mode,period),pilotId:pilot.id});
    }
    return result(404,{error:'Not found'});
  };
}
