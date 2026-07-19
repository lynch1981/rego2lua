#!/bin/sh
# Sanity first, then language features, then comparison operators.
prove \
  t/sanity.t \
  t/scalars.t \
  t/access.t \
  t/membership.t \
  t/cmp_eq.t t/cmp_ne.t t/cmp_gt.t t/cmp_gte.t t/cmp_lt.t t/cmp_lte.t
