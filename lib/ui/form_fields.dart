import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatting/vnd_words.dart';
import '../features/payment/vietqr_banks.dart';
import 'app_theme.dart';

/// VND amount input: groups thousands while typing and shows the amount in
/// words underneath, as Vietnamese contracts state amounts in both forms.
/// The controller holds the grouped text; read [VndInputFormatter.digitsOf]
/// to obtain the canonical value.
class MoneyFormField extends StatelessWidget {
  const MoneyFormField({
    required this.controller,
    required this.label,
    this.helper,
    this.validator,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final amount = int.tryParse(VndInputFormatter.digitsOf(value.text));
          final help = [
            if (amount != null && amount > 0) 'Bằng chữ: ${vndInWords(amount)}',
            ?helper,
          ];
          return TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: textInputAction,
            inputFormatters: const [VndInputFormatter()],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: label,
              suffixText: 'đ',
              helperText: help.isEmpty ? null : help.join('\n'),
              helperMaxLines: 4,
            ),
            validator: validator,
          );
        },
      );
}

/// Date input with a Vietnamese calendar picker and bounded range. Values use
/// the canonical `dd/mm/yyyy` text already stored in v1 drafts.
class DateFormField extends StatelessWidget {
  const DateFormField({
    required this.controller,
    required this.label,
    required this.firstDate,
    required this.lastDate,
    this.helper,
    this.validator,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final DateTime firstDate;
  final DateTime lastDate;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  static String format(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  static DateTime? parse(String text) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text.trim());
    if (m == null) return null;
    final d = DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
    return d.day == int.parse(m.group(1)!) && d.month == int.parse(m.group(2)!)
        ? d
        : null;
  }

  Future<void> _pick(BuildContext context) async {
    final current = parse(controller.text);
    final initial = current == null || current.isBefore(firstDate)
        ? firstDate
        : current.isAfter(lastDate)
        ? lastDate
        : current;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: label,
      fieldLabelText: 'Ngày (dd/mm/yyyy)',
      locale: const Locale('vi', 'VN'),
    );
    if (selected != null) controller.text = format(selected);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    readOnly: true,
    onTap: () => _pick(context),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'dd/mm/yyyy',
      helperText: helper,
      suffixIcon: IconButton(
        tooltip: 'Chọn ngày',
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: enabled ? () => _pick(context) : null,
      ),
    ),
    validator: validator,
  );
}

/// Bank chooser bound to a controller that stores the 6-digit BIN.
class BankPickerFormField extends StatelessWidget {
  const BankPickerFormField({
    required this.controller,
    this.label = 'Ngân hàng nhận tiền',
    this.validator,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final VoidCallback? onChanged;

  Future<void> _choose(BuildContext context) async {
    final bin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _BankSheet(current: controller.text),
    );
    if (bin != null && bin != controller.text) {
      controller.text = bin;
      onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final bank = bankByBin(value.text);
          return FormField<String>(
            key: ValueKey(value.text),
            initialValue: value.text,
            validator: (_) => validator?.call(controller.text),
            builder: (state) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? () => _choose(context) : null,
              child: InputDecorator(
                isEmpty: value.text.isEmpty,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'Chọn ngân hàng',
                  enabled: enabled,
                  errorText: state.errorText,
                  helperText: value.text.isEmpty
                      ? null
                      : 'Mã BIN: ${value.text}',
                  suffixIcon: const Icon(Icons.expand_more),
                ),
                child: value.text.isEmpty
                    ? null
                    : Text(
                        bank?.shortName ?? 'Ngân hàng khác',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          );
        },
      );
}

class _BankSheet extends StatefulWidget {
  const _BankSheet({required this.current});
  final String current;

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  final query = TextEditingController();
  final manual = TextEditingController();

  @override
  void dispose() {
    query.dispose();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = vietQrBanks.where((b) => b.matches(query.text)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: query,
                autofocus: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm theo tên hoặc mã BIN',
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final bank in results)
                    ListTile(
                      title: Text(bank.shortName),
                      subtitle: Text('${bank.name} · ${bank.bin}'),
                      trailing: bank.bin == widget.current
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, bank.bin),
                    ),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Không tìm thấy ngân hàng phù hợp.'),
                    ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ngân hàng khác',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: manual,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Mã BIN 6 chữ số',
                            helperText: 'Xem mã BIN trong app ngân hàng của người nhận.',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: manual.text.length == 6
                              ? () => Navigator.pop(context, manual.text)
                              : null,
                          child: const Text('Dùng mã BIN này'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
