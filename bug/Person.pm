package Person;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw();

    ##################################################
    ## the object constructor (simplistic version)  ##
    ##################################################
    sub new {
        my $self  = {};
        $self->{NAME}   = undef;
        $self->{AGE}    = undef;
        $self->{PEERS}  = [];
        bless($self);           # but see below
        return $self;
    }
    ##############################################
    ## methods to access per-object data        ##
    ##                                          ##
    ## With args, they set the value.  Without  ##
    ## any, they only retrieve it/them.         ##
    ##############################################
    sub name {
        my $self = shift;
        if (@_) { $self->{NAME} = shift }
        return $self->{NAME};
    }
    sub age {
        my $self = shift;
        if (@_) { $self->{AGE} = shift }
        return $self->{AGE};
    }
    sub peers {
        my $self = shift;
        if (@_) { @{ $self->{PEERS} } = @_ }
        return @{ $self->{PEERS} };
    }

1;