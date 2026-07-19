package foo

default allow := false

allow if {
    input.method == "GET"
}

