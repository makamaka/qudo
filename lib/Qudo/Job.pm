package Qudo::Job;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    bless {%args}, $class;
}

sub id       { $_[0]->{job_data}->{job_id}       }
sub uniqkey  { $_[0]->{job_data}->{job_uniqkey}  }
sub func_id  { $_[0]->{job_data}->{func_id}      }

sub funcname {
    my $self = shift;
    $self->manager->funcid_to_name($self->func_id, $self->db);
}

sub retry_cnt     { $_[0]->{job_data}->{job_retry_cnt}     }
sub grabbed_until { $_[0]->{job_data}->{job_grabbed_until} }
sub priority { $_[0]->{job_data}->{job_priority} }
sub arg : lvalue  { $_[0]->{job_data}->{job_arg}           }
sub arg_origin : lvalue { $_[0]->{arg_origin} }
sub db { $_[0]->{db} }

sub manager  { $_[0]->{manager} }
sub job_start_time : lvalue { $_[0]->{job_start_time} }

sub completed {
    my $self = shift;

    $self->{_complete} = 1;

    return unless $self->funcname->set_job_status;
    $self->manager->set_job_status($self, 'completed');
}

sub is_completed { $_[0]->{_complete} }
sub is_aborted   { $_[0]->{_abort}    }
sub is_failed    { $_[0]->{_fail}    }

sub reenqueue {
    my ($self, $args) = @_;
    $self->manager->reenqueue($self, $args);
}

sub dequeue {
    my $self = shift;
    $self->manager->dequeue($self);
}

sub failed {
    my ($self, $error) = @_;

    $self->{_fail} = 1;

    if ($self->funcname->set_job_status) {
        $self->manager->set_job_status($self, 'failed');
    }
    $self->manager->job_failed($self, $error);
}

sub abort {
    my ($self, $error) = @_;

    $self->{_abort} = 1;
    $error ||= 'abort!!';

    if ($self->funcname->set_job_status) {
        $self->manager->set_job_status($self, 'abort');
    }
    $self->manager->job_failed($self, $error);
}

sub replace {
    my ($self, @jobs) = @_;

    my $db = $self->manager->driver_for($self->db);
    $db->dbh->begin_work;

        for my $job (@jobs) {
            $self->manager->enqueue(@$job, $self->db);
        }

        $self->completed;

    $db->dbh->commit;
}

1;

