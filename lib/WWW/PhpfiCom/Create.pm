package WWW::PhpfiCom::Create;

use warnings;
use strict;

our $VERSION = '0.001';

use Carp;
use URI;
use LWP::UserAgent;
use HTTP::Request::Common;
use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw(
    ua
    uri
    error
);

my %Valid_Syntax_Highlights = _make_valid_highlights();

sub new {
    my $class = shift;
    croak "Must have even number of arguments to new()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;
    $args{ua} ||= LWP::UserAgent->new(
        timeout => $args{timeout},
        agent   => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.8.1.12)'
                    .' Gecko/20080207 Ubuntu/7.10 (gutsy) Firefox/2.0.0.12',
    );

    my $self = bless {}, $class;
    $self->ua( $args{ua} );

    return $self;
}

sub paste {
    my ( $self, $text ) = splice @_, 0, 2;

    $self->$_(undef) for qw(uri error);
    
    defined $text or carp "Undefined paste content" and return;
    
    croak "Must have even number of optional arguments to paste()"
        if @_ & 1;

    my %args = @_;
    %args = (
        source      => $text,
        name        => '',
        desc        => '',
        lang        => 'auto',

        %args,
    );

    $args{lang} = lc $args{lang};
    croak "Invalid value for 'lang' argument to paste()"
        unless exists $Valid_Syntax_Highlights{ $args{lang} };
        
    $args{file}
        and not -e $args{source}
        and return $self->_set_error(
            "File $args{source} does not seem to exist"
        );

    @args{ qw(nick descr) } = delete @args{ qw(name desc) };
    
    my $uri = URI->new('http://phpfi.com');
    
    my $ua = $self->ua;
    $ua->requests_redirectable( [] );
    my @post_request = $self->_make_request_args( \%args );
    my $response = $self->ua->request( POST @post_request );
    if ( $response->code == 302 ) {
        my $id = $response->header('Location');
        return $self->uri( URI->new( 'http://phpfi.com' . $id ) );
    }
    elsif ( not $response->is_success ) {
        return $self->_set_error( $response, 'net' );    
    }
    else {
        return $self->_set_error(
            q|Request was successfull but I don't see a link to the paste| .
                $response->code . $response->content
        );
    }
}

sub _make_request_args {
    my ( $self, $args ) = @_;
    my $source = delete $args->{sourcefile};
    my %content = (
        exists $args->{file}
        ? ( sourcefile => [ $args->{source} ], source => '' )
        : ( source     => $args->{source}, sourcefile => '' )
    );
    delete @$args{qw(file source)};
    %content = ( %$args, %content );
    return (
        'http://phpfi.com/',
        Content_Type => 'form-data',
        Content => [ %content ],
    );
}

sub _set_error {
    my ( $self, $error, $type ) = @_;
    if ( defined $type and $type eq 'net' ) {
        $self->error( 'Network error: ' . $error->status_line );
    }
    else {
        $self->error( $error );
    }
    return;
}

sub _make_valid_highlights {
    return map { $_ => $_ } qw(
        auto
        plaintext
        ada
        ada95
        awk
        c
        c++
        cc
        cpp
        cxx
        patch
        gpasm
        groff
        html
        java
        javascript
        lisp
        m4
        make
        makefile
        pascal
        patch
        perl
        php
        povray
        python
        ruby
        shellscript
        sql
    );
}

1;
__END__


=head1 NAME

WWW::PhpfiCom::Create - create new pastes on http://phpfi.com pastebin site

=head1 SYNOPSIS

    use strict;
    use warnings;

    use WWW::PhpfiCom::Create;

    my $paster = WWW::PhpfiCom::Create->new;

    $paster->paste('large text to paste')
        or die $paster->error;

    printf "Your paste is located on %s\n", $paster->uri;

=head1 DESCRIPTION

The module provides interface to paste large texts or files to
L<http://phpfi.com>

=head1 CONSTRUCTOR

=head2 new

    my $paster = WWW::PhpfiCom::Create->new;

    my $paster = WWW::PhpfiCom::Create->new(
        timeout => 10,
    );

    my $paster = WWW::PhpfiCom::Create->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'PasterUA',
        ),
    );

Constructs and returns a brand new yummy juicy WWW::PhpfiCom::Create
object. Takes two arguments, both are I<optional>. Possible arguments are
as follows:

=head3 timeout

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for pasting. B<Defaults to:> C<30> seconds.

=head3 ua

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for pasting, feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::PhpfiCom::Create>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head1 METHODS

=head2 paste

    my $paste_uri = $paster->paste('lots and lots of text')
        or die $paster->error;

    $paster->paste(
        'paste.txt',
        file    => 1,
        name    => 'Zoffix',
        desc    => 'paste from file',
        lang    => 'perl',
    ) or die $paster->error;

Instructs the object to create a new paste. If an error occured during
pasting will return either C<undef> or an empty list depending on the context
and the reason for the error will be available via C<error()> method.
On success returns a L<URI> object pointing to a newly created paste.
The first argument is mandatory and must be either a scalar containing
the text to paste or a filename. The rest of the arguments are optional
and are passed in a key/value fashion. Possible arguments are as follows:

=head3 file

    $paster->paste( 'paste.txt', file => 1 );

B<Optional>.
When set to a true value the object will treat the first argument as a
filename of the file containing the text to paste. When set to a false
value the object will treat the first argument as a scalar containing
the text to be pasted. B<Defaults to:> C<0>

=head3 name

    $paster->paste( 'some text', name => 'Zoffix' );

B<Optional>. Takes a scalar as a value which specifies the name of the
person creating the paste. B<Defaults to:> empty string (no name)

=head3 desc

    $paster->paste( 'some text', desc => 'some l33t codez' );

B<Optional>. Takes a scalar as a value which specifies the description of
the paste. B<Defaults to:> empty string (no description)

=head3 lang

    $paster->paste( 'some text', lang => 'perl' );

B<Optional>. Takes a scalar as a value which must be one of predefined
language codes and specifies (computer) language of the paste, in other
words which syntax highlighting to use. When set to C<auto>
the pastebin will try to guess the language. B<Defaults to:> C<auto>. Valid
language codes are as follows (case insensitive):

        auto
        plaintext
        ada
        ada95
        awk
        c
        c++
        cc
        cpp
        cxx
        patch
        gpasm
        groff
        html
        java
        javascript
        lisp
        m4
        make
        makefile
        pascal
        patch
        perl
        php
        povray
        python
        ruby
        shellscript
        sql

=head2 error

    my $paste_uri = $paster->paste('lots and lots of text')
        or die $paster->error;

If an error occured during the call to C<paste()>
it will return either C<undef> or an empty list depending on the context
and the reason for the error will be available via C<error()> method. Takes
no arguments, returns a human parsable error message explaining why
we failed.

=head2 uri

    my $last_paste_uri = $paster->uri;

Must be called after a successfull call to C<paste()>. Takes no arguments,
returns a L<URI> object pointing to a paste created by the last call
to C<paste()>, i.e. the return value of the last C<paste()> call.

=head2 ua

    my $old_LWP_UA_obj = $paster->ua;

    $paster->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for pating. Takes one
optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<paste()>.

=head1 AUTHOR

'Zoffix, C<< <'zoffix at cpan.org'> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-phpficom-create at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-PhpfiCom-Create>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::PhpfiCom::Create

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-PhpfiCom-Create>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-PhpfiCom-Create>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-PhpfiCom-Create>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-PhpfiCom-Create>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 'Zoffix, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

