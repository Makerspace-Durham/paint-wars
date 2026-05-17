extends Area2D

signal collected

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.has_method("apply_stun"):
		return
	# Only the local player can collect
	if not body.is_multiplayer_authority():
		return
	collected.emit()
	queue_free()
