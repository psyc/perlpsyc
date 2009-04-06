package Net::PSYC::Tie::AbbrevHash;

our $VERSION = '0.2';

use strict;
# 'stolen' from Tie::StdHash;

sub TIEHASH  { bless {}, $_[0] }
sub STORE    { $_[0]->{$_[1]} = $_[2] }
sub FIRSTKEY { my $a = scalar keys %{$_[0]}; each %{$_[0]} }
sub NEXTKEY  { each %{$_[0]} }
sub DELETE   { delete $_[0]->{$_[1]} }
sub CLEAR    { %{$_[0]} = () }


sub FETCH {
    my $self = shift;
    my $key = shift;

    while ( $key && !exists $self->{$key}) {
	$key = substr($key, 0, rindex($key, '_'));
    }
    return $self->{$key} if ($key && exists $self->{$key});
    return;
}

sub EXISTS { 
    my $self = shift;
    my $key = shift;
    my $c = 0;
    while ( $key && !exists $self->{$key}) {
	$c++;
	$key = substr($key, 0, rindex($key, '_'));
    } 
    return (exists $self->{$key}) ? (($c == 0) ? -1 : $c) : 0;
}



1;
