package WebEditor::OldController::Msg;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw(C EditorLang Messages));

sub new {
    my($class, $c, $lang) = @_;
    my $self = { C          => $c,
		 EditorLang => $lang||"en", # named EditorLang for OldController.pm compat
		 Messages   => {},
	       };
    bless $self, $class;
}

sub msg {
    my($self, $key) = @_;
    my $stash = $self->Messages->{$self->EditorLang};
    if (!$stash) {
	my $c = $self->C;
	my @try_langs = ($self->EditorLang);
	push @try_langs, "en" if $self->EditorLang ne "en";
	for my $lang (@try_langs) {
	    my $langres_file = $c->paths->we_templatebase . "/langres_$lang";
	    if (-r $langres_file) {
		require Template::Context;
		my $ctx = Template::Context->new({ ABSOLUTE => 1});
		$ctx->process($langres_file);
		$stash = $ctx->stash;
		last if $stash;
	    }
	}
	if (!$stash) {
	    return "[[$key]]";
	}
	$self->Messages->{$self->EditorLang} = $stash;
    }
    my $val = $stash->get($key);
    if (!defined $val) {
	"[[$key]]";
    } else {
	$val;
    }
}

sub fmt_msg {
    my($self, $key, @arg) = @_;
    sprintf $self->msg($key), @arg;
}

1;
