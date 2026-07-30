package example

# MakeSet + SetAdd (partial set rule)
deny contains msg if {
	msg := "missing admin"
	not "admin" in input.roles
}

deny contains msg if {
	msg := "prod without approval"
	input.env == "prod"
	not input.approved
}
