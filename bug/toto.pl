use Inline (
    Java => 'DATA',
	STUDY => ['java.util.HashMap'],
	AUTOSTUDY => 1,
) ;

my $o = test->f() ;
print $o->[0] ;


__END__
__Java__

class test {
	static public Object f(){
		return new String [] {"allo"} ;
	}
}
