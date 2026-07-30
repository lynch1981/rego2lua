package example

default allow := false

# ScanStmt: iterate array
allow if {
	some name in input.names
	name == "alice"
}

# MakeArray + ArrayAppend (+ Scan): comprehension
errors := [msg |
	some msg in input.messages
	msg.level == "error"
]
