class_name T
extends RefCounted

static var failures: Array[String] = []


static func eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		failures.append(("%s expected %s, got %s" % [msg, str(b), str(a)]).strip_edges())


static func ok(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("condition false: %s" % msg)


static func near(a: float, b: float, eps: float = 0.001) -> void:
	if absf(a - b) > eps:
		failures.append("expected %f near %f (eps %f)" % [a, b, eps])
