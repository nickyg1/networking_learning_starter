class_name NetworkManager extends Node

# Standard:
#	-host DONE
#	-connect DONE
#	-disconnect DONE
# Core:
#	-Track connected players
#	-Track networked objects
#	-Spawn Objects across network
#	-Manage object ownership
# Extended:
#	-Manage database connection
#	-Network Ticks
#	-Auth
#	-batching sync vars
#	-room management
#	-proximity management
#	-etc

@export var ip : String = "127.0.0.1"
@export var port : int = 9999

var multiplayer_peer = ENetMultiplayerPeer.new()
var connected_players : Array[ConnectePlayer] = []
var network_id : int
var is_server : bool = false
var network_started : bool = false

signal on_server_started

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var args : PackedStringArray = OS.get_cmdline_args()
	
	if args.has("server"):
		# create server
		_create_server()
	else:
		# connect client
		_connect_client()

func _create_server():
	multiplayer_peer.create_server(port)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	network_started = true
	is_server = multiplayer.is_server()
	connected_players.append(_create_connected_player(multiplayer.get_unique_id()))

func _connect_client():
	multiplayer_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_peer_connected(peer_id : int):
	connected_players.append(_create_connected_player(peer_id))
	print("peer with id %s connected" % peer_id)

func _on_peer_disconnected(peer_id : int):
	print("peer with id %s disconnected" % peer_id)

func _on_connected_to_server():
	network_id = multiplayer.get_unique_id()
	network_started = true
	on_server_started.emit()
	print("Ive connected to the server")
	

func _create_connected_player(player_id : int) -> ConnectePlayer:
	var player = ConnectePlayer.new()
	player.network_id = player_id
	return player

func _register_network_object(network_object : NetworkObject):
	if !is_instance_valid(network_object):
		return
	
	if !is_server && !network_object._is_owner():
		return
	
	for player in connected_players:
		if player.network_id != network_object.owner_id:
			continue
		
		if player.players_objects.has(network_object):
			printerr("player already owns this object")
			return
		
		player.players_objects.append(network_object)
	
	print("added network object")
