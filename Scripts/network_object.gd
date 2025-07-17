class_name NetworkObject
extends Node

@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")

var owner_id : int = 1
var has_begun_initialization : bool = false

var validate_ownership_change_callable : Callable
var validate_destroy_request_callable : Callable

signal on_network_ready()
signal on_ownership_change(old_owner : int, new_owner : int)
signal on_network_object_destroy()
func _ready() -> void:
	if !network_manager.network_started:
		network_manager.on_server_started.connect(_on_network_started)
		
func _on_network_started():
	if has_begun_initialization:
		return
		
	has_begun_initialization = true 
	
	network_manager._register_network_object(self)
	
	
	if !network_manager.is_server:
		_request_onwership.rpc_id(1)	

	if network_manager.on_server_started.is_connected(_on_network_started):
		network_manager.on_server_started.disconnect(_on_network_started)

func _is_owner()->bool:
	return owner_id == network_manager.network_id
	
func _get_transforms() -> Dictionary:
	var transforms : Dictionary = {}
	
	var children : Array[Node] = _get_all_children_transform(self)
	
	for child in children:
		transforms.set(child.get_path(), child.transform) 
		
	return transforms

func _get_all_children_transform(node : Node) -> Array[Node]:
	var nodes : Array[Node] = []
	
	for n in node.get_children():
		if n.get_child_count() > 0:
			if n is Node2D || n is Node3D:
				nodes.append(n)
				
			nodes.append_array(_get_all_children_transform(n))
		elif n is Node2D || n is Node3D:
			nodes.append(n)
			
	return nodes
	
@rpc("any_peer", "call_local", "reliable")

func _request_onwership():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	print("%s requested ownership" % sender_id)

	if !network_manager.is_server : return 
		
	if owner_id == sender_id :  return
	
	#flesh this out when going into production 
	if validate_ownership_change_callable:
		if validate_ownership_change_callable.call(sender_id):
			_change_owner.rpc(sender_id)
	else:
		_change_owner.rpc(sender_id)
		
@rpc("authority", "call_local", "reliable")

func _change_owner(new_owner : int):
	if network_manager.is_server|| new_owner == network_manager.network_id || owner_id == network_manager.network_id:
		network_manager._switch_network_object(new_owner, self)
	
	on_ownership_change.emit(owner_id, new_owner)
	print("old ownder : %s new owner: %s" % [owner_id, new_owner])
	owner_id = new_owner


@rpc("authority", "call_remote", "reliable")

func _initialize_network_object(owner_id : int, transforms : Dictionary):
	self.owner_id = owner_id
	
	var children_transforms : Array[Node] = _get_all_children_transform(self)
	
	for child in children_transforms:
		var child_path = child.get_path()
		if transforms.has(child_path):
			child.transform = transforms[child_path]
			
	on_network_ready.emit()

@rpc("any_peer", "call_local", "reliable")
func _request_destroy_network_object():
	var sender_id : int = network_manager.multiplayer.get_remote_sender_id()
	
	if validate_destroy_request_callable:
		if validate_destroy_request_callable.call(sender_id):
			_destroy_network_object.rpc()
	else:
		_destroy_network_object.rpc()
		
@rpc("authority", "call_local", "reliable")
func _destroy_network_object():
	if _is_owner() || network_manager.is_server:
		#remove network object from players object list 
		pass
		
	on_network_object_destroy.emit()
	queue_free()