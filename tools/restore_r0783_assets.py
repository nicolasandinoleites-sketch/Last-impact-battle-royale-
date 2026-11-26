"""Restore exact R0783 binary assets from verified Git blobs."""
from pathlib import Path
import hashlib, json, sys
ROOT = Path(__file__).resolve().parents[1]
transfer = ROOT / "asset_transfer/r0783"
def gitsha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
for e in json.loads((transfer / "manifest.json").read_text()):
    parts=[]
    for p in e["parts"]:
        d=(ROOT/p["path"]).read_bytes()
        assert gitsha(d)==p["sha"], p["path"]
        parts.append(d)
    data=b"".join(parts)
    assert gitsha(data)==e["sha"], e["path"]
    dest=ROOT/e["path"]; dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(data)
    print("Verified",e["path"],len(data))
errors=[]
for e in json.loads((transfer/"project_manifest.json").read_text()):
    p=ROOT/e["path"]
    if not p.is_file() or gitsha(p.read_bytes())!=e["sha"]: errors.append(e["path"])
if errors:
    print("Manifest differences:",*errors,sep="\n")
    sys.exit(1)
print("R0783 PROJECT MANIFEST PASS")
