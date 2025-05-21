extends Node

@onready var http := HTTPRequest.new()

func _ready():
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	var url = "http://localhost:3000/join"
	var headers = ["content-Type: application/json"]
	var body = JSON.stringify({ "room_id": "room1" })

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)

	if err != OK:
		print(" request error:", err)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print(" response:", body.get_string_from_utf8())
