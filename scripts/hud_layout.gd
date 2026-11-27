extends RefCounted
const DEFAULTS={"FIRE":Vector2(.91,.59),"AIM":Vector2(.79,.48),"JUMP":Vector2(.92,.80),"SLIDE":Vector2(.80,.82),"LOAD":Vector2(.68,.82),"RUN":Vector2(.10,.49),"CROUCH":Vector2(.29,.49),"SIDE":Vector2(.66,.49),"PICKUP":Vector2(.60,.70),"MED":Vector2(.08,.32),"SHIELD":Vector2(.19,.32),"SWAP":Vector2(.55,.87),"MELEE":Vector2(.40,.82),"GRENADE":Vector2(.40,.63),"ABILITY":Vector2(.40,.43),"VEHICLE":Vector2(.88,.78)}
var slots:Dictionary={}
func path()->String:
 var p:=OS.get_environment("LASTIMPACT_HUD_PATH")
 return p if not p.is_empty() else "user://lastimpact_hud.cfg"
func load_layout()->void:
 var c:=ConfigFile.new()
 slots.clear()
 if c.load(path())!=OK:return
 for id in DEFAULTS:
  var p=c.get_value(id,"position",DEFAULTS[id])
  if p is Vector2: set_control(id,p,float(c.get_value(id,"scale",1.0)),float(c.get_value(id,"opacity",1.0)))
func set_control(id:String,p:Vector2,s:float,a:float)->void:
 if not DEFAULTS.has(id):return
 slots[id]={"position":p.clamp(Vector2(.07,.10),Vector2(.93,.90)),"scale":clampf(s,.6,1.5),"opacity":clampf(a,.25,1.0)}
func position(id:String,fallback:Vector2)->Vector2:
 return slots.get(id,{}).get("position",fallback)
func scale(id:String)->float:
 return slots.get(id,{}).get("scale",1.0)
func opacity(id:String)->float:
 return slots.get(id,{}).get("opacity",1.0)
func save_layout()->Error:
 var c:=ConfigFile.new()
 for id in slots:
  for k in slots[id]:c.set_value(id,k,slots[id][k])
 return c.save(path())
