use DynaLoader ();

BEGIN {
    use Config;
    my $libperl = "$Config{installarchlib}/CORE/libperl.so";

    DynaLoader::dl_load_file($libperl, 0x01);
}


use Cwd ;
print "OK\n" ;
