use strict;
use warnings;
use Redis;
use Plack::Builder;
use JSON;
use Plack::Request;
use HTTP::Status qw(
    HTTP_NO_CONTENT HTTP_NOT_FOUND HTTP_METHOD_NOT_ALLOWED
    HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_UNPROCESSABLE_ENTITY
    HTTP_INTERNAL_SERVER_ERROR
);

my $redis = Redis->new(server => $ENV{REDIS_HOST}.':6379', reconnect => 60);

sub gen_nonce {
    return (sprintf "%08X", rand 0xffffffff).'-'.(sprintf "%08X", rand 0xffffffff);
}

sub check_license {
    my ($key, $nonce) = (@_);

    my @key_pieces = split '-', $key;
    my $num_key_pieces = scalar(@key_pieces);

    my @nonce_pieces = split '-', $nonce;
    my $num_nonce_pieces = scalar(@nonce_pieces);

    my $key_resulting = 0;
    my $nonce_resulting = 0;

    unless($num_key_pieces != 4) {
        foreach my $idx (0 .. $#key_pieces) {
            if(length $key_pieces[$idx] != 4) {   
                return 0; 
            }

            $key_resulting = int(((($key_resulting + (int(hex('0x'.$key_pieces[$idx])) * 1337) + hex('0x137') * $idx) % 64) +1) * 37); 
        }
    } else {
        return 0;
    }

    unless($num_nonce_pieces != 2) {
    foreach my $idx (0 .. $#nonce_pieces) {
        if(length $nonce_pieces[$idx] != 8) {   
            return 0; 
        }

        $nonce_resulting = int(((($nonce_resulting + (int(hex('0x'.$nonce_pieces[$idx])) * 1337) + hex('0x137') * $idx) % 64) + 1) * 37); 
    }
    } else {
        return 0;
    }

    return int($key_resulting == $nonce_resulting);
}

my $generate_nonce = sub {
    my $env = shift;
    my $req = Plack::Request->new( $env );
    my $nonce = gen_nonce;

    my $user_exists = $redis->exists($req->cookies->{session_id});

    if ($user_exists eq 0) {
        return [200, [ 'Content-Type' => 'application/json' ], [to_json { error => 'unauthorized'}]];
    };
          
    my $session = from_json $redis->get($req->cookies->{session_id});
    $session->{license_nonce} = $nonce;
    $redis->set($req->cookies->{session_id}, to_json $session);
    $redis->expire($req->cookies->{session_id}, 180);
    return [200, [ 'Content-Type' => 'application/json' ], [to_json {license_nonce => $nonce}]];
};

my $license_status = sub {
    my $env = shift;
    my $req = Plack::Request->new( $env );

    my $user_exists = $redis->exists($req->cookies->{session_id});

    if ($user_exists eq 0) {
        return [200, [ 'Content-Type' => 'application/json' ], [to_json { error => 'unauthorized'}]];
    };

    my $session = from_json $redis->get($req->cookies->{session_id});

    if( !defined($session->{licensed}) ) {
        return [200, [ 'Content-Type' => 'application/json' ], [to_json { licensed => '0' }]];
    }

    return [200, [ 'Content-Type' => 'application/json' ], [to_json {licensed => '1' }]];
};

my $activate_license = sub {
    my $env = shift;
    my $req = Plack::Request->new( $env );

    return $req->new_response(HTTP_METHOD_NOT_ALLOWED)->finalize
        unless 'POST' eq $req->method;
    return $req->new_response(HTTP_UNSUPPORTED_MEDIA_TYPE)->finalize
        unless $req->content_type =~ m'^application/.*json$';

    my $json;    
    $req->request_body_parser->register('application/json', 'HTTP::Entity::Parser::JSON');

    $json = $req->parameters->as_hashref_mixed;

    my $license = $json->{license_key};    

    my $user_exists = $redis->exists($req->cookies->{session_id});

    if ($user_exists eq 0) {
        return [200, [ 'Content-Type' => 'application/json' ], [to_json { error => 'unauthorized'}]];
    };

    my $session = from_json $redis->get($req->cookies->{session_id});

    if( !defined($session->{license_nonce}) ) {
        return [200, [ 'Content-Type' => 'application/json' ], [to_json { error => 'nonce not generated'}]];
    }

    my $result = check_license $license, $session->{license_nonce};

    if ( $result eq 0 ) {
        return [200, [ 'Content-Type' => 'application/json' ], [to_json {license_key => $license, nonce => $session->{license_nonce}, result => $result, error => "failed license check"}]];
    }
    
    $session->{licensed} = 1;
    $redis->set($req->cookies->{session_id}, to_json $session);
    $redis->expire($req->cookies->{session_id}, 180);
    return [200, [ 'Content-Type' => 'application/json' ], [to_json {license_key => $license, nonce => $session->{license_nonce}, result => $result, message => "Enjoy your premium access!"}]];
};

my $app = builder {
    enable "ReviseEnv", revisors => { 'psgix.input.buffered' => 1};
    mount "/" => builder {
        enable "ReviseEnv", revisors => { 'psgix.input.buffered' => 1};
        mount "/get_license_nonce"   => builder { $generate_nonce; };
        mount "/activate_license"    => builder { $activate_license; };
        mount "/license_status"      => builder { $license_status; };
    };
};
