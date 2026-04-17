import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/constrained_content.dart';
import '../../widgets/ikamva_app_bar_title.dart';

class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Teacher', logoHeight: 28),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: ListView(
            children: [
              ListTile(
                title: const Text('Create / edit quest'),
                subtitle: const Text('Topic, level, limits'),
                onTap: () => context.push('/teacher/quest'),
              ),
              ListTile(
                title: const Text('Class summary (on-device)'),
                onTap: () => context.push('/teacher/class'),
              ),
              ListTile(
                title: const Text('Insight cards'),
                onTap: () => context.push('/teacher/insights'),
              ),
              ListTile(
                title: const Text('Privacy & data'),
                onTap: () => context.push('/teacher/privacy'),
              ),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Exit teacher mode'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
