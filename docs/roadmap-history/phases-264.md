## Phase 264 — Dropping part of a stack: a quantity slider

Dragging a stack into the world drops one unit, or all of it with Shift. There is no way to drop,
say, 7 of 20.

- Dropping a stack of more than one (drag to the world, or a Drop entry where the inventory offers
  one) opens a small dialog: the item's icon and name, a slider from 1 to the stack size, a number
  field kept in sync with it, buttons for 1, half and all, then Drop and Cancel. Enter confirms and
  Esc cancels; the number field owns the keyboard while focused (Phase 219).
- The slider starts at the whole stack. Shift-drag keeps dropping the whole stack without the
  dialog, and a stack of one never opens it.
- The request goes through `request_drop`, and the host clamps the quantity to what the bag holds,
  as now.

**Acceptance criteria**
- Suite tests: a drag of a stack above one opens the dialog with its range 1..count; a stack of one
  and a Shift-drag drop without it; the slider and the field stay equal; confirming emits one drop
  of the chosen quantity, cancelling emits none; Enter and Esc do the same while the field has focus.
- Suite test: the host clamps a drop request above the bag's count.
- Every new string is in both locales.
