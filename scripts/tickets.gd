extends Node
## The fare box. Every place on the line costs a few tickets to visit (the site's coins, which the counter at Wayside
## Station calls tickets), and one admission lets you stay as long as you like.
##
## The site has no route yet for a game to spend a player's tickets, so for now every ride is on a preview pass:
## the booth shows the fare and punches the ticket, and nothing is taken. When the server can charge, `admit` is the
## one place that changes.

signal balance_changed(balance: int)

## Unknown until the site tells us (-1).
var balance := -1
var preview := true


func admit(place_id: String, fare: int) -> bool:
	if preview:
		print("admitted to %s on a preview pass (fare %d)" % [place_id, fare])
		return true
	if balance < fare:
		return false
	balance -= fare
	balance_changed.emit(balance)
	return true
