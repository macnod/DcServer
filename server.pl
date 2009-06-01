use DcServer;
my $server= DcServer->new(processor_cb => \&reverse_text);
$server->start;

sub reverse_text {
    my $data= shift;
    join('', reverse(split //, $data));
}
