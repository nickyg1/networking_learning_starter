class_name CharacterNetwork extends NetworkObject

@export var spawn_client_on_server : bool = false

@onready var my_body : PlayerCharacterBody = get_node("CharacterBody3D")

signal on_player_input_recieved(ray_origin : Vector3, ray_end : Vector3)

signal on_target_recieved(target : Vector3)

var validate_player_input : Callable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	on_network_ready.connect(_on_network_ready)
	super()

func _on_network_ready():
	print("on network ready!")
	
	if network_manager.is_server:
		var server_script = CharacterServer.new()
		
		add_child(server_script)
		
		if spawn_client_on_server:
			var client_script = CharacterClient.new()
			add_child(client_script)
	else:
		var client_script = CharacterClient.new()
		add_child(client_script)
	


@rpc("any_peer", "call_local", "unreliable")
func _send_input_ray(ray_origin : Vector3, ray_end : Vector3):
	if validate_player_input:
		if validate_player_input.call(network_manager.multiplayer.get_remote_sender_id(), ray_origin, ray_end):
			on_player_input_recieved.emit(ray_origin, ray_end)
		else:
			_set_target.rpc(my_body.position)
	else:
		on_player_input_recieved.emit(ray_origin, ray_end)

@rpc("authority", "call_local", "unreliable")
func _set_target(target : Vector3):
	on_target_recieved.emit(target)
