use 5.012;
use MooseX::Declare;

class Foo::Handler {
    use Foo::Request;
    use MooseX::Types::Moose qw/HashRef Bool Str/;

    has class => (
        is => 'ro',
        isa => Str,
        required => 1,
        trigger => sub {
            eval "require $_[1]";
            die if $@;
        }
    );

    has handler => (
        is => 'ro',
        isa => Str,
        default => 'handler'
    );

    has as_method => (
        is => 'ro',
        isa => Bool,
        default => 0,
    );

    method setup (ClassName $class: Str $handle){
        my %param;

        if ($handle =~ /([\w:]+)->(\w+)$/) {
            $param{as_method} = 1;
            $param{class} = $1;
            $param{handler} = $2;
        }
        elsif($handle =~ /([\w\:]+)::(\w+)$/) {
            $param{class} = $1;
            $param{handler} = $2;
        }
        else {
            die "Couldn't parse handler: $handle";
        }

        return $class->new(%param)->app;
    }

    # return Plack 'app'
    method app {
        return sub {
            my $r = Foo::Request->new(shift);

            say STDERR "Handler: ".$self->class;
            my $status = $self->execute_handler($r);
            say STDERR "$status done.";

            return $r->response->finalize;
        }
    }

    method execute_handler (Request $req) {
        my $call = $self->class
            . ( $self->as_method ? '->' : '::' )
            . $self->handler
            . "(\$req)";

        my $status = eval $call;
         die $@ if $@;

        $req->response->status($status)
            unless $req->has_custom_response;
        return $req->response->status;   
    }
}
