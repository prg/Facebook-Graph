package Facebook::Graph::Batch;

use Any::Moose;
use Facebook::Graph::Response;
with 'Facebook::Graph::Role::Uri';
use LWP::UserAgent;
use URI::Encode qw(uri_decode uri_encode);
use JSON;
use Ouch;

has access_token => (
    is => 'rw',
    predicate => 'has_access_token',
);

has ua => (
    is => 'rw',
);

sub _build_batch {
    my ($self, $queries) = @_;
    my $batch;
    my $api_limit = 50; # max limit by Facebook

    foreach (@{ $queries }) {
        if ($api_limit > 0) {
            my $relative_url = $_->relative_uri_as_string;
            # if ($_->has_access_token) {
            #     # request specific access tokens have to be passed in the url,
            #     # see https://developers.facebook.com/bugs/212455918831996
            # }
            push @$batch, { method => $_->method, relative_url => $relative_url };

            $api_limit--;
        }
    }

    return JSON->new->encode($batch);
}

sub request {
    my ($self, $queries) = @_;
    my (%params, @response);
    my $uri = $self->uri;

    my $batch = $self->_build_batch($queries);

    if ($self->has_access_token) {
        $params{access_token} = uri_decode($self->access_token);
    }

    $params{batch} = $batch;

    my $response = ($self->ua || LWP::UserAgent->new)->post($uri, \%params);

    if ($response->is_success) {
        foreach (@{ JSON->new->decode($response->content) }) {
            push @response,
                Facebook::Graph::Response->new(
                    response => HTTP::Response->new($_->{code}, undef, $_->{headers}, $_->{body})
                );
        }

        return \@response;
    } else {
        my $message = $response->message;
        my $error = eval { JSON->new->decode($response->content) };
        unless ($@) {
            $message = $error->{error}{type} . ' - ' . $error->{error}{message};
        }
        ouch $response->code, 'Could not execute request ('.$response->request->uri->as_string.'): '.$message,
            $response->request->uri->as_string;
    }
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;
