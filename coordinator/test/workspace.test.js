import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { generateKeyPairSync, randomBytes, createHash, sign } from 'node:crypto';
import { createCoordinator } from '../src/coordinator.js';

let server, url;
before(async () => { server = createServer(createCoordinator()); await new Promise(resolve => server.listen(0,'127.0.0.1',resolve)); url = `http://127.0.0.1:${server.address().port}`; });
after(async () => { await new Promise(resolve => server.close(resolve)); });
const canon = value => JSON.stringify(Object.fromEntries(Object.keys(value).sort().map(key => [key,value[key]])));
const sha = value => '0x'+createHash('sha256').update(canon(value)).digest('hex');
const token = () => randomBytes(32).toString('base64url');
const pair = () => { const key = generateKeyPairSync('ed25519'); return {...key, public: key.publicKey.export({format:'der',type:'spki'}).subarray(-32).toString('base64url')}; };
const box = () => ({nonce:randomBytes(12).toString('base64url'),mac:randomBytes(16).toString('base64url'),ciphertext:randomBytes(128).toString('base64url')});
const post = (path,body,credential) => fetch(url+path,{method:'POST',headers:{'content-type':'application/json',...(credential ? {authorization:`Bearer ${credential}`} : {})},body:JSON.stringify(body)});

for (const creator of ['partyA','partyB']) test(`${creator} creates and signs first; only A approves/receives, only B reports`, async () => {
  const keys = {partyA:pair(),partyB:pair()}, id=token(), ownerToken=token(), participantToken=token();
  const createPacket={domain:'civiltrust-workspace-create/1',id,creatorRole:creator,publicKey:keys[creator].public};
  const body={...createPacket,ownerToken,participantToken,createSignature:sign(null,Buffer.from(canon(createPacket)),keys[creator].privateKey).toString('base64url'),encryptedPayload:box()};
  assert.equal((await post('/v2/sessions',body)).status,201);
  assert.equal((await post('/v2/sessions',body)).status,200); // same operation after lost response
  let version=1;
  async function act(role,action,overrides={}) {
    const encryptedPayload=box();
    const packet={domain:'civiltrust-workspace-request/1',sessionId:id,role,action,expectedVersion:version,
      draftDigest:'0x'+'a'.repeat(64),payloadSha256:sha(encryptedPayload),artifactSha256:'',...overrides};
    return post(`/v2/sessions/${id}/actions`,{packet,publicKey:keys[role].public,
      signature:sign(null,Buffer.from(canon(packet)),keys[role].privateKey).toString('base64url'),encryptedPayload},role===creator ? ownerToken:participantToken);
  }
  assert.equal((await act('partyB','approve')).status,400);
  assert.equal((await act('partyA','approve')).status,200); version++;
  const other=creator==='partyA'?'partyB':'partyA';
  assert.equal((await act(other,'sign')).status,400);
  assert.equal((await act(creator,'sign')).status,200); version++;
  assert.equal((await act(other,'sign')).status,200); version++;
  assert.equal((await act('partyA','reportTransfer')).status,400);
  assert.equal((await act('partyB','reportTransfer',{expectedVersion:1})).status,409);
  assert.equal((await act('partyB','reportTransfer')).status,200); version++;
  assert.equal((await act('partyB','confirmReceived')).status,400);
  assert.equal((await act('partyA','confirmReceived')).status,200); version++;
  assert.equal((await act('partyA','approve')).status,400);
  assert.equal((await act('partyA','sign',{draftDigest:'0x'+'b'.repeat(64)})).status,409);
  const response=await fetch(`${url}/v2/sessions/${id}`,{headers:{authorization:`Bearer ${ownerToken}`}});
  const snapshot=(await response.json()).data;
  assert.equal(snapshot.phase,'paymentConfirmed'); assert.equal(snapshot.version,version); assert.equal(snapshot.creatorRole,creator);
  assert.equal((await fetch(`${url}/v1/sessions/${id}`,{headers:{authorization:`Bearer ${ownerToken}`}})).status,404);
});

test('new B proposal: A signs first, original artifact required and immutable, payment stays role-scoped', async () => {
  const keys={partyA:pair(),partyB:pair()},id=token(),ownerToken=token(),participantToken=token();
  const packet={domain:'civiltrust-workspace-create/1',id,creatorRole:'partyB',publicKey:keys.partyB.public,workflowProfile:'payer-proposal/1'};
  const body={...packet,ownerToken,participantToken,createSignature:sign(null,Buffer.from(canon(packet)),keys.partyB.privateKey).toString('base64url'),encryptedPayload:box()};
  assert.equal((await post('/v2/sessions',body)).status,201);
  assert.equal((await post('/v2/sessions',{...body,workflowProfile:'creator-independent/1'})).status,403);
  let version=1;
  const act=async(role,action,artifact=false)=>{
    const encryptedPayload=box(),encryptedArtifact=artifact?box():undefined;
    const p={domain:'civiltrust-workspace-request/1',sessionId:id,role,action,expectedVersion:version,draftDigest:'0x'+'a'.repeat(64),payloadSha256:sha(encryptedPayload),artifactSha256:encryptedArtifact?sha(encryptedArtifact):''};
    const response=await post(`/v2/sessions/${id}/actions`,{packet:p,publicKey:keys[role].public,signature:sign(null,Buffer.from(canon(p)),keys[role].privateKey).toString('base64url'),encryptedPayload,encryptedArtifact},role==='partyB'?ownerToken:participantToken);
    if(response.status===200)version++;
    return response;
  };
  assert.equal((await act('partyB','approve')).status,400);
  assert.equal((await act('partyA','approve')).status,200);
  assert.equal((await act('partyB','sign')).status,400);
  assert.equal((await act('partyA','sign')).status,200);
  assert.equal((await act('partyB','sign')).status,200);
  assert.equal((await act('partyB','reportTransfer')).status,409);
  assert.equal((await act('partyA','publishSignedArtifact',true)).status,409);
  assert.equal((await act('partyB','publishSignedArtifact',true)).status,200);
  assert.equal((await act('partyB','publishSignedArtifact',true)).status,409);
  assert.equal((await fetch(`${url}/v2/sessions/${id}/artifact`,{headers:{authorization:`Bearer ${participantToken}`}})).status,200);
  assert.equal((await act('partyA','publishArtifact',true)).status,403);
  assert.equal((await act('partyA','reportTransfer')).status,400);
  assert.equal((await act('partyB','reportTransfer')).status,200);
  assert.equal((await act('partyA','reportIssue')).status,200);
  assert.equal((await act('partyA','reportIssue')).status,409);
  assert.equal((await act('partyB','confirmReceived')).status,400);
  assert.equal((await act('partyA','confirmReceived')).status,200);
  assert.equal((await act('partyB','publishArtifact',true)).status,403);
  assert.equal((await act('partyA','publishArtifact',true)).status,200);
});
