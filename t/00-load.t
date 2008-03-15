#!/usr/bin/env perl

use Test::More tests => 8;

BEGIN {
    use_ok('Carp');
    use_ok('URI');
    use_ok('LWP::UserAgent');
    use_ok('HTTP::Request::Common');
    use_ok('Class::Data::Accessor');
	use_ok( 'WWW::PhpfiCom::Create' );
}

diag( "Testing WWW::PhpfiCom::Create $WWW::PhpfiCom::Create::VERSION, Perl $], $^X" );

my $o = WWW::PhpfiCom::Create->new;

isa_ok($o,'WWW::PhpfiCom::Create');
can_ok($o,qw(new uri error paste _make_valid_highlights
                _make_request_args _set_error));


