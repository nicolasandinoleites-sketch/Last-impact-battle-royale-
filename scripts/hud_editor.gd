extends CanvasLayer
const Layout=preload("res://scripts/hud_layout.gd")
var layout=Layout.new()
var game
var old_pause:=false
var selected:="FIRE"
var preview:Control
var nodes:Dictionary={}
var scale_slider:HSlider
var opacity_slider:HSlider
var dragging:=false
func open(owner_game=null)->void:
 game=owner_game
 layout.load_layout()
 old_pause=get_tree().paused
 process_mode=Node.PROCESS_MODE_ALWAYS
 layer=101
 get_tree().paused=true
 var bg:=ColorRect.new()
 bg.color=Color("17242d")
 add_child(bg)
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 preview=Control.new()
 bg.add_child(preview)
 preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 preview.offset_bottom=-110
 preview.gui_input.connect(handle_drag)
 preview.resized.connect(refresh)
 for id in Layout.DEFAULTS:
  var b:=Button.new()
  b.text=id
  b.mouse_filter=Control.MOUSE_FILTER_IGNORE
  preview.add_child(b)
  nodes[id]=b
 var bar:=VBoxContainer.new()
 bg.add_child(bar)
 bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 bar.offset_top=-108
 var row:=HBoxContainer.new()
 bar.add_child(row)
 var picker:=OptionButton.new()
 for id in Layout.DEFAULTS:picker.add_item(id)
 row.add_child(picker)
 picker.item_selected.connect(func(i): selected=picker.get_item_text(i); sync_sliders())
 scale_slider=HSlider.new()
 scale_slider.min_value=.6
 scale_slider.max_value=1.5
 scale_slider.step=.05
 scale_slider.custom_minimum_size.x=120
 row.add_child(scale_slider)
 scale_slider.value_changed.connect(func(v):change(v,layout.opacity(selected)))
 opacity_slider=HSlider.new()
 opacity_slider.min_value=.25
 opacity_slider.max_value=1
 opacity_slider.step=.05
 opacity_slider.custom_minimum_size.x=120
 row.add_child(opacity_slider)
 opacity_slider.value_changed.connect(func(v):change(layout.scale(selected),v))
 var actions:=HBoxContainer.new()
 bar.add_child(actions)
 for label in ["GUARDAR","RESTAURAR","CANCELAR"]:
  var b:=Button.new()
  b.text=label
  b.custom_minimum_size.y=44
  actions.add_child(b)
  if label=="GUARDAR":b.pressed.connect(func():finish(true))
  elif label=="CANCELAR":b.pressed.connect(func():finish(false))
  else:b.pressed.connect(func():layout.slots.clear();sync_sliders();refresh())
 sync_sliders()
 refresh()
func sync_sliders()->void:
 scale_slider.set_value_no_signal(layout.scale(selected))
 opacity_slider.set_value_no_signal(layout.opacity(selected))
func change(s:float,a:float)->void:
 layout.set_control(selected,layout.position(selected,Layout.DEFAULTS[selected]),s,a)
 refresh()
func refresh()->void:
 if not is_instance_valid(preview):return
 for id in nodes:
  var b:Button=nodes[id]
  b.size=Vector2(64,40)*layout.scale(id)
  b.position=layout.position(id,Layout.DEFAULTS[id])*preview.size-b.size*.5
  b.modulate=Color(1,1,1,layout.opacity(id))
func handle_drag(e:InputEvent)->void:
 if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
  dragging=e.pressed
  if dragging:
   for id in nodes:
    if nodes[id].get_rect().has_point(e.position):selected=id;sync_sliders();break
 elif e is InputEventScreenTouch:
  dragging=e.pressed
  if dragging:
   for id in nodes:
    if nodes[id].get_rect().has_point(e.position):selected=id;sync_sliders();break
 elif dragging and (e is InputEventMouseMotion or e is InputEventScreenDrag):
  layout.set_control(selected,e.position/preview.size,layout.scale(selected),layout.opacity(selected))
  refresh()
func finish(save:bool)->void:
 if save and layout.save_layout()!=OK:return
 if save and is_instance_valid(game):game.hud.layout.load_layout()
 get_tree().paused=old_pause
 queue_free()
