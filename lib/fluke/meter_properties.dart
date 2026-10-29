import 'package:equatable/equatable.dart';

/// Texts the owner stored in the meter (company, operator, site, contact),
/// read with the undocumented `qmpq` command and written with `mpq` (see
/// `dmm_util`). `null` where the meter has no text or does not know the
/// property.
class MeterProperties extends Equatable {
  const MeterProperties({this.company, this.operator, this.site, this.contact});

  /// Property names as the meter knows them, in display order.
  static const names = ['company', 'operator', 'site', 'contact'];

  /// Builds the properties from texts by [names]; blank texts count as
  /// missing.
  factory MeterProperties.fromMap(Map<String, String?> values) {
    String? value(String name) {
      final text = values[name]?.trim();
      return text == null || text.isEmpty ? null : text;
    }

    return MeterProperties(
      company: value('company'),
      operator: value('operator'),
      site: value('site'),
      contact: value('contact'),
    );
  }

  final String? company;
  final String? operator;
  final String? site;
  final String? contact;

  /// The text of the property [name] (one of [names]).
  String? operator [](String name) => switch (name) {
    'company' => company,
    'operator' => operator,
    'site' => site,
    'contact' => contact,
    _ => throw ArgumentError.value(name, 'name'),
  };

  /// Characters the meter takes: printable ASCII without `'`, which ends
  /// the quoted text of the `mpq` command.
  static final allowedCharacters = RegExp(r"[ -&(-~]");

  bool get isEmpty =>
      company == null && operator == null && site == null && contact == null;

  @override
  List<Object?> get props => [company, operator, site, contact];
}
