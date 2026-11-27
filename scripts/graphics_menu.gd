extends CanvasLayer
const Options=preload("res://scripts/graphics_options.gd")
var options=Options.new()
var game
var previous_pause:=false
var panel: PanelContainer
func open(owner_game=null) -> void:
 game=owner_game
 options.load_options()
 previous_pause=get_tree().paused
 process_mode=Node.PROCESS_MODE_ALWAYS
 layer=100
 get_tree().paused=true
 var bg:=ColorRect.new()
 bg.color=Color(0.04,0.08,0.12,0.96)
 add_child(bg)
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var scroll:=ScrollContainer.new()
 bg.add_child(scroll)
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var box:=VBoxContainer.new()
 scroll.add_child(box)
 box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation",8)
 var heading:=Label.new()
 heading.text="LAST IMPACT / GRAFICOS"
 box.add_child(heading)
 choice(box,"Calidad",["Baja","Media","Alta","Ultra"],options.profile,func(i): options.preset(i); refresh())
 choice(box,"FPS",["30","45","60","90"],[30,45,60,90].find(options.fps),func(i): options.fps=[30,45,60,90][i])
 choice(box,"Resolucion interna",["50%","65%","80%","90%","100%"],nearest([50,65,80,90,100],options.resolution),func(i): options.resolution=[50,65,80,90,100][i])
 choice(box,"Sombras",["No","Si"],int(options.shadows),func(i): options.shadows=bool(i))
 choice(box,"Distancia de vision",["175 m","200 m","250 m","300 m"],nearest([175,200,250,300],options.distance),func(i): options.distance=[175,200,250,300][i])
 choice(box,"Resolucion dinamica",["No","Si"],int(options.dynamic),func(i): options.dynamic=bool(i))
 var note:=Label.new()
 note.text="Los FPS son un limite, no una garantia. Compatibility / OpenGL."
 box.add_child(note)
 var apply:=Button.new()
 apply.text="GUARDAR Y VOLVER"
 apply.custom_minimum_size.y=44
 box.add_child(apply)
 apply.pressed.connect(close)
func nearest(values:Array,value:int)->int:
 var best:=0
 for i in range(values.size()):
  if absi(values[i]-value)<absi(values[best]-value): best=i
 return best
func choice(box:VBoxContainer,title:String,items:Array,selected:int,callback:Callable)->void:
 var row:=HBoxContainer.new()
 box.add_child(row)
 var label:=Label.new()
 label.text=title
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_child(label)
 var option:=OptionButton.new()
 option.custom_minimum_size=Vector2(150,36)
 for item in items: option.add_item(item)
 option.select(selected)
 row.add_child(option)
 option.item_selected.connect(callback)
func refresh()->void:
 var box=get_child(0).get_child(0).get_child(0)
 var values=[options.profile,[30,45,60,90].find(options.fps),nearest([50,65,80,90,100],options.resolution),int(options.shadows),nearest([175,200,250,300],options.distance),int(options.dynamic)]
 for i in range(values.size()): box.get_child(i+1).get_child(1).select(values[i])
func close()->void:
 if options.save_options()!=OK: return
 options.apply(get_tree().root)
 if is_instance_valid(game) and game.has_method("apply_graphics_options"): game.apply_graphics_options()
 get_tree().paused=previous_pause
 queue_free()
