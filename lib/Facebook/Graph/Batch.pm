package Facebook::Graph::Batch;

use Any::Moose;
use Facebook::Graph::Response;
with 'Facebook::Graph::Role::Uri';
use LWP::UserAgent;
use URI::Encode qw(uri_decode);
use JSON;

has secret => (
    is => 'ro',
    required => 0,
    predicate => 'has_secret',
);

has access_token => (
    is => 'rw',
    predicate => 'has_access_token',
);

has queries => (
    is => 'rw',
    isa => 'ArrayRef[Facebook::Graph::Query]',
);

has _batch => (
    is => 'rw',
);

has ua => (
    is => 'rw',
);

sub build_batch {
    my ($self) = @_;
    my @batch;

    foreach (@{ $self->queries }) {
        push @batch, { method => $_->method, relative_url => $_->relative_uri_as_string };
        if ($_->has_access_token) {
            $self->access_token($_->access_token);
        }
    }
    $self->_batch(\@batch);

    return $self;
}

sub request {
    my ($self) = @_;
    my (@params, @response);
    my $uri = $self->uri;

    $self->build_batch;

    #push @params, { access_token => uri_decode($self->access_token) };
    push @params, { batch => $self->_batch };

    my $response = ($self->ua || LWP::UserAgent->new)->post($uri, \@params);

    foreach (@{ JSON->new->decode($response->content) }) {
        push @response,
            Facebook::Graph::Response->new(
                response => HTTP::Response->new($_->{code}, undef, $_->{headers}, $_->{body})
            );
    }

    return \@response;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;
