package My::Pandora::RESTAPI;
use warnings;
use strict;
use v5.10.0;

use LWP::UserAgent;
use HTTP::Cookies;
use JSON;
use Data::Dumper;

use Moo;

has 'endpoint' => (
    is => 'rw', default => 'https://www.pandora.com/api/'
);
has 'ua' => (
    is => 'rw', lazy => 1, default => sub {
        my ($self) = @_;
        my $ua = LWP::UserAgent->new();
        $ua->cookie_jar($self->cookieJar);
        $ua->agent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36');
        # $ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
        # $ua->add_handler("request_send",  sub { print shift->as_string; return });
        # $ua->add_handler("response_done", sub { print shift->as_string; return });
        return $ua;
    },
);
has 'cookieJar' => (
    is => 'rw', lazy => 1, default => sub {
        my ($self) = @_;
        my $jar = HTTP::Cookies->new(
            file => "$ENV{HOME}/.pandora/cookies.dat",
            autosave => 1,
            ignore_discard => 1,
        );
        return $jar;
    },
);
has 'json' => (
    is => 'rw', lazy => 1, default => sub {
        my ($self) = @_;
        my $json = JSON->new();
        # $json->pretty(1);
        return $json;
    },
);
has 'jsonPretty' => (
    is => 'rw', lazy => 1, default => sub {
        my ($self) = @_;
        my $json = JSON->new();
        $json->pretty(1);
        return $json;
    },
);
has 'username' => (is => 'rw');
has 'password' => (is => 'rw');
has 'authToken' => (is => 'rw');
has 'webname' => (is => 'rw');
has 'positiveFeedbackCount' => (is => 'rw');
has 'loginResponse' => (is => 'rw');
has 'profile' => (is => 'rw');

# @param $method: 'v1/station/getFeedback'
sub createRequest {
    my ($self, %args) = @_;
    my $method      = $args{method};
    my $data        = $args{data};
    my $noAuthToken = $args{noAuthToken};
    my $request = HTTP::Request->new();
    my $uri = $self->endpoint . $method;
    $request->method('POST');
    $request->uri($uri);
    $request->content_type('application/json');
    $request->content($self->json->encode($data));
    $request->header('Accept', 'application/json');
    $self->cookieJar->scan(sub {
                               my $key = $_[1];
                               my $val = $_[2];
                               $request->header('X-CsrfToken', $val) if $key eq 'csrftoken';
                           });
    unless ($noAuthToken) {
        $request->header('X-AuthToken', $self->authToken);
    }
    return $request;
}

sub executeRequest {
    my ($self, $request) = @_;
    my $response = $self->ua->request($request);
    if (!$response->is_success) {
        die(sprintf("%s: %s\n", $response->base, $response->status_line));
    }
    return $response;
}

sub execute {
    my ($self, %args) = @_;
    my $request = $self->createRequest(%args);
    my $response = $self->executeRequest($request);
    if ($response->content_type eq 'application/json') {
        return $self->json->decode($response->decoded_content);
    }
    return $response;
}

sub login {
    my ($self) = @_;
    my $response = $self->execute(
        method => 'v1/auth/login',
        data => {
            existingAuthToken => JSON::null,
            keepLoggedIn => JSON::true,
            username => $self->username,
            password => $self->password,
        },
    );
    $self->authToken($response->{authToken});
    $self->webname($response->{webname});
    $self->loginResponse($response);
    return $response;
}

sub getCSRFToken {
    my ($self) = @_;
    my $request = HTTP::Request->new('GET', 'https://www.pandora.com/');
    my $response = $self->executeRequest($request);
}

use POSIX qw(floor);

sub getProfile {
    my ($self) = @_;
    my $response = $self->execute(
        method => 'v1/listener/getProfile',
        data => {
            webname => $self->webname,
        }
    );
    $self->positiveFeedbackCount($response->{positiveFeedbackCount});
    $self->profile($response);
    return $response;
}

sub getFeedback {
    my ($self, %args) = @_;
    my $pageSize = 100;
    my $pages = floor(($self->positiveFeedbackCount + $pageSize - 1) / $pageSize);
    my $feedback = [];
    my $misc = [];
    my $callback = $args{callback};
    for (my $i = 0; $i < $pages; $i += 1) {
        if ($i) {
            print STDERR ("Waiting...\n");
            sleep(2);
        }
        printf STDERR ("Retrieving page %d of %d of all account feedback...\n", $i + 1, $pages);
        my $response = $self->execute(
            method => 'v1/station/getFeedback',
            data => {
                pageSize   => 100,
                startIndex => $i * $pageSize,
                webname    => $self->webname,
            }
        );
        if ($callback && ref $callback eq 'CODE') {
            $callback->($i, $response);
        }
        delete $response->{total};
        my $batch = delete $response->{feedback};
        push(@$feedback, @$batch);
        push(@$misc, $response);
    }
    return {
        misc => $misc,
        feedback => $feedback,
    };
}

1;
