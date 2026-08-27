const interleaved1 = (rule, delim) => seq(rule, repeat(seq(delim, rule)));

module.exports = grammar({
  name: 'portfile',

  word: $ => $.simple_word,

  externals: $ => [
    $._concat,
    $._immediate,
  ],

  inline: $ => [
    $._terminator,
    $._word,
  ],

  extras: $ => [
    /\s+/,
    /\\\r?\n/,
    $.comment,
  ],

  rules: {

    source_file: $ => repeat(seq(
      optional($._command),
      $._terminator,
    )),

    _terminator: _ => choice('\n', ';'),

    comment: _ => /#[^\n]*/,

    _command: $ => choice(
      // $._builtin,
      $.command,
    ),

    command: $ => choice(
      $._command_exclusion,
      $._command_generic,
    ),

    _command_exclusion: $ => seq(
      field('name', choice(
        'license',
        'platforms',
        'maintainers',
      )),
      field('value', repeat1(choice(
        $.simple_word,
        $.braced_word_simple,
      ))),
    ),

    _command_generic: $ => seq(
      field('name', $._word),
      optional(field('arguments', $.word_list)),
    ),

    word_list: $ => repeat1($._word),

    unpack: _ => '{*}',

    _word: $ => seq(
      optional($.unpack),
      choice(
        $.braced_word,
        $._concat_word,
      ),
    ),

    _word_simple: $ => interleaved1(
      choice(
        $.escaped_character,
        $.command_substitution,
        $.simple_word,
        $.quoted_word,
        $.variable_substitution,
        $.braced_word_simple,
      ),
      $._concat,
    ),

    _concat_word: $ => interleaved1(
      choice(
        $.escaped_character,
        $.command_substitution,
        seq($.simple_word, optional($.array_index)),
        $.quoted_word,
        $.variable_substitution,
      ),
      $._concat,
    ),

    array_index: $ => seq(token.immediate('('), $._word_simple, ')'),

    variable_substitution: $ => seq(
      '$',
      choice(
        seq('{', /[^}]+/, '}'),
        $.simple_word,
      ),
      optional($.array_index),
    ),

    braced_word: $ => seq('{', optional(seq(
      interleaved1($._command, repeat1($._terminator)),
      repeat($._terminator),
    )), '}'),

    braced_word_simple: $ => seq('{', repeat($._word_simple), '}'),

    quoted_word: $ => seq(
      '"',
      repeat(choice(
        $.variable_substitution,
        $._quoted_word_content,
        $.command_substitution,
        $.escaped_character,
      )),
      '"',
    ),

    escaped_character: _ => /\\./,

    _quoted_word_content: _ => token(prec(-1, /[^$\\\[\]"]+/)),

    command_substitution: $ => seq('[', $._command, ']'),

    simple_word: _ => /[^!$\s\\\[\]{}();"]+/,
  },
});
