package Inline::Java::Callback ;


use strict ;

$Inline::Java::Callback::VERSION = '0.31' ;


use Carp ;


sub InterceptCallback {
	my $inline = shift ;
	my $resp = shift ;

	# With JNI we need to store the object somewhere since we
	# can't drag it along all the way through Java land...
	if (! defined($inline)){
		$inline = $Inline::Java::JNI::INLINE_HOOK ;
	}

	if ($resp =~ s/^callback (.*?) (\w+)//){
		my $module = $1 ;
		my $function = $2 ;
		my @args = split(' ', $resp) ;
		return Inline::Java::Callback::ProcessCallback($inline, $module, $function, @args) ;
	}

	croak "Malformed callback request from server: $resp" ;
}


sub ProcessCallback {
	my $inline = shift ;
	my $module = shift ;
	my $function = shift ;
	my @sargs = @_ ;

	my $pc = new Inline::Java::Protocol(undef, $inline) ;
	my $thrown = 'false' ;
	my $ret = undef ;
	eval {
		my @args = map {$pc->DeserializeObject(0, $_)} @sargs ;

		Inline::Java::debug(" processing callback $module" . "::" . "$function(" . 
			join(", ", @args) . ")") ;

		no strict 'refs' ;
		my $sub = "$module" . "::" . $function ;
		$ret = $sub->(@args) ;
	} ;
	if ($@){
		$ret = $@ ;
		$thrown = 'true' ;

		if ((ref($ret))&&(! UNIVERSAL::isa($ret, "Inline::Java::Object"))){
			croak "Can't propagate non-Inline::Java reference exception ($ret) to Java" ;
		}
	}

	($ret) = $pc->ValidateArgs([$ret]) ;

	return "callback $thrown $ret" ;
}


__DATA__

/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	public InlineJavaPerlCaller(){
	}


	class InlineJavaException extends Exception {
		private InlineJavaServer.InlineJavaException ije = null ;
		
		InlineJavaException(InlineJavaServer.InlineJavaException e) {
			ije = e ;
		}

		public InlineJavaServer.InlineJavaException GetException(){
			return ije ;
		}
	}


	class PerlException extends Exception {
		private Object obj = null ;

		PerlException(Object o) {
			obj = o ;
		}

		public Object GetObject(){
			return obj ;
		}
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaException, PerlException {
		if (InlineJavaServer.instance == null){
			System.err.println("Can't use InlineJavaPerlCaller outside of an Inline::Java context") ;
			System.err.flush() ;
			System.exit(1) ;
		}

		try {
			return InlineJavaServer.instance.Callback(pkg, method, args) ;
		}
		catch (InlineJavaServer.InlineJavaException e){
			throw new InlineJavaException(e) ;
		}
		catch (InlineJavaServer.InlineJavaPerlException e){
			throw new PerlException(e.GetObject()) ;
		}
	}
}


