/// Một trường khách sửa tại chỗ (từng ô một). `apiKey` là khoá của
/// `UpdateCustomerRequest` (omni-flow-api) mà ô đó ghi — `note` và `tags` cùng
/// nằm trong `metadata` (máy chủ gộp NÔNG từng khoá con).
enum CustomerField {
  phone,
  email,
  address,
  note,
  owner,
  tags;

  String get label => switch (this) {
    CustomerField.phone => 'Điện thoại',
    CustomerField.email => 'Email',
    CustomerField.address => 'Địa chỉ',
    CustomerField.note => 'Ghi chú',
    CustomerField.owner => 'Phụ trách',
    CustomerField.tags => 'Nhãn',
  };

  String get apiKey => switch (this) {
    CustomerField.phone => 'primary_contact_phone',
    CustomerField.email => 'primary_contact_email',
    CustomerField.address => 'address',
    CustomerField.note => 'metadata',
    CustomerField.owner => 'assigned_sales_rep_id',
    CustomerField.tags => 'metadata',
  };
}
