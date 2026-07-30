package example

default allow := false

allow if {
    lower(input.user) == "alice"
}
