use strict;
use warnings;
use utf8;
use Tie::IxHash;
use feature qw(signatures);
no warnings qw(experimental::smartmatch experimental::signatures);

my %pp = ();
tie %pp, 'Tie::IxHash';


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
    my @digits = ( 0, "1", "2", "3", "4", "5", "6", "7", "8", "9" );
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
    my @specialCharachters = ( "{", "}", "[", "]", ",", ":" );

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
use JSON;
use utf8;
use Data::Printer;

sub parse($json) {
    my @tokens = lexer($json);
    makeTokens(@tokens);

    my %hash;
    my $ast = json();
    if($ast) {
        $hash{"json"} = $ast;
        #print JSON->new->ascii->pretty->encode(\%hash);
        return %hash;
    } else {
        return 0;
    }
}

sub json() {
    my $hash = hash();
    if($hash) {
        return {"hash" => $hash};
    } else {
        return 0;
    }
}



sub hash() {
    my $openBrace = tokenOpenBrace();
    if(! $openBrace) { return 0; }

    my $keyValues = keyValues();
    if(! $keyValues) { return 0; }

    my $closeBrace = tokenCloseBrace();
    if(! $closeBrace) { return 0; }

    return { "keyValues" => $keyValues };
}

sub array() {
    my $openBracket = tokenOpenBracket();
    if(! $openBracket) { return 0; }

    my $arrayElements = arrayElements();
    if(! $arrayElements) { return 0; }

    my $closeBracket = tokenClosedBracket();
    if(! $closeBracket) { return 0; }

    return { "arrayElements" => $arrayElements };
}


sub tokenOpenBracket() {
    my $token = getToken();

    if( $token->{"value"} eq "[" ) {
        return 1;
    } else {
        putToken($token);
        return 0;
    }
}

sub tokenClosedBracket() {
    my $token = getToken();
    if( $token->{"value"} eq "]" ) {
        return 1;
    } else {
        putToken($token);
        return 0;
    }
}

sub keyValues() {
    my @keyValue = ();
    while(1) {
        my $keyValue = keyValue();
        if($keyValue) {
            push @keyValue, { "keyValue" => $keyValue };
        }

        my $token = getToken();
        if($token->{value} ne ",") {
            putToken($token);
            return \@keyValue;
        }

        $keyValue = keyValue();
        if($keyValue) {
            push @keyValue, { "keyValue" => $keyValue };
        }
    }
    return 1;
}

sub arrayElements() {
    my @arrayElements = ();
    while(1) {
        my $arrayElement = arrayElement();
        if($arrayElement) {
            push @arrayElements, { "arrayElement" => $arrayElement };
        }

        my $token = getToken();
        if($token->{value} ne ",") {
            putToken($token);
            return \@arrayElements;
        }

        $arrayElement = arrayElement();
        if($arrayElement) {
            push @arrayElements, { "arrayElement" => $arrayElement };
        }
    }
}

sub arrayElement() {
    my $anyValue = anyValue();
    if(! $anyValue) { return 0; }
    return $anyValue;
}

sub keyValue() {
    my $keyValue = {};

    my $key = key();
    if(! $key) {return 0};
    $keyValue->{"key"} = $key;

    my $separator = sep();
    if(! $separator) { return 0; }
    $keyValue->{"separator"} = $separator;

    my $value = value();
    if(! $value) { return 0; }
    $keyValue->{"value"} = $value;

    return $keyValue;
}

sub key() {
    my $stringValue = stringValue();
    if(! $stringValue) { return 0; }

    return { "stringValue" => $stringValue };
}

sub stringValue() {
    my $stringValue;
    my $token = getToken();
    
    if( $token->{"type"} eq "String") {
        $stringValue = $token->{"value"};
    } else {
        putToken($token);
        return 0;
    }
    return $stringValue;
}

sub numericValue() {
    my $numericValue;
    my $token = getToken();
    if( $token->{"type"} eq "Number") {
        $numericValue = $token->{"value"};
    } else {
        putToken($token);
        return 0;
    }

    return $numericValue;
}

sub sep() {
    my $sep;
    my $token = getToken();
    if($token->{"type"} eq "specialCharachter" && $token->{"value"} eq ":") {
        $sep = ":";
    } else {
        putToken($token);
        return 0;
    }

    return ":";
}

sub value() {
    my $anyValue = anyValue();
    if(! $anyValue) { return 0 };
    return {"anyValue" => $anyValue};
}

sub anyValue() {
    my $stringValue = stringValue();
    if($stringValue) {
        return { "stringValue" => $stringValue };
    }

    my $numericValue = numericValue();
    if($numericValue) {
        return { "numericValue" => $numericValue };
    }

    my $nullValue = nullValue();
    if($nullValue) {
        return { "nullValue" => $nullValue };
    }

    my $hash = hash();
    if($hash) {
        return { "hash" =>$hash };
    }

    my $array = array();
    if($array) {
        return { "array" => $array };
    }

    my $true = true();
    if($true) {
        return { "true" => $true };
    }

    my $false = false();
    if($false) {
        return { "false" => $false };
    }

    return 0;
}

sub tokenOpenBrace() {
    my $token = getToken();
    if( $token->{"value"} eq "{" ) {
        return 1;
    } else {
        putToken($token);
        return 0;
    }
}

sub tokenCloseBrace() {
    my $token = getToken();
    if( $token->{"value"} eq "}" ) {
        return 1;
    } else {
        putToken($token);
        return 0;
    }
}


sub nullValue() {
    my $token = getToken();
  
    if( $token->{"value"} eq "null" ) {
        return "null";
    } else {
        putToken($token);
        return 0;
    }
}

sub true() {
    my $token = getToken();
    if( $token->{"value"} eq "true" ) {
        return "true";
    } else {
        putToken($token);
        return 0;
    }
}

sub false() {
    my $token = getToken();
    if( $token->{"value"} eq "false" ) {
        return "false";
    } else {
        putToken($token);
        return 0;
    }
}

##################################### Genrator

sub generator {
    my (%ast) = @_;

    my $write = "";
    my @keys = keys %ast;
    foreach my $key (@keys) {
        if($key eq "json") {
            $write .= __json($ast{$key});
        }
    }
    return $write;
}

sub __json {
    my ($ast) = @_;
    my $write = "";
    
    my @keys = keys %{$ast};
    foreach my $key (@keys) {
        if($key eq "hash") {
            $write .= __hash($ast->{$key});
        }
    }

    return $write;
}

sub __hash {
    my ($ast) = @_;

    my $write = "";
    $write .= "{";
    
    my @keys = keys %{$ast};
    foreach my $key (@keys) {
        if($key eq "keyValues") {
            $write .= __keyValues($ast->{$key});
        }
    }

    $write .= "}";
    return $write;
}

sub __keyValues {
    my ($ast) = @_;
    # p $ast;
    my $write = "";

    if(ref($ast) eq "ARRAY") {
        my @array = @$ast;
        foreach my $element (@array) {
            $write .= __keyValue($element);
        }
    }
    chop($write);
    return $write;
}

sub __keyValue {
    my ($ast) = @_;
    my $keyValue = $ast->{"keyValue"};
    
    my $key = __key($keyValue->{key});
    my $value = __value($keyValue->{value});

    $keyValue = "\"" . $key . "\":" . $value . ",";
    return $keyValue;
}

sub __key {
    my ($ast) = @_;
    my $stringValue = $ast->{stringValue};
    return $stringValue;
}

sub __value {
    my ($ast) = @_;
    my $anyValue = __anyValue($ast->{anyValue});
    return $anyValue;
}

sub __anyValue {
    my ($ast) = @_;
    my $write = "";

    my @keys = keys %{$ast};
    foreach my $key (@keys) {
        if($key eq "stringValue") {
            $write .= __stringValue($ast->{$key});
        }

        if($key eq "numericValue") {
            $write .= __numericValue($ast->{$key});
        }
        if($key eq "nullValue") {
            $write .= __nullValue($ast->{$key});
        }
        if($key eq "hash") {
            $write .= __hash($ast->{$key});
        }
        if($key eq "array") {
            $write .= __array($ast->{$key});
        }
        if($key eq "true") {
            $write .= __true($ast->{$key});
        }
        if($key eq "false") {
            $write .= __false($ast->{$key});
        }
    }

    return $write;
}

sub __false {
    my ($ast) = @_;
    return $ast;
}

sub __true {
    my ($ast) = @_;
    return $ast;
}

sub __nullValue {
    my ($ast) = @_;
    return $ast;
}

sub __stringValue {
    my ($ast) = @_;
    return "\"" . $ast . "\"";
}

sub __array {
    my ($ast) = @_;
    my $arrayElements = __arrayElements($ast->{arrayElements});
    return $arrayElements;
}

sub __arrayElements {
    my ($ast) = @_;
    my $write = "[";

    if(ref($ast) eq "ARRAY") {
        my @array = @$ast;
        foreach my $element (@array) {
            $write .= __arrayElement($element);
            $write .= ",";
        }
        chop($write);
    }

    $write .= "]";
    return $write;
}

sub __arrayElement {
    my ($ast) = @_;
    my $anyValue = __anyValue($ast->{arrayElement});
    return $anyValue;
}

sub __numericValue {
    my ($ast) = @_;
    return $ast;
}

my $json = '{
    "false" : false,
    "null" : null,
    "true" : true,
    "foo" : "thirtyfour",
    "buz":  {
        "ase" : [21,2,2,3],
        "string": "another string"
    }
    "1" : 41
  }
';

my %jsonAst = parse($json);
my $formattedJson = generator(%jsonAst);
print $formattedJson;
