use blib ;
use vars qw($JARS);
BEGIN {
  $JARS = '/home/patrickl/perl/dev/Inline-Java/bug/piccolo-1.0/build' ;
}
use Inline Java => Config =>
  CLASSPATH => "$JARS/piccolo.jar:$JARS/piccolox.jar:$JARS/examples.jar";
use Inline::Java qw(study_classes) ;
study_classes(['java.awt.Color',
	       'edu.umd.cs.piccolo.nodes.PPath',
	       'edu.umd.cs.piccolo.nodes.PText',
	       'edu.umd.cs.piccolo.PCanvas',
	       'edu.umd.cs.piccolo.PLayer',
	       'java.awt.BasicStroke',
	      ]);
use Inline Java => 'DATA';

use Getopt::Long;
my %OPTIONS;
my $rc = GetOptions(\%OPTIONS,
		    'input=s',
		    'help',
		   );

my $USAGE = <<"EOU";
usage: $0 [required params] [options]
  require params:
    --input=file : gaps file to process

  options:
    --help        : this message
EOU

die "Bad option\n$USAGE" unless $rc;
die "$USAGE" if exists $OPTIONS{help};

die "Must specify --input\n$USAGE"
  unless exists $OPTIONS{input};

# create the Java connection
my $t = new Test();

# set up some useful constants
my $UNIT = 10;
my $STROKE = java::awt::BasicStroke->new($UNIT);

# read in the file data
open(IN,$OPTIONS{input})
  or die "Couldn't open $OPTIONS{input} for reading";
while (<IN>) {
  my ($ref_pos,$query_pos,$length) = m/^\s+(\d+)\s+(\d+)\s+(\d+)\s+/;
  push(@gaps,[$ref_pos,$query_pos,$length]);
}
my $max_ref = $gaps[-1]->[0] + $gaps[-1]->[2];
my $max_query = $gaps[-1]->[1] + $gaps[-1]->[2];

# get access to some picolo internal objects
my $c = $t->getCanvas();
my $layer = $c->getLayer();

# create rectangles for the landmarks
for (my $i=0;$i<$max_ref;$i+=10_000) {
  print "$i\n" ;
  my $r = edu::umd::cs::piccolo::nodes::PPath->createRectangle($i-$UNIT,
					$i-$UNIT,
					2*$UNIT,
					2*$UNIT);
  $r->setPaint($java::awt::Color::RED);
  $layer->addChild($r);

# FIXME - this line causes the following error:
# Method createPolyline for class edu.umd.cs.piccolo.nodes.PPath with signature ([F,[F) not found at (eval 10) line 1159
my $text = edu::umd::cs::piccolo::nodes::PText->new("$i");
$text->setOffset($i,$i);
$layer->addChild($text);

# FIXME - this line causes the following error:
# Method createPolyline for class edu.umd.cs.piccolo.nodes.PPath with signature ([F,[F) not found at (eval 10) line 1159
#
# unless you comment out the foreach loop for drawing lines
  my $text = $t->getText("$i");
  $text->setOffset($i,$i);
  $layer->addChild($text);
}

my $tag = 0;
my $i = 0 ;
foreach my $gap (@gaps) {
  print "$i\n" ; $i++ ;

  my $l = edu::umd::cs::piccolo::nodes::PPath->createPolyline([$gap->[0],$gap->[0]+$gap->[2]],
			     [$gap->[1],$gap->[1]+$gap->[2]],
			    );
  $l->setStroke($STROKE);
  if ($tag) {
    $l->setStrokePaint($java::awt::Color::BLUE);
    $tag = 0;
  } else {
    $l->setStrokePaint($java::awt::Color::GREEN);
    $tag = 1;
  }
# FIXME - this line causes the following error:
# Method createPolyline for class edu.umd.cs.piccolo.nodes.PPath with signature ([F,[F) not found at (eval 10) line 1159
 $layer->addChild($l);

# so instead I've created a bogus wrapper method to do the work
#  $t->addChild($l);

}

while (1) {
  sleep 5;
}
print "Finished\n";

__DATA__

__Java__

import java.awt.BasicStroke;
import java.awt.Paint;
// import java.awt.Color;
// import java.awt.Graphics2D;
// import edu.umd.cs.piccolo.activities.PActivity;
// import edu.umd.cs.piccolo.util.PPaintContext;
import edu.umd.cs.piccolo.PLayer;
import edu.umd.cs.piccolo.PCanvas;
import edu.umd.cs.piccolo.PNode;
import edu.umd.cs.piccolox.PFrame;
import edu.umd.cs.piccolo.nodes.PPath;
import edu.umd.cs.piccolo.nodes.PText;

class Test extends PFrame {

	public Test() {
		super();
	}
	public void addChild(PNode aNode) {
		PLayer layer = getCanvas().getLayer();
		layer.addChild(aNode);
        }
	public PText getText(String s) {
	        return new PText(s);
        }
	public void initialize() {
		long currentTime = System.currentTimeMillis();
	}
}
/*
public class SemanticPath extends PPath {
	public void paint(PPaintContext aPaintContext) {
		double s = aPaintContext.getScale();
		Graphics2D g2 = aPaintContext.getGraphics();
		
		if (s < 1) {
			g2.setPaint(Color.blue);
		} else {
			g2.setPaint(Color.orange);
		}
		
		g2.fill(getBoundsReference());
	}
}
*/
