enum ContractKind { deposit, loan }

class ContractFieldSpec {
  const ContractFieldSpec({
    required this.key,
    required this.label,
    this.hint,
    this.initialValue = '',
    this.numeric = false,
    this.multiline = false,
    this.required = true,
  });

  final String key;
  final String label;
  final String? hint;
  final String initialValue;
  final bool numeric;
  final bool multiline;
  final bool required;
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
