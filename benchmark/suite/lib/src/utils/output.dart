import 'package:ansi_escape_codes/ansi_escape_codes.dart';

const Color defaultFg = Color256(Colors.gray12);
// const Color defaultBg = Color256(Colors.gray4);
const _h1 = fg256Rgb520;
const _h2 = fg256Rgb134;
const _accent = fg256Gray23;
const _faintAccent = fg256Gray16;
const _error = fg256Rgb311;
const _accentError = fg256Rgb500;
const _warning = fg256Rgb331;
const _accentWarning = fg256Rgb550;
const _ok = fg256Rgb131;
const _accentOk = fg256Rgb050;

String h1(String text) => '$_h1$text$reset';

String h2(String text) => '$_h2$text$reset';

String accent(String text) => '$_accent$text$reset';

String faintAccent(String text) => '$_faintAccent$text$reset';

String error(String text) => '$_error$text$reset';

String accentError(String text) => '$_accentError$text$reset';

String warning(String text) => '$_warning$text$reset';

String accentWarning(String text) => '$_accentWarning$text$reset';

String ok(String text) => '$_ok$text$reset';

String accentOk(String text) => '$_accentOk$text$reset';
