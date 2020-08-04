#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long::Descriptive;
use Mojo::DOM;
use WWW::Mechanize;

my ( $opt, $usage ) = describe_options(
    [ 'url=s', "Base URL for RT", { required => 1 } ],
    [ 'username|u=s', "RT username", { required => 1 } ],
    [ 'password|p=s', "RT password", { required => 1 } ],
    [],
    [ 'verbose|v', "print extra stuff" ],
    [ 'help', "print usage message and exit", { shortcircuit => 1 } ],
);
print( $usage->text ), exit if $opt->help;

my $url = $opt->url;
my $username = $opt->username;
my $password = $opt->password;

my $groups_url = qq{$url/Admin/Groups/index.html?Format=%27%3Ca%20href%3D%22__WebPath__%2FAdmin%2FGroups%2FModify.html%3Fid%3D__id__%22%3E__id__%3C%2Fa%3E%2FTITLE%3A%23%27%2C%27%3Ca%20href%3D%22__WebPath__%2FAdmin%2FGroups%2FModify.html%3Fid%3D__id__%22%3E__Name__%3C%2Fa%3E%2FTITLE%3AName%27%2C%27__Description__%27%2C__Disabled__&Order=ASC&OrderBy=Name&Page=1&Rows=5000};
my $group_url = qq{$url/Admin/Groups/Members.html?id=};

my $mech = WWW::Mechanize->new();

$mech->get( $url );
$mech->submit_form(
    form_name => 'login',
    fields    => {
        user => $username,
        pass => $password,
    },
);

$mech->get( $groups_url );

my @group_ids;
my @links = $mech->links;
foreach my $link ( @links ) {
    next unless $link->url =~ /^\/Admin\/Groups\/Modify.html/;

    my $text = $link->text;
    next unless $text;
    next unless $text =~ /^\d+$/;

    push( @group_ids, $text );
}

my $groups = {};
foreach my $group_id ( @group_ids ) {
    $mech->get( $group_url . $group_id );
    my $res = $mech->res;
    my $html = $res->decoded_content;
    my $dom = Mojo::DOM->new( $html );
    my $element = $dom->find( "div#header h1" )->first;
    my $group_name = $element->text;
    $group_name =~ s/Modify the group //;
    say "GROUP: $group_name";

    my $emails = $dom->find( 'ul li a[href^=/User/Summary.html]' )->to_array;
    my @addresses;
    push( @addresses, $_->text ) for @$emails;

    $groups->{group_name} = \@addresses;
}
