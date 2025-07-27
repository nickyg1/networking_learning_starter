extends Control

@export var ip_field : LineEdit
@export var port_field : LineEdit
@export var connect_button : Button
@export var host_button : Button
@export var status_text : RichTextLabel
@onready var network_manager : NetworkManager = get_node("/root/Network_Manager")
@onready var character_select_menu : Control = get_node("/root/Node3D/UI/CharacterSelectMenu")


func _ready() -> void:
	network_manager.on_server_started.connect(_on_connected_to_server)
	connect_button.button_up.connect(_connect)
	host_button.button_up.connect(_host)
	
func _on_connected_to_server():
	status_text.clear()
	var text = "client"
	
	if network_manager.is_server:
		text = "server"
		
	status_text.add_text(text)
	character_select_menu.show()
	hide()
	
func _host():
	network_manager.port = port_field.text as int
	network_manager._create_server()
	
func _connect():
	network_manager.ip = ip_field.text
	network_manager.port = port_field.text as int 
	
	network_manager._connect_client() 