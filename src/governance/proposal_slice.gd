extends Node
## Proposal slice — in-game governance (Phase 24). Grounds the
## `CommunityOwnsTheFuture` constitution principle: players submit proposals,
## others vote, and a proposal ratifies once a threshold fraction of votes is in
## favour. A ratified proposal mirrors the fabric decision state machine
## (`proposed → accepted → superseded`) and is recorded in a runtime decisions
## log.
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
##   get_decisions_log()                  -> Array      (ratified proposals)
##   set_ratification_threshold(frac)
##   can_form_guild(leadership_tier)      -> bool

const STATE_PROPOSED := "proposed"
const STATE_ACCEPTED := "accepted"
const STATE_SUPERSEDED := "superseded"

## Skill tier order — matches fabric skill state machine (novice → master).
const TIER_ORDER: Array = ["novice", "apprentice", "journeyman", "expert", "master"]

## Minimum tier required to form a guild (Leadership).
const GUILD_MIN_TIER := "apprentice"

## Default fraction of cast votes that must be "for" to ratify.
const DEFAULT_RATIFICATION_THRESHOLD: float = 0.6

var _proposals: Dictionary = {}
var _next_id: int = 0
var _decisions_log: Array = []
var _ratification_threshold: float = DEFAULT_RATIFICATION_THRESHOLD

func set_ratification_threshold(frac: float) -> void:
	_ratification_threshold = frac

## Submit a proposal for community vote; returns the proposal id.
func submit_proposal(author: String, title: String, body: String) -> String:
	var id := "proposal_%d" % _next_id
	_next_id += 1
	_proposals[id] = {
		"id": id,
		"author": author,
		"title": title,
		"body": body,
		"state": STATE_PROPOSED,
		"votes": {},
	}
	GameBus.proposal_submitted.emit(id)
	return id

## Cast a vote ("for" or "against"). One vote per voter (last wins). After the
## vote is recorded, ratification is re-checked. Returns the proposal record.
func vote(proposal_id: String, voter: String, verdict: String) -> Dictionary:
	var p: Dictionary = _proposals.get(proposal_id, {})
	if p.is_empty():
		return { "success": false, "reason": "unknown_proposal" }
	if verdict != "for" and verdict != "against":
		return { "success": false, "reason": "invalid_verdict", "proposal_id": proposal_id }
	if str(p["state"]) != STATE_PROPOSED:
		return { "success": false, "reason": "not_open", "proposal_id": proposal_id }
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
	return _tier_rank(leadership_tier) >= _tier_rank(GUILD_MIN_TIER)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _check_ratification(proposal_id: String) -> void:
	var p: Dictionary = _proposals[proposal_id]
	var votes: Dictionary = p["votes"]
	var total: int = votes.size()
	if total == 0:
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
