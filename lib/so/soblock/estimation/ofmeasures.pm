package so::soblock::estimation::ofmeasures;

use strict;
use warnings;
use Moose;
use MooseX::Params::Validate;
use include_modules;
use XML::LibXML;

has 'Deviance' => ( is => 'rw', isa => 'Maybe[Str]' );

sub parse
{
    my $self = shift;
    my $node = shift;

    my $xpc = so::xml::get_xpc();

    (my $dev) = $xpc->findnode('x:Deviance', $node);
    $self->Deviance($dev->textContent) if (defined $dev);
}

sub xml
{
    my $self = shift;

    my $l;

    if (defined $self->Deviance) {
        $l = XML::LibXML::Element->new("OFMeasures");
        my $dev = XML::LibXML::Element->new("Deviance");
        $dev->appendTextNode($self->Deviance);
        $l->appendChild($dev);
    }

    return $l;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
