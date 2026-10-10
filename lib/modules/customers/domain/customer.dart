import 'package:flutter/foundation.dart';

import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import 'customer_field.dart';

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
    this.legalName = '',
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.taxCode = '',
    this.source = Channel.web,
    this.tags = const [],
    this.lifetimeValue,
    this.status = CustomerStatus.fresh,
    this.customerType = 'DIRECT_CLIENT',
    this.ownerId,
    this.ownerName,
    this.note,
    this.lastInteractionAt,
    this.createdAt,
    this.rawStatus,
    this.metadata = const {},
    this.origin,
  });

  /// Empty draft for the create form — filled by [applyForm].
  factory Customer.blank() =>
      const Customer(id: '', name: '', source: Channel.zalo);

  factory Customer.fromJson(Map<String, dynamic> json) {
    final metadata = json.child('metadata');
    final name =
        json.str('display_name') ??
        json.str('legal_name') ??
        json.str('primary_contact_name') ??
        'Khách chưa đặt tên';

    final loaded = Customer(
      id: json.strOr('id', ''),
      name: name,
      code: json.strOr('customer_code', ''),
      legalName: json.strOr('legal_name', ''),
      contactName: json.strOr('primary_contact_name', ''),
      phone: json.strOr('primary_contact_phone', ''),
      email: json.strOr('primary_contact_email', ''),
      address: json.strOr('address', ''),
      taxCode: json.strOr('tax_code', ''),
      // `source` is the web's key; `channel` is what older app builds wrote.
      source: Channel.parse(metadata.str('source') ?? metadata.str('channel')),
      tags: metadata.strList('tags'),
      // `orders_total` = tổng đơn không huỷ, API trả ở `/customers` và
      // `/customers/{id}` từ Đợt 7 (A1). API cũ chưa có khoá này → null ("—"):
      // `lifetime_booking_value` là số nhập cũ không ai cập nhật, hiện nó là
      // hiện số sai (GD-I11, APP-I4).
      lifetimeValue: json.dbl('orders_total'),
      status: CustomerStatus.parse(json.str('customer_status')),
      rawStatus: json.str('customer_status'),
      customerType: json.strOr('customer_type', 'DIRECT_CLIENT'),
      ownerId: json.str('assigned_sales_rep_id'),
      ownerName: json.str('assigned_sales_rep_name'),
      note: _noteOf(metadata),
      // Chỉ `last_interaction_at` (API A1). Sửa thông tin khách không phải là
      // liên hệ, nên không rơi về `updated_at`/`last_booking_date` (Q8a).
      lastInteractionAt: DateUtilsX.parse(json['last_interaction_at']),
      createdAt: DateUtilsX.parse(json['created_at']),
      metadata: metadata,
    );
    return loaded._from(loaded);
  }

  final String id;

  /// What the app shows and edits: `display_name`, else `legal_name`.
  final String name;
  final String code;

  /// `legal_name` as loaded (company name on invoices). The app has no field
  /// for it and never overwrites it — see [toPayload].
  final String legalName;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String taxCode;
  final Channel source;
  final List<String> tags;
  final double? lifetimeValue;
  final CustomerStatus status;
  final String customerType;
  final String? ownerId;
  final String? ownerName;
  final String? note;
  final DateTime? lastInteractionAt;
  final DateTime? createdAt;

  /// `customer_status` exactly as the API sent it. [status] is coarser —
  /// `AT_RISK`, `LOST` and `INACTIVE` all show as "Ngưng hoạt động" — so
  /// writing `status` back would turn an at-risk customer into `INACTIVE`.
  final String? rawStatus;

  /// The metadata bag as loaded. Read-only: never echoed back.
  final Map<String, dynamic> metadata;

  /// The record as loaded from the API; null for a new draft. [toPayload]
  /// sends only what differs from it.
  final Customer? origin;

  /// What goes back to the API: the original code while the user keeps the
  /// same group, the group's own code once they pick another one.
  String get statusCode {
    final raw = rawStatus;
    if (raw != null && raw.isNotEmpty && CustomerStatus.parse(raw) == status) {
      return raw;
    }
    return switch (status) {
      CustomerStatus.vip => 'WARM',
      CustomerStatus.inactive => 'INACTIVE',
      _ => 'ACTIVE',
    };
  }

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasEmail => email.trim().isNotEmpty;

  /// The web's "Cá nhân / Doanh nghiệp" (`metadata.party_type`); a record
  /// without it is an individual, as on the web.
  bool get isBusiness => metadata['party_type'] == 'business';

  /// The city is the last comma-separated part of the address — good enough for
  /// a list row, and the API has no separate field.
  String get city {
    if (address.isEmpty) return '';
    return address.split(',').last.trim();
  }

  /// `POST` (new draft) or `PUT` body.
  ///
  /// `PUT /customers/{id}` (`UpdateCustomer`) keeps every field it is not sent
  /// and merges `metadata` SHALLOWLY (`MetadataPatch::merge`: a key sent
  /// overwrites, a key sent as null is removed, a key not sent is kept). So an
  /// edit sends only what changed since loading — echoing the whole record
  /// would write back the copy the app holds over whatever the web changed
  /// meanwhile (legal name, source, notes, keys this app doesn't know).
  ///
  /// Names: the form edits the DISPLAY name only. `legal_name` is sent when
  /// creating (required there), or for an individual whose legal name is
  /// still blank — never over a company's registered name.
  Map<String, dynamic> toPayload() {
    final fields = _fields();
    final meta = _ownMetadata();
    final origin = this.origin;

    if (origin == null || id.isEmpty) {
      // Bản nháp tạo mới chưa chọn người phụ trách: null ở đây là "chưa chọn",
      // không phải "bỏ gán" — không gửi khoá.
      if (ownerId == null) fields.remove('assigned_sales_rep_id');
      return {
        'legal_name': name,
        ...fields,
        'metadata': {
          for (final entry in meta.entries)
            if (entry.value != null) entry.key: entry.value,
        },
      };
    }

    final loadedFields = origin._fields();
    final loadedMeta = origin._ownMetadata();
    final changedMeta = <String, dynamic>{
      for (final entry in meta.entries)
        if (!_same(entry.value, loadedMeta[entry.key])) entry.key: entry.value,
    };
    // A source picked in the app supersedes the `channel` older builds wrote;
    // the API's source filter matches either key, so the stale one goes.
    if (changedMeta.containsKey('source') &&
        origin.metadata.containsKey('channel')) {
      changedMeta['channel'] = null;
    }
    // Bỏ gán: tên người phụ trách còn rơi về `metadata.owner_name` (web đọc cả
    // `sales_account`) — không xoá thì nhãn cũ hiện lại sau khi lưu (như web).
    // Khách chỉ có tên (metadata.owner_name, không có id) cũng là "có người":
    // bản nháp đã xoá cả id lẫn tên mới là bỏ gán (sửa phụ trường khác của
    // khách đó giữ nguyên tên, không bị coi là bỏ gán).
    final unassign =
        ownerId == null &&
        ownerName == null &&
        (origin.ownerId != null || origin.ownerName != null);
    if (unassign) {
      for (final legacy in const ['owner_name', 'sales_account']) {
        final old = origin.metadata[legacy];
        if (old != null && '$old'.trim().isNotEmpty) changedMeta[legacy] = null;
      }
    }

    return {
      if (origin.legalName.isEmpty && !isBusiness && name != origin.name)
        'legal_name': name,
      for (final entry in fields.entries)
        if (!_same(entry.value, loadedFields[entry.key]))
          entry.key: entry.value,
      if (unassign && origin.ownerId == null) 'assigned_sales_rep_id': null,
      if (changedMeta.isNotEmpty) 'metadata': changedMeta,
    };
  }

  Map<String, dynamic> _fields() => {
    'display_name': name,
    'customer_type': customerType,
    'primary_contact_name': contactName.isEmpty ? name : contactName,
    'primary_contact_phone': phone,
    'primary_contact_email': email,
    'address': address,
    'tax_code': taxCode,
    'customer_status': statusCode,
    // null là giá trị thật: so với bản gốc nên chỉ được gửi khi bản gốc có
    // người (= bỏ gán); máy chủ ghi null (UpdateCustomer::CLEARABLE).
    'assigned_sales_rep_id': ownerId,
  };

  /// The metadata keys this app writes. Notes go under the web's `notes` AND
  /// the `note` older app builds read — the web writes both the same way.
  Map<String, dynamic> _ownMetadata() => {
    'source': source.slug,
    'tags': tags,
    'notes': note,
    'note': note,
  };

  static bool _same(Object? a, Object? b) =>
      a is List && b is List ? listEquals(a, b) : a == b;

  /// `metadata.notes` when it is text (the web's key), else `metadata.note`.
  /// A converted lead can carry `notes` as a LIST of entries — not a note.
  static String? _noteOf(Map<String, dynamic> metadata) {
    final notes = metadata['notes'];
    if (notes is String && notes.trim().isNotEmpty) return notes.trim();
    return metadata.str('note');
  }

  /// The form's fields applied to this record — the loaded customer when
  /// editing ([Customer.blank] when creating), so what the form doesn't show
  /// (tax code, tags, type, the fine-grained status) is kept. [note] is
  /// applied as given: an emptied note box clears the note.
  Customer applyForm({
    required String name,
    required String contactName,
    required String phone,
    required String email,
    required String address,
    required Channel source,
    required CustomerStatus status,
    String? note,
  }) => copyWith(
    name: name,
    contactName: contactName,
    phone: phone,
    email: email,
    address: address,
    source: source,
    status: status,
  )._withNote(note);

  /// Bản nháp với MỘT trường đổi — đầu vào của [toPayload] cho sửa tại chỗ.
  /// [value]: `String` (phone/email/address/note), `({String? id, String? name})`
  /// (owner; id null = bỏ gán), `List<String>` (tags).
  Customer patch(CustomerField field, Object? value) => switch (field) {
    CustomerField.phone => copyWith(phone: (value as String).trim()),
    CustomerField.email => copyWith(email: (value as String).trim()),
    CustomerField.address => copyWith(address: (value as String).trim()),
    CustomerField.note => _withNote((value as String).trim()),
    CustomerField.owner => switch (value as ({String? id, String? name})) {
      // Xoá trước để tên cũ không sống sót khi tên mới null.
      (id: final id?, name: final name) => copyWith(
        clearOwner: true,
      ).copyWith(ownerId: id, ownerName: name),
      _ => copyWith(clearOwner: true),
    },
    CustomerField.tags => copyWith(
      tags: List.unmodifiable(value as List<String>),
    ),
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
    String? ownerName,
    bool clearOwner = false,
    String? note,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      code: code,
      legalName: legalName,
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
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      ownerName: clearOwner ? null : (ownerName ?? this.ownerName),
      note: note ?? this.note,
      lastInteractionAt: lastInteractionAt,
      createdAt: createdAt,
      // Kept only while the group is unchanged — see [statusCode].
      rawStatus: status == null || status == this.status ? rawStatus : null,
      metadata: metadata,
      origin: origin,
    );
  }

  Customer _withNote(String? note) => Customer(
    id: id,
    name: name,
    code: code,
    legalName: legalName,
    contactName: contactName,
    phone: phone,
    email: email,
    address: address,
    taxCode: taxCode,
    source: source,
    tags: tags,
    lifetimeValue: lifetimeValue,
    status: status,
    customerType: customerType,
    ownerId: ownerId,
    ownerName: ownerName,
    note: note,
    lastInteractionAt: lastInteractionAt,
    createdAt: createdAt,
    rawStatus: rawStatus,
    metadata: metadata,
    origin: origin,
  );

  Customer _from(Customer origin) => Customer(
    id: id,
    name: name,
    code: code,
    legalName: legalName,
    contactName: contactName,
    phone: phone,
    email: email,
    address: address,
    taxCode: taxCode,
    source: source,
    tags: tags,
    lifetimeValue: lifetimeValue,
    status: status,
    customerType: customerType,
    ownerId: ownerId,
    ownerName: ownerName,
    note: note,
    lastInteractionAt: lastInteractionAt,
    createdAt: createdAt,
    rawStatus: rawStatus,
    metadata: metadata,
    origin: origin,
  );
}
