use Inline Java => 'bug/Foo.java' ;

eval{
	Foo->new->test_a();
	Foo->new->test_b();
} ;
if (Inline::Java::caught("javax.xml.parsers.FactoryConfigurationError")){
    my $msg = $@->getMessage() ;
    die($msg) ;
}

