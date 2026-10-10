import 'package:flutter/material.dart';

import '../../../design/components/components.dart';
import 'opportunities_segment.dart';

/// Lối vào `/opportunities`: cùng đoạn "Cơ hội" của tab Khách, đứng một mình
/// (mục "Cơ hội" trong "Tất cả" và đường dẫn sâu vẫn tới đây).
class PipelinePage extends StatefulWidget {
  const PipelinePage({super.key});

  @override
  State<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends State<PipelinePage> {
  bool _filtersOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OmniTopBar(
        semanticsTitle: 'Cơ hội',
        bottom: OpportunitySearchRow(
          filtersOpen: _filtersOpen,
          onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
        ),
      ),
      body: OpportunitiesSegment(filtersOpen: _filtersOpen),
    );
  }
}
