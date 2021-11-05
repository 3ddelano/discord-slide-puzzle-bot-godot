extends Control

var is_started = false
var game_won = false

onready var board = $Viewport/MarginContainer/VBoxContainer/GameView/Board
onready var overlay = $Viewport/MarginContainer/VBoxContainer/GameView/StartOverlay
onready var overlay_text = $Viewport/MarginContainer/VBoxContainer/GameView/StartOverlay/TextOverlay
onready var move_value = $Viewport/MarginContainer/VBoxContainer/StatsView/HBoxContainer/Moves/MoveValue
onready var player_value = $Viewport/MarginContainer/VBoxContainer/StatsView/HBoxContainer/Player/PlayerValue
onready var viewport = $Viewport

var help_text = "Press any button to start"

func _ready():
	help_text = "Press any button to start"

	overlay.visible = false

	update_board_size(3)
	set_show_numbers(true)
	update_backgound_texture("res://assets/backgrounds/deku.jpg")


func _on_Board_game_started():
	overlay.visible = false
	is_started = true
	game_won = false


func _on_Board_game_won():
	overlay_text.text = 'Nice Work!\nYou won!'
	help_text = "Game ended"
	overlay.visible = true
	is_started = false
	game_won = true


func _on_Board_moves_updated(move_count):
	move_value.text = str(move_count)

#func _on_RestartButton_pressed():
#	if not is_started:
#		return
#	board.reset_move_count()
#	board.scramble_board()
#	board.game_state = board.GAME_STATES.STARTED
#	is_started = true

func move(dir: String):
	match dir:
		"left":
			board.move(Vector2(1, 0))
		"right":
			board.move(Vector2(-1, 0))
		"up":
			board.move(Vector2(0, 1))
		"down":
			board.move(Vector2(0, -1))

func start_game():
	if not is_started:
		board.scramble_board()
		board.game_state = board.GAME_STATES.STARTED
		is_started = true
		help_text = "Game in progress. Press a button to make a move."

func update_board_size(new_size):
	board.update_size(new_size)


func set_show_numbers(state):
	board.set_tile_numbers(state)


func update_backgound_texture(image_path: String):
	var tex: StreamTexture = load(image_path)
	board.update_background_texture(tex)


func set_player(tag: String):
	player_value.text = tag
