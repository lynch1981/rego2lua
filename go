#!/bin/sh
# Runtime helpers first, then policy fixtures (sanity → features → compares).

prove -j "$(nproc)" \
  t/runtime.t \
  t/opa_check.t \
  t/sanity.t \
  t/not.t \
  t/scalars.t \
  t/access.t \
  t/membership.t \
  t/cmp_eq.t \
  t/cmp_ne.t \
  t/cmp_gt.t \
  t/cmp_gte.t \
  t/cmp_lt.t \
  t/cmp_lte.t
