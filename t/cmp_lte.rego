package cmp

default lte := false

lte if {
    input.a <= input.b
}
