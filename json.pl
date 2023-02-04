use strict;
use warnings;
use utf8;
#use Tie::IxHash;
use feature qw(signatures);
no warnings qw(experimental::smartmatch experimental::signatures);

my %pp = ();
#tie %pp, 'Tie::IxHash';


################ lexer
sub makeChars($json) {
    my @chars = split("", $json);
    $pp{"chars"} = \@chars;
    $pp{"charsLength"} = $#chars;
}

sub jsonLength() {
    return $pp{"charsLength"};
}

sub getChar() {
    my @chars = @{$pp{"chars"}};
    my $char = shift(@chars);
    $pp{"chars"} = \@chars;
    return $char;
}

sub nextChar() {
    my @chars = @{$pp{"chars"}};
    return $chars[0];
}

sub putChar($char) {
    my @chars = @{$pp{"chars"}};
    unshift(@chars, $char);
    $pp{"chars"} = \@chars;
    $pp{"charsLength"} = $#chars;
}

########################### charGroups

sub isSpaceNewLine($char) {
    my @spaceNewLline = (" ", "\n", "\t", "\r");
    if($char ~~ @spaceNewLline) {
        return 1;
    } else {
        return 0;
    }
}

sub isDigit($char) {
    my @digits = ( "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" );
    foreach my $digit (@digits) {
        if ( $char eq $digit ) {
            return 1;
        }
    }
    return 0;
}

sub isAlpha($char) {
    my @alpha = ();

    for my $char ( 'a' ... 'z' ) {
        push @alpha, $char;
    }
    for my $char ( 'A' ... 'Z' ) {
        push @alpha, $char;
    }

    if ( $char ~~ @alpha ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub isQuote($char) {
    if ( $char eq '"' ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub isSpecialCharachter($char) {
    my @specialCharachters = ( "{", "}", ",", ":" );

    if ( $char ~~ @specialCharachters ) {
        return 1;
    }
    else {
        return 0;
    }
}

############################ Lexer

sub lexer($json) {
    my @tokens;
    makeChars($json);

    my $counter = 0;
    my $jsonLength = jsonLength();

    while($counter <= $jsonLength) {
        my $currentChar = getChar();
        $counter++;
        if(isSpaceNewLine($currentChar)) {
            next;
        }

        if(isSpecialCharachter($currentChar)) {
            my $token = {
                "type" => "specialCharachter",
                "value" => $currentChar
            };
            push @tokens, $token;
        }

        if(isQuote($currentChar)) {
          my $string = "";
          my $delimiter = $currentChar;

          $currentChar = getChar();
          $counter++;

          while($currentChar ne $delimiter) {
            $string .= $currentChar;
            $currentChar = getChar();
            $counter++;
          }

          my $token = {"type" => "String", "value" => $string};
          push @tokens, $token;
          next;
        }

        if(isDigit($currentChar)) {
          my $number = "";
          $number .= $currentChar;

          $currentChar = getChar();
          $counter++;

          while(isDigit($currentChar) || $currentChar eq ".") {
            $number .= $currentChar;
            $currentChar = getChar();
            $counter++;
          }

          putChar($currentChar);
          $counter = $counter -1;

          my $token = {"type" => "Number", "value" => $number};
          push @tokens, $token;

          next;
        }

        if(isAlpha($currentChar)) {
          my $symbol = "";
          $symbol .= $currentChar;

          $currentChar = getChar();
          $counter++;

          while(isAlpha($currentChar)) {
            $symbol .= $currentChar;
            $currentChar = getChar();
            $counter++;
          }

          putChar($currentChar);
          $counter = $counter - 1;

          my $token = {"type" => "Symbol", "value" => $symbol};
          push(@tokens, $token);
          next;
        }
    }
    return @tokens;
}

################################ Parser

sub makeTokens(@tokens) {
    $pp{"tokens"} = \@tokens;
    $pp{"tokensLength"} = $#tokens;
}

sub tokensLength() {
    return $pp{"tokensLength"};
}

sub getToken() {
    my @tokens = @{$pp{"tokens"}};
    my $currentToken = shift(@tokens);
    $pp{"tokens"} = \@tokens;
    $pp{"tokensLength"} = $#tokens;
    return $currentToken;
}

sub nextToken() {
    my @tokens = @{$pp{"tokens"}};
    return $tokens[0];
}

sub putToken($token) {
    my @tokens = @{ $pp{"tokens"}};
    unshift(@tokens, $token);
    $pp{"tokens"} = \@tokens;
    $pp{"tokensLength"} = $#tokens;
}

########################################## Parser

sub parse($json) {
    my @tokens = lexer($json);
    makeTokens(@tokens);

    use Data::Dumper;
    print Dumper \@tokens;
}

my $json = '{
    "false" : false,
    "null" : null,
    "true" : true,
    "foo" : [3, 4, "౮"],
    "buz": "a string ఈ వారపు వ్యాసం with spaces",
    "more": {
      "3" : [8, 9]
    },
    "1" : 41
  }
';
parse($json);
