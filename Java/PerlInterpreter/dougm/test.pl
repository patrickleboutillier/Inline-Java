use strict;
use warnings FATAL => 'all';

use DynaLoader ();

our $code;

BEGIN {
    use Config;
    my $libperl = "$Config{installarchlib}/CORE/libperl.so";

    DynaLoader::dl_load_file($libperl, 0x01);

    $Inline::Java::DEBUG = 1;

    $code = <<EOF;

class Jtest {

    public Jtest () { }

    public static void listProps() {
        System.getProperties().list(System.out);
    }
}

EOF
}

use blib '/home/dougm/build/Inline-Java-0.33';

use Inline Java => $code,
  AUTOSTUDY => 1, JNI => 2,
  DIRECTORY => '/home/dougm/covalent/eam/PerlInterpreter/inline',
  NAME => 'MyStuff';

Jtest->new->listProps();

print "ok\n";

1;
