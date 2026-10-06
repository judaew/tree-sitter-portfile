/**
 * Tree-sitter grammar for MacPorts Portfile
 *
 * A Portfile is a Tcl script, so this is a simplified Tcl grammar
 * plus edicatd nodes for commands that matter to MacPorts
*/

const interleaved1 = (rule, delim) => seq(rule, repeat(seq(delim, rule)));

// Phases that accept pre-/post- hooks (e.g. post-destroot)
const phases = [
  'fetch', 'checksum', 'extract', 'patch', 'configure', 'build', 'test',
  'destroot', 'archive', 'install', 'activate', 'deactivate',
];

const phase_keywords = phases.flatMap(p => [p, `pre-${p}`, `post-${p}`]);

module.exports = grammar({
  name: 'portfile',

  word: $ => $.simple_word,

  externals: $ => [
    $._concat,
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

    _command: $ => $.command,

    command: $ => choice(
      // MacPorts-specific commands
      $.portsystem_command,
      $.portgroup_command,
      $.variant_command,
      $.platform_command,
      $.subport_command,
      $.phase_hook,
      // Tcl control structures
      $.if_command,
      $.foreach_command,
      $.while_command,
      $.for_command,
      $.switch_command,
      $.proc_command,
      // Everything else
      $._command_exclusion,
      $._command_generic,
    ),

    // PortSystem 1.0
    portsystem_command: $ => prec(1, seq(
      field('name', 'PortSystem'),
      field('version', $._word),
    )),

    // PortGroup python 1.0
    portgroup_command: $ => prec(1, seq(
      field('name', 'PortGroup'),
      field('group', $._word),
      field('version', $._word),
    )),

    // variant gcc11 description "..." requires some conflicts other { ... }
    variant_command: $ => prec.right(seq(
      field('name', 'variant'),
      field('variant', $._word),
      repeat(choice(
        seq('requires', field('requires', repeat1($._variant_word))),
        seq('conflicts', field('conflicts', repeat1($._variant_word))),
        seq('description', field('description', $._word)),
      )),
      field('body', $.braced_word),
    )),

    // Plain words only
    // a "{" here must start the variant body
    _variant_word: $ => choice(
      $.simple_word,
      $.variable_substitution,
      $.quoted_word,
    ),

    // platform darwin { ... }
    // platform darwin 23 { ... }
    platform_command: $ => prec(1, seq(
      field('name', 'platform'),
      field('platform', $._word),
      optional(field('arch', $._word)),
      field('body', $.braced_word),
    )),

    // subport py39-numpy { ... }
    subport_command: $ => prec(1, seq(
      field('name', 'subport'),
      field('subport', $._word),
      field('body', $.braced_word),
    )),

    // post-destroot { ... }, build { ... }
    phase_name: _ => choice(...phase_keywords),
    phase_hook: $ => prec(1, seq(
      field('name', $.phase_name),
      field('body', $.braced_word),
    )),

    // if {cond} { ... } elseif {cond} { ... } else { ... }
    if_command: $ => prec.right(seq(
      field('name', 'if'),
      field('condition', $._word),
      field('consequence', $._word),
      repeat($.elseif_clause),
      optional($.else_clause),
    )),

    elseif_clause: $ => seq(
      'elseif',
      field('condition', $._word),
      field('consequence', $._word),
    ),

    else_clause: $ => seq(
      'else',
      field('alternative', $._word),
    ),

    // foreach x {a b c} { ... }
    // foreach {k v} $pairs { ... }
    // foreach x $l1 y $l2 { ... }
    foreach_command: $ => prec.right(seq(
      field('name', 'foreach'),
      repeat1(seq(
        field('variables', $._word),
        field('list', $._word),
      )),
      field('body', $._word),
    )),

    // while {cond} { ... }
    while_command: $ => prec(1, seq(
      field('name', 'while'),
      field('condition', $._word),
      field('body', $._word),
    )),

    // for {set i 0} {$i < 10} {incr i} { ... }
    for_command: $ => prec(1, seq(
      field('name', 'for'),
      field('start', $._word),
      field('condition', $._word),
      field('next', $._word),
      field('body', $._word),
    )),

    // switch $x { ... }
    // switch -glob $x { a { ... } b { ... } }
    // switch -- $x a { ... } b { ... }
    switch_command: $ => prec.right(seq(
      field('name', 'switch'),
      repeat($._switch_option),
      field('subject', $._word),
      choice(
        field('body', $.braced_word),
        repeat1($.switch_pair),
      ),
    )),

    _switch_option: _ => choice(
      '--', '-exact', '-glob', '-regexp', '-nocase', '-matchvar', '-indexvar',
    ),

    switch_pair: $ => seq(
      field('pattern', $._word),
      field('body', $.braced_word),
    ),

    // proc name {args} { ... }
    proc_command: $ => prec(1, seq(
      field('name', 'proc'),
      field('proc_name', $._word),
      field('parameters', $._word),
      field('body', $.braced_word),
    )),

    // Options whose value is a plain word list
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

    _command_generic: $ => prec(-1, seq(
      field('name', $._word),
      optional(field('arguments', $.word_list)),
    )),

    word_list: $ => repeat1($._word),

    unpack: _ => '{*}',

    _word: $ => seq(
      optional($.unpack),
      choice(
        $.braced_word,
        $._concat_word,
      ),
    ),

    // Word parts joined without whitespace ($a$b)
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

    // Braces quote literally;
    // the content is a command script
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
