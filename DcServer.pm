package DcServer;

use lib '.';
use threads;
use threads::shared;
use Thread::Queue;
use IO::Socket;
use Time::HiRes qw/sleep/;
use strict;
use warnings;

my $stop :shared;
my $accept_queue= Thread::Queue->new;
my $closed_queue= Thread::Queue->new;

sub new {
  # Params: host, port, thread_count, eom_marker, main_yield, main_cb,
  # done_cb, processor_cb
  my ($proto, %param)= @_;
  my $class= ref($proto) || $proto;
  bless +{
    socket_defaults => +{
      LocalHost => $param{host} || 'localhost',
      LocalPort => $param{port} || 8191},
    thread_count => $param{thread_count} || 10,
    main_yield => $param{main_yield} || 5,
    main_cb => $param{main_cb} || sub {},
    done_cb => $param{done_cb} || sub {},
    processor_cb => $param{processor_cb} || \&processor,
    eom_marker => $param{eom_marker} || "\\n\\.\\n",
    thread_pool => undef
  } => $class;
}

# This callback (for processor_cb) does sommething stupid with the string
# that the client sends to the server, then returns the new string. This
# code hopefully illustrates how to put together a callback function for
# processing data from clients.
sub processor {
  my ($data, $ip, $tid, $fnstop)= @_;
  "[tid=$tid; ip=$ip] " . join('', reverse(split //, $data));
}

sub start {
  my $self= shift;

  # Start a thread to dispatch incoming requests
  threads->create(sub {$self->accept_requests})->detach;

  # Start the thread pool to handle dispatched requests
  for (1 .. $self->{thread_count}) {
    threads->create(sub {$self->request_handler})->detach}

  # Start a loop for performing tasks in the background, while
  # handling requests
  $self->main_loop;

  $self->{done_cb}->();
}

sub stop {
  my $self= shift;
  $stop= 1;
}

sub main_loop {
  my $self= shift;
  my $counter= 1;
  until($stop) {
    $self->{main_cb}->($counter++, sub {$self->stop});
    sleep $self->{main_yield};
  }
}

sub accept_requests {
  my $self= shift;
  my ($csocket, $n, %socket);
  my $lsocket= new IO::Socket::INET(
    %{$self->{socket_defaults}},
    Proto => 'tcp',
    Listen => 1,
    Reuse => 1);
  die "Can't create listerner socket. Server can't start. $!." unless $lsocket;
  until($stop) {
    $csocket= $lsocket->accept;
    $n= fileno $csocket;
    $socket{$n}= $csocket;
    $accept_queue->enqueue($n . ' ' . inet_ntoa($csocket->peeraddr));
    while($n= $closed_queue->dequeue_nb) {
      $socket{$n}->shutdown(2);
      delete $socket{$n}}}
  $lsocket->shutdown(2);
  print "Thread ", threads->tid, " terminated.\n";
}

sub request_handler {
  my $self= shift;
  my ($n, $ip, $data);
  my ($receive_time, $process_time, $send_time);
  until($stop) {
    ($n, $ip)= split / /, $accept_queue->dequeue;
    next unless $n;
    open my $socket, '+<&=' . $n or die $!;
    if(defined($data= $self->receive_client_request($socket))) {
      print $socket $self->{processor_cb}->(
        $data, $ip, threads->tid, sub {$self->stop}
      ), "\n.\n"}
    close $socket;
    $closed_queue->enqueue($n)}
}

sub receive_client_request {
  my ($self, $socket)= @_;
  my ($eom, $buffer, $data)= $self->{eom_marker};
  while($buffer= <$socket>) {
    $data.= $buffer;
    last if $data =~ s/$eom$//}
  $data
}

1;
