class SpecField {
  final int fieldId;
  final int sectionId;
  final String name;
  final String inputType;
  final int sortOrder;
  final List<String> options; // 🔴 NEW

  SpecField({
    required this.fieldId,
    required this.sectionId,
    required this.name,
    required this.inputType,
    required this.sortOrder,
    required this.options,
  });

  factory SpecField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['Options'] ?? json['options'];
    final List<String> opts = rawOptions == null
        ? <String>[]
        : rawOptions
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return SpecField(
      fieldId: json['FieldID'] ?? json['fieldId'],
      sectionId: json['SectionID'] ?? json['sectionId'],
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      inputType: (json['InputType'] ?? json['inputType'] ?? 'text').toString(),
      sortOrder: json['SortOrder'] ?? json['sortOrder'] ?? 0,
      options: opts,
    );
  }
}

class SpecSection {
  final int sectionId;
  final String name;
  final int sortOrder;
  final List<SpecField> fields;

  SpecSection({
    required this.sectionId,
    required this.name,
    required this.sortOrder,
    required this.fields,
  });

  factory SpecSection.fromJson(Map<String, dynamic> json) {
    final fieldsJson = (json['fields'] ?? []) as List<dynamic>;
    return SpecSection(
      sectionId: json['SectionID'] ?? json['sectionId'],
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      sortOrder: json['SortOrder'] ?? json['sortOrder'] ?? 0,
      fields: fieldsJson
          .map((e) => SpecField.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
