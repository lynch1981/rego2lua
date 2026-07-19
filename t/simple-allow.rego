package foo

default allow := false

allow if {
    method := input.method
    method == "GET"
}
