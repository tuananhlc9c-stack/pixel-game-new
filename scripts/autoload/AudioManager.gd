extends Node

# Quản lý phát âm thanh tập trung (Audio Manager)
# Tự động preload và phát âm thanh từ res://Content T1/sounds/

const SOUND_PATHS: Dictionary = {
	# Player
	"player_swing": "res://Content T1/sounds/items/sword.wav",
	"player_roll": "res://Content T1/sounds/player/roll.wav",
	"player_hurt": "res://Content T1/sounds/player/playerHurt.wav",
	
	# Combat & Enemies / Boss
	"enemy_hurt": "res://Content T1/sounds/enemies/enemyHurt.wav",
	"enemy_die": "res://Content T1/sounds/enemies/enemyDie.wav",
	"projectile": "res://Content T1/sounds/enemies/projectile.wav",
	"explosion": "res://Content T1/sounds/items/explosion.wav",
	"fire": "res://Content T1/sounds/items/fire.wav",
	"arrow": "res://Content T1/sounds/items/arrow.wav",
	"boomerang": "res://Content T1/sounds/items/boomerang.wav",
	
	# Items, Chest & Interact
	"coin": "res://Content T1/sounds/items/coin.wav",
	"coin_edit": "res://Content T1/sounds/items/coin-edit.wav",
	"chest": "res://Content T1/sounds/items/chest.wav",
	"set": "res://Content T1/sounds/items/set.wav",
	"grapple": "res://Content T1/sounds/items/grapple.wav",
	
	# UI
	"click": "res://Content T1/sounds/ui/click.wav",
	"select": "res://Content T1/sounds/ui/select.wav",
	"menu_open": "res://Content T1/sounds/ui/menu-open.wav",
	"menu_close": "res://Content T1/sounds/ui/menu-close.wav"
}

var sound_streams: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 16

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Preload all sounds
	for s_name in SOUND_PATHS.keys():
		var p: String = SOUND_PATHS[s_name]
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is AudioStream:
				sound_streams[s_name] = res

	# Initialize audio player pool
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		player_pool.append(p)

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if not sound_streams.has(sound_name):
		return null
	
	var stream: AudioStream = sound_streams[sound_name]
	if not stream:
		return null

	for p in player_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return p
			
	# Fallback nếu pool bận hết: mượn slot đầu tiên
	var fallback_player := player_pool[0]
	fallback_player.stream = stream
	fallback_player.volume_db = volume_db
	fallback_player.pitch_scale = pitch_scale
	fallback_player.play()
	return fallback_player

# Phát âm thanh có biến tấu cao độ nhẹ (pitch randomization) tạo cảm giác tự nhiên chân thực
func play_sfx_random_pitch(sound_name: String, volume_db: float = 0.0, pitch_min: float = 0.92, pitch_max: float = 1.08) -> AudioStreamPlayer:
	var rnd_pitch: float = randf_range(pitch_min, pitch_max)
	return play_sfx(sound_name, volume_db, rnd_pitch)
