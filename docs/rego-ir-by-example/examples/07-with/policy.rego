package example

inner if {
	input.x == 1
}

# WithStmt: temporary override
allow if {
	inner with input as {"x": 1}
}
