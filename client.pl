use DcClient;
my $message= shift;
die "Usage: perl client.pl string\n" unless defined($message);
my $c= DcClient->new;
print "$message => ", $c->query($message), "\n";
