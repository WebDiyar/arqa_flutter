import 'package:driver_diary/core/time/zoned_date_time.dart';
import 'package:driver_diary/features/trips/domain/entities/trip.dart';

/// DTO: форма JSON на проводе. Время — ISO-строки со смещением.
class TripModel {
  const TripModel({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
    id: json['id'] as String,
    start: json['start'] as String,
    end: json['end'] as String,
    amount: json['amount'] as int,
    payment: json['payment'] as String,
    commission: json['commission'] as int,
  );

  factory TripModel.fromEntity(Trip t) => TripModel(
    id: t.id,
    start: t.start.toIso(),
    end: t.end.toIso(),
    amount: t.amount,
    payment: t.payment.name,
    commission: t.commission,
  );

  final String id;
  final String start;
  final String end;
  final int amount;
  final String payment;
  final int commission;

  Map<String, Object> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'amount': amount,
    'payment': payment,
    'commission': commission,
  };

  Trip toEntity() => Trip(
    id: id,
    start: ZonedDateTime.parse(start),
    end: ZonedDateTime.parse(end),
    amount: amount,
    payment: PaymentMethod.values.byName(payment),
    commission: commission,
  );
}
