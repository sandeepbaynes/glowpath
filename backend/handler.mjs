import {createNeonStore} from './stores.mjs';
import {createService} from './service.mjs';
let service;
export async function handler(event) {
 try {
  if(!process.env.DATABASE_URL) throw Error('Database is not configured');
  service ??= createService(await createNeonStore(process.env.DATABASE_URL));
  let raw=event.body||'';if(event.isBase64Encoded)raw=Buffer.from(raw,'base64').toString('utf8');
  if(Buffer.byteLength(raw)>16384)return {statusCode:413,body:'{}'};
  const answer=await service({method:event.requestContext.http.method,path:event.rawPath,token:event.headers?.authorization?.replace(/^Bearer /,''),body:raw?JSON.parse(raw):{}});
  return {statusCode:answer.status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'},body:JSON.stringify(answer.data)};
 }catch{return {statusCode:503,body:JSON.stringify({error:'Flight league is temporarily unavailable.'})};}
}
