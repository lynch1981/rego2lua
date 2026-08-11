# vi:set ft=perl:
# Unit tests for runtime/rego_rt.lua (LuaJIT).

use strict;
use warnings;

use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

my $ROOT   = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
my $LUAJIT = $ENV{LUAJIT} || 'luajit';
my $SCRIPT = File::Spec->catfile($ROOT, 't', 'runtime_rt.lua');

my $cmd = quotemeta($LUAJIT) . ' ' . quotemeta($SCRIPT);
my $out = `$cmd 2>&1`;
my $status = $? >> 8;

if ($status == -1) {
    fail("failed to run $LUAJIT: $!");
    done_testing;
    exit 1;
}

# Parse TAP from the Lua harness so each check shows up under prove.
my $saw_plan = 0;
my $n = 0;
for my $line (split /\n/, $out) {
    if ($line =~ /^1\.\.(\d+)\s*$/) {
        $saw_plan = 1;
        next;
    }
    if ($line =~ /^ok\s+(\d+)\s+-\s+(.*)$/) {
        $n++;
        pass($2);
        next;
    }
    if ($line =~ /^not ok\s+(\d+)\s+-\s+(.*)$/) {
        $n++;
        fail($2);
        next;
    }
}

if (!$saw_plan || $n == 0) {
    fail("runtime_rt.lua produced no TAP");
    diag($out);
}

is($status, 0, "luajit runtime_rt.lua exit 0") or diag($out);

done_testing;
