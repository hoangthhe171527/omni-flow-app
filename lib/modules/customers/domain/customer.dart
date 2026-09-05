import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

enum CustomerStatus {
  fresh,
  active,
  vip,
  inactive;

  /// The API's `customer_status` vocabulary is coarser than what a rep thinks
  /// in, so it is mapped rather than shown raw.
  static CustomerStatus parse(String? raw) => switch (raw) {
    'ACTIVE' => CustomerStatus.active,
    'WARM' => CustomerStatus.vip,
    'AT_RISK' || 'LOST' || 'INACTIVE' => CustomerStatus.inactive,
    _ => CustomerStatus.fresh,
  };

  String get label => switch (this) {
    CustomerStatus.fresh => 'Mới',
    CustomerStatus.active => 'Đang hoạt động',
    CustomerStatus.vip => 'VIP',
    CustomerStatus.inactive => 'Ngưng hoạt động',
  };
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.code = '',
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.taxCode = '',
    this.source = Channel.web,
    this.tags = const [],
    this.lifetimeValue = 0,
    this.status = CustomerStatus.fresh,
    this.customerType = 'DIRECT_CLIENT',
    this.ownerId,
    this.ownerName,
    this.note,
    this.lastInteractionAt,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final metadata = json.child('metadata');
    final name =
        json.str('display_name') ??
        json.str('legal_name') ??
        json.str('primary_contact_name') ??
        'Khách chưa đặt tên';

    return Customer(
      id: json.strOr('id', ''),
      name: name,
      code: json.strOr('customer_code', ''),
      contactName: json.strOr('primary_contact_name', ''),
      phone: json.strOr('primary_contact_phone', ''),
      email: json.strOr('primary_contact_email', ''),
      address: json.strOr('address', ''),
      taxCode: json.strOr('tax_code', ''),
      source: Channel.parse(metadata.str('channel') ?? metadata.str('source')),
      tags: metadata.strList('tags'),
      lifetimeValue: json.dbl('lifetime_booking_value') ?? 0,
      status: CustomerStatus.parse(json.str('customer_status')),
      customerType: json.strOr('customer_type', 'DIRECT_CLIENT'),
      ownerId: json.str('assigned_sales_rep_id'),
      ownerName: json.str('assigned_sales_rep_name'),
      note: metadata.str('note'),
      lastInteractionAt:
          DateUtilsX.parse(json['last_booking_date']) ??
          DateUtilsX.parse(json['updated_at']),
      createdAt: DateUtilsX.parse(json['created_at']),
    );
  }

  final String id;
  final String name;
  final String code;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String taxCode;
  final Channel source;
  final List<String> tags;
  final double lifetimeValue;
  final CustomerStatus status;
  final String customerType;
  final String? ownerId;
  final String? ownerName;
  final String? note;
  final DateTime? lastInteractionAt;
  final DateTime? createdAt;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasEmail => email.trim().isNotEmpty;

  /// The city is the last comma-separated part of the address — good enough for
  /// a list row, and the API has no separate field.
  String get city {
    if (address.isEmpty) return '';
    return address.split(',').last.trim();
  }

  Map<String, dynamic> toPayload() => {
    'legal_name': name,
    'display_name': name,
    'customer_type': customerType,
    'primary_contact_name': contactName.isEmpty ? name : contactName,
    'primary_contact_phone': phone,
    'primary_contact_email': email,
    'address': address,
    'tax_code': taxCode,
    'customer_status': switch (status) {
      CustomerStatus.vip => 'WARM',
      CustomerStatus.inactive => 'INACTIVE',
      _ => 'ACTIVE',
    },
    if (ownerId != null) 'assigned_sales_rep_id': ownerId,
    'metadata': {
      'channel': source.slug,
      'tags': tags,
      if (note != null) 'note': note,
    },
  };

  Customer copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
    Channel? source,
    List<String>? tags,
    CustomerStatus? status,
    String? ownerId,
    String? note,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      code: code,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxCode: taxCode ?? this.taxCode,
      source: source ?? this.source,
      tags: tags ?? this.tags,
      lifetimeValue: lifetimeValue,
      status: status ?? this.status,
      customerType: customerType,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName,
      note: note ?? this.note,
      lastInteractionAt: lastInteractionAt,
      createdAt: createdAt,
    );
  }
}
