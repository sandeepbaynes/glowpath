import http from 'node:http';
import {createService} from './service.mjs';
import {createLocalStore} from './stores.mjs';
const store=await createLocalStore(process.env.LEAGUE_DB || './league.sqlite');
const service=createService(store); const limits=new Map();
http.createServer(async(req,res)=>{
 const origin=req.headers.origin;
 const allowed=(process.env.ALLOWED_ORIGINS || 'http://127.0.0.1:8765,http://localhost:8765').split(',');
 if(origin && allowed.includes(origin)) res.setHeader('Access-Control-Allow-Origin',origin);
 res.setHeader('Access-Control-Allow-Headers','Content-Type,Authorization'); res.setHeader('Access-Control-Allow-Methods','GET,POST,DELETE,OPTIONS'); res.setHeader('Content-Type','application/json');
 if(req.method==='OPTIONS') {res.writeHead(204);res.end();return;}
 const key=req.socket.remoteAddress, time=Date.now(), rate=limits.get(key)||{start:time,count:0};
 if(time-rate.start>60000){rate.start=time;rate.count=0;} rate.count++; limits.set(key,rate);
 if(rate.count>60){res.writeHead(429);res.end(JSON.stringify({error:'Please wait a moment.'}));return;}
 let raw='';try{
  for await(const chunk of req){ raw+=chunk; if(Buffer.byteLength(raw)>16384){res.writeHead(413);res.end('{}');return;} }
  const answer=await service({method:req.method,path:new URL(req.url,'http://localhost').pathname,token:req.headers.authorization?.replace(/^Bearer /,''),body:raw?JSON.parse(raw):{}});
  res.writeHead(answer.status);res.end(JSON.stringify(answer.data));
 }catch {res.writeHead(400);res.end(JSON.stringify({error:'Request could not be completed.'}));}
}).listen(Number(process.env.PORT||8787),process.env.HOST||'127.0.0.1',()=>console.log('Glowpath league listening on port '+(process.env.PORT||8787)));
