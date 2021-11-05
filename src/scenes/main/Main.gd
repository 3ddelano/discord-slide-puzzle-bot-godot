extends Control

var PREFIX = "gd."

# games is a dictionary which has the
# key as the message_id and value as the game_data
var games = {}

# array of user_ids of players currently playing the game
var current_players = []

onready var current_players_value = $CurrentPlayersValue
onready var GameScene = preload("res://src/scenes/game/game_scene.tscn")
var backgrounds = {
	"deku": "res://assets/backgrounds/deku.jpg",
	"saitama": "res://assets/backgrounds/saitama.jpg",
	"allmight": "res://assets/backgrounds/allmight.jpg"
}

# These are buttons used for the game controls
onready var buttons = [ MessageButton.new().set_style(MessageButton.STYLES.PRIMARY).set_label("Left").set_custom_id("btn_left"), MessageButton.new().set_style(MessageButton.STYLES.PRIMARY).set_label("Right").set_custom_id("btn_right"), MessageButton.new().set_style(MessageButton.STYLES.PRIMARY).set_label("Up").set_custom_id("btn_up"), MessageButton.new().set_style(MessageButton.STYLES.PRIMARY).set_label("Down").set_custom_id("btn_down"), MessageButton.new().set_style(MessageButton.STYLES.SECONDARY).set_label(".").set_custom_id("dis1").set_disabled(true), MessageButton.new().set_style(MessageButton.STYLES.SECONDARY).set_label(".").set_custom_id("dis2").set_disabled(true)
	]
onready var rows = [MessageActionRow.new().add_component(buttons[4]).add_component(buttons[2]).add_component(buttons[5]),
	MessageActionRow.new().add_component(buttons[0]).add_component(buttons[3]).add_component(buttons[1])]

func _ready():
	var bot = $DiscordBot

	var file = File.new()
	file.open("res://token.secret", File.READ)
	var token = file.get_as_text()
	file.close()
	assert(Helpers.is_valid_str(token), "Missing token in file: token.secret")
	bot.TOKEN = token

	bot.connect("bot_ready", self, "_on_DiscordBot_bot_ready")
	bot.connect("message_create", self, "_on_DiscordBot_message_create")
	bot.connect("interaction_create", self, "_on_DiscordBot_interaction_create")
	bot.login()


func _on_DiscordBot_bot_ready(bot: DiscordBot):
	print("Logged in as " + bot.user.username + "#" + bot.user.discriminator)
	bot.set_presence({
		"activity": {
			"type": "Game",
			"name": "gd.play | Slide Puzzle"
		}
	})


func _on_DiscordBot_message_create(bot: DiscordBot, message: Message, channel: Dictionary):
	if message.author.bot or not message.content.begins_with(PREFIX):
		return

	var raw_content = message.content.lstrip(PREFIX)
	var tokens = []
	var r = RegEx.new()
	r.compile("\\S+") # Negated whitespace character class
	for token in r.search_all(raw_content):
		tokens.append(token.get_string())
	var cmd = tokens[0].to_lower()
	tokens.remove(0) # Remove the command name from the tokens
	var args = tokens
	handle_command(bot, message, channel, cmd, args)


func handle_command(bot: DiscordBot, message: Message, channel: Dictionary, cmd: String, args: Array):
	match cmd:
		"ping":
			# Basic latency check command
			var starttime = OS.get_ticks_msec()
			var msg = yield(bot.reply(message, "Ping.."), "completed")
			var latency = str(OS.get_ticks_msec() - starttime)
			bot.edit(msg, "Pong! Latency is " + latency + "ms.")

		"help":
			# Simple help command to tell instructions
			var embed = Embed.new().set_title("Slide Puzzle Game Help").set_timestamp().set_footer("Requested by " + message.author.username + "#" + message.author.discriminator + " | Powered by Godot & Discord.gd | Creator: 3ddelano#6033").set_color("#2c6ef2")

			var commands = {
				"ping": "Check my latency",
				"play": "Start the game\n**Optional Flags:** --image --size --hidenum\nEg. Start a 5x5 game - `gd.play --size=5`\nEg. Change background image - `gd.play --image=allmight`",
				"stop": "Stop the game"
			}

			var helptext = "**Available Commands**\n\n"
			for cmd in commands.keys():
				helptext += "`" + PREFIX + cmd + "` - " + commands[cmd] + "\n\n"

			embed.set_description(helptext)

			bot.send(message, {
				"embeds": [embed]
			})

		"play":
			# The main command to start a game

			if message.author.id in current_players:
				# The user is already in a game
				bot.reply(message, "You are already playing the game!")
				return


			var game = GameScene.instance()
			add_child(game)

			# Parse the various arguments for the game
			var ret = false
			if args.size() > 0:
				for arg in args:
					if arg.begins_with("--size="):
						var parts = arg.split('=')
						if parts.size() == 1:
							bot.reply(message, 'Invalid size provided. Enter a number from 3-7')
							ret = true
							break

						var size = int(parts[1])
						if size < 3 or size > 7:
							bot.reply(message, 'Invalid size provided. Enter a number from 3-7')
							ret = true
							break
						game.update_board_size(size)

					if arg.begins_with("--image="):
						var parts = arg.split('=')
						if parts.size() == 1:
							bot.reply(message, 'Invalid image provided. Enter one of: ' + PoolStringArray(backgrounds.keys()).join(", "))
							ret = true
							break

						var image = str(parts[1])
						if not image in backgrounds.keys():
							bot.reply(message, 'Invalid image provided. Enter one of: ' + PoolStringArray(backgrounds.keys()).join(", "))
							ret = true
							break

						var tex = backgrounds[image]
						game.update_backgound_texture(tex)

					if arg.begins_with("--hidenum"):
						game.set_show_numbers(false)


			if ret:
				# Invalid flags were passed
				game.queue_free()
				return

			print("New game started by " + message.author.username + "#" + message.author.discriminator + " on " + bot.guilds[message.guild_id].name)
			current_players.append(message.author.id)
			update_current_players_text()
			game.set_player(message.author.username + "#" + message.author.discriminator)


			yield(VisualServer, "frame_post_draw") # important
			var screenshot = game.viewport.get_texture().get_data()
			var bytes = screenshot.save_png_to_buffer()
			var embed = Embed.new().set_image("attachment://screenshot.png").set_title("Slide Puzzle Game").set_description(game.help_text).set_footer("Requested by " + message.author.username + "#" + message.author.discriminator).set_timestamp()

			var msg = yield(bot.send(message, {
				"embeds": [embed],
				"files": [{
					"name": "screenshot.png",
					"media_type": "image/png",
					"data": bytes
				}],
				"components": [rows[0], rows[1]]
			}), "completed")
			games[msg.id] = {
				"author_id": message.author.id,
				"author_tag": message.author.username + "#" + message.author.discriminator,
				"node_name": game.name
			}

		"stop":
			# Used to stop playing the game
			if not message.author.id in current_players:
				# User is not even playing a game
				bot.reply(message, "You are not playing the game!")
				return

			# Find the game which the user is playing and remove it
			for cur_game_id in games.keys():
				var game_data = games[cur_game_id]
				if game_data["author_id"] == message.author.id:
					var game_node = get_node(game_data["node_name"])
					game_node.queue_free()
					games.erase(cur_game_id)
					current_players.erase(message.author.id)
					update_current_players_text()
					bot.reply(message, "Your game was stopped.")
					break

		"players":
			var games_data = games.values()
			var players = []
			for game in games_data:
				players.append(game["author_tag"])

			var players_string = "None"
			if players.size() != 0:
				players_string = PoolStringArray(players).join(', ')
			bot.send(message, "**Current Players**: " + players_string)

func _on_DiscordBot_interaction_create(bot: DiscordBot, interaction: DiscordInteraction):
	if not interaction.is_button():
		return

	var msg_id = interaction.message.id

	# Remove buttons if the interaction is not cached in games variable
	if not games.has(msg_id):
		for embed in interaction.message.embeds:
			embed["description"] = "Game ended"
		interaction.update({
			"content": interaction.message.content,
			"embeds": interaction.message.embeds,
			"components": []
		})
		interaction.follow_up({
			"ephemeral": true,
			"content": "The game is ended or is timed out. Start a new game to play."
		})
		return


	# Check to see the author is the game author
	if not interaction.member.user.id == games[msg_id]["author_id"]:
		interaction.reply({
			"ephemeral": true,
			"content": "Not allowed. You are not the player of the game."
		})
		return

	var game_data = games[msg_id]
	var game_node = get_node(game_data["node_name"])

	# Check if the user has made the first move
	if not game_node.is_started:
		# Initial move can be any button
		game_node.start_game()
		var new_msg_data = yield(make_game_embed(interaction.message, game_node), "completed")
		interaction.defer_update()
		bot.edit(interaction.message, new_msg_data)
		return


	match interaction.data.custom_id:
		"btn_left":
			game_node.move("left")
		"btn_right":
			game_node.move("right")
		"btn_up":
			game_node.move("up")
		"btn_down":
			game_node.move("down")

	var new_msg_data = yield(make_game_embed(interaction.message, game_node), "completed")
	interaction.defer_update()
	bot.edit(interaction.message, new_msg_data)

	# Check if the game is won
	if game_node.game_won:
		game_node.queue_free()
		games.erase(msg_id)
		current_players.erase(interaction.member.user.id)
		update_current_players_text()
		return


# The main method which generates the embed after a move/command
# is made while the game is being played
func make_game_embed(message: Message, game_node: Node):
	var random_file_name = str(randi() % 4096)
	yield(VisualServer, "frame_post_draw") # important
	var image = game_node.viewport.get_texture().get_data()
	var bytes = image.save_png_to_buffer()

	var embed = Embed.new().set_title("Slide Puzzle Game").set_description(game_node.help_text).set_image("attachment://"+random_file_name+".png").set_footer("Requested by " + game_node.player_value.text).set_timestamp()

	return {
		"files": [{
			"name": random_file_name+".png",
			"media_type": "image/png",
			"data": bytes
		}],
		"attachments": [],
		"components": rows if not game_node.game_won else [],
		"embeds": [embed]
	}


func update_current_players_text():
	current_players_value.text = str(current_players.size())


func _on_CheckBox_toggled(button_pressed):
	if button_pressed:
		print("VERBOSE activated")
	else:
		print("VERBOSE deactivated")
	$DiscordBot.VERBOSE = button_pressed
