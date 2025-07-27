class_name NetworkManager
extends Node

#Standard: bear minimum a network manager should control 
# host, connect, disconnect 
#Core: what every game could use 
# track connected player, track networked objects, spawn objects across network, manage object ownership
#Extended: 
# manage database connection, network ticks, auth, batching sync vars, proximity management, etc 

#Standard version

@export var ip : String = "127.0.0.1"
@export var port : int = 9999

var multiplayer_peer = ENetMultiplayerPeer.new()

var connected_players : Array[NetworkCharacter] = []
var network_id : int 
var is_server : bool = false 
var network_started : bool = false 

## takes requester_id : int and sapwn_args : Dictionary
var validate_spawn_callable : Callable

signal on_server_started
signal on_connection_failed

func _create_server():
	var error : Error = multiplayer_peer.create_server(port)
	
	if error != OK:
		printerr(error)
		on_connection_failed.emit()
		return 
	
	multiplayer.multiplayer_peer = multiplayer_peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	network_started = true 
	is_server = multiplayer.is_server()
	network_id = multiplayer.get_unique_id()
	connected_players.append(_create_connected_player(multiplayer.get_unique_id()))
	on_server_started.emit()
	
func _connect_client():
	var error : Error = multiplayer_peer.create_client(ip, port)

	if error != OK:
		printerr(error)
		on_connection_failed.emit()
		return

	multiplayer.multiplayer_peer = multiplayer_peer

	multiplayer.connected_to_server.connect(_on_connect_to_server)

func _on_peer_connected(peer_id : int):
	#connected_players.append(_create_connected_player(peer_id))
	print("peer with id %s connected" % peer_id)
	
	for player in connected_players:
		if !is_instance_valid(player):
			connected_players.erase(player)
			
		if player.network_id == peer_id:
			for network_object in player.players_objects:
				if !is_instance_valid(network_object): continue
				network_object._destroy_network_object.rpc()
				
			connected_players.erase(player)
			continue
			
		for network_object in player.players_objects:
			if network_object.resource_path.is_empty():
				network_object._initialize_network_object.rpc(network_object.owner_id, network_object._get_transforms())
			else:
				_network_spawn_object.rpc_id(peer_id, network_object.owner_id, network_object.spawn_args)
				network_object._initialize_network_object.rpc_id(peer_id, network_object.owner_id, network_object._get_transforms())
	connected_players.append(_create_connected_player(peer_id))
	
func _on_peer_disconnected(peer_id : int):
	print("peer with id %s disconnected" % peer_id)
	
	var disconnected_player : NetworkCharacter
	
	for player in connected_players:
		if player.network_id == peer_id:
			disconnected_player = player 
			break
		
	if !is_instance_valid(disconnected_player):
		return

	for network_object in disconnected_player.players_objects:
		network_object._destroy_network_object.rpc()
		
	if connected_players.has(disconnected_player):
		connected_players.erase(disconnected_player)
			
func _on_connect_to_server():
	network_id = multiplayer.get_unique_id()
	network_started = true 
	on_server_started.emit()
	print("I've connected to the server")
	
func _create_connected_player(player_id : int) -> NetworkCharacter:
	var player = NetworkCharacter.new()
	player.network_id = player_id
	return player
	
func _register_network_object(network_object : NetworkObject):
	if !is_instance_valid(network_object):
		return
		
	if !is_server && !network_object._is_owner():
		return 
	
	if is_server:
		network_object._initialize_network_object.rpc(network_object.owner_id, network_object._get_transforms())
		
	for player in connected_players:
		if player.network_id != network_object.owner_id:
			continue
			
		if player.players_objects.has(network_object):
			printerr("PLAYER ALREADY OWNS THIS OBJECT")
			return
			
		player.players_objects.append(network_object)
		
	print("Added network object")
	
func _switch_network_object(new_owner : int, network_object : NetworkObject):
	if !is_instance_valid(network_object): return
		
	for player in connected_players:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
		if player.network_id == new_owner: 
			player.players_objects.append(network_object)
			
func _remove_network_object(network_object : NetworkObject):
	for player in connected_players:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
				return

func _request_spawn_helper(resource_path : String, args : Dictionary = {}):
	
	if resource_path is not String:
		push_warning("Resource path is not a string")
		return

	if !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://"):
		push_warning("Invalid resource path %s" % resource_path)
		return

	var dict : Dictionary = {
	"resource_path" : resource_path,
	"args" : args
	}

	_request_spawn_object.rpc_id(1, dict)

## overridable function 
func _spawn_object(owner_id : int, spawn_args : Dictionary):
	var resource_path : String = spawn_args["resource_path"]
	
	var obj = load(resource_path).instantiate()
	if !is_instance_valid(obj):
		push_error("Failed to instantiate: %s" % resource_path)
		return
		
	if obj is NetworkObject:
		obj.resource_path = resource_path
		obj.owner_id = owner_id 
		obj.spawn_args = spawn_args
		
	get_tree().current_scene.add_child(obj)
	
@rpc("any_peer", "call_local", "reliable")
func _request_spawn_object(spawn_args : Dictionary):
	var request_id = multiplayer.get_remote_sender_id()
	
	if !spawn_args.has("resource_path"):
		push_warning("No resource path provided")
		return 
		
	var resource_path : String = spawn_args["resource_path"]
	
	if resource_path is not String:
		push_warning("Resource path is not a string")
		return

	if !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://"):
		push_warning("Invalid resource path %s" % resource_path)
		return 
	
	if validate_spawn_callable: 
		if validate_spawn_callable.call(request_id, spawn_args):
			_network_spawn_object.rpc(request_id,spawn_args)
	else:
		_network_spawn_object.rpc(request_id,spawn_args)

@rpc("authority", "call_local", "reliable")

func _network_spawn_object(
	owner_id : int,
	spawn_args : Dictionary
):
	var resource_path = spawn_args["resource_path"]
	
	if resource_path is not String:
		push_warning("The resource path is not a string")
		return

	if !ResourceLoader.exists(resource_path) || !resource_path.begins_with("res://"):
		push_warning("Invalid resource path %s" % resource_path)
		return 	

	_spawn_object(owner_id, spawn_args)