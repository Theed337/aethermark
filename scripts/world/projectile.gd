class_name Projectile
extends Node3D
## Einfaches Geschoss (Spieler- oder Gegnergeschoss). Treffer werden per Abstand geprüft –
## robust, performant und ohne Physik-Layer-Abhängigkeit.

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var radius: float = 0.5            # Trefferradius
var life: float = 3.0
var from_player: bool = true
var pierce: int = 0
var explode_radius: float = 0.0    # > 0: Flächenexplosion beim Einschlag
var color: Color = Color(1.0, 0.5, 0.2)
var category: String = "ranged"
var tags: Array = []
var owner_player: Node = null      # Player (bei Spielergeschossen)
var on_impact: Callable = Callable()   # (position) -> void
var gravity: float = 0.0
var homing_to: Node3D = null
var _hit: Array = []
var _arena: Node = null
var net_id := 0          # Multiplayer: vom Host vergebene ID
var ghost := false       # Client: rein kosmetische Kopie (bewegt sich nur, trifft nie)
var net_pos := Vector3.ZERO
var visual_size := 0.25  # Darstellungsgröße (für die Client-Kopie)


func _ready() -> void:
	add_to_group("projectiles")


func setup(arena: Node, pos: Vector3, vel: Vector3, col: Color, size: float = 0.25) -> void:
	_arena = arena
	position = pos
	velocity = vel
	color = col
	visual_size = size
	top_level = true
	var core := Toon.part(self, "sphere", Vector3(size, 0, 0), col, Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(col, 3.0), false)
	var halo := Toon.part(self, "sphere", Vector3(size * 1.8, 0, 0), col, Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(col, 1.0, 0.3), false)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 4.0
	l.light_energy = 1.2
	add_child(l)
	arena.add_child(self)
	if not ghost and arena.has_method("net_proj_spawn"):
		arena.net_proj_spawn(self)


func _exit_tree() -> void:
	if not ghost and _arena != null and is_instance_valid(_arena) and _arena.has_method("net_proj_end"):
		_arena.net_proj_end(net_id)


func _physics_process(delta: float) -> void:
	if ghost:
		life -= delta
		position += velocity * delta
		if net_pos != Vector3.ZERO:
			position = position.lerp(net_pos, clampf(delta * 18.0, 0.0, 1.0))
		if life <= 0.0 or position.y < 0.05:
			queue_free()
		return
	life -= delta
	if gravity != 0.0:
		velocity.y -= gravity * delta
	if homing_to != null and is_instance_valid(homing_to):
		var want: Vector3 = (homing_to.global_position + Vector3(0, 1, 0) - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	position += velocity * delta
	if life <= 0.0 or position.y < 0.05:
		_impact()
		return
	if from_player:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e in _hit or not is_instance_valid(e) or e.dead:
				continue
			var c: Vector3 = e.global_position + Vector3(0, 0.9 * e.model_scale, 0)
			if c.distance_to(global_position) <= radius + 0.5 * e.model_scale:
				_hit.append(e)
				if explode_radius <= 0.0:
					owner_player.deal_damage(e, damage, category, tags, global_position)
				if pierce > 0:
					pierce -= 1
					if explode_radius > 0.0:
						_explode()
					FX.burst(_arena, global_position, color, 5, 3.0, 0.08, 0.3)
				else:
					_impact()
					return
	else:
		for p in get_tree().get_nodes_in_group("player"):
			if not is_instance_valid(p) or p.is_down():
				continue
			var c: Vector3 = p.global_position + Vector3(0, 0.9, 0)
			if c.distance_to(global_position) <= radius + 0.45:
				p.take_damage(damage, global_position)
				_impact()
				return


func _impact() -> void:
	if is_queued_for_deletion():
		return
	if ghost:
		queue_free()
		return
	if explode_radius > 0.0 and from_player:
		_explode()
	else:
		FX.burst(_arena, global_position, color, 6, 3.0, 0.08, 0.3)
	if on_impact.is_valid():
		on_impact.call(global_position)
	queue_free()


func _explode() -> void:
	FX.ring(_arena, global_position, explode_radius, color, 0.35)
	FX.burst(_arena, global_position, color, 18, 6.0, 0.14, 0.5)
	Sfx.play("boom", 1.2, -6.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) <= explode_radius + 0.5 * e.model_scale:
			owner_player.deal_damage(e, damage, category, tags, global_position)
