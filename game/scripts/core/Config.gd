extends Node
##
## Engine-wide configuration. Paths, feature flags, runtime toggles.
## Autoload as `Config`. Has no dependencies; loads first.
##

const DATA_DIR        := "res://data/"
const INDEX_FILE      := "res://data/_index.json"
const NPC_DIR         := "res://data/npc/"
const BRIEFINGS_DIR   := "res://data/briefings/"

## Feature flags. Defaults are safe for offline development.
var use_mock_ai: bool   = true
var debug_overlay: bool = false

## Set by command-line args. When true, BootValidator exits the process
## after running, instead of continuing to the main scene.
var validate_only: bool = false

## When true, BootValidator prints every NPC's flattened dossier before
## exiting. Useful for debugging which briefings each NPC starts with.
var dump_dossiers: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--validate-only" in args or "--check" in args:
		validate_only = true
	if "--dump-dossiers" in args:
		dump_dossiers = true
		validate_only = true   # dumping implies headless run
	if "--debug-overlay" in args:
		debug_overlay = true
	if "--real-ai" in args:
		use_mock_ai = false
