#!/usr/bin/env python3
"""ANI-01/02: audit source GLB archive without modifying the playable rig."""
import argparse, hashlib, json, pathlib, re, struct, zipfile

EXPECTED = "cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724"
def read_glb(data):
    magic, version, size, n, kind = struct.unpack_from("<4sIIII",data)
    if magic != b"glTF" or version != 2 or size != len(data) or kind != 0x4e4f534a:
        raise ValueError("Invalid GLB 2.0")
    return json.loads(data[20:20+n])

def inspect(doc):
    nodes=doc.get("nodes",[])
    joints=sorted({j for skin in doc.get("skins",[]) for j in skin["joints"]})
    if not joints:
        joints=sorted({c["target"]["node"] for a in doc.get("animations",[]) for c in a["channels"] if "node" in c["target"]})
    clips=[]
    for a in doc.get("animations",[]):
        duration=0
        for sampler in a["samplers"]:
            acc=doc["accessors"][sampler["input"]]
            duration=max(duration,max(acc.get("max",[0])))
        clips.append({"name":a.get("name",""),"duration":duration,"channels":len(a["channels"])})
    return {"bones":[nodes[j].get("name",str(j)) for j in joints],"clips":clips}

def norm(x):
    return re.sub(r"[^a-z0-9]","",x.lower().split(":")[-1])

ALIASES={
 "hips": ["hips","pelvis","waist"],
 "spine": ["spine","spine01","spine1"],
 "chest": ["chest","spine02","spine2"],
 "head": ["head"],
 "neck": ["neck","neck01"],
}
for side,prefix in [("left","l"),("right","r")]:
    for key,names in {
        "thigh":["upperleg","upleg","thigh"],
        "calf":["lowerleg","leg","calf","shin"],
        "foot":["foot"],"toe":["toe","toebase"],
        "upperarm":["upperarm","arm"],"forearm":["lowerarm","forearm"],
        "hand":["hand"],"shoulder":["shoulder","clavicle"],
    }.items():
        ALIASES[side+"_"+key]=[p+n for p in [side,prefix] for n in names]+[n+p for p in [side,prefix] for n in names]

def mapping(bones):
    by_norm={}
    for name in bones:
        by_norm.setdefault(norm(name),[]).append(name)
    result={}
    for role,aliases in ALIASES.items():
        candidates=sorted({name for a in aliases for name in by_norm.get(a,[])})
        result[role]={"name":candidates[0] if len(candidates)==1 else None,"candidates":candidates}
    return result

def main():
    p=argparse.ArgumentParser()
    p.add_argument("archive",type=pathlib.Path)
    p.add_argument("target",type=pathlib.Path)
    p.add_argument("output",type=pathlib.Path)
    args=p.parse_args()
    digest=hashlib.sha256(args.archive.read_bytes()).hexdigest()
    if digest != EXPECTED:
        raise SystemExit("Source archive checksum mismatch")
    target=json.loads(args.target.read_text())
    candidates=[]
    with zipfile.ZipFile(args.archive) as z:
        for info in z.infolist():
            if not info.filename.lower().endswith(".glb"):
                continue
            if info.file_size>100_000_000:
                raise ValueError("Unexpected GLB size")
            d=inspect(read_glb(z.read(info)))
            if d["clips"]:
                candidates.append({"file":info.filename,**d,"mapping":mapping(d["bones"])})
    if not candidates:
        raise SystemExit("No animated GLB found")
    report={"source_sha256":digest,"source_license":"CC0-1.0","target_asset":target["asset"],"target_mapping":mapping([b["name"] for b in target["bones"]]),"target_clips":[c["name"] for c in target["clips"]],"source_candidates":candidates}
    args.output.write_text(json.dumps(report,indent=2,ensure_ascii=False))
    print("ANI SOURCE AUDIT COMPLETE",len(candidates),"animated GLBs")
if __name__=="__main__":
    main()
