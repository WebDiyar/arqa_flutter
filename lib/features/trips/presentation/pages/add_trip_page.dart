import 'package:driver_diary/core/error/app_exception.dart';
import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/core/utils/format.dart';
import 'package:driver_diary/core/utils/id.dart';
import 'package:driver_diary/core/widgets/content_width.dart';
import 'package:driver_diary/features/trips/di.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';
import 'package:driver_diary/features/trips/domain/repositories/trips_repository.dart';
import 'package:driver_diary/features/trips/presentation/providers/day_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AddTripPage extends ConsumerStatefulWidget {
  const AddTripPage({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends ConsumerState<AddTripPage> {
  /// Один id на всё время жизни формы — ключ идемпотентности. Ретрай после
  /// таймаута или двойной тап шлют тот же id, и сервер не создаёт дубль.
  final _id = newId();
  final _amount = TextEditingController();
  final _commission = TextEditingController();
  TimeOfDay? _start;
  TimeOfDay? _end;
  var _payment = PaymentMethod.card;
  var _errors = <String, String>{};
  var _submitting = false;

  /// Пока водитель не трогал комиссию, она считается от суммы сама.
  var _commissionEdited = false;

  @override
  void dispose() {
    _amount.dispose();
    _commission.dispose();
    super.dispose();
  }

  /// Окончание раньше начала по часам — поездка через полночь.
  bool get _crossesMidnight =>
      _start != null && _end != null && _minutes(_end!) < _minutes(_start!);

  Trip _buildTrip() {
    final d = widget.day;
    DateTime at(TimeOfDay t, {int plusDays = 0}) =>
        DateTime(d.year, d.month, d.day + plusDays, t.hour, t.minute);

    return Trip(
      id: _id,
      start: ZonedDateTime.fromLocal(at(_start!)),
      end: ZonedDateTime.fromLocal(
        at(_end!, plusDays: _crossesMidnight ? 1 : 0),
      ),
      amount: int.parse(_amount.text),
      payment: _payment,
      commission: int.parse(_commission.text),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final errors = {
      if (_start == null) 'start': 'Укажите время начала',
      if (_end == null) 'end': 'Укажите время окончания',
      if (int.tryParse(_amount.text) == null) 'amount': 'Укажите сумму',
      if (int.tryParse(_commission.text) == null)
        'commission': 'Укажите комиссию',
    };
    final trip = errors.isEmpty ? _buildTrip() : null;
    if (trip != null) errors.addAll(trip.validate());
    setState(() => _errors = errors);
    if (trip == null || errors.isNotEmpty) return;

    setState(() => _submitting = true);
    // Берём до await: если пользователь уйдёт с экрана во время запроса,
    // `ref` станет недоступен, а список дня обновить всё равно нужно.
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final outcome = await ref.read(addTripProvider)(trip);
      container.invalidate(dayReportProvider(widget.day));
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (outcome) {
            AddOutcome.sent => 'Поездка добавлена',
            AddOutcome.queued =>
              'Нет связи. Поездка сохранена на устройстве '
                  'и отправится автоматически',
          }),
        ),
      );
      if (mounted) context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _errors = Map.of(e.fields));
      if (e.fields.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ?? _start ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _errors
        ..remove('start')
        ..remove('end');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая поездка')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              formatDay(widget.day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Начало',
                    value: _start,
                    error: _errors['start'],
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'Окончание',
                    value: _end,
                    error: _errors['end'],
                    helper: _crossesMidnight ? 'на следующий день' : null,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MoneyField(
              label: 'Сумма',
              controller: _amount,
              error: _errors['amount'],
              onChanged: () => setState(() {
                _errors.remove('amount');
                if (_commissionEdited) return;
                final amount = int.tryParse(_amount.text);
                _commission.text = amount == null
                    ? ''
                    : '${(amount * defaultCommissionRate).round()}';
              }),
            ),
            const SizedBox(height: 16),
            _MoneyField(
              label: 'Комиссия',
              controller: _commission,
              error: _errors['commission'],
              helper: _commissionEdited || _commission.text.isEmpty
                  ? null
                  : '${(defaultCommissionRate * 100).round()}% от суммы — '
                        'можно изменить',
              onChanged: () => setState(() {
                _errors.remove('commission');
                _commissionEdited = true;
              }),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PaymentMethod>(
              segments: const [
                ButtonSegment(
                  value: PaymentMethod.card,
                  label: Text('Карта'),
                  icon: Icon(Icons.credit_card),
                ),
                ButtonSegment(
                  value: PaymentMethod.cash,
                  label: Text('Наличные'),
                  icon: Icon(Icons.payments_outlined),
                ),
              ],
              selected: {_payment},
              onSelectionChanged: (s) => setState(() => _payment = s.first),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

// ponytail: ставка из данных примера (360/2400 = 225/1500 = 15%). У каждого
// парка своя — тогда отдавать её с сервера вместе с профилем водителя.
const defaultCommissionRate = 0.15;

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
    this.helper,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          errorMaxLines: 2,
          helperText: helper,
          suffixIcon: const Icon(Icons.schedule),
        ),
        child: Text(value?.format(context) ?? ''),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.error,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9), // без переполнения int на вебе
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: currencySymbol,
        errorText: error,
        helperText: helper,
      ),
    );
  }
}
