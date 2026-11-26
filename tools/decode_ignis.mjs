import fs from 'node:fs';
import { MeshoptDecoder } from 'meshoptimizer';
await MeshoptDecoder.ready;
const input = fs.readFileSync('assets/tripo/ignis_x1_source.glb');
if(input.toString('ascii',0,4)!=='glTF'||input.readUInt32LE(4)!==2||input.readUInt32LE(8)!==input.length) throw Error('Invalid GLB');
const jsonSize=input.readUInt32LE(12);
const doc=JSON.parse(input.toString('utf8',20,20+jsonSize));
const bin=input.subarray(28+jsonSize);
const chunks=[];
let offset=0;
const append=(bytes)=>{const b=Buffer.from(bytes);const start=offset;chunks.push(b);offset+=b.length;const padding=(4-offset%4)%4;if(padding){chunks.push(Buffer.alloc(padding));offset+=padding;}return start;};
for(const view of doc.bufferViews){
 const ext=view.extensions?.EXT_meshopt_compression;
 let decoded;
 if(ext){
   if(ext.buffer!==0||ext.byteOffset+ext.byteLength>bin.length)throw Error('Invalid compressed range');
   decoded=new Uint8Array(ext.count*ext.byteStride);
   MeshoptDecoder.decodeGltfBuffer(decoded,ext.count,ext.byteStride,bin.subarray(ext.byteOffset,ext.byteOffset+ext.byteLength),ext.mode,ext.filter||'NONE');
 } else {
   if(view.buffer!==0)throw Error('Unexpected buffer');
   decoded=bin.subarray(view.byteOffset||0,(view.byteOffset||0)+view.byteLength);
 }
 view.buffer=0;view.byteOffset=append(decoded);view.byteLength=decoded.byteLength;delete view.extensions;
}
let buffer=Buffer.concat(chunks);
// Expand the packed signed-byte normals into ordinary float normals.
const normal=doc.accessors[doc.meshes[0].primitives[0].attributes.NORMAL];
if(normal.componentType===5120&&normal.normalized){
 const v=doc.bufferViews[normal.bufferView];const out=Buffer.alloc(normal.count*12);
 for(let i=0;i<normal.count;i++){
   const start=v.byteOffset+(normal.byteOffset||0)+i*(v.byteStride||3);
   const xyz=[0,1,2].map(k=>Math.max(-1,buffer.readInt8(start+k)/127));
   const length=Math.hypot(...xyz)||1;
   xyz.forEach((x,k)=>out.writeFloatLE(x/length,i*12+k*4));
 }
 normal.bufferView=doc.bufferViews.length;normal.byteOffset=0;normal.componentType=5126;delete normal.normalized;
 doc.bufferViews.push({buffer:0,byteOffset:append(out),byteLength:out.length,target:34962});
}
buffer=Buffer.concat(chunks);
// Normalize the fictional asset's long horizontal axis. Keep source geometry intact.
const prim=doc.meshes[0].primitives[0], pos=doc.accessors[prim.attributes.POSITION], pv=doc.bufferViews[pos.bufferView];
const pts=Array.from({length:pos.count},(_,i)=>[0,1,2].map(k=>buffer.readFloatLE(pv.byteOffset+(pos.byteOffset||0)+i*(pv.byteStride||12)+k*4)));
if(pts.some(p=>p.some(v=>!Number.isFinite(v))))throw Error('Nonfinite vertex');
let mx=0,mz=0;for(const p of pts){mx+=p[0]/pts.length;mz+=p[2]/pts.length;}
let xx=0,xz=0,zz=0;for(const p of pts){const x=p[0]-mx,z=p[2]-mz;xx+=x*x;xz+=x*z;zz+=z*z;}
const theta=.5*Math.atan2(2*xz,xx-zz);let ax=Math.cos(theta),az=Math.sin(theta);
const project=p=>p[0]*ax+p[2]*az;
let lo=Math.min(...pts.map(project)),hi=Math.max(...pts.map(project));
const spread=(list)=>{if(!list.length)return Infinity;const ys=list.map(p=>p[1]),xs=list.map(p=>-az*p[0]+ax*p[2]);return (Math.max(...ys)-Math.min(...ys))*(Math.max(...xs)-Math.min(...xs));};
const endA=spread(pts.filter(p=>project(p)<lo+(hi-lo)*.15)),endB=spread(pts.filter(p=>project(p)>hi-(hi-lo)*.15));
if(endA<endB){ax=-ax;az=-az;[lo,hi]=[-hi,-lo];}
const mid=(lo+hi)/2, factor=.68/(hi-lo);
const cross=p=>az*p[0]-ax*p[2];
const cx=(Math.min(...pts.map(cross))+Math.max(...pts.map(cross)))/2;
const cy=(Math.min(...pts.map(p=>p[1]))+Math.max(...pts.map(p=>p[1])))/2;
const min=[Infinity,Infinity,Infinity],max=[-Infinity,-Infinity,-Infinity];
pts.forEach((p,i)=>{const a=[(cross(p)-cx)*factor,(p[1]-cy)*factor,-(project(p)-mid)*factor];a.forEach((v,k)=>{buffer.writeFloatLE(v,pv.byteOffset+(pos.byteOffset||0)+i*(pv.byteStride||12)+k*4);min[k]=Math.min(min[k],v);max[k]=Math.max(max[k],v);});});
pos.min=min;pos.max=max;
const nv=doc.bufferViews[normal.bufferView];if(normal.componentType===5126){for(let i=0;i<normal.count;i++){const off=nv.byteOffset+(normal.byteOffset||0)+i*(nv.byteStride||12),x=buffer.readFloatLE(off),z=buffer.readFloatLE(off+8);buffer.writeFloatLE(az*x-ax*z,off);buffer.writeFloatLE(-ax*x-az*z,off+8);}}
const ia=doc.accessors[prim.indices],iv=doc.bufferViews[ia.bufferView],parent=Array.from({length:pos.count},(_,i)=>i);
const root=i=>{while(parent[i]!==i){parent[i]=parent[parent[i]];i=parent[i];}return i;};const join=(a,b)=>{parent[root(a)]=root(b);};
const weld=new Map();pts.forEach((p,i)=>{const key=p.map(x=>Math.round(x*10000)).join(',');if(weld.has(key))join(i,weld.get(key));else weld.set(key,i);});
const ids=Array.from({length:ia.count},(_,i)=>buffer.readUInt16LE(iv.byteOffset+(ia.byteOffset||0)+i*2));
if(ids.some(i=>i>=pos.count))throw Error('Invalid mesh index');
for(let i=0;i<ids.length;i+=3){join(ids[i],ids[i+1]);join(ids[i],ids[i+2]);}
const counts=new Map();for(let i=0;i<ids.length;i+=3){const k=root(ids[i]);counts.set(k,(counts.get(k)||0)+1);}
console.log('IGNIS geometry audit',JSON.stringify({bounds:[min,max],componentTriangles:[...counts.values()].sort((a,b)=>b-a).slice(0,20),endA,endB}));
// A detached accessory may be intentional; report components without deleting meaningful geometry.
doc.buffers=[{byteLength:buffer.length}];
delete doc.extensionsRequired;delete doc.extensionsUsed;
const json=Buffer.from(JSON.stringify(doc));const padded=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
const header=Buffer.alloc(12);header.write('glTF');header.writeUInt32LE(2,4);header.writeUInt32LE(12+8+padded.length+8+buffer.length,8);
const jh=Buffer.alloc(8);jh.writeUInt32LE(padded.length,0);jh.writeUInt32LE(0x4e4f534a,4);
const bh=Buffer.alloc(8);bh.writeUInt32LE(buffer.length,0);bh.writeUInt32LE(0x004e4942,4);
fs.writeFileSync('assets/tripo/ignis_x1.glb',Buffer.concat([header,jh,padded,bh,buffer]));
console.log('IGNIS converted:',doc.accessors[3].count/3,'triangles; standard GLB');
