package Employee;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw();

    use Person;
    @ISA = ("Person");

    sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self  = $class->SUPER::new();
        $self->{SALARY}        = undef;
        $self->{ID}            = undef;
        $self->{START_DATE}    = undef;
        bless ($self, $class);          # reconsecrate
        return $self;
    }
        sub salary {
        my $self = shift;
        if (@_) { $self->{SALARY} = shift }
        return $self->{SALARY};
    }    sub id_number {
        my $self = shift;
        if (@_) { $self->{ID} = shift }
        return $self->{ID};
    }    sub start_date {
        my $self = shift;
        if (@_) { $self->{START_DATE} = shift }
        return $self->{START_DATE};
    }

1;