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
doc.buffers=[{byteLength:buffer.length}];
delete doc.extensionsRequired;delete doc.extensionsUsed;
const json=Buffer.from(JSON.stringify(doc));const padded=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
const header=Buffer.alloc(12);header.write('glTF');header.writeUInt32LE(2,4);header.writeUInt32LE(12+8+padded.length+8+buffer.length,8);
const jh=Buffer.alloc(8);jh.writeUInt32LE(padded.length,0);jh.writeUInt32LE(0x4e4f534a,4);
const bh=Buffer.alloc(8);bh.writeUInt32LE(buffer.length,0);bh.writeUInt32LE(0x004e4942,4);
fs.writeFileSync('assets/tripo/ignis_x1.glb',Buffer.concat([header,jh,padded,bh,buffer]));
console.log('IGNIS converted:',doc.accessors[3].count/3,'triangles; standard GLB');
