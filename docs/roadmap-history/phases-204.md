# Roadmap history — Phase 204

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 204 — Clans: a name, invites, one clan each, and every member's skills in view ✅ Done

**Goal:** players found and join clans, see what each member is good at, and message the one they
need.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- `src/clan/clan_slice.gd` and its wiring: found (name), invite, accept, leave, kick, roles. One
  clan per player, enforced on the host. Names are validated, unique and moderated.
- Saved settlements migrate to clans as Phase 203 decided (a data-format bump). A clan has no
  hearth.
- The clan roster: every member's skills, sortable by skill, so "who sews best" is one click. The
  host sends a member's skills only to their own clan's peers, and stops when they leave.
- Private messages: from the roster (and a chat command) to one player. The host relays them only
  to the recipient, rate-limits them, and hosts send keys and params for any system text.

**Acceptance criteria:**
- [x] Suite: founding a second clan, or accepting an invite while in a clan, is refused. A duplicate
  or invalid name is refused.
- [x] Suite: a migrated settlement is a clan with the same name, members and roles.
- [x] Harness: a clan member's peer receives another member's skills, and an outsider's peer never
  does (checked on the wire). A member who leaves stops receiving them.
- [x] Harness: a private message reaches only its recipient.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:**
- `src/clan/clan_slice.gd` and `clan_wiring.gd`: found, invite, uninvite, join, decline, leave, kick and
  role, with the fabric's role table (`Clan.roles`). The founder leaves only as the last member, which
  disbands the clan. An actor kicks only members ranked below them. Names go through
  `CreationRules.name_refusal` with the clan's bounds (3–24 letters, 3 separators, clan-only reserved
  words) and are unique by skeleton. "Moderated as chat is" means those rules: chat has no other filter.
- The roster sends each member's skill XP and tier from the host's own records. Views go only to the
  members and invitees of a changed clan, and a player who leaves is pushed a view without a roster.
  A skill grant (`attributes_synced`) or a new tier re-sends the roster.
- Migration: world format 3 (`PersistenceSlice.WORLD_FORMAT_VERSION`) carries `clans`. A record without
  them has its settlements migrated on load (`ClanSlice.migrate_settlements`): same name (a default-named
  settlement keeps its number, a duplicate name gets one), members, roles and pending invites. The hearth
  and the stockpile move to Phases 205 and 208, which remove the hearth and add chests.
- Private messages: `/msg <handle or name> <text>`, also opened from the roster's Message button. The host
  posts the line to the recipient alone (`chat_posted` with a target) and echoes it to the sender, at
  most `Clan.messages.perMinute` per sender in any minute and `maxLength` characters.
- The Clan window is on J (the dock box and the reserved shortcut keys include it).
- Harness: `clan_roster` (an outsider's peer receives no view with the host's skills, a member's does,
  and a leaver's next views have no roster) and `private_message` (one line each way, each seen only
  by its recipient and echoed to its sender).
