package example

# Logical OR via two complete rules (same value true).
# IR: top-level func blocks — usually NO BlockStmt.
allow if {
	input.role == "admin"
}

allow if {
	input.role == "user"
}
