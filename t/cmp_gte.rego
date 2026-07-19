package cmp

default gte := false

gte if {
    input.a >= input.b
}
