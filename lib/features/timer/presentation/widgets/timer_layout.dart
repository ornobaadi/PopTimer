/// Shared proportions so the pager and the session view put the numeral in
/// exactly the same place (`design.md` section 4).
class TimerLayout {
  /// Numeral height as a share of screen height.
  static const double numeralFraction = 0.60;

  /// Page height as a share of screen height. Smaller than the numeral plus
  /// its margins, so neighbours peek ~9% at the top and bottom edges.
  static const double pageFraction = 0.68;

  /// Gap between the numeral's bottom and the countdown line.
  static const double lineGap = 24;

}
