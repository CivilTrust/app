import { createHash, randomBytes, timingSafeEqual, createPublicKey, verify } from 'node:crypto';
import { corsPolicy } from './cors.js';

const profile = 'creator-independent/1';
const payerProfile = 'payer-proposal/1';
const hash = value => createHash('sha256').update(value).digest();
const canonical = value => JSON.stringify(Object.fromEntries(Object.keys(value).sort().map(key => [key, value[key]])));
const digest = value => '0x' + hash(canonical(value)).toString('hex');
const tokenHash = token => hash(token);
const token = () => randomBytes(32).toString('base64url');
const keyObject = value => {
  if (!/^[A-Za-z0-9_-]{43}$/.test(value)) throw new Error('Invalid key');
  return createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100','hex'), Buffer.from(value,'base64url')]), format:'der', type:'spki' });
};
const validBox = box => box && typeof box.ciphertext === 'string' && box.ciphertext.length < 14 * 1024 * 1024 &&
  /^[A-Za-z0-9_-]{16}$/.test(box.nonce) && /^[A-Za-z0-9_-]{22}$/.test(box.mac) && /^[A-Za-z0-9_-]+$/.test(box.ciphertext);
async function readBody(request) {
  let length = 0; const chunks = [];
  for await (const chunk of request) { length += chunk.length; if (length > 16 * 1024 * 1024) throw new Error('Payload too large'); chunks.push(chunk); }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}
function next(phase, role, creator, action, payer = false) {
  const first = payer ? 'partyA' : creator;
  if (action === 'approve' && phase === 'draft' && role === 'partyA') return 'contentFrozen';
  if (action === 'sign' && phase === 'contentFrozen' && role === first) return first === 'partyA' ? 'partyASigned' : 'partyBSigned';
  if (action === 'sign' && role !== first && ((phase === 'partyASigned' && first === 'partyA') || (phase === 'partyBSigned' && first === 'partyB'))) return 'bothSigned';
  if (payer && phase === 'draft' && role === 'partyA' && ['requestChanges','decline'].includes(action)) return action === 'decline' ? 'declined' : 'changesRequested';
  if (payer && phase === 'paymentPending' && role === 'partyA' && action === 'reportIssue') return phase;
  if (action === 'reportTransfer' && role === 'partyB' && phase === 'bothSigned') return 'paymentPending';
  if (action === 'confirmReceived' && role === 'partyA' && phase === 'paymentPending') return 'paymentConfirmed';
  throw new Error('Action not allowed for this role/state');
}

export function createWorkspaceCoordinator({store, legacy, allowedOrigins = null, now = () => Date.now(), maxSessions = 200}) {
  return async (request, response) => {
    const url = new URL(request.url, 'http://localhost');
    if (!url.pathname.startsWith('/v2/sessions')) return legacy(request, response);
    const policy = corsPolicy(request, allowedOrigins);
    const reply = (status, value) => { response.writeHead(status, {'content-type':'application/json', 'cache-control':'no-store', ...policy.headers}); response.end(JSON.stringify(value)); };
    if (!policy.allowed) return reply(403, {error:'Origin is not allowed'});
    if (request.method === 'OPTIONS') {
      const headers = (request.headers['access-control-request-headers'] || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
      if (headers.some(h => !['authorization','content-type'].includes(h))) return reply(403, {error:'Header not allowed'});
      return reply(204, {});
    }
    try {
      if (url.pathname === '/v2/sessions' && request.method === 'POST') {
        for (const id of store.keys()) { if (store.get(id).expiresAt <= now()) store.delete(id); }
        const body = await readBody(request);
        const workflowProfile = body.workflowProfile || profile;
        if (![profile,payerProfile].includes(workflowProfile) || (workflowProfile === payerProfile && body.creatorRole !== 'partyB')) return reply(400,{error:'Unsupported workflow profile'});
        if (!['partyA','partyB'].includes(body.creatorRole) || !validBox(body.encryptedPayload) ||
            ![body.id,body.ownerToken,body.participantToken].every(value => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value)) || body.ownerToken === body.participantToken) return reply(400, {error:'Invalid workflow proposal'});
        keyObject(body.publicKey);
        const packet = {domain:'civiltrust-workspace-create/1',id:body.id,creatorRole:body.creatorRole,publicKey:body.publicKey};
        if (body.workflowProfile) packet.workflowProfile = body.workflowProfile;
        if (body.domain !== packet.domain || !verify(null,Buffer.from(canonical(packet)),keyObject(body.publicKey),Buffer.from(body.createSignature || '', 'base64url'))) return reply(403,{error:'Invalid create signature'});
        const ownerToken = body.ownerToken, participantToken = body.participantToken, id = body.id;
        const existing = store.get(id);
        if (existing) {
          if (existing.workflowProfile !== workflowProfile || existing.ownerKey !== body.publicKey || existing.creatorRole !== body.creatorRole ||
              !timingSafeEqual(existing.ownerTokenHash,tokenHash(ownerToken)) || !timingSafeEqual(existing.participantTokenHash,tokenHash(participantToken))) return reply(409,{error:'Creation conflict'});
          return reply(200,{data:{id,version:existing.version,expiresAt:existing.expiresAt}});
        }
        if (store.size >= maxSessions) return reply(503, {error:'Session capacity reached'});
        const row = {id, workflowProfile, creatorRole:body.creatorRole, phase:'draft', version:1,
          ownerTokenHash:tokenHash(ownerToken), participantTokenHash:tokenHash(participantToken),
          ownerKey:body.publicKey, participantKey:null, encryptedPayload:body.encryptedPayload,
          frozenDigest:null, finalized:false, createdAt:now(), expiresAt:now()+7*86400000};
        store.set(id,row);
        return reply(201, {data:{id,version:1,expiresAt:row.expiresAt}});
      }
      const match = url.pathname.match(/^\/v2\/sessions\/([A-Za-z0-9_-]+)(?:\/(actions|artifact))?$/);
      if (!match) return reply(404,{error:'Route not found'});
      const [,id,route] = match; const row = store.get(id);
      if (!row || ![profile,payerProfile].includes(row.workflowProfile) || row.expiresAt <= now()) {
        if (row?.expiresAt <= now()) store.delete(id);
        return reply(404,{error:'Session not found or expired'});
      }
      const supplied = tokenHash(request.headers.authorization?.startsWith('Bearer ') ? request.headers.authorization.slice(7) : '');
      const owner = timingSafeEqual(supplied,row.ownerTokenHash);
      if (!owner && !timingSafeEqual(supplied,row.participantTokenHash)) return reply(401,{error:'Invalid session capability'});
      const role = owner ? row.creatorRole : row.creatorRole === 'partyA' ? 'partyB' : 'partyA';
      const keys = {[row.creatorRole]:row.ownerKey, [row.creatorRole === 'partyA' ? 'partyB' : 'partyA']:row.participantKey};
      if (!route && request.method === 'GET') return reply(200,{data:{id,creatorRole:row.creatorRole,role,phase:row.phase,version:row.version,
        finalized:row.finalized,expiresAt:row.expiresAt,encryptedPayload:row.encryptedPayload,keys,
        frozenDigest:row.frozenDigest,artifactReady:!!row.encryptedArtifact,workflowProfile:row.workflowProfile,signedArtifactReady:!!row.signedArtifact}});
      if (route === 'artifact' && request.method === 'GET') {
        const artifact=row.encryptedArtifact || row.signedArtifact;
        return artifact ? reply(200,{data:{encryptedArtifact:artifact}}) : reply(404,{error:'Artifact not published'});
      }
      if (route !== 'actions' || request.method !== 'POST') return reply(405,{error:'Method not allowed'});
      const body = await readBody(request), packet = body.packet;
      if (!packet || packet.sessionId !== id || packet.role !== role || packet.domain !== 'civiltrust-workspace-request/1') return reply(403,{error:'Role/action binding mismatch'});
      if (packet.expectedVersion !== row.version) return reply(409,{error:'Version conflict; refresh before retry'});
      const publicKey = owner ? row.ownerKey : row.participantKey || body.publicKey;
      if (body.publicKey !== publicKey || !verify(null, Buffer.from(canonical(packet)), keyObject(publicKey), Buffer.from(body.signature || '', 'base64url'))) return reply(403,{error:'Invalid action signature'});
      if (!validBox(body.encryptedPayload) || packet.payloadSha256 !== digest(body.encryptedPayload) ||
          packet.artifactSha256 !== (body.encryptedArtifact ? digest(body.encryptedArtifact) : '') ||
          !/^0x[0-9a-f]{64}$/.test(packet.draftDigest)) return reply(400,{error:'Encrypted action payload mismatch'});
      if (row.frozenDigest && packet.draftDigest !== row.frozenDigest) return reply(409,{error:'Frozen draft cannot change'});
      if (row.finalized) return reply(409,{error:'Session already finalized'});
      if (packet.action === 'publishSignedArtifact') {
        if(row.workflowProfile!==payerProfile || role!=='partyB' || row.phase!=='bothSigned' || row.signedArtifact || !validBox(body.encryptedArtifact))return reply(409,{error:'Original signed artifact is immutable or not allowed'});
        row.signedArtifact=body.encryptedArtifact;
      } else if (packet.action === 'publishArtifact') {
        if (role !== 'partyA' || row.phase !== 'paymentConfirmed' || !validBox(body.encryptedArtifact)) return reply(403,{error:'Only payee A can publish after receipt confirmation'});
        row.encryptedArtifact = body.encryptedArtifact; row.finalized = true; row.expiresAt = now()+30*86400000;
      } else {
        if (body.encryptedArtifact) return reply(400,{error:'Artifact requires publish action'});
        if(row.workflowProfile===payerProfile && packet.action==='reportTransfer' && !row.signedArtifact)return reply(409,{error:'Save original signed artifact before reporting transfer'});
        if(packet.action==='reportIssue' && row.paymentIssue)return reply(409,{error:'Payment issue already recorded'});
        row.phase = next(row.phase,role,row.creatorRole,packet.action,row.workflowProfile===payerProfile);
        if(packet.action==='reportIssue')row.paymentIssue=true;
      }
      if (packet.action === 'approve') row.frozenDigest = packet.draftDigest;
      if (!owner) row.participantKey = publicKey;
      row.encryptedPayload = body.encryptedPayload; row.version++;
      if (!store.set(id,row,packet.expectedVersion)) return reply(409,{error:'Version conflict'});
      return reply(200,{data:{version:row.version,finalized:row.finalized,expiresAt:row.expiresAt}});
    } catch (_) { return reply(400,{error:'Workflow request rejected; check role, state and payload'}); }
  };
}
