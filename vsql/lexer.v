// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

// Except for the eof and the keywords, the other tokens use the names described
// in the SQL standard.
enum TokenKind {
	asterisk // <asterisk> ::= *
	colon // <colon> ::= :
	comma // <comma> ::= ,
	concatenation_operator // <concatenation operator> ::= ||
	equals_operator // <equals operator> ::= =
	greater_than_operator // <greater than operator> ::= >
	greater_than_or_equals_operator // <greater than or equals operator> ::= >=
	keyword
	left_paren // <left paren> ::= (
	less_than_operator // <less than operator> ::= <
	less_than_or_equals_operator // <less than or equals operator> ::= <=
	literal_identifier // foo or "foo" (delimited)
	literal_number // 123
	literal_string // 'hello'
	minus_sign // <minus sign> ::= -
	not_equals_operator // <not equals operator> ::= <>
	period // <period> ::= .
	plus_sign // <plus sign> ::= +
	right_paren // <right paren> ::= )
	semicolon // <semicolon> ::= ;
	solidus // <solidus> ::= /
}

struct Token {
pub:
	kind  TokenKind
	value string
}

fn tokenize(sql string) []Token {
	mut tokens := []Token{}
	cs := sql.trim(';').runes()
	mut i := 0

	next: for i < cs.len {
		// space
		if cs[i] == ` ` {
			i++
			continue
		}

		// numbers
		if cs[i] >= `0` && cs[i] <= `9` {
			mut word := ''
			for i < cs.len && cs[i] >= `0` && cs[i] <= `9` {
				word += '${cs[i]}'
				i++
			}
			tokens << Token{.literal_number, word}
			continue
		}

		// strings
		if cs[i] == `'` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `'` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Token{.literal_string, word}
			continue
		}

		// delimited identifiers
		if cs[i] == `"` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `"` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Token{.literal_identifier, '"${word}"'}
			continue
		}

		// operators
		multi := {
			'<>': TokenKind.not_equals_operator
			'>=': TokenKind.greater_than_or_equals_operator
			'<=': TokenKind.less_than_or_equals_operator
			'||': TokenKind.concatenation_operator
		}
		for op, tk in multi {
			if cs[i] == op[0] && cs[i + 1] == op[1] {
				tokens << Token{tk, op}
				i += 2
				continue next
			}
		}

		single := {
			`(`: TokenKind.left_paren
			`)`: TokenKind.right_paren
			`*`: TokenKind.asterisk
			`+`: TokenKind.plus_sign
			`,`: TokenKind.comma
			`-`: TokenKind.minus_sign
			`/`: TokenKind.solidus
			`;`: TokenKind.semicolon
			`<`: TokenKind.less_than_operator
			`=`: TokenKind.equals_operator
			`>`: TokenKind.greater_than_operator
			`.`: TokenKind.period
			`:`: TokenKind.colon
		}
		for op, tk in single {
			if cs[i] == op {
				tokens << Token{tk, op.str()}
				i++
				continue next
			}
		}

		// keyword or regular identifier
		mut word := ''
		mut is_not_first := false
		for i < cs.len && is_identifier_char(cs[i], is_not_first) {
			word += '${cs[i]}'
			i++
			is_not_first = true
		}

		if word == '' {
			i++
			continue
		}

		tokens << if is_key_word(word) {
			Token{TokenKind.keyword, word.to_upper()}
		} else {
			Token{TokenKind.literal_identifier, word}
		}
	}

	return tokens
}

[inline]
fn is_identifier_char(c u8, is_not_first bool) bool {
	yes := (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`

	if is_not_first {
		return yes || (c >= `0` && c <= `9`)
	}

	return yes
}
