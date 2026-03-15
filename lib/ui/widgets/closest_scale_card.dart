// Modified content of closest_scale_card.dart

import 'package:flutter/material.dart';
import 'package:your_project_name/theme/app_theme.dart'; // Adjust import path as needed

class ClosestScaleCard extends StatelessWidget {
  final Scale scale;

  ClosestScaleCard({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSM, vertical: AppTheme.spaceXS + 2), // Adjusted padding
        child: Column(
          children: <Widget>[
            // Removed Text(scale.name, ...) section to hide scale name
            // Include other widgets as needed
          ],
        ),
      ),
    );
  }
}