# vi:set ft=perl:
# Compile-fail cases for opa check --strict (and parse/type errors at check).

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: unused local assignment
--- Rego
package foo

default allow := false

allow if {
    x := 1
    input.method == "GET"
}
--- err
assigned var x unused



=== TEST 2: unused import
--- Rego
package foo

import data.bar

default allow := false

allow if {
    input.method == "GET"
}
--- err
import data.bar unused



=== TEST 3: unused function argument
--- Rego
package foo

f(x) := 1

default allow := false

allow if {
    f(1) == 1
}
--- err
unused argument x



=== TEST 4: parse error
--- Rego
package foo

default allow := false

allow if {
    input.method === "GET"
}
--- err
rego_parse_error



=== TEST 5: type error
--- Rego
package foo

default allow := false

allow if {
    1 == "x"
}
--- err
rego_type_error
