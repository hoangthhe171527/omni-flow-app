import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/channels/application/oauth_watch.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';

ChannelConnection _connection(String id) =>
    ChannelConnection.fromJson({'id': id, 'channel_id': 'facebook'});

void main() {
  test('trả về id chưa từng thấy', () {
    expect(firstNewId({'a', 'b'}, [_connection('a'), _connection('b'), _connection('c')]), 'c');
  });

  test('không có gì mới thì trả null', () {
    expect(firstNewId({'a', 'b'}, [_connection('a'), _connection('b')]), isNull);
  });

  test('kênh biến mất không bị nhầm là kênh mới', () {
    expect(firstNewId({'a', 'b'}, [_connection('a')]), isNull);
  });

  test('vừa mất một vừa thêm một vẫn nhận ra cái mới', () {
    expect(firstNewId({'a', 'b'}, [_connection('a'), _connection('z')]), 'z');
  });

  test('danh sách trước rỗng thì kênh đầu tiên là mới', () {
    expect(firstNewId({}, [_connection('a')]), 'a');
  });
}
