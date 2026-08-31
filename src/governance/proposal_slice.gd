extends Node
## Proposal slice — in-game governance (Phase 24). Grounds the
## `CommunityOwnsTheFuture` constitution principle: players submit proposals,
## others vote, and a proposal ratifies only once a quorum of distinct voters
## has cast ballots within a voting window and a threshold fraction favour the
## change. The proposal author cannot vote on their own proposal, so a single
## author cannot self-ratify. A ratified proposal mirrors the fabric decision
## state machine (`proposed → accepted → superseded`); a proposal whose window
## lapses without ratifying transitions to `expired` — both states are defined
## in the fabric GovernanceSystem state machine.
##
## Host authority (Phase 18/24): the host owns governance state. A
## non-authoritative slice (client) forwards submit/vote intents to the host
## and applies `governance_synced` broadcasts. Open proposals + the decisions
## log round-trip through the save snapshot and the authoritative sync.
##
## Balance numbers (threshold, quorum, voting window, guild min tier) come from
## the fabric GovernanceSystem entity — fabric-first, no hardcoded constants.
##
## Social skill wiring: `can_form_guild` gates guild formation on the
## Leadership skill tier (apprentice or higher).
##
## Plug contract (GameBus signals emitted / consumed):
##   OUT : proposal_submitted / proposal_ratified
##         governance_synced(data)  — authoritative full state (host)
##         proposal_submit_intent / proposal_vote_intent — client intent
##   IN  : proposal_submit_intent / proposal_vote_intent (host applies)
##         governance_synced(data)  — apply authoritative state (client)
##
## Public API:
##   submit_proposal(author, title, body) -> String
##   vote(proposal_id, voter, verdict)    -> Dictionary  ("for" / "against")
##   get_proposal(proposal_id)            -> Dictionary
##   get_all_proposals()                  -> Array
##   get_decisions_log()                  -> Array      (ratified proposals)
##   is_open(proposal_id)                 -> bool
##   expire_proposals()                   -> int   (mark lapsed proposals expired)
##   supersede_proposal(proposal_id, replacement_id) -> Dictionary
##   get_governance_data()                -> Dictionary  (persistence + sync)
##   apply_governance_data(data)          -> void
##   set_ratification_threshold(frac) / set_quorum(n) / set_voting_window(seconds)
##   can_form_guild(leadership_tier)      -> bool

const SkillTiers := preload("res://src/core/skill_tiers.gd")

const STATE_PROPOSED := "proposed"
const STATE_ACCEPTED := "accepted"
const STATE_SUPERSEDED := "superseded"
const STATE_EXPIRED := "expired"

## How often (seconds) the runtime window-expiry tick runs.
const EXPIRY_TICK_INTERVAL: float = 1.0

## Fallbacks mirroring the fabric GovernanceSystem defaults; overridden from
## GameData in _ready().
const DEFAULT_RATIFICATION_THRESHOLD: float = 0.6
const DEFAULT_QUORUM: int = 3
const DEFAULT_WINDOW_SECONDS: float = 86400.0
const DEFAULT_GUILD_MIN_TIER := "apprentice"

## Host authority (Phase 18). The host mutates + broadcasts; a client forwards
## intent and applies authoritative deltas.
var is_authoritative: bool = true

var _proposals: Dictionary = {}
var _next_id: int = 0
var _decisions_log: Array = []
var _ratification_threshold: float = DEFAULT_RATIFICATION_THRESHOLD
var _quorum: int = DEFAULT_QUORUM
var _window_seconds: float = DEFAULT_WINDOW_SECONDS
var _guild_min_tier: String = DEFAULT_GUILD_MIN_TIER
var _expiry_tick_accum: float = 0.0

func _ready() -> void:
	_load_governance_config()
	GameBus.proposal_submit_intent.connect(_on_submit_intent)
	GameBus.proposal_vote_intent.connect(_on_vote_intent)
	GameBus.proposal_supersede_intent.connect(_on_supersede_intent)
	GameBus.governance_synced.connect(_on_governance_synced)

func _process(delta: float) -> void:
	if not is_authoritative:
		return
	_expiry_tick_accum += delta
	if _expiry_tick_accum >= EXPIRY_TICK_INTERVAL:
		_expiry_tick_accum = 0.0
		expire_proposals()

## Load ratification + guild parameters from the fabric GovernanceSystem entity.
func _load_governance_config() -> void:
	var res: Resource = GameData.WORLD_SYSTEMS.get("GovernanceSystem", null)
	if res == null:
		return
	var rat: Variant = res.get("ratification")
	if rat is Dictionary:
		var r: Dictionary = rat
		if r.has("threshold"):
			_ratification_threshold = float(r["threshold"])
		if r.has("quorum"):
			_quorum = int(r["quorum"])
		if r.has("windowSeconds"):
			_window_seconds = float(r["windowSeconds"])
	var tier: String = str(res.get("guildMinTier"))
	if tier != "":
		_guild_min_tier = tier

func set_ratification_threshold(frac: float) -> void:
	_ratification_threshold = frac

func set_quorum(n: int) -> void:
	_quorum = n

func set_voting_window(seconds: float) -> void:
	_window_seconds = seconds

## Wall-clock now (Unix epoch seconds).
func _now() -> float:
	return Time.get_unix_time_from_system()

## Submit a proposal for community vote. On the authoritative slice returns the
## proposal id; on a client forwards a submit intent and returns "".
func submit_proposal(author: String, title: String, body: String) -> String:
	if not is_authoritative:
		GameBus.proposal_submit_intent.emit(author, title, body)
		return ""
	var id := "proposal_%d" % _next_id
	_next_id += 1
	var now := _now()
	_proposals[id] = {
		"id": id,
		"author": author,
		"title": title,
		"body": body,
		"state": STATE_PROPOSED,
		"votes": {},
		"submitted_at": now,
		"expires_at": now + _window_seconds,
	}
	GameBus.proposal_submitted.emit(id)
	_emit_synced()
	return id

## Cast a vote ("for" or "against"). One vote per voter (last wins). The author
## cannot vote on their own proposal; votes past the window are rejected. After
## the vote is recorded, ratification is re-checked. On a client this forwards a
## vote intent. Returns the proposal record (or a failure/forwarded marker).
func vote(proposal_id: String, voter: String, verdict: String) -> Dictionary:
	if not is_authoritative:
		GameBus.proposal_vote_intent.emit(proposal_id, voter, verdict)
		return { "success": false, "reason": "forwarded", "proposal_id": proposal_id }
	var p: Dictionary = _proposals.get(proposal_id, {})
	if p.is_empty():
		return { "success": false, "reason": "unknown_proposal" }
	if verdict != "for" and verdict != "against":
		return { "success": false, "reason": "invalid_verdict", "proposal_id": proposal_id }
	if str(p["state"]) != STATE_PROPOSED:
		return { "success": false, "reason": "not_open", "proposal_id": proposal_id }
	if str(p["author"]) == voter:
		return { "success": false, "reason": "author_cannot_vote", "proposal_id": proposal_id }
	if float(p["expires_at"]) <= _now():
		return { "success": false, "reason": "expired", "proposal_id": proposal_id }
	p["votes"][voter] = verdict
	_check_ratification(proposal_id)
	_emit_synced()
	return get_proposal(proposal_id)

func get_proposal(proposal_id: String) -> Dictionary:
	return _proposals.get(proposal_id, {}).duplicate(true)

## Every proposal (submitted and ratified) as a list of records.
func get_all_proposals() -> Array:
	var out: Array = []
	for id in _proposals:
		out.append(_proposals[id].duplicate(true))
	return out

## Whether a proposal is still open for voting (proposed and within its window).
func is_open(proposal_id: String) -> bool:
	var p: Dictionary = _proposals.get(proposal_id, {})
	if p.is_empty():
		return false
	if str(p["state"]) != STATE_PROPOSED:
		return false
	return float(p["expires_at"]) > _now()

## Mark every proposed proposal whose voting window has lapsed as expired, so it
## stops rendering vote controls and can no longer ratify. Returns the number
## expired. Called by the runtime tick and directly by tests.
func expire_proposals() -> int:
	var now := _now()
	var n := 0
	for id in _proposals:
		var p: Dictionary = _proposals[id]
		if str(p["state"]) == STATE_PROPOSED and float(p["expires_at"]) <= now:
			p["state"] = STATE_EXPIRED
			n += 1
	if n > 0:
		_emit_synced()
	return n

## Mark a proposal as superseded by a ratified replacement. Per the fabric
## GovernanceSystem state machine, supersede is legal from `proposed` or
## `accepted`, and the replacement must already be ratified (`accepted`). On a
## client this forwards a supersede intent. Returns a success/failure record.
func supersede_proposal(proposal_id: String, replacement_id: String) -> Dictionary:
	if not is_authoritative:
		GameBus.proposal_supersede_intent.emit(proposal_id, replacement_id)
		return { "success": false, "reason": "forwarded", "proposal_id": proposal_id }
	var p: Dictionary = _proposals.get(proposal_id, {})
	if p.is_empty():
		return { "success": false, "reason": "unknown_proposal", "proposal_id": proposal_id }
	var state := str(p["state"])
	if state == STATE_SUPERSEDED or state == STATE_EXPIRED:
		return { "success": false, "reason": "not_supersedable", "proposal_id": proposal_id }
	var repl: Dictionary = _proposals.get(replacement_id, {})
	if repl.is_empty() or str(repl["state"]) != STATE_ACCEPTED:
		return { "success": false, "reason": "replacement_not_ratified", "proposal_id": proposal_id }
	p["state"] = STATE_SUPERSEDED
	_emit_synced()
	return { "success": true, "reason": "", "proposal_id": proposal_id, "state": STATE_SUPERSEDED }

## The runtime decisions log: every ratified proposal, most recent last.
func get_decisions_log() -> Array:
	return _decisions_log.duplicate()

## Restore the decisions log from a persisted snapshot (persistence restore).
func apply_decisions_log(log: Array) -> void:
	_decisions_log.clear()
	for entry in log:
		if entry is Dictionary:
			_decisions_log.append(entry)

## Whether a Leadership tier is sufficient to form a guild.
func can_form_guild(leadership_tier: String) -> bool:
	return SkillTiers.rank(leadership_tier) >= SkillTiers.rank(_guild_min_tier)

## Full governance state (open proposals + decisions log) for persistence and
## authoritative sync.
func get_governance_data() -> Dictionary:
	return {
		"proposals": _proposals.duplicate(true),
		"decisions_log": _decisions_log.duplicate(),
		"next_id": _next_id,
	}

## Restore full governance state from a persisted snapshot / authoritative sync.
func apply_governance_data(data: Dictionary) -> void:
	_proposals.clear()
	var props: Variant = data.get("proposals", {})
	if props is Dictionary:
		_proposals = props.duplicate(true)
	_decisions_log.clear()
	var log: Variant = data.get("decisions_log", [])
	if log is Array:
		for entry in log:
			if entry is Dictionary:
				_decisions_log.append(entry)
	_next_id = int(data.get("next_id", _next_id))

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _check_ratification(proposal_id: String) -> void:
	var p: Dictionary = _proposals[proposal_id]
	var votes: Dictionary = p["votes"]
	var total: int = votes.size()
	if total < _quorum:
		return
	var for_count: int = 0
	for voter in votes:
		if votes[voter] == "for":
			for_count += 1
	if float(for_count) / float(total) >= _ratification_threshold:
		p["state"] = STATE_ACCEPTED
		_decisions_log.append({
			"proposal_id": proposal_id,
			"title": p["title"],
			"author": p["author"],
			"state": STATE_ACCEPTED,
		})
		GameBus.proposal_ratified.emit(proposal_id, p["title"])

# ---------------------------------------------------------------------------
# Authority (Phase 24) — intent forwarding + authoritative broadcast
# ---------------------------------------------------------------------------

func _on_submit_intent(author: String, title: String, body: String) -> void:
	if is_authoritative:
		submit_proposal(author, title, body)

func _on_vote_intent(proposal_id: String, voter: String, verdict: String) -> void:
	if is_authoritative:
		vote(proposal_id, voter, verdict)

func _on_supersede_intent(proposal_id: String, replacement_id: String) -> void:
	if is_authoritative:
		supersede_proposal(proposal_id, replacement_id)

func _on_governance_synced(data: Dictionary) -> void:
	if not is_authoritative:
		apply_governance_data(data)

func _emit_synced() -> void:
	if is_authoritative:
		GameBus.governance_synced.emit(get_governance_data())
