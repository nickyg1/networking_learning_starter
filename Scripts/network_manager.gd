class_name NetworkManager extends Node

@export var ip : String = "127.0.0.1"
@export var port : int = 9999
@export var number_of_transfer_channels : int = 3
@export var max_clients : int = 4

var multiplayer_peer = ENetMultiplayerPeer.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var args : PackedStringArray = OS.get_cmdline_args()
	
	if args.has("server"):
		_create_server()
	else:
		_connect_client()

func _create_server():
	multiplayer_peer.create_server(port, max_clients, number_of_transfer_channels)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnect)

func _connect_client():
	multiplayer_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_peer_connected(peer_id : int):
	print("peer with id %s connected" % peer_id)
	_send_rpc(peer_id)

func _on_connected_to_server():
	print("Ive connected to the server")


func _on_peer_disconnect(peer_id : int):
	print("peer with id %s disconnected" % peer_id)

func _send_rpc(reciver_id : int):
	_my_rpc.rpc_id(reciver_id)

@rpc("any_peer", "call_local", "unreliable", 0)
func _my_rpc():
	print("Called by %s on %s" % [multiplayer.get_remote_sender_id(), multiplayer.get_unique_id()])
