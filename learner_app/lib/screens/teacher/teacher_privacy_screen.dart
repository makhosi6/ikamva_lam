import 'package:flutter/material.dart';

import '../../widgets/constrained_content.dart';
import '../../widgets/ikamva_app_bar_title.dart';

/// Visible privacy copy (TASKS §13.5, design §7).
class TeacherPrivacyScreen extends StatelessWidget {
  const TeacherPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Privacy', logoHeight: 28),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: const Text(
            'Ikamva Lam keeps learner practice on this device by default. '
            'Teacher views use summaries and aggregates — not raw chat logs. '
            'When sync is enabled, only compressed summary JSON leaves the tablet, '
            'as described in docs/api_sync_contract.md.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
        ),
      ),
    );
  }
}
