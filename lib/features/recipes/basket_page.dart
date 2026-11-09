import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import 'basket_view.dart';

class BasketPage extends StatelessWidget {
  const BasketPage({super.key, this.onOpenPlans});

  final VoidCallback? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: PageHeader(
            title: '菜篮子',
            subtitle: '记下家里的食材，按热量和天数生成食谱',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: BasketView(onOpenPlans: onOpenPlans)),
      ],
    );
  }
}
