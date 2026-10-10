import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';

void main() {
  Map<String, dynamic> json(String stage, {int? probability}) => {
    'id': 'o1',
    'title': 'Piano cho con',
    'customer_id': 'c1',
    'estimated_budget': 1000,
    'opportunity_stage': stage,
    'metadata': {'probability': ?probability},
  };

  test(
    'vòng % = thắng 100, else effectiveProbability (kể cả mặc định phễu)',
    () {
      final won = Opportunity.fromJson(json('won'));
      expect(won.displayPercent(), 100);

      final noProb = Opportunity.fromJson(json('tu_van'));
      expect(noProb.displayPercent(), noProb.effectiveProbability());

      final set = Opportunity.fromJson(json('tu_van', probability: 35));
      expect(set.displayPercent(), 35);
    },
  );
}
