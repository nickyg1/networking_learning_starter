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
			network_object._initialize_network_object.rpc(network_object.owner_id, network_object._get_transforms())
			
	connected_players.append(_create_connected_player(peer_id))
	
func _on_peer_disconnected(peer_id : int):
	print("peer with id %s disconnected" % peer_id)
	
	var disconnected_player : NetworkCharacter
	
	for player in connected_players:
		if player.network_id == peer_id:
			disconnected_player = player 
			break
			
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
		
	for player in connected_players:
		if player.network_id == network_object.owner_id:
			continue
		if player.players_objects.has(network_object):
			print("PLAYER ALREADY OWNS THIS OBJECT")
			return
			
		player.players_objects.append(network_object)
		
	print("Added network object")
	
func _switch_network_object(new_owner : int, network_object : NetworkObject):
	if !is_instance_valid(network_object):
		return
		
	for player in connected_players:
		if player.network_id == network_object.owner_id:
			if player.players_objects.has(network_object):
				player.players_objects.erase(network_object)
		if player.network_id == new_owner: 
			player.players_objects.append(network_object)
			
func _remove_network_object(network_object : NetworkObject):
	for player in connected_players:
		if player.network_id == network_object.owner_id:
			player.player_objects.erase(network_object)
			return