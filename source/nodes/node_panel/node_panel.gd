class_name NodePanel extends Control

var chain_provider: ChainProvider
var chain_state: ChainState

const HEADER_PANEL_STYLE_BOX = preload("res://resource/style_box/nodes/header_panel_style.stylebox")

@export var drivechain_title_font_size : int = 32
@export var drivechain_descr_font_size : int = 16
@export var drivechain_minimum_height  : int = 100
@export var subchain_title_font_size   : int = 20
@export var subchain_descr_font_size   : int = 16
@export var subchain_minimum_height    : int = 70
@onready var overlay: ColorRect = $Overlay

@onready var download_button: DownloadButton = $MarginContainer/Container/Header/Download
@onready var heading_label: Label = $MarginContainer/Container/Header/Heading
@onready var description_label: Label = $MarginContainer/Container/Description
@onready var shimmer_effect: TextureRect = $ShimmerEffect
@onready var panel: Panel = $MarginContainer/Panel
@onready var progress_bar: ProgressBar = $MarginContainer/Container/Header/Download/ProgressBar
@onready var delete_button: Button = $MarginContainer/Container/Header/Delete
@onready var settings_button: Button = $MarginContainer/Container/Header/Settings

var download_req: HTTPRequest
var progress_timer: Timer
var cooldown_timer: Timer

const BACKUP_DIR_NAME := "wallets_backup"
const WALLET_INFO_PATH := "user://wallets_backup/wallet_info.json"

var is_drivechain: bool = false

func _ready():
	cooldown_timer = Timer.new()
	add_child(cooldown_timer)
	cooldown_timer.wait_time = 2.0
	cooldown_timer.one_shot = true
	cooldown_timer.connect("timeout", Callable(self, "_on_cooldown_timer_timeout"))
	
	delete_button.connect("pressed", Callable(self, "_on_delete_node_button_pressed"))
	settings_button.connect("pressed", Callable(self, "_on_settings_button_pressed"))
	
	download_button.action_requested.connect(_on_action_requested)
	
	Appstate.connect("chain_states_changed", Callable(self, "update_view"))
	if not is_drivechain:
		Appstate.connect("drivechain_downloaded", Callable(self, "update_overlay"))
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_variation = load("res://assets/fonts/Satoshi-Regular.otf")
	heading_label.add_theme_font_override("font", font_variation)
	description_label.add_theme_font_override("font", font_variation)

func setup(_chain_provider: ChainProvider, _chain_state: ChainState):
	chain_provider = _chain_provider
	chain_state = _chain_state
	
	is_drivechain = chain_provider.chain_type == ChainProvider.c_type.MAIN
	
	if is_drivechain:
		heading_label.add_theme_font_size_override("font_size", drivechain_title_font_size)
		description_label.add_theme_font_size_override("font_size", drivechain_descr_font_size)
		custom_minimum_size.y = drivechain_minimum_height
		shimmer_effect.show()
		panel.set("theme_override_styles/panel", HEADER_PANEL_STYLE_BOX)
	else:
		heading_label.add_theme_font_size_override("font_size", subchain_title_font_size)
		description_label.add_theme_font_size_override("font_size", subchain_descr_font_size)
		custom_minimum_size.y = subchain_minimum_height
		size.y = subchain_minimum_height
	
	heading_label.text = chain_provider.display_name
	description_label.text = chain_provider.description
	download_button.text = str(int(chain_provider.binary_zip_size * 0.000001)) + " mb"
	
	update_view()
	is_drivechain = chain_provider.chain_type == ChainProvider.c_type.MAIN
	
	if is_drivechain:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	update_overlay()

func update_view():
	if is_drivechain:
		update_drivechain_view()
	else:
		update_sidechain_view()
	update_overlay()

func update_drivechain_view():
	update_button_state()
	overlay.color = Color(1, 1, 1, 0)  # Always fully transparent for L1

func update_sidechain_view():
	var drivechain_provider = Appstate.get_drivechain_provider()
	var drivechain_state = Appstate.chain_states[drivechain_provider.id] if drivechain_provider.id in Appstate.chain_states else null
	var drivechain_running = drivechain_provider.is_ready_for_execution() and drivechain_state and drivechain_state.state == ChainState.c_state.RUNNING
	download_button.disabled = not drivechain_running
	if not drivechain_running:
		download_button.modulate = Color(0.5, 0.5, 0.5)  # Grey out the button
		heading_label.modulate = Color(0.5, 0.5, 0.5)  # Grey out the heading text
		description_label.modulate = Color(0.5, 0.5, 0.5)  # Grey out the description text
	else:
		download_button.modulate = Color(1, 1, 1)  # Normal color
		heading_label.modulate = Color(1, 1, 1)  # Normal color for heading text
		description_label.modulate = Color(1, 1, 1)  # Normal color for description text
	update_button_state()
	
func update_overlay():
	if is_drivechain:
		overlay.color = Color(1, 1, 1, 0)  
	else:
		var drivechain_provider = Appstate.get_drivechain_provider()
		var drivechain_state = Appstate.chain_states[drivechain_provider.id] if drivechain_provider.id in Appstate.chain_states else null
		var drivechain_running = drivechain_provider.is_ready_for_execution() and drivechain_state and drivechain_state.state == ChainState.c_state.RUNNING
		if drivechain_running:
			overlay.color = Color(1, 1, 1, 0) 
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			heading_label.modulate = Color(1, 1, 1)  # Normal color for heading text
			description_label.modulate = Color(1, 1, 1)  # Normal color for description text
		else:
			overlay.color = Color(1, 1, 1, 0.5)  # Semi-transparent white
			overlay.mouse_filter = Control.MOUSE_FILTER_STOP
			heading_label.modulate = Color(0.5, 0.5, 0.5)  # Grey out the heading text
			description_label.modulate = Color(0.5, 0.5, 0.5)  # Grey out the description text

func update_button_state():
	var drivechain_provider = Appstate.get_drivechain_provider()
	var drivechain_state = Appstate.chain_states[drivechain_provider.id] if drivechain_provider.id in Appstate.chain_states else null
	var drivechain_running = drivechain_provider.is_ready_for_execution() and drivechain_state and drivechain_state.state == ChainState.c_state.RUNNING
	
	if not chain_provider.is_ready_for_execution():
		download_button.set_state(DownloadButton.STATE.NOT_DOWNLOADED)
	elif chain_provider.is_ready_for_execution() and chain_state.state != ChainState.c_state.RUNNING:
		download_button.set_state(DownloadButton.STATE.NOT_RUNNING)
	else:
		download_button.set_state(DownloadButton.STATE.RUNNING)
	
	if not is_drivechain:
		download_button.disabled = not drivechain_running
		if not drivechain_running:
			download_button.modulate = Color(0.5, 0.5, 0.5)  # Grey out the button
		else:
			download_button.modulate = Color(1, 1, 1)

func _on_action_requested(action: String):
	var drivechain_provider = Appstate.get_drivechain_provider()
	var drivechain_state = Appstate.chain_states[drivechain_provider.id] if drivechain_provider.id in Appstate.chain_states else null
	var drivechain_running = drivechain_provider.is_ready_for_execution() and drivechain_state and drivechain_state.state == ChainState.c_state.RUNNING
	
	if is_drivechain or drivechain_running:
		if cooldown_timer.is_stopped():
			match action:
				"download":
					download()
				"run":
					_on_start_button_pressed()
				"stop":
					_on_stop_button_pressed()
			if action == "run":
				start_cooldown()
		else:
			print("Action is on cooldown. Please wait.")
	else:
		print("Cannot perform action. Drivechain is not running.")

func start_cooldown():
	cooldown_timer.start()
	download_button.disabled = true

func _on_cooldown_timer_timeout():
	download_button.disabled = false

func download():
	print("\nStarting download process for: ", chain_provider.id, "\n")
	
	ensure_directories_exist()
	
	var user_data_dir = OS.get_user_data_dir()
	var wallet_starters_dir = user_data_dir.path_join("wallet_starters")
	var sidechain_base_dir = chain_provider.base_dir
	
	print("Wallet starters directory: ", wallet_starters_dir)
	print("Sidechain base directory: ", sidechain_base_dir)
	
	if chain_provider.chain_type == ChainProvider.c_type.MAIN:
		handle_mainchain_file(wallet_starters_dir, sidechain_base_dir)
	else:
		handle_sidechain_file(wallet_starters_dir, sidechain_base_dir)
	
	download_button.set_state(DownloadButton.STATE.DOWNLOADING)
	
	setup_download_requirements()
	initiate_download_process()

func handle_mainchain_file(wallet_starters_dir: String, sidechain_base_dir: String):
	var mainchain_filename = "mainchain_starter.txt"
	var source_path = wallet_starters_dir.path_join(mainchain_filename)
	var dest_path = sidechain_base_dir.path_join(mainchain_filename)
	
	print("Checking for mainchain starter file:")
	print("Source path: ", source_path)
	print("Destination path: ", dest_path)
	
	if not FileAccess.file_exists(dest_path):
		if FileAccess.file_exists(source_path):
			print("Mainchain starter file found in wallet_starters directory. Moving to sidechain base directory.")
			var err = DirAccess.copy_absolute(source_path, dest_path)
			if err == OK:
				print("Successfully moved mainchain starter file to sidechain base directory.")
			else:
				print("Failed to move mainchain starter file. Error code: ", err)
		else:
			print("Mainchain starter file not found in wallet_starters directory.")
			print("This may indicate that the wallet has not been set up properly.")
			print("Please ensure you have created a wallet and generated the mainchain starter file.")
			print("If you have already created a wallet, try regenerating the mainchain starter file.")
			list_directory_contents(wallet_starters_dir)
	else:
		print("Mainchain starter file already exists in sidechain base directory.")

func handle_sidechain_file(wallet_starters_dir: String, sidechain_base_dir: String):
	var slot_number = get_sidechain_slot_number()
	var sidechain_filename = "sidechain_%s_starter.txt" % slot_number
	var source_path = wallet_starters_dir.path_join(sidechain_filename)
	var dest_path = sidechain_base_dir.path_join(sidechain_filename)
	
	print("Checking for sidechain starter file:")
	print("Source path: ", source_path)
	print("Destination path: ", dest_path)
	
	if not FileAccess.file_exists(dest_path):
		if FileAccess.file_exists(source_path):
			print("Sidechain starter file found in wallet_starters directory. Moving to sidechain base directory.")
			var err = DirAccess.copy_absolute(source_path, dest_path)
			if err == OK:
				print("Successfully moved sidechain starter file to sidechain base directory.")
			else:
				print("Failed to move sidechain starter file. Error code: ", err)
		else:
			print("Sidechain starter file not found in wallet_starters directory.")
			print("This may indicate that the wallet has not been set up properly.")
			print("Please ensure you have created a wallet and generated sidechain starter files.")
			print("If you have already created a wallet, try regenerating the sidechain starter files.")
			list_directory_contents(wallet_starters_dir)
	else:
		print("Sidechain starter file already exists in sidechain base directory.")

func get_sidechain_slot_number() -> String:
	if chain_provider and "slot" in chain_provider:
		var slot = chain_provider.slot
		if slot != -1:
			return str(slot)
	
	print("Warning: Slot number not found for chain ID: ", chain_provider.id)
	return "unknown"

func ensure_directories_exist():
	var user_data_dir = OS.get_user_data_dir()
	var wallet_starters_dir = user_data_dir.path_join("wallet_starters")
	
	var dir = DirAccess.open(user_data_dir)
	if dir:
		if not dir.dir_exists("wallet_starters"):
			var err = dir.make_dir("wallet_starters")
			if err != OK:
				print("Failed to create wallet_starters directory. Error code: ", err)
	else:
		print("Failed to access user data directory")
	
	# Ensure the sidechain base directory exists
	if chain_provider:
		var err = DirAccess.make_dir_recursive_absolute(chain_provider.base_dir)
		if err != OK:
			print("Failed to create sidechain base directory. Error code: ", err)

func list_directory_contents(path: String):
	var dir = DirAccess.open(path)
	if dir:
		print("Contents of ", path, ":")
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("  [Dir] " + file_name)
			else:
				print("  [File] " + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("An error occurred when trying to access the path: ", path)
		print("This could be due to permission issues or the directory not existing.")
		print("Please check that the following directory exists and is accessible:")
		print(path)

func setup_download_requirements():
	if download_req != null:
		remove_child(download_req)
	
	if progress_timer != null:
		progress_timer.stop()
		remove_child(progress_timer)

func initiate_download_process():
	print("Downloading ", chain_provider.display_name, " from ", chain_provider.download_url)
	download_req = HTTPRequest.new()
	add_child(download_req)
	download_req.request_completed.connect(self._on_download_complete)
	
	var err = download_req.request(chain_provider.download_url)
	if err != OK:
		push_error("An error occurred during download request.")
		return
	
	progress_timer = Timer.new()
	add_child(progress_timer)
	progress_timer.wait_time = 0.1
	progress_timer.timeout.connect(self._on_download_progress)
	progress_timer.start()
	progress_bar.visible = true

func _on_download_progress():
	if download_req != null:
		var bodySize: float = download_req.get_body_size()
		var downloadedBytes: float = download_req.get_downloaded_bytes()
		progress_bar.value = downloadedBytes * 100 / bodySize

func _on_download_complete(result, response_code, _headers, body):
	reset_download()
	if result != 0 or response_code != 200:
		print("Could not download ", chain_provider.display_name, ": ", response_code)
		return
	
	print("Downloading ", chain_provider.display_name,  ": OK" )
	var path = chain_provider.base_dir + "/" + chain_provider.id + ".zip"
	var save_game = FileAccess.open(path, FileAccess.WRITE)
	save_game.store_buffer(body)
	save_game.close()
	
	unzip_file_and_setup_binary(chain_provider.base_dir, path)
	download_button.set_state(DownloadButton.STATE.NOT_RUNNING)

func reset_download():
	if download_req:
		remove_child(download_req)
		download_req.queue_free()
	if progress_timer:
		progress_timer.stop()
		remove_child(progress_timer)
		progress_timer.queue_free()
	progress_bar.visible = false
	update_view()

func unzip_file_and_setup_binary(base_dir: String, zip_path: String):
	var prog = "unzip"
	var args = [zip_path, "-d", base_dir]
	if Appstate.get_platform() == Appstate.platform.WIN:
		prog = "powershell.exe"
		args = ["-Command", 'Expand-Archive -Force ' + zip_path + ' ' + base_dir]

	print("Unzipping ", zip_path, ": ", prog, " ", args)

	OS.execute(prog, args)

	chain_provider.write_start_script()
	if Appstate.get_platform() != Appstate.platform.WIN:
		var start_path = ProjectSettings.globalize_path(chain_provider.get_start_path())
		print("chmodding start path: ", start_path)

		var bin_path = ProjectSettings.globalize_path(chain_provider.base_dir + "/" + chain_provider.binary_zip_path)
		print("chmodding bin path: ", bin_path)

		OS.execute("chmod", ["+x", start_path])
		OS.execute("chmod", ["+x", bin_path])

	update_view()

func _on_start_button_pressed():
	var drivechain_provider = Appstate.get_drivechain_provider()
	var drivechain_state = Appstate.chain_states[drivechain_provider.id] if drivechain_provider.id in Appstate.chain_states else null
	var drivechain_running = drivechain_provider.is_ready_for_execution() and drivechain_state and drivechain_state.state == ChainState.c_state.RUNNING
	
	if is_drivechain or drivechain_running:
		print("Starting chain: ", chain_provider.id)
		chain_provider.start_chain()
		download_button.set_state(DownloadButton.STATE.RUNNING)
		update_view()
	else:
		print("Cannot start sidechain. Drivechain is not running.")

func _on_stop_button_pressed():
	if is_drivechain:
		print("Stopping drivechain: ", chain_provider.id)
		stop_all_running_sidechains()
		await get_tree().create_timer(1.0).timeout  # Wait for sidechains to stop

	print("Stopping chain: ", chain_provider.id)
	chain_state.stop_chain()
	download_button.set_state(DownloadButton.STATE.NOT_RUNNING)
	update_view()

func _on_settings_button_pressed():
	Appstate.show_chain_provider_info(chain_provider)

func _on_delete_node_button_pressed():
	var confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.dialog_text = "Are you sure you want to delete your node AND wallet?"
	confirmation_dialog.min_size = Vector2(400, 100)
	add_child(confirmation_dialog)
	confirmation_dialog.popup_centered()

	confirmation_dialog.connect("confirmed", Callable(self, "_on_confirm_delete_and_purge"))
	confirmation_dialog.connect("popup_hide", Callable(confirmation_dialog, "queue_free"))

func _on_confirm_delete_and_purge():
	print("User has confirmed the action.")
	delete_backup()
	purge()

func delete_backup():
	print("Starting deletion process for provider: ", chain_provider.id, "\n")
	var backup_dir_path = Appstate.setup_wallets_backup_directory()
	var target_backup_path = "%s/%s" % [backup_dir_path, chain_provider.id.replace("/", "_")]
	var dir_separator = "\\" if OS.get_name() == "Windows" else "/"
	target_backup_path = target_backup_path.replace("/", dir_separator).replace("\\", dir_separator)

	print("Target backup path for deletion: ", target_backup_path, "\n")

	var command: String
	var arguments: PackedStringArray
	var output: Array = []

	match OS.get_name():
		"Windows":
			command = "cmd"
			arguments = PackedStringArray(["/c", "rd", "/s", "/q", target_backup_path])
		"Linux", "macOS", "FreeBSD":
			command = "rm"
			arguments = PackedStringArray(["-rf", target_backup_path])
		_:
			print("OS not supported for direct folder deletion.\n")
			return

	print("Executing deletion command: ", command, " with arguments: ", arguments, "\n")
	var result = OS.execute(command, arguments, output, false, false)
	if result == OK:
		print("Successfully deleted backup for '", chain_provider.id, "' at: ", target_backup_path, "\n")
		var wallet_paths_info = load_existing_wallet_paths_info()
		wallet_paths_info.erase(chain_provider.id)
		save_wallet_paths_info(wallet_paths_info)
		print("Successfully removed '", chain_provider.id, "' from wallet paths info.\n")
	else:
		var output_str = Appstate.array_to_string(output)
		print("Failed to delete backup for ", chain_provider.id, "\n")

func purge():
	print("Purging chain provider: ", chain_provider.id)
	stop_and_cleanup_chain()
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
	purge_directory()
	
	print("Loading version configuration...")
	Appstate.load_version_config()

	print("Loading configuration...")
	Appstate.load_config()

	print("Saving configuration...")
	Appstate.save_config()

	Appstate.load_app_config()

	print("Setting up directories...")
	Appstate.setup_directories()

	print("Setting up configurations...")
	Appstate.setup_confs()

	print("Setting up chain states...")
	Appstate.setup_chain_states()
	
	Appstate.chain_providers_changed.emit()
	
	Appstate.start_chain_states()

func stop_and_cleanup_chain():
	if chain_provider:
		print("Attempting to stop and clean up the chain for provider: ", chain_provider.id)
		if chain_provider.id in Appstate.chain_states:
			var chain_state = Appstate.chain_states[chain_provider.id]
			if chain_state:
				chain_state.stop_chain()
				await get_tree().create_timer(1.0).timeout
				if is_instance_valid(chain_state):
					remove_child(chain_state)
					chain_state.cleanup()
					print("Chain stopped and node removed for provider:", chain_provider.display_name)
				else:
					print("Chain state is no longer valid after stopping.")
			else:
				print("Chain state not found in AppState.chain_states for id: ", chain_provider.id)
		else: 
			print("Chain provider id not found in AppState.chain_states: ", chain_provider.id)
	else:
		print("stop_and_cleanup_chain called but no chain provider available.")

func purge_directory():
	if chain_provider.id == "ethsail":
		Appstate.delete_ethereum_directory()
	elif chain_provider.id == "zsail":
		Appstate.delete_zcash_directory()

	print("Preparing to purge directory for provider: ", chain_provider.display_name)
	var directory_text = ProjectSettings.globalize_path(chain_provider.base_dir)
	print(directory_text + " is the directory txt")
	
	if OS.get_name() == "Windows":
		directory_text = directory_text.replace("/", "\\")
	
	Appstate.purge(directory_text)
	print("Directory purged: " + directory_text)

func load_existing_wallet_paths_info() -> Dictionary:
	var wallet_paths_info = {}
	var file = FileAccess.open(WALLET_INFO_PATH, FileAccess.ModeFlags.READ)
	if file != null:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			wallet_paths_info = json.data
		else:
			print("Failed to parse existing wallet paths JSON. Error: ", error)
	else:
		print("No existing wallet paths JSON file found. Starting with an empty dictionary.")
	return wallet_paths_info

func save_wallet_paths_info(wallet_paths_info: Dictionary) -> void:
	var json_text := JSON.stringify(wallet_paths_info)
	var file := FileAccess.open(WALLET_INFO_PATH, FileAccess.ModeFlags.WRITE)
	if file != null:
		file.store_string(json_text)
		file.flush()
		file.close()
	else:
		print("Failed to open JSON file for writing: ", WALLET_INFO_PATH)

func is_sidechain() -> bool:
	return not is_drivechain

func get_current_state() -> int:
	if chain_state == null:
		return -1  # or some other value to indicate an invalid state
	return chain_state.state

func refresh_chain_data():
	if chain_provider and chain_state:
		chain_provider.refresh()
		chain_state.refresh()
		update_view()
		
func stop_all_running_sidechains():
	for chain_id in Appstate.chain_states:
		var chain_state = Appstate.chain_states[chain_id]
		if chain_state.state == ChainState.c_state.RUNNING and chain_id != chain_provider.id:
			print("Stopping sidechain: ", chain_id)
			chain_state.stop_chain()
	await get_tree().create_timer(2.0).timeout
