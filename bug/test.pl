BEGIN {
	$main::CNOTE_HOME = "/bla/bla/bla"
}

use Inline (Java  => 'DATA',
    PORT => 4500,
    EXTRA_JAVA_ARGS => "-Xmx196m -DCNOTE_HOME=$main::CNOTE_HOME"
);

print test->get_prop("CNOTE_HOME"), "\n" ;

__END__
__Java__
class test {
	public static String get_prop(String p){
		return System.getProperty(p) ;
	}
}
