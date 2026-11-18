enum ContractKind { deposit, loan }

/// Input kind only drives UI/validation. Stored `fields` values keep the
/// canonical v1 encoding (money as plain digits, dates as dd/mm/yyyy) so the
/// signed draft digest is unchanged by presentation.
enum FieldKind { text, money, percent, date }

class ContractFieldSpec {
  const ContractFieldSpec({
    required this.key,
    required this.label,
    this.hint,
    this.helper,
    this.initialValue = '',
    this.kind = FieldKind.text,
    this.multiline = false,
    this.required = true,
    this.minLength = 0,
    this.maxLength = 300,
  });

  final String key;
  final String label;
  final String? hint;
  final String? helper;
  final String initialValue;
  final FieldKind kind;
  final bool multiline;
  final bool required;
  final int minLength;
  final int maxLength;

  bool get numeric => kind == FieldKind.money || kind == FieldKind.percent;
  bool get isDate => kind == FieldKind.date;
}

class ContractTemplate {
  const ContractTemplate({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.sourceFile,
    required this.iconName,
    required this.fields,
  });

  final String id;
  final ContractKind kind;
  final String title;
  final String subtitle;
  final String sourceFile;
  final String iconName;
  final List<ContractFieldSpec> fields;
}
