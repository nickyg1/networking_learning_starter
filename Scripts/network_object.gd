class_name NetworkObject extends Node

@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

var owner_id : int = 1
var has_begun_initialiation : bool = false

signal on_network_ready()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !network_manager.network_started:
		network_manager.on_server_started.connect(_on_network_started)
	else:
		_on_network_started()

func _on_network_started():
	if has_begun_initialiation:
		return
		
	has_begun_initialiation = true
	
	network_manager._register_network_object(self)
	on_network_ready.emit()
	
	if network_manager.on_server_started.is_connected(_on_network_started):
		network_manager.on_server_started.disconnect(_on_network_started)

func _is_owner() -> bool:
	return owner_id == network_manager.network_id
