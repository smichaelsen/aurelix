extends Node
##
## Engine-wide typed signals.
##
## Add signals here as phases bring them online. Declaring them centrally
## makes the engine's nervous system discoverable in one file.
## Autoload as `EventBus`. No dependencies.
##

# --- Boot (phase 1) -------------------------------------------------------
signal data_loaded
signal boot_validated(ok: bool, error_count: int)

# --- Player / world (phase 3+) --------------------------------------------
signal player_moved(col: int, row: int)
signal player_facing_changed(facing: String)
signal player_step_changed(stepping: bool)
signal npc_facing_changed(npc_id: String, facing: String)
signal iskar_facing_changed(facing: String)
signal interaction_available(target_id: String, target_type: String, label: String)
signal interaction_unavailable
signal exit_attempted(direction: String, target: String)
signal cage_interacted(object_id: String)
signal cage_opened

# --- Dialogue (phase 4+) --------------------------------------------------
signal dialogue_requested(npc_id: String)
signal dialogue_opened(npc_id: String)
signal dialogue_closed

# --- Quests / facts (phase 5+) --------------------------------------------
signal fact_granted(fact_id: String, source: Dictionary)
signal quest_state_changed(quest_id: String, new_state: String)
signal quest_paid(quest_id: String)

# --- Inventory (phase 6+) -------------------------------------------------
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal item_offered(npc_id: String, item_id: String)
signal party_heal_applied(who: String, item_id: String, amount: int, hp: int, max_hp: int)

# --- Combat (phase 7+) ----------------------------------------------------
signal combat_started(encounter_id: String)
signal combat_ended(outcome: String)
signal enemy_defeated(enemy_id: String)
signal party_hp_changed(who: String, hp: int, max_hp: int)

# --- Companion (phase 7+) -------------------------------------------------
signal iskar_bonded
signal iskar_stance_changed(stance: String)
signal affinity_gained(amount: int, new_total: int)
signal companion_unlocked(tier: int, reward_id: String)
signal iskar_entered_location(location_id: String)

# --- Journal (phase 8+) ---------------------------------------------------
signal journal_briefing_added(briefing_id: String, tier: String)

# --- Dossier mutations (phase 9+) -----------------------------------------
signal npc_dossier_mutated(npc_id: String, briefing_id: String, tier: String)

# --- Debug overlay (phase 10+) --------------------------------------------
signal debug_turn_recorded(info: Dictionary)
