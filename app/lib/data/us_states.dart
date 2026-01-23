/// Complete list of US states and territories.
class USStates {
  USStates._();

  /// All 50 US states plus DC
  static const List<USState> all = [
    USState('AL', 'Alabama'),
    USState('AK', 'Alaska'),
    USState('AZ', 'Arizona'),
    USState('AR', 'Arkansas'),
    USState('CA', 'California'),
    USState('CO', 'Colorado'),
    USState('CT', 'Connecticut'),
    USState('DE', 'Delaware'),
    USState('DC', 'District of Columbia'),
    USState('FL', 'Florida'),
    USState('GA', 'Georgia'),
    USState('HI', 'Hawaii'),
    USState('ID', 'Idaho'),
    USState('IL', 'Illinois'),
    USState('IN', 'Indiana'),
    USState('IA', 'Iowa'),
    USState('KS', 'Kansas'),
    USState('KY', 'Kentucky'),
    USState('LA', 'Louisiana'),
    USState('ME', 'Maine'),
    USState('MD', 'Maryland'),
    USState('MA', 'Massachusetts'),
    USState('MI', 'Michigan'),
    USState('MN', 'Minnesota'),
    USState('MS', 'Mississippi'),
    USState('MO', 'Missouri'),
    USState('MT', 'Montana'),
    USState('NE', 'Nebraska'),
    USState('NV', 'Nevada'),
    USState('NH', 'New Hampshire'),
    USState('NJ', 'New Jersey'),
    USState('NM', 'New Mexico'),
    USState('NY', 'New York'),
    USState('NC', 'North Carolina'),
    USState('ND', 'North Dakota'),
    USState('OH', 'Ohio'),
    USState('OK', 'Oklahoma'),
    USState('OR', 'Oregon'),
    USState('PA', 'Pennsylvania'),
    USState('RI', 'Rhode Island'),
    USState('SC', 'South Carolina'),
    USState('SD', 'South Dakota'),
    USState('TN', 'Tennessee'),
    USState('TX', 'Texas'),
    USState('UT', 'Utah'),
    USState('VT', 'Vermont'),
    USState('VA', 'Virginia'),
    USState('WA', 'Washington'),
    USState('WV', 'West Virginia'),
    USState('WI', 'Wisconsin'),
    USState('WY', 'Wyoming'),
  ];

  /// Get state by abbreviation
  static USState? byCode(String code) {
    try {
      return all.firstWhere((s) => s.code == code.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  /// Get state by name
  static USState? byName(String name) {
    try {
      return all.firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Search states by query (matches code or name)
  static List<USState> search(String query) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    return all.where((s) {
      return s.code.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q);
    }).toList();
  }
}

/// US State model
class USState {
  const USState(this.code, this.name);

  /// State abbreviation (e.g., 'TX')
  final String code;

  /// Full state name (e.g., 'Texas')
  final String name;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is USState && code == other.code;

  @override
  int get hashCode => code.hashCode;
}
