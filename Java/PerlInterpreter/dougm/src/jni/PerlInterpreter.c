#include "jni.h"
#include "EXTERN.h"
#include "perl.h"

#define JENV (*env)

#define PERL_PACKAGE "org/perl"

void boot_DynaLoader(pTHX_ CV* cv);

static void xs_init(pTHX)
{
    char *file = __FILE__;
    dXSUB_SYS;
    newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
}

static void perl_throw_exception(JNIEnv *env, char *msg)
{
    jclass errorClass = 
        JENV->FindClass(env, PERL_PACKAGE "PerlException");

    JENV->ThrowNew(env, errorClass, msg);
}

static PerlInterpreter *perl_get_pointer(JNIEnv *env, jobject obj) {
    jfieldID pointer_field;
    jclass cls;
      
    cls = JENV->GetObjectClass(env, obj);

    pointer_field = JENV->GetFieldID(env, cls, "perlInterpreter", "I");

    return (PerlInterpreter *)JENV->GetIntField(env, obj, pointer_field);
}

static void perl_set_pointer(JNIEnv *env, jobject obj, const void *ptr) {
    jfieldID pointer_field;
    int pointer_int;
    jclass cls;
    
    cls = JENV->GetObjectClass(env, obj);

    pointer_field = JENV->GetFieldID(env, cls, "perlInterpreter", "I");
    pointer_int = (int)ptr;

    JENV->SetIntField(env, obj, pointer_field, pointer_int);
}

JNIEXPORT jobject JNICALL Java_org_perl_PerlInterpreter_create
(JNIEnv *env, jobject obj, jobject parent)
{
    PerlInterpreter *interp = NULL;

    if (parent) {
        PerlInterpreter *parent_perl = perl_get_pointer(env, parent);
        interp = perl_clone(parent_perl, 0);
    }
    else {
        char *args[] = {"java", "-e0"};

        interp = perl_alloc();
        perl_construct(interp);
        perl_parse(interp, xs_init, 2, args, NULL);
        perl_run(interp);
    }

    perl_set_pointer(env, obj, interp);

    return NULL;
}

JNIEXPORT void JNICALL Java_org_perl_PerlInterpreter_destroy
(JNIEnv *env, jobject obj)
{
    PerlInterpreter *perl = perl_get_pointer(env, obj);

    perl_destruct(perl);
    perl_free(perl);
}

JNIEXPORT jstring JNICALL Java_org_perl_PerlInterpreter_eval
(JNIEnv *env, jobject obj, jstring jcode)
{
    PerlInterpreter *perl = perl_get_pointer(env, obj);
    dTHXa(perl);
    SV *sv = Nullsv;

    const char *code = JENV->GetStringUTFChars(env, jcode, 0);

    sv = eval_pv(code, FALSE);

    if (SvTRUE(ERRSV)) {
        perl_throw_exception(env, SvPVX(ERRSV));
    }

    if (SvTRUE(sv)) {
        STRLEN n_a;
        return JENV->NewStringUTF(env, SvPV(sv, n_a));
    }

    return NULL;
}

JNIEXPORT jstring JNICALL Java_org_perl_PerlInterpreter_call
(JNIEnv *env, jobject obj, jstring jfunction, jobjectArray args)
{
    PerlInterpreter *perl = perl_get_pointer(env, obj);
    dTHXa(perl);

    const char *function = JENV->GetStringUTFChars(env, jfunction, 0);

    if (SvTRUE(ERRSV)) {
        perl_throw_exception(env, SvPVX(ERRSV));
    }

    return NULL;
}

/*
#!perl

use 5.8.0;
use strict;
use Config;
use ExtUtils::Embed;

my $cmodule = 'PerlInterpreter';

chomp(my $ccopts = ccopts());
chomp(my $ldopts = ldopts());

$ccopts .= " -I$ENV{JAVA_HOME}/include/linux -I$ENV{JAVA_HOME}/include";
$ldopts .= " $Config{lddlflags}";

my $ar  = "-Wl,--whole-archive";
my $nar = "-Wl,--no-whole-archive";

run("$Config{cc} -Wall $ar $ccopts $ldopts $nar -o lib$cmodule.so $cmodule.c");

sub run {
    print "@_\n";
    system "@_";
}

__END__
*/
