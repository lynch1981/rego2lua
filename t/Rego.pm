package t::Rego;

use strict;
use warnings;

# Test::Base/Spiffy: subs with prototypes are plain functions (no $self).
# Subs without prototypes become methods (implicit my $self = shift).
use Test::Base -Base;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use JSON::PP qw( decode_json encode_json );
use File::Basename qw( dirname );
use Cwd qw( abs_path );

our @EXPORT = qw( run_tests );

my $ROOT = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
my $LUAJIT = $ENV{LUAJIT} || 'luajit';
my $EVAL_PKG = File::Spec->catfile($ROOT, 't', 'eval_pkg.lua');
my $REGO2LUA = $ENV{REGO2LUA} || File::Spec->catfile($ROOT, 'rego2lua');

sub run_tests () {
    # Test::Base already filters blocks when --- ONLY is present.
    for my $block (blocks()) {
        _run_block($block);
    }
}

sub _run_block ($) {
    my $block = shift;
    my $name = $block->name;

    my $rego       = _section($block, 'Rego');
    my $lua_ref    = _section($block, 'ref_lua');
    my $input_json = _section($block, 'input');
    my $data_json  = _section($block, 'data');
    my $out_json   = _section($block, 'out');

    $input_json = '{}' if !defined $input_json || _strip($input_json) eq '';
    $data_json  = '{}' if !defined $data_json  || _strip($data_json)  eq '';

    if (!defined $rego || _strip($rego) eq ''
        || !defined $out_json || _strip($out_json) eq '')
    {
        fail("$name: --- Rego and --- out are required");
        return;
    }

    my ($input, $data, $want);
    eval {
        $input = decode_json(_strip($input_json));
        $data  = decode_json(_strip($data_json));
        $want  = decode_json(_strip($out_json));
        1;
    } or do {
        fail("$name: invalid JSON in input/data/out: $@");
        diag("input=[[$input_json]]\ndata=[[$data_json]]\nout=[[$out_json]]");
        return;
    };

    my $dir = tempdir(CLEANUP => 1);
    my $mod_path  = File::Spec->catfile($dir, 'policy.lua');
    my $rego_path = File::Spec->catfile($dir, 'policy.rego');

    my ($lua_src, $src_label);
    if (-e $REGO2LUA && -x $REGO2LUA) {
        _write($rego_path, $rego);
        my $cmd = _q($REGO2LUA) . ' ' . _q($rego_path);
        my $out = `$cmd 2>&1`;
        my $status = $?;
        if ($status != 0) {
            fail("$name: rego2lua failed (exit $status): $out");
            return;
        }
        $lua_src = $out;
        $src_label = 'rego2lua';
    }
    elsif (defined $lua_ref && _strip($lua_ref) ne '') {
        $lua_src = $lua_ref;
        $src_label = 'ref_lua';
        pass("$name: rego2lua not built; evaluating --- ref_lua");
    }
    else {
        fail("$name: no rego2lua binary and no --- ref_lua");
        return;
    }

    # When --- ONLY is set (Test::Base already limited which blocks run),
    # print the Lua under test for debugging.
    if (defined $block->ONLY) {
        _show_lua($name, $src_label, $lua_src);
    }

    # Module is a file (multi-line source). input/data are JSON argv strings.
    _write($mod_path, $lua_src);
    my $cmd = join(' ',
        _q($LUAJIT),
        _q($EVAL_PKG),
        _q($mod_path),
        _q(encode_json($input)),
        _q(encode_json($data)),
    );
    my $got_raw = `$cmd 2>&1`;
    my $status = $?;
    if ($status != 0) {
        fail("$name: eval failed ($src_label, exit $status): $got_raw");
        return;
    }

    my $got;
    eval {
        $got = decode_json(_strip($got_raw));
        1;
    } or do {
        fail("$name: eval did not print JSON ($src_label): $got_raw");
        return;
    };

    is_deeply($got, $want, "$name: $src_label result matches --- out")
        or diag(
            "got:  " . encode_json($got) . "\n" .
            "want: " . encode_json($want)
        );
}

sub _section ($$) {
    my ($block, $name) = @_;
    if ($block->can('original_values')) {
        my $ov = $block->original_values;
        if (ref $ov eq 'HASH' && exists $ov->{$name}) {
            my $v = $ov->{$name};
            return ref $v eq 'ARRAY' ? join('', @$v) : $v;
        }
    }
    my $v = eval { $block->$name };
    return undef if $@;
    return ref $v eq 'ARRAY' ? join('', @$v) : $v;
}

sub _show_lua ($$$) {
    my ($name, $src_label, $lua_src) = @_;
    # Plain stderr (no Test::More # prefix) so the dump is easy to copy.
    print STDERR "======== $name ($src_label) ========\n";
    print STDERR $lua_src;
    print STDERR "\n" unless $lua_src =~ /\n\z/;
    print STDERR "======== end lua ========\n";
}

sub _strip ($) {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/^\s+//;
    $s =~ s/\s+\z//;
    return $s;
}

sub _write ($$) {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} $content;
    close $fh;
}

sub _q ($) {
    my ($s) = @_;
    $s =~ s/'/'\\''/g;
    return "'$s'";
}

1;
