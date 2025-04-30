class_name NetworkManager extends Node

# Standard:
#	-host
#	-connect
#	-disconnect
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

func _connect_client():
	multiplayer_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_peer_connected(peer_id : int):
	print("peer with id %s connected" % peer_id)

func _on_peer_disconnected(peer_id : int):
	print("peer with id %s disconnected" % peer_id)

func _on_connected_to_server():
	print("Ive connected to the server")
