package Inline::Java::Callback ;


use strict ;

$Inline::Java::Callback::VERSION = '0.31' ;


use Carp ;


sub InterceptCallback {
	my $inline = shift ;
	my $resp = shift ;

	# With JNI we need to store the object somewhere since we
	# can't drag it along all the wat through Java land...
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
	my @args = map {$pc->DeserializeObject(0, $_)} @sargs ;

	Inline::Java::debug(" processing callback $module" . "::" . "$function(" . 
		join(", ", @args) . ")") ;

	no strict 'refs' ;
	my $sub = "$module" . "::" . $function ;
	my $ret = $sub->(@args) ;

	($ret) = $pc->ValidateArgs([$ret]) ;

	return "callback $ret" ;
}


__DATA__

/*
	Callback to Perl...
*/
public class InlineJavaPerlCaller {
	public InlineJavaPerlCaller(){
		if (InlineJavaServer.instance == null){
			System.err.println("Can't use InlineJavaPerlCaller outside of an Inline::Java context") ;
			System.err.flush() ;
		}
	}


	class InlineJavaPerlCallerException extends Exception {
		InlineJavaPerlCallerException(String s) {
			super(s) ;
		}
	}


	public Object CallPerl(String pkg, String method, Object args[]) throws InlineJavaPerlCallerException {
		try {
			return InlineJavaServer.instance.Callback(pkg, method, args) ;
		}
		catch (InlineJavaServer.InlineJavaException e){
			throw new InlineJavaPerlCallerException(e.getMessage()) ;
		}
	}
}


