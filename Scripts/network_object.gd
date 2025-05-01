class_name NetworkObject extends Node

@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

var owner_id : int = 1
var has_begun_initialiation : bool = false

var validate_ownership_change_callable : Callable

signal on_network_ready()
signal on_ownership_change(old_owner : int, new_owner : int)

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
	
	#if !network_manager.is_server:
		#_request_ownership.rpc_id(1)

	
	if network_manager.on_server_started.is_connected(_on_network_started):
		network_manager.on_server_started.disconnect(_on_network_started)

func _is_owner() -> bool:
	return owner_id == network_manager.network_id

@rpc("any_peer", "call_local", "reliable")
func _request_ownership():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	print("%s requested ownership" % sender_id)
	
	if !network_manager.is_server: return
	
	if owner_id == sender_id: return
	
	if validate_ownership_change_callable:
		if validate_ownership_change_callable.call(sender_id):
			_change_owner.rpc(sender_id)
	else:
		_change_owner.rpc(sender_id)
		

@rpc("authority", "call_local", "reliable")
func _change_owner(new_owner : int):
	var is_server = network_manager.is_server
	var is_new_owner = new_owner == network_manager.network_id
	var is_old_owner = owner_id == network_manager.network_id
	
	if is_server || is_new_owner || is_old_owner:
		network_manager._switch_network_object(new_owner, self)
		
	
	on_ownership_change.emit(owner_id, new_owner)
	print("old owner: %s new owner: %s" % [owner_id, new_owner])
	owner_id = new_owner
