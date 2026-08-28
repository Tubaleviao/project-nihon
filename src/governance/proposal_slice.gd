extends Node
## Proposal slice — in-game governance (Phase 24). Grounds the
## `CommunityOwnsTheFuture` constitution principle: players submit proposals,
## others vote, and a proposal ratifies only once a quorum of distinct voters
## has cast ballots within a voting window and a threshold fraction favour the
## change. The proposal author cannot vote on their own proposal, so a single
## author cannot self-ratify. A ratified proposal mirrors the fabric decision
## state machine (`proposed → accepted → superseded`) and is recorded in a
## runtime decisions log.
##
## Balance numbers (threshold, quorum, voting window, guild min tier) come from
## the fabric GovernanceSystem entity — fabric-first, no hardcoded constants.
##
## Social skill wiring: `can_form_guild` gates guild formation on the
## Leadership skill tier (apprentice or higher).
##
## Plug contract (GameBus signals emitted):
##   OUT : proposal_submitted(proposal_id)
##         proposal_ratified(proposal_id, title)
##
## Public API:
##   submit_proposal(author, title, body) -> String
##   vote(proposal_id, voter, verdict)    -> Dictionary  ("for" / "against")
##   get_proposal(proposal_id)            -> Dictionary
##   get_all_proposals()                  -> Array
##   get_decisions_log()                  -> Array      (ratified proposals)
##   is_open(proposal_id)                 -> bool
##   set_ratification_threshold(frac) / set_quorum(n) / set_voting_window(seconds)
##   can_form_guild(leadership_tier)      -> bool

const STATE_PROPOSED := "proposed"
const STATE_ACCEPTED := "accepted"
const STATE_SUPERSEDED := "superseded"

## Skill tier order — matches fabric skill state machine (novice → master).
const TIER_ORDER: Array = ["novice", "apprentice", "journeyman", "expert", "master"]

## Fallbacks mirroring the fabric GovernanceSystem defaults; overridden from
## GameData in _ready().
const DEFAULT_RATIFICATION_THRESHOLD: float = 0.6
const DEFAULT_QUORUM: int = 3
const DEFAULT_WINDOW_SECONDS: float = 86400.0
const DEFAULT_GUILD_MIN_TIER := "apprentice"

var _proposals: Dictionary = {}
var _next_id: int = 0
var _decisions_log: Array = []
var _ratification_threshold: float = DEFAULT_RATIFICATION_THRESHOLD
var _quorum: int = DEFAULT_QUORUM
var _window_seconds: float = DEFAULT_WINDOW_SECONDS
var _guild_min_tier: String = DEFAULT_GUILD_MIN_TIER

func _ready() -> void:
	_load_governance_config()

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

## Wall-clock now (Unix epoch seconds) — the voting window is a real deadline,
## not process uptime, so it survives save/load like market listings.
func _now() -> float:
	return Time.get_unix_time_from_system()

## Submit a proposal for community vote; returns the proposal id.
func submit_proposal(author: String, title: String, body: String) -> String:
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
	return id

## Cast a vote ("for" or "against"). One vote per voter (last wins). The author
## cannot vote on their own proposal; votes past the window are rejected. After
## the vote is recorded, ratification is re-checked. Returns the proposal record.
func vote(proposal_id: String, voter: String, verdict: String) -> Dictionary:
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
	return get_proposal(proposal_id)

func get_proposal(proposal_id: String) -> Dictionary:
	return _proposals.get(proposal_id, {}).duplicate()

## Every proposal (submitted and ratified) as a list of records.
func get_all_proposals() -> Array:
	var out: Array = []
	for id in _proposals:
		out.append(_proposals[id].duplicate())
	return out

## Whether a proposal is still open for voting (proposed and within its window).
func is_open(proposal_id: String) -> bool:
	var p: Dictionary = _proposals.get(proposal_id, {})
	if p.is_empty():
		return false
	if str(p["state"]) != STATE_PROPOSED:
		return false
	return float(p["expires_at"]) > _now()

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
	return _tier_rank(leadership_tier) >= _tier_rank(_guild_min_tier)

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

func _tier_rank(tier: String) -> int:
	return TIER_ORDER.find(tier)
