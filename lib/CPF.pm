package CPF;
use Dancer2;
use Dancer2::Plugin::DBIC;
use Data::Dumper;
use DateTime;
use File::Temp qw/tempfile/;
use Mail::Message;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => {
        ssl_user => $ENV{SSL_CLIENT_S_DN_CN},
        now      => DateTime->now,
    };
};

post '/cpf/:type/:action/?' => sub {
    my $type   = route_parameters->get('type');
    my $action = route_parameters->get('action');
    header "Cache-Control" => "max-age=0, must-revalidate, private";
    _cpfmsg($type, $action);
};

post '/cpf/receive/?' => sub {
    my $dump_dir = config->{cpf}->{request_dump_dir};
    my ($fh, $filename) = tempfile(DIR => $dump_dir);
    my $data = request->body;
    print $fh $data;

    Mail::Message->build(
        To       => config->{cpf}->{request_notify} || 'root',
        Subject  => "New CPF order",
        data     => "Contained in $filename",
    )->send(via => 'postfix');

    content_type 'application/xml';
    header "Cache-Control" => "no-cache";
    return ''; # Content length of 0 required by CPF
};

sub _cpfmsg
{   my ($type, $action) = @_;

    $type =~ /^(AcknowledgePurchaseOrder|Invoice)$/
        or _error(400, "Invalid message type: $type");

    my $prefix = config->{cpf}->{prefix};

    my $id = request_header 'UID';

    if ($id)
    {
        $id =~ /^$prefix([0-9]+)$/
            or return _error(400, "Invalid message ID format: $id");
        $id = $1;
    }

    if ($action eq 'GetList')
    {
        my @ids = schema->resultset('Cpfmsg')->search({
            type    => $type,
            deleted => 0,
        })->get_column('id')->all;
        if (!@ids)
        {
            return _error(204, "No messages present");
        }
        else {
            @ids = map { "$prefix$_" } @ids;
            return join "\n", @ids;
        }
    }
    elsif ($action eq 'Download')
    {
        my $error = _check_id($id);
        $error and return $error;
        my $message = _message($type, $id)
            or return _error(404, "No such message: $id");
        content_type 'application/xml';
        return $message->content;
    }
    elsif ($action eq 'Delete')
    {
        my $error = _check_id($id);
        $error and return $error;
        my $message = _message($type, $id)
            or return _error(404, "No such message: $id", 404);
        $message->update({ deleted => 1 });
        return 1;
    }
    else {
        _error(400, qq(Invalid action "$action"));
    }
}

sub _check_id
{   my $id = shift;
    my $error;
    defined $id
        or $error = _error(400, "Missing header UID");
    $error || $id
        or $error = _error(400, "Required message ID must be specified in header UID");
    $error;
}

sub _message
{   my ($type, $id) = @_;
    my ($message) = schema->resultset('Cpfmsg')->search({
        id      => $id,
        type    => $type,
        deleted => 0,
    })->all;
    $message;
}

sub _error
{   my ($code, $message) = @_;
    status $code;
    return $message;
}

true;
