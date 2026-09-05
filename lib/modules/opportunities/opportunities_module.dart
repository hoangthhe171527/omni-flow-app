import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/opportunity_permissions.dart';
import 'presentation/opportunity_detail_page.dart';
import 'presentation/opportunity_form_page.dart';
import 'presentation/pipeline_page.dart';

class OpportunitiesModule extends OmniModule {
  const OpportunitiesModule();

  static const pipeline = 'opportunities.pipeline';
  static const detail = 'opportunities.detail';
  static const create = 'opportunities.create';
  static const edit = 'opportunities.edit';

  @override
  String get id => 'opportunities';

  @override
  String get title => 'Cơ hội';

  @override
  List<String> get permissions => OpportunityPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/opportunities',
      name: pipeline,
      access: const AccessRequirement.any(OpportunityPermissions.anyRead),
      builder: (_, _) => const PipelinePage(),
    ),
    ModuleRoute(
      path: '/opportunities/new',
      name: create,
      rootNavigator: true,
      access: const AccessRequirement.any([OpportunityPermissions.create]),
      // `?customer=<id>` pre-selects the customer when the form is opened
      // from a profile or a chat thread.
      builder: (_, state) => OpportunityFormPage(
        customerId: state.uri.queryParameters['customer'],
      ),
    ),
    ModuleRoute(
      path: '/opportunities/:id',
      name: detail,
      rootNavigator: true,
      access: const AccessRequirement.any(OpportunityPermissions.anyRead),
      builder: (_, state) =>
          OpportunityDetailPage(opportunityId: state.pathParameters['id']!),
    ),
    ModuleRoute(
      path: '/opportunities/:id/edit',
      name: edit,
      rootNavigator: true,
      access: const AccessRequirement.any([OpportunityPermissions.update]),
      builder: (_, state) =>
          OpportunityFormPage(opportunityId: state.pathParameters['id']!),
    ),
  ];

  /// Reached through "Thêm" rather than a tab.
  ///
  /// Four tabs is the ceiling and "Việc của tôi" took this slot: the people who
  /// use the phone all day are on the workshop floor, and a sales pipeline is
  /// not what they need at arm's reach. Sales work happens on the web, where
  /// the pipeline keeps its place.
  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'opportunities',
      label: 'Cơ hội',
      subtitle: 'Theo dõi cơ hội bán hàng',
      icon: Icons.trending_up_outlined,
      selectedIcon: Icons.trending_up_rounded,
      routeName: pipeline,
      area: NavArea.sales,
      // Người bán hàng sống ở đây cả ngày; người thợ thì không có quyền và
      // cũng không thấy nó. Quyền tự lo việc đó.
      weight: NavWeight.primary,
      order: 20,
      access: AccessRequirement.any(OpportunityPermissions.anyRead),
    ),
  ];
}
