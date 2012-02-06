package Facebook::Graph::Batch;

use Any::Moose;
use Facebook::Graph::Response;
with 'Facebook::Graph::Role::Uri';
use LWP::UserAgent;
use URI::Encode qw(uri_decode);
use JSON;
use Ouch;

has secret => (
    is => 'ro',
    required => 0,
    predicate => 'has_secret',
);

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

    foreach (@{ $queries }) {
        if ($_->has_access_token) {
            $self->access_token($_->access_token);
        }
        push @$batch, { method => $_->method, relative_url => $_->relative_uri_as_string };
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
