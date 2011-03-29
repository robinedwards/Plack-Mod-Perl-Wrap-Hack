use 5.012;
use MooseX::Declare;

class Foo::Request {
    use Plack::Request;
    use MooseX::Types::Moose qw/Str Bool Int HashRef/;
    use Moose::Util::TypeConstraints;

    class_type 'Plack::Request';
    class_type 'Plack::Response';
    class_type 'HTTP::Headers';

    has request => (
        is => 'ro',
        isa => 'Plack::Request',
        required => 1,
        handles => {
            params => 'params',
            env => 'env',
            address => 'address',
            remote_ip => 'address',
            remote_host => 'remote_host',
            method => 'method',
            protocol => 'protocol',
            uri => 'path',
            request_uri => 'path',
            path => 'path',
            path_info => 'path_info',
            filename => 'path',
            scheme => 'scheme',
            secure => 'secure',
            body_parameters => 'body_parameters',
            parameters => 'parameters',
            content => 'content',
            user => 'user',
            header_in => 'header',
            headers => 'headers',
            content_encoding => 'content_encoding',
            content_length => 'content_length',
            content_type => 'content_type',
            referer => 'referer', 
            user_agent => 'user_agent',
            upload => 'upload',
        },
    );

    has response => (
        is => 'rw',
        isa => 'Plack::Response',
        required => 1,
        handles => {
            header_out => 'header',
            err_header_out => 'header',
            status => 'status',
            header => 'header',
            print => 'body',
        },
        builder => '_build_response',
    );

    has _pnotes => (
        is => 'rw',
        isa => HashRef,
        traits => [qw/Hash/],
        handles => { pnotes => 'accessor' },
    );
    
    has _dir_config => (
        is => 'rw',
        isa => HashRef,
        traits => [qw/Hash/],
        handles => { dir_config => 'get' }
    );

    has has_custom_response => (is => 'rw', isa => Bool, default => 0);
    
    method BUILDARGS(ClassName $class: HashRef $env) {
        $class->SUPER::BUILDARGS(
            request => Plack::Request->new($env)
        );
    }

    method BUILD {
        $self->response->header(
            'X-Foo-Host',
            $self->request->env->{FOO}{'X-Foo-Host'}
        );

        # set real client ip
        if (my $address = $self->header('X-Forwarded-For')) {
            ($address) = split /,\s*/, $address;
            $self->request->address($address);
        }
        
        $self->_pnotes(
            $self->request->env->{FOO}{pnotes} // {}
        );

        $self->response->header(
            'Content-Type', 'text/html; charset=utf-8' 
        );

        $self->_dir_config(
            $self->request->env->{FOO}{dir_config} // {}
        );
    }

    method _build_response {
        return $self->request->new_response;
    }

    method header_only {
        return 1 if $self->method eq 'HEAD';
    }


    method custom_response (Int $status, Str $body?) {
        $self->response->body($body) if $body;
        $self->response->status($status);
        $self->has_custom_response(1);
    }

    method base {
        return $self->request->base->as_string;
    }


    method hostname {
        return $self->headers->header('Host');
    }

    method send_http_header (Str $type?) {
        $self->response->content_type($type)
            if $type;
    }

    method args {
        return %{$self->request->query_parameters}
            if wantarray;
        return $self->request->uri->path_query;
    }

    method no_cache (Bool $t?) {
        if ($t) {
            $self->header_out('Cache-Control', "private, no-cache, no-store");
            $self->header_out('Pragma', "no-cache");
        }
    }

    # HACKETY HACK.

    method headers_out {
        my $headers = $self->response->headers;

        return eval {
            package Foo::Response::Headers;
                sub new { return bless $_[1], $_[0]; }
                sub get { $_[0]->{headers}->header($_[1]); }
                sub set { $_[0]->{headers}->header($_[1],$_[2]); }
            __PACKAGE__;
        }->new({headers => $headers});
    }

    method headers_in {
        my $headers = $self->request->headers;

        return eval {
            package Foo::Request::Headers;
                sub new { return bless $_[1], $_[0]; }
                sub get { $_[0]->{headers}->header($_[1]); }
            __PACKAGE__;
        }->new({headers => $headers});
    }

    method connection {
        return eval {
            package Foo::Request::Connection;
                sub new { return bless $_[1], $_[0]; }
                sub remote_ip { $_[0]->{remote_ip} }
            __PACKAGE__;
        }->new({remote_ip => $self->remote_ip});
    }
}
