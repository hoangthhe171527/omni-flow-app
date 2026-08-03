import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/customers/domain/customer_permissions.dart';
import 'package:omni_app/modules/inbox/domain/inbox_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/permissions/access_scope.dart';

void main() {
  group('AccessPolicy.scopeOf', () {
    test('the unsuffixed slug means tenant-wide', () {
      const policy = AccessPolicy({'crm.customers.read'});
      expect(policy.scopeOf('crm.customers.read'), AccessScope.all);
    });

    test('picks the widest scope the session holds', () {
      const policy = AccessPolicy({
        'crm.customers.read.own',
        'crm.customers.read.team',
      });
      expect(policy.scopeOf('crm.customers.read'), AccessScope.team);
    });

    test('own-only stays own', () {
      const policy = AccessPolicy({'crm.customers.read.own'});
      expect(policy.scopeOf('crm.customers.read'), AccessScope.own);
    });

    test('nothing held is denied', () {
      const policy = AccessPolicy({'inbox.read'});
      expect(policy.scopeOf('crm.customers.read'), AccessScope.none);
    });
  });

  group('convention-based CRUD', () {
    test('reads each verb from its own slug', () {
      const policy = AccessPolicy({
        'crm.customers.read.team',
        'crm.customers.create',
        'crm.customers.update',
      });
      final access = CustomerPermissions.of(policy);

      expect(access.readScope, AccessScope.team);
      expect(access.canCreate, isTrue);
      expect(access.canUpdate, isTrue);
      expect(access.canDelete, isFalse);
    });

    test('named capabilities only appear when granted', () {
      const withApproval = AccessPolicy({'crm.quotes.read', 'crm.quotes.approve'});
      const withoutApproval = AccessPolicy({'crm.quotes.read'});

      expect(withApproval.crud('crm.quotes', capabilities: {'approve'}).can('approve'),
          isTrue);
      expect(
        withoutApproval.crud('crm.quotes', capabilities: {'approve'}).can('approve'),
        isFalse,
      );
    });
  });

  group('InboxAccess', () {
    test('write unlocks every inbox mutation at once', () {
      final access = InboxAccess.of(
        const AccessPolicy({'inbox.read', 'inbox.write'}),
      );

      expect(access.canSend, isTrue);
      expect(access.canNote, isTrue);
      expect(access.canAssign, isTrue);
      expect(access.canConvert, isTrue);
      expect(access.canLabel, isTrue);
    });

    test('read-only session can see but not act', () {
      final access = InboxAccess.of(const AccessPolicy({'inbox.read.own'}));

      expect(access.canRead, isTrue);
      expect(access.readScope, AccessScope.own);
      expect(access.canSend, isFalse);
      expect(access.hasAnyMutation, isFalse);
    });

    test('an own-scoped member is not offered the assignee filter', () {
      // Every row would be theirs — the filter would be a no-op that looks broken.
      expect(
        InboxAccess.of(const AccessPolicy({'inbox.read.own'})).showsAssigneeFilter,
        isFalse,
      );
      expect(
        InboxAccess.of(const AccessPolicy({'inbox.read'})).showsAssigneeFilter,
        isTrue,
      );
    });
  });
}
