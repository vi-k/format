#include <clocale>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <functional>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <sys/utsname.h>
#include <utility>
#include <vector>

#if defined(__GLIBC__)
#include <gnu/libc-version.h>
#endif

#define FORMAT_STRINGIFY_INNER(value) #value
#define FORMAT_STRINGIFY(value) FORMAT_STRINGIFY_INNER(value)

namespace {

struct FixtureCase {
  std::string id;
  std::string format;
  std::function<std::string()> render;
};

std::string json_escape(const std::string& value) {
  static constexpr char digits[] = "0123456789abcdef";
  std::string escaped;
  escaped.reserve(value.size());
  for (const unsigned char code_unit : value) {
    switch (code_unit) {
      case '\"':
        escaped += "\\\"";
        break;
      case '\\':
        escaped += "\\\\";
        break;
      case '\b':
        escaped += "\\b";
        break;
      case '\f':
        escaped += "\\f";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        if (code_unit < 0x20) {
          escaped += "\\u00";
          escaped += digits[code_unit >> 4];
          escaped += digits[code_unit & 0x0f];
        } else {
          escaped += static_cast<char>(code_unit);
        }
    }
  }
  return escaped;
}

template <typename... Arguments>
std::string sprintf_string(const char* format, Arguments... arguments) {
  const int size = std::snprintf(nullptr, 0, format, arguments...);
  if (size < 0) {
    throw std::runtime_error("std::snprintf failed while sizing output");
  }
  std::vector<char> buffer(static_cast<std::size_t>(size) + 1);
  const int written = std::sprintf(buffer.data(), format, arguments...);
  if (written != size) {
    throw std::runtime_error("std::sprintf length differs from std::snprintf");
  }
  return std::string(buffer.data(), static_cast<std::size_t>(written));
}

std::string compiler_version() {
#if defined(__clang__)
  return std::string("Clang ") + __clang_version__;
#elif defined(__GNUC__)
  return std::string("GCC ") + __VERSION__;
#else
  return "unknown";
#endif
}

std::string standard_library_version() {
#if defined(_LIBCPP_VERSION)
  return std::string("libc++ ") + FORMAT_STRINGIFY(_LIBCPP_VERSION);
#elif defined(__GLIBCXX__)
  return std::string("libstdc++ ") + FORMAT_STRINGIFY(__GLIBCXX__);
#else
  return "unknown";
#endif
}

std::string c_library_version() {
#if defined(__GLIBC__)
  return std::string("glibc ") + gnu_get_libc_version();
#elif defined(__APPLE__)
  return "libSystem";
#else
  return "unknown";
#endif
}

std::string operating_system() {
  utsname information{};
  if (uname(&information) != 0) return "unknown";
  return std::string(information.sysname) + " " + information.release + " " +
         information.machine;
}

std::vector<FixtureCase> fixture_cases() {
  const double denormal_min = std::numeric_limits<double>::denorm_min();
  const double min_normal = std::numeric_limits<double>::min();
  const double max_finite = std::numeric_limits<double>::max();
  const double infinity = std::numeric_limits<double>::infinity();
  return {
      {"character-ascii", "%c", [] { return sprintf_string("%c", 65); }},
      {"double-a-default", "%a", [] { return sprintf_string("%a", 1.5); }},
      {"double-a-max-finite", "%a", [=] { return sprintf_string("%a", max_finite); }},
      {"double-a-min-normal", "%a", [=] { return sprintf_string("%a", min_normal); }},
      {"double-a-precision", "%.1a", [] { return sprintf_string("%.1a", 1.5625); }},
      {"double-a-subnormal", "%a", [=] { return sprintf_string("%a", denormal_min); }},
      {"double-a-upper", "%A", [] { return sprintf_string("%A", 1.5); }},
      {"double-e-default", "%e", [] { return sprintf_string("%e", 12.5); }},
      {"double-e-precision", "%.3e", [] { return sprintf_string("%.3e", 12.5); }},
      {"double-e-upper", "%.3E", [] { return sprintf_string("%.3E", 12.5); }},
      {"double-f-alternate-zero", "%#.0f", [] { return sprintf_string("%#.0f", 1.0); }},
      {"double-f-default", "%f", [] { return sprintf_string("%f", 12.5); }},
      {"double-f-negative-zero", "%f", [] { return sprintf_string("%f", -0.0); }},
      {"double-f-precision", "%.2f", [] { return sprintf_string("%.2f", 12.5); }},
      {"double-f-round-even-down", "%.0f", [] { return sprintf_string("%.0f", 2.5); }},
      {"double-f-round-even-up", "%.0f", [] { return sprintf_string("%.0f", 3.5); }},
      {"double-g-alternate", "%#.5g", [] { return sprintf_string("%#.5g", 12.0); }},
      {"double-g-fixed", "%.5g", [] { return sprintf_string("%.5g", 12.5); }},
      {"double-g-scientific", "%.3g", [] { return sprintf_string("%.3g", 12345.0); }},
      {"double-infinity-lower", "%f", [=] { return sprintf_string("%f", infinity); }},
      {"double-infinity-upper", "%F", [=] { return sprintf_string("%F", infinity); }},
      {"dynamic-negative-precision", "%.*f", [] { return sprintf_string("%.*f", -1, 1.5); }},
      {"dynamic-negative-width", "%*d", [] { return sprintf_string("%*d", -5, 42); }},
      {"dynamic-width-precision-order", "%*.*f", [] { return sprintf_string("%*.*f", 8, 2, 1.5); }},
      {"integer-alternate-hex", "%#x", [] { return sprintf_string("%#x", 42U); }},
      {"integer-alternate-octal", "%#o", [] { return sprintf_string("%#o", 42U); }},
      {"integer-decimal", "%d", [] { return sprintf_string("%d", -42); }},
      {"integer-i", "%i", [] { return sprintf_string("%i", -42); }},
      {"integer-left-width", "%-6d", [] { return sprintf_string("%-6d", 42); }},
      {"integer-precision-zero", "%.0d", [] { return sprintf_string("%.0d", 0); }},
      {"integer-sign-plus", "%+d", [] { return sprintf_string("%+d", 42); }},
      {"integer-sign-space", "% d", [] { return sprintf_string("% d", 42); }},
      {"integer-unsigned", "%u", [] { return sprintf_string("%u", 42U); }},
      {"integer-upper-hex", "%X", [] { return sprintf_string("%X", 48879U); }},
      {"integer-zero-prefix-width", "%#08x", [] { return sprintf_string("%#08x", 42U); }},
      {"integer-zero-width", "%06d", [] { return sprintf_string("%06d", -42); }},
      {"literal-percent", "rate=100%%", [] { return sprintf_string("rate=100%%"); }},
      {"mixed-consumption", "%s:%*.*f:%#x", [] { return sprintf_string("%s:%*.*f:%#x", "v", 7, 2, 1.5, 42U); }},
      {"string-basic", "%s", [] { return sprintf_string("%s", "hello"); }},
      {"string-precision", "%.3s", [] { return sprintf_string("%.3s", "hello"); }},
      {"string-width", "%8s", [] { return sprintf_string("%8s", "hi"); }},
  };
}

void write_report(std::ostream& output) {
  const char* locale = std::setlocale(LC_ALL, "C");
  if (locale == nullptr) throw std::runtime_error("LC_ALL=C is unavailable");
  const auto cases = fixture_cases();
  output << "{\n"
         << "  \"schema\": 1,\n"
         << "  \"generator\": {\n"
         << "    \"compiler\": \"" << json_escape(compiler_version()) << "\",\n"
         << "    \"standard_library\": \""
         << json_escape(standard_library_version()) << "\",\n"
         << "    \"c_library\": \"" << json_escape(c_library_version()) << "\",\n"
         << "    \"os\": \"" << json_escape(operating_system()) << "\",\n"
         << "    \"locale\": \"" << json_escape(locale) << "\",\n"
         << "    \"standard\": \"C++23\"\n"
         << "  },\n"
         << "  \"cases\": [\n";
  for (std::size_t index = 0; index < cases.size(); ++index) {
    const auto& fixture = cases[index];
    output << "    {\"id\": \"" << json_escape(fixture.id)
           << "\", \"template\": \"" << json_escape(fixture.format)
           << "\", \"output\": \"" << json_escape(fixture.render()) << "\"}";
    output << (index + 1 == cases.size() ? "\n" : ",\n");
  }
  output << "  ]\n}\n";
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      std::cerr << "usage: generate_sprintf_fixtures OUTPUT.json\n";
      return 64;
    }
    std::ofstream output(argv[1]);
    if (!output) {
      std::cerr << "cannot open output file: " << argv[1] << '\n';
      return 73;
    }
    write_report(output);
    return output ? 0 : 74;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
