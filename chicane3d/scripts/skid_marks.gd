# ============================================================
# CHICANE 3D — skid_marks.gd
# Pooled skid marks: a MultiMesh ring buffer of dark quads laid
# under slipping tyres. Zero allocation during play.
# ============================================================
class_name SkidMarks
extends MultiMeshInstance3D

const MAX_MARKS := 700
var _next := 0
var _count := 0

func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 1.1)
	quad.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.035, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	multimesh.mesh = quad
	multimesh.instance_count = MAX_MARKS
	# park all instances far underground until used
	for i in MAX_MARKS:
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -500, 0)))

func add_mark(pos: Vector3, fwd: Vector3) -> void:
	var basis := Basis.looking_at(fwd, Vector3.UP) if fwd.length() > 0.01 else Basis()
	multimesh.set_instance_transform(_next, Transform3D(basis, pos + Vector3.UP * 0.04))
	_next = (_next + 1) % MAX_MARKS
	_count = mini(_count + 1, MAX_MARKS)
