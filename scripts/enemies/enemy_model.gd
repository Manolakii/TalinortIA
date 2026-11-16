class_name EnemyModel
extends Node3D
## Modelo 3D de un enemigo (pedido del grupo, 2026-11-16: ver el juego más "modelado" mientras
## llegan los modelos propios). Usa los personajes CC0 de KayKit: carga el .glb, esconde las
## armas que no van, lo escala a la altura del enemigo, lo tiñe más apagado (los enemigos van
## más apagados que los jugadores) y maneja las animaciones: quieto, caminar / correr, atacar
## (sincronizado con el aviso naranja), recibir un golpe y morir.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
const BLEND := 0.15

var materials: Array[StandardMaterial3D] = []
var _anim: AnimationPlayer
var _attack_anim: String = ""
var _busy: float = 0.0
var _dead: bool = false
var _current: String = ""


## Arma el modelo según los datos del enemigo. Devuelve false si no se pudo cargar.
func setup(data: EnemyData) -> bool:
	var scene: PackedScene = load(data.model_path) as PackedScene
	if scene == null:
		return false
	var model: Node3D = scene.instantiate()
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if data.model_hide.has(String(mesh.name)):
			mesh.visible = false
			continue
		_tint(mesh, data.model_tint)
	var top: float = _model_height(model)
	if top > 0.01:
		scale = Vector3.ONE * (data.body_height * data.model_scale / top)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		_attack_anim = data.anim_attack
		_play("Idle")
	return true


## Cada frame: quieto o caminando según la velocidad (si no está atacando o recibiendo).
func update(speed: float, delta: float) -> void:
	if _anim == null or _dead:
		return
	_busy = maxf(_busy - delta, 0.0)
	if _busy > 0.0:
		return
	if speed > 3.0:
		_play("Running_A")
	elif speed > 0.4:
		_play("Walking_A")
	else:
		_play("Idle")


## El ataque dura lo que el aviso, así el golpe cae cuando termina.
func play_attack(windup: float) -> void:
	if _anim == null or _dead or _attack_anim == "" or not _anim.has_animation(_attack_anim):
		return
	var length: float = _anim.get_animation(_attack_anim).length
	var duration: float = windup + 0.25
	_play(_attack_anim, clampf(length * 0.55 / maxf(windup, 0.1), 0.6, 3.0), true)
	_busy = duration


func play_hit() -> void:
	if _anim == null or _dead or _busy > 0.0:
		return
	_play("Hit_A", 1.4, true)
	_busy = 0.3


func play_death() -> void:
	if _anim == null:
		return
	_dead = true
	_play("Death_A", 1.2, true)


func _play(animation: String, speed: float = 1.0, restart: bool = false) -> void:
	if not _anim.has_animation(animation):
		return
	if animation == _current and not restart:
		return
	_current = animation
	_anim.play(animation, BLEND, speed)
	if restart:
		_anim.seek(0.0, true)


## Copia los materiales, los tiñe y les pone el contorno de los personajes.
func _tint(mesh: MeshInstance3D, tint: Color) -> void:
	if mesh.mesh == null:
		return
	for i: int in mesh.mesh.get_surface_count():
		var original := mesh.get_active_material(i) as StandardMaterial3D
		var copy: StandardMaterial3D = original.duplicate() if original != null else StandardMaterial3D.new()
		copy.albedo_color = copy.albedo_color * tint
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		copy.next_pass = outline
		mesh.set_surface_override_material(i, copy)
		materials.append(copy)


## Alto del modelo (sin estar en el árbol): suma las transformaciones hasta la raíz.
func _model_height(root_node: Node3D) -> float:
	var top: float = 0.0
	for mesh: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible or mesh.mesh == null:
			continue
		var xform: Transform3D = mesh.transform
		var parent: Node = mesh.get_parent()
		while parent != null and parent != root_node:
			if parent is Node3D:
				xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		var box: AABB = xform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top
