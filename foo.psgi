use 5.012;
use strict;
use warnings;
use Plack::Builder;
use aliased 'Foo::Handler';
use Plack::Middleware::Debug::DBIC::QueryLog;

builder {
    enable "Deflater";
    
    enable 'Debug', panels => [ 
        qw(DBITrace W3CValidate PerlConfig ModuleVersions
        Parameters Environment Response Timer Memory),
    ];

    enable sub {
        my $app = shift; 
        sub {
            my $env = shift;
            $env->{PLACK_URLMAP_DEBUG} =    
            $env->{'FOO'} = {
                dir_config => {
                    LocalServerIP => "10.0.0.1"
                },
                pnotes => {}
            };

            $app->($env);
        };
    };

    mount "/something" => Handler->setup(
        'Foo::SomeThing::handler'
    );

    mount "/someotherthing" => Handler->setup(
        'Foo::SomeOtherThing->meth'
    );
};
