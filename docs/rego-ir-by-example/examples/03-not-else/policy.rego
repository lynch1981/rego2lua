package example

# NotStmt
allow if {
	not input.denied
}

# BlockStmt via else chain
role := "admin" if {
	input.role == "admin"
} else := "user" if {
	input.role == "user"
} else := "guest"
