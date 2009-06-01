package DcClient;

use IO::Socket;
use strict;
use warnings;

sub new {
  # Params: host, port
  my ($proto, %param)= @_;
  my $class= ref($proto) || $proto;
  bless +{%param} => $class;
}

sub stop_server {shift->query('$self->stop')}

sub query {
  my ($self, $query)= @_;
  my ($buffer, $reply)= ('', '');
  my $socket= new IO::Socket::INET(
    PeerAddr => $self->{host} || 'localhost',
    PeerPort => $self->{port} || 8191,
    Proto => 'tcp');
  die "$!. Is the server running?\n" unless $socket;
  print $socket $query . "\n.\n";
  while($buffer= <$socket>) {
    $reply.= $buffer;
    last if $reply =~ s/\n\.\n$//;
  }
  $socket->shutdown(2);
  $reply;
}

1;
