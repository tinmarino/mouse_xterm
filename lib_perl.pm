use strict; use warnings; use v5.26;

=head

QUICKSTART
  unshift @INC, '.'; require lib_perl 

TODO 
  disable bad click
  remap c-l
  mutualise what can be mutualised with mouse.sh

=cut


use Term::ReadLine;
use Term::ReadKey;

our $term = new Term::ReadLine 'Reply';
$term->add_defun('cb_debug', \&cb_debug, ord "\ch");
$term->add_defun('cb_click_0', \&cb_click_0);

# Mouse click
$term->bind_keyseq("\e[<0;", 'cb_click_0');


sub mlog {
	my $in = shift;
    # open(LOG, '>>/tmp/xterm_monitor');
    # say LOG "Reply : $in";
}

sub stop_reading {
	given (shift){
		when ('m'){ return 1 }
		when ('M'){ return 1 }
		when ('R'){ return 1 }
		when ('') { return 1 }
	}
	return 0;
}

sub read_keys {
    my $res = '';
	# TODO $term->read_key
	while ( not stop_reading (my $key = ReadKey(-1)) ) {
		$key = '' if not defined $key;
		$res .= $key;
	}
    return $res;
}

sub get_beginning_of_line {
    # Clean stdin
    read_keys;

	# Read cursor location
	print "\033[6n";
	my $keys = read_keys;
	my ($y0, $x0) = split ";", $keys;
	$y0 = substr($y0, 2);

	# Get terminal size
	my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize;

	# Substract cursor location
	my $pt = $term->{point};
	$x0 -= int($pt % $wchar);
	$y0 -= int($pt / $wchar);

	# Return
	return ($x0, $y0);
}

sub cb_debug {
    my @readline_vars = qw/line_buffer point end mark done num_chars_to_read pending_input dispatching erase_empty_line prompt display_prompt already_prompted library_version readline_version gnu_readline_p terminal_name readline_name instream outstream prefer_env_winsize last_func startup_hook pre_input_hook signal_event_hook input_available_hook redisplay_function prep_term_function deprep_term_function executing_keymap binding_keymap executing_macro executing_key executing_keyseq key_sequence_length readline_state explicit_arg numeric_arg editing_mode/;
    for my $w (@readline_vars) {
        my $text = $term->{$w};
        say '======================';
        say "$w : $text";
    }
}


sub cb_click_0 {
	# Callback for mouse
	my $keys;
	mlog "====================== click";

	# Read rest
    $keys = read_keys;
	my ($x1, $y1) = split ";", $keys;
	mlog "x1 $x1 ; y1 $y1";

	# Get terminal size
	my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize;

	# Get first column
	my ($x0, $y0) = get_beginning_of_line;
	mlog "x0 $x0 ; y0 $y0";

	# Arithme
	my $col = ($y1 - $y0) * $wchar;
	$col = 0 if ($col < 0);
	mlog "Column : $col and $wchar";
	my $line_pos = $x1 - $x0 + $col;
	mlog "line_pos $line_pos";
	mlog "";

	# Move cursor
	$term->{point} = $line_pos;
}

sub cb_click_void {
}

1;
